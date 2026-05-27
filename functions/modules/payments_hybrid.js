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
 * ÉTAPE 1 : Initialisation ou exécution directe du paiement
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

        // Extraction des bases financières de base
        const balanceWallet = parseFloat(walletData.balance || 0);
        const pointsFidelite = parseFloat(userData.wallet_points || 0);
        const creditsBailleur = parseFloat(userData.commission_credit || 0);

        // 🟢 SÉCURISATION & HARMONISATION : Gestion stricte de la date d'expiration du bonus
        const bonusExpiryTimestamp = walletData.bonusExpiryDate;
        let bonusWallet = parseFloat(walletData.bonusBalance || 0);

        if (bonusExpiryTimestamp) {
            const expiryDate = bonusExpiryTimestamp.toDate();
            if (new Date() > expiryDate) {
                bonusWallet = 0.0; // Le bonus a expiré, on le neutralise immédiatement
            }
        }

        // Calcul des fonds disponibles réels et valides
        const totalInterneDisponible = Math.round((balanceWallet + bonusWallet + pointsFidelite + creditsBailleur) * 100) / 100;

        // =================================================================
        // CAS A & B : Paiement 100% interne -> Traitement et déduction directe sécurisés
        // =================================================================
        if (totalInterneDisponible >= amount) {
            let restantADeduire = amount;
            
            const deduitePoints = Math.min(pointsFidelite, restantADeduire);
            restantADeduire = Math.round((restantADeduire - deduitePoints) * 100) / 100;

            const deduiteBonus = Math.min(bonusWallet, restantADeduire);
            restantADeduire = Math.round((restantADeduire - deduiteBonus) * 100) / 100;

            const deduiteCommissions = Math.min(creditsBailleur, restantADeduire);
            restantADeduire = Math.round((restantADeduire - deduiteCommissions) * 100) / 100;

            const deduiteBalance = Math.min(balanceWallet, restantADeduire);
            restantADeduire = Math.round((restantADeduire - deduiteBalance) * 100) / 100;

            await db.runTransaction(async (transaction) => {
                const walletRef = db.collection('wallets').doc(userId);
                const userRef = db.collection('utilisateurs').doc(userId);

                // Déduction atomique sur les documents respectifs
                transaction.update(walletRef, {
                    balance: getFieldValue().increment(-deduiteBalance),
                    bonusBalance: getFieldValue().increment(-deduiteBonus),
                    lastUpdate: getFieldValue().serverTimestamp()
                });

                transaction.update(userRef, {
                    wallet_points: getFieldValue().increment(-deduitePoints),
                    commission_credit: getFieldValue().increment(-deduiteCommissions),
                    last_wallet_usage: getFieldValue().serverTimestamp()
                });

                // Enregistrement immédiat dans l'historique des opérations
                const historyRef = walletRef.collection('operations').doc();
                transaction.set(historyRef, {
                    type: "ACHAT_INTERNE_DIRECT",
                    serviceId: serviceId || "service_unique",
                    montantTotal: amount,
                    detail: `Wallet: ${deduiteBalance}$, Bonus: ${deduiteBonus}$, Points: ${deduitePoints}$, Commissions: ${deduiteCommissions}$, Passerelle: 0$`,
                    date: getFieldValue().serverTimestamp()
                });

                // Activation instantanée du service VIP si requis
                if (serviceType && serviceType.toUpperCase().includes('VIP')) {
                    transaction.update(userRef, { "statusVIP": "active" });
                }
            });

            return {
                status: "INTERNAL_PAYMENT_COMPLETED",
                message: "Paiement interne effectué et sécurisé avec succès.",
                amountPaid: amount,
                details: {
                    deductions: {
                        wallet: deduiteBalance,
                        bonus: deduiteBonus,
                        points: deduitePoints,
                        commissions: deduiteCommissions
                    }
                }
            };
        }

        // =================================================================
        // CAS C : Paiement Hybride ou Externe requis -> Génération de l'intention d'attente
        // =================================================================
        
        // Un paiement est un VRAI hybride seulement si l'utilisateur possède au moins un reliquat interne à vider
        const isRealHybrid = totalInterneDisponible > 0;
        
        const reliquatPasserelle = isRealHybrid 
            ? Math.round((amount - totalInterneDisponible) * 100) / 100
            : amount;

        const hybridRef = `HYB-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

        // Sauvegarde de l'intention de paiement avec les fonds réels mobilisés
        await db.collection('pending_payments').doc(hybridRef).set({
            userId,
            serviceId: serviceId || "service_unique",
            serviceType: serviceType || "divers",
            amountTotal: amount,
            // Si ce n'est pas un vrai hybride, on force l'écriture à 0 pour éviter d'embarquer des valeurs d'anciens reliquats
            fromWallet: isRealHybrid ? balanceWallet : 0,
            fromBonus: isRealHybrid ? bonusWallet : 0, 
            fromPoints: isRealHybrid ? pointsFidelite : 0,
            fromCommissions: isRealHybrid ? creditsBailleur : 0,
            amountToPayGateway: reliquatPasserelle,
            isHybrid: isRealHybrid, // 🟢 Flag crucial transmis directement pour le webhook final
            status: "awaiting_gateway",
            metadata: metadata || {},
            createdAt: getFieldValue().serverTimestamp()
        });

        return {
            status: "REQUIRES_EXTERNAL_PAYMENT",
            amountToPayGateway: reliquatPasserelle,
            paymentReference: hybridRef,
            details: {
                cumulInterne: isRealHybrid ? totalInterneDisponible : 0,
                resteAPayer: reliquatPasserelle,
                isHybrid: isRealHybrid
            }
        };

    } catch (error) {
        console.error("Erreur initiateHybridPayment:", error);
        throw new HttpsError('internal', error.message);
    }
});

/**
 * ÉTAPE 2 : Finalisation (Appelée par le Webhook dans payments.js)
 * Traite la déduction finale une fois que MaxiCash confirme la transaction hybride.
 */
exports.finalizeHybridTransaction = async (transactionId) => {
    const db = getDb();
    const pendingRef = db.collection('pending_payments').doc(transactionId);
    
    try {
        await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(pendingRef);
            
            // Sécurité Idempotence : évite les doubles traitements réseaux
            if (!doc.exists || doc.data().status !== 'awaiting_gateway') {
                console.log(`Paiement hybride ${transactionId} déjà traité ou inexistant.`);
                return;
            }

            const data = doc.data();
            const userId = data.userId;
            const walletRef = db.collection('wallets').doc(userId);
            const userRef = db.collection('utilisateurs').doc(userId);

            // 1. Déduction atomique des différents portefeuilles internes engagés lors de l'initiation
            // Grâce à notre sécurité, si isHybrid était false, tous ces incréments vaudront -0, donc aucun impact.
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

            // 2. Clôture de l'intention de paiement
            transaction.update(pendingRef, { 
                status: "completed",
                completedAt: getFieldValue().serverTimestamp()
            });

            // 3. Enregistrement historique adapté au type réel de transaction
            const historyRef = walletRef.collection('operations').doc();
            transaction.set(historyRef, {
                type: data.isHybrid ? "ACHAT_HYBRIDE" : "ACHAT_EXTERNE_MAXICASH",
                serviceId: data.serviceId,
                montantTotal: data.amountTotal,
                detail: `Wallet: ${data.fromWallet}$, Bonus: ${data.fromBonus}$, Points: ${data.fromPoints}$, Commissions: ${data.fromCommissions}$, Passerelle: ${data.amountToPayGateway}$`,
                date: getFieldValue().serverTimestamp()
            });
            
            // 4. Activation du service VIP si nécessaire
            if (data.serviceType && data.serviceType.toUpperCase().includes('VIP')) {
                 transaction.update(userRef, { "statusVIP": "active" });
            }
        });
        
        console.log(`Paiement hybride/externe ${transactionId} finalisé avec succès.`);
        return true;
    } catch (e) {
        console.error("Erreur critique finalizeHybridTransaction:", e);
        return false;
    }
};