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
 * ÉTAPE 1 : Initialisation ou exécution directe du paiement (Optimisé)
 */
exports.initiateHybridPayment = onCall({ region: region }, async (request) => {
    const db = getDb();
    
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Vous devez être connecté.');
    }

    const { serviceId, serviceType, totalAmount, metadata } = request.data;
    const userId = request.auth.uid;
    const amount = parseFloat(totalAmount);

    if (!amount || amount <= 0) {
        throw new HttpsError('invalid-argument', 'Le montant total est invalide.');
    }

    try {
        // Lecture unique dans la collection WALLETS
        const walletDoc = await db.collection('wallets').doc(userId).get();
        const walletData = walletDoc.exists ? walletDoc.data() : {};

        // Extraction des soldes unifiés
        const balance = parseFloat(walletData.balance || 0);
        const bonus = parseFloat(walletData.bonusBalance || 0);
        const cashback = parseFloat(walletData.cashback_balance || 0);
        const commission = parseFloat(walletData.commission_balance || 0);

        // Gestion expiration bonus
        let bonusWallet = bonus;
        if (walletData.bonusExpiryDate && new Date() > walletData.bonusExpiryDate.toDate()) {
            bonusWallet = 0;
        }

        const totalInterne = Math.round((balance + bonusWallet + cashback + commission) * 100) / 100;

        // CAS A & B : Paiement 100% interne
        if (totalInterne >= amount) {
            let restant = amount;
            
            const dCashback = Math.min(cashback, restant); restant -= dCashback;
            const dBonus = Math.min(bonusWallet, restant); restant -= dBonus;
            const dCommission = Math.min(commission, restant); restant -= dCommission;
            const dBalance = Math.min(balance, restant); restant -= dBalance;

            await db.runTransaction(async (transaction) => {
                const walletRef = db.collection('wallets').doc(userId);
                
                // Déduction atomique centralisée
                transaction.update(walletRef, {
                    balance: getFieldValue().increment(-dBalance),
                    bonusBalance: getFieldValue().increment(-dBonus),
                    cashback_balance: getFieldValue().increment(-dCashback),
                    commission_balance: getFieldValue().increment(-dCommission),
                    lastUpdate: getFieldValue().serverTimestamp()
                });

                // Historique
                const historyRef = walletRef.collection('operations').doc();
                transaction.set(historyRef, {
                    type: "ACHAT_INTERNE_DIRECT",
                    serviceId: serviceId || "service_unique",
                    amountTotal: amount,
                    detail: `W:${dBalance}, B:${dBonus}, C:${dCashback}, Com:${dCommission}, P:0`,
                    date: getFieldValue().serverTimestamp()
                });

                // Activation VIP si requis
                if (serviceType && serviceType.toUpperCase().includes('VIP')) {
                    transaction.update(db.collection('utilisateurs').doc(userId), { "statusVIP": "active" });
                }
            });

            return { status: "INTERNAL_PAYMENT_COMPLETED", amountPaid: amount };
        }

        // CAS C : Paiement Hybride
        const isRealHybrid = totalInterne > 0;
        const reliquatPasserelle = isRealHybrid ? Math.round((amount - totalInterne) * 100) / 100 : amount;
        const hybridRef = `HYB-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

        await db.collection('pending_payments').doc(hybridRef).set({
            userId,
            serviceId: serviceId || "service_unique",
            serviceType: serviceType || "divers",
            amountTotal: amount,
            fromWallet: isRealHybrid ? balance : 0,
            fromBonus: isRealHybrid ? bonusWallet : 0, 
            fromCashback: isRealHybrid ? cashback : 0,
            fromCommission: isRealHybrid ? commission : 0,
            amountToPayGateway: reliquatPasserelle,
            isHybrid: isRealHybrid,
            status: "awaiting_gateway",
            metadata: metadata || {},
            createdAt: getFieldValue().serverTimestamp()
        });

        return { status: "REQUIRES_EXTERNAL_PAYMENT", amountToPayGateway: reliquatPasserelle, paymentReference: hybridRef };

    } catch (error) {
        console.error("Erreur initiateHybridPayment:", error);
        throw new HttpsError('internal', error.message);
    }
});

/**
 * ÉTAPE 2 : Finalisation
 */
exports.finalizeHybridTransaction = async (transactionId) => {
    const db = getDb();
    const pendingRef = db.collection('pending_payments').doc(transactionId);
    
    try {
        await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(pendingRef);
            if (!doc.exists || doc.data().status !== 'awaiting_gateway') return;

            const data = doc.data();
            const walletRef = db.collection('wallets').doc(data.userId);

            // 1. Déduction centralisée
            transaction.update(walletRef, {
                balance: getFieldValue().increment(-data.fromWallet),
                bonusBalance: getFieldValue().increment(-data.fromBonus),
                cashback_balance: getFieldValue().increment(-data.fromCashback),
                commission_balance: getFieldValue().increment(-data.fromCommission),
                lastUpdate: getFieldValue().serverTimestamp()
            });

            // 2. Clôture intention
            transaction.update(pendingRef, { status: "completed", completedAt: getFieldValue().serverTimestamp() });

            // 3. Historique
            const historyRef = walletRef.collection('operations').doc();
            transaction.set(historyRef, {
                type: data.isHybrid ? "ACHAT_HYBRIDE" : "ACHAT_EXTERNE_MAXICASH",
                serviceId: data.serviceId,
                amountTotal: data.amountTotal,
                detail: `W:${data.fromWallet}, B:${data.fromBonus}, C:${data.fromCashback}, Com:${data.fromCommission}, P:${data.amountToPayGateway}`,
                date: getFieldValue().serverTimestamp()
            });
            
            // 4. VIP
            if (data.serviceType && data.serviceType.toUpperCase().includes('VIP')) {
                 transaction.update(db.collection('utilisateurs').doc(data.userId), { "statusVIP": "active" });
            }
        });
        return true;
    } catch (e) {
        console.error("Erreur finalizeHybridTransaction:", e);
        return false;
    }
};