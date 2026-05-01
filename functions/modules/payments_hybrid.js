const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const crypto = require('crypto');

// Initialisation sécurisée
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const getDb = () => admin.firestore();
const getFieldValue = () => admin.firestore.FieldValue;
const region = 'europe-west1';

/**
 * ÉTAPE 1 : Initialisation du paiement hybride
 * Accessible depuis Flutter via Callable Function
 */
exports.initiateHybridPayment = onCall({ region: region }, async (request) => {
    const db = getDb();
    
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Vous devez être connecté.');
    }

    const { serviceId, serviceType, totalAmount, metadata } = request.data;
    const userId = request.auth.uid;

    // Sécurité : on s'assure que le montant est traité comme un nombre propre
    const amount = parseFloat(totalAmount);

    if (!amount || amount <= 0) {
        throw new HttpsError('invalid-argument', 'Le montant total est invalide.');
    }

    try {
        // Lecture des soldes actuels
        const [walletDoc, userDoc] = await Promise.all([
            db.collection('wallets').doc(userId).get(),
            db.collection('utilisateurs').doc(userId).get()
        ]);

        const walletData = walletDoc.exists ? walletDoc.data() : {};
        if (!userDoc.exists) throw new HttpsError('not-found', 'Profil utilisateur introuvable.');
        const userData = userDoc.data();

        // Calcul des fonds disponibles (Arrondi à 2 décimales pour éviter les bugs de précision JS)
        const balanceWallet = parseFloat(walletData.balance || 0);
        const bonusWallet = parseFloat(walletData.bonusBalance || 0);
        const pointsFidelite = parseFloat(userData.wallet_points || 0);
        const creditsBailleur = parseFloat(userData.commission_credit || 0);

        const totalInterneDisponible = Math.round((balanceWallet + bonusWallet + pointsFidelite + creditsBailleur) * 100) / 100;

        // Cas A : Paiement 100% interne (Direct)
        if (totalInterneDisponible >= amount) {
            return {
                status: "INTERNAL_PAYMENT_POSSIBLE",
                message: "Solde suffisant pour paiement interne.",
                internalAvailable: totalInterneDisponible
            };
        }

        // Cas B : Paiement Hybride requis
        const reliquatPasserelle = Math.round((amount - totalInterneDisponible) * 100) / 100;
        const hybridRef = `HYB-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

        // Sauvegarde de l'intention de paiement
        await db.collection('pending_payments').doc(hybridRef).set({
            userId,
            serviceId: serviceId || "service_unique",
            serviceType: serviceType || "divers",
            amountTotal: amount,
            fromWallet: balanceWallet,
            fromBonus: bonusWallet,
            fromPoints: pointsFidelite,
            fromCommissions: creditsBailleur,
            amountToPayGateway: reliquatPasserelle,
            status: "awaiting_gateway",
            metadata: metadata || {},
            createdAt: getFieldValue().serverTimestamp()
        });

        return {
            status: "REQUIRES_EXTERNAL_PAYMENT",
            amountToPayGateway: reliquatPasserelle,
            paymentReference: hybridRef,
            details: {
                cumulInterne: totalInterneDisponible,
                resteAPayer: reliquatPasserelle
            }
        };

    } catch (error) {
        console.error("Erreur initiateHybridPayment:", error);
        throw new HttpsError('internal', error.message);
    }
});

/**
 * ÉTAPE 2 : Finalisation (Exportée pour être appelée par le Webhook dans payments.js)
 * Cette fonction traite la déduction des fonds internes une fois que la passerelle a confirmé le paiement.
 */
exports.finalizeHybridTransaction = async (transactionId) => {
    const db = getDb();
    const pendingRef = db.collection('pending_payments').doc(transactionId);
    
    try {
        await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(pendingRef);
            
            // Vérification de sécurité pour éviter le double traitement
            if (!doc.exists || doc.data().status !== 'awaiting_gateway') {
                console.log(`Paiement hybride ${transactionId} déjà traité ou inexistant.`);
                return;
            }

            const data = doc.data();
            const userId = data.userId;
            const walletRef = db.collection('wallets').doc(userId);
            const userRef = db.collection('utilisateurs').doc(userId);

            // 1. Déduction atomique des différents portefeuilles internes
            transaction.update(walletRef, {
                balance: getFieldValue().increment(-data.fromWallet),
                bonusBalance: getFieldValue().increment(-data.fromBonus),
                lastUpdate: getFieldValue().serverTimestamp()
            });

            transaction.update(userRef, {
                wallet_points: getFieldValue().increment(-data.fromPoints),
                commission_credit: getFieldValue().increment(-data.fromCommissions),
                last_wallet_usage: getFieldValue().serverTimestamp()
            });

            // 2. Marquer le paiement comme complété
            transaction.update(pendingRef, { 
                status: "completed",
                completedAt: getFieldValue().serverTimestamp()
            });

            // 3. Enregistrement dans l'historique des opérations du wallet
            const historyRef = walletRef.collection('operations').doc();
            transaction.set(historyRef, {
                type: "ACHAT_HYBRIDE",
                serviceId: data.serviceId,
                montantTotal: data.amountTotal,
                detail: `Wallet: ${data.fromWallet}$, Bonus: ${data.fromBonus}$, Points: ${data.fromPoints}$, Commissions: ${data.fromCommissions}$, Passerelle: ${data.amountToPayGateway}$`,
                date: getFieldValue().serverTimestamp()
            });
            
            // 4. Activation de service VIP si le type de service le mentionne
            if (data.serviceType && data.serviceType.toUpperCase().includes('VIP')) {
                 transaction.update(userRef, { "statusVIP": "active" });
            }
        });
        
        console.log(`Paiement hybride ${transactionId} finalisé avec succès.`);
        return true;
    } catch (e) {
        console.error("Erreur critique finalizeHybridTransaction:", e);
        return false;
    }
};