const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const crypto = require('crypto');

if (admin.apps.length === 0) { admin.initializeApp(); }

const getDb = () => admin.firestore();
const getFieldValue = () => admin.firestore.FieldValue;
const region = 'europe-west1';

exports.initiateHybridPayment = onCall({ region: region }, async (request) => {
    const db = getDb();
    if (!request.auth) throw new HttpsError('unauthenticated', 'Connectez-vous.');

    const { serviceId, serviceType, totalAmount, metadata, walletAmountRequested, partLocataire } = request.data;
    const userId = request.auth.uid;
    const amount = parseFloat(totalAmount);
    
    if (!amount || amount <= 0) throw new HttpsError('invalid-argument', 'Montant invalide.');

    const limiteMaxWallet = parseFloat(partLocataire || 0) * 0.25;
    const montantWalletFinal = Math.min(parseFloat(walletAmountRequested || 0), limiteMaxWallet);

    try {
        const walletDoc = await db.collection('wallets').doc(userId).get();
        const w = walletDoc.exists ? walletDoc.data() : {};
        
        const bonusWallet = (w.bonusExpiryDate && new Date() > w.bonusExpiryDate.toDate()) ? 0 : (parseFloat(w.bonusBalance) || 0);
        const cashback = parseFloat(w.cashback_balance) || 0;
        const commission = parseFloat(w.commission_balance) || 0;
        const balance = parseFloat(w.balance) || 0;

        let restant = montantWalletFinal;
        const dBonus = Math.min(bonusWallet, restant); restant -= dBonus;
        const dCashback = Math.min(cashback, restant); restant -= dCashback;
        const dCommission = Math.min(commission, restant); restant -= dCommission;
        const dBalance = Math.min(balance, restant); restant -= dBalance;

        const reliquatPasserelle = Math.round((amount - montantWalletFinal) * 100) / 100;
        const hybridRef = `HYB-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

        await db.collection('pending_payments').doc(hybridRef).set({
            userId, serviceId, serviceType,
            amountTotal: amount,
            fromWallet: dBalance,
            fromBonus: dBonus,
            fromCashback: dCashback,
            fromCommission: dCommission,
            amountToPayGateway: reliquatPasserelle,
            isHybrid: montantWalletFinal > 0,
            status: "awaiting_gateway",
            metadata: metadata || {},
            createdAt: getFieldValue().serverTimestamp()
        });

        return { 
            status: reliquatPasserelle <= 0 ? "INTERNAL_PAYMENT_COMPLETED" : "REQUIRES_EXTERNAL_PAYMENT", 
            amountToPayGateway: reliquatPasserelle, 
            paymentReference: hybridRef 
        };
    } catch (error) {
        console.error("Erreur initiateHybridPayment:", error);
        throw new HttpsError('internal', error.message);
    }
});

exports.finalizeHybridTransaction = async (transactionId) => {
    const db = getDb();
    const pendingRef = db.collection('pending_payments').doc(transactionId);
    
    try {
        await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(pendingRef);
            if (!doc.exists || doc.data().status !== 'awaiting_gateway') return;

            const data = doc.data();
            const walletRef = db.collection('wallets').doc(data.userId);

            transaction.update(walletRef, {
                balance: getFieldValue().increment(-data.fromWallet),
                bonusBalance: getFieldValue().increment(-data.fromBonus),
                cashback_balance: getFieldValue().increment(-data.fromCashback),
                commission_balance: getFieldValue().increment(-data.fromCommission),
                lastUpdate: getFieldValue().serverTimestamp()
            });

            transaction.update(pendingRef, { status: "completed", completedAt: getFieldValue().serverTimestamp() });

            const historyRef = walletRef.collection('operations').doc();
            transaction.set(historyRef, {
                type: data.isHybrid ? "ACHAT_HYBRIDE" : "ACHAT_EXTERNE_MAXICASH",
                serviceId: data.serviceId,
                amountTotal: data.amountTotal,
                detail: `W:${data.fromWallet}, B:${data.fromBonus}, C:${data.fromCashback}, Com:${data.fromCommission}, P:${data.amountToPayGateway}`,
                date: getFieldValue().serverTimestamp()
            });
            
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

// --- NOUVELLE FONCTION DE REMBOURSEMENT CENTRALISÉE ---
exports.annulerReservationEtRembourser = onCall({ region: region }, async (request) => {
    const { transactionId } = request.data; 
    const db = getDb();
    
    // On cherche dans pending_payments le document qui a le serviceId correspondant à la facture
    const pendingSnap = await db.collection('pending_payments')
        .where('serviceId', '==', transactionId)
        .where('status', '==', 'completed')
        .get();
    
    if (pendingSnap.empty) {
        throw new HttpsError('not-found', 'Aucune transaction complétée trouvée pour cet ID.');
    }
    
    const doc = pendingSnap.docs[0];
    const data = doc.data();
    const walletRef = db.collection('wallets').doc(data.userId);

    await db.runTransaction(async (t) => {
        // 1. Recréditer les poches
        t.update(walletRef, {
            balance: getFieldValue().increment(data.fromWallet || 0),
            bonusBalance: getFieldValue().increment(data.fromBonus || 0),
            cashback_balance: getFieldValue().increment(data.fromCashback || 0),
            commission_balance: getFieldValue().increment(data.fromCommission || 0),
            lastUpdate: getFieldValue().serverTimestamp()
        });

        // 2. Marquer la transaction comme remboursée
        t.update(doc.ref, { status: "refunded" });

        // 3. Ajouter une ligne d'historique
        const histRef = walletRef.collection('operations').doc();
        t.set(histRef, {
            type: "REMBOURSEMENT_ANNULATION",
            serviceId: data.serviceId,
            amountTotal: data.amountTotal,
            detail: "Remboursement suite à annulation de réservation",
            date: getFieldValue().serverTimestamp()
        });
    });

    return { status: "success" };
});