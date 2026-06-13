// functions/modules/payments_hybrid.js

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const crypto = require('crypto');

if (admin.apps.length === 0) { admin.initializeApp(); }

const getDb = () => admin.firestore();
const getFieldValue = () => admin.firestore.FieldValue;
const region = 'europe-west1';

// --- UTILITAIRE DE CALCUL DE DÉBIT WALLET ---
exports.calculateWalletDeduction = (walletData, requestedAmount) => {
    const bonus = (walletData.bonusExpiryDate && new Date() > walletData.bonusExpiryDate.toDate()) ? 0 : (parseFloat(walletData.bonusBalance) || 0);
    const cashback = parseFloat(walletData.cashback_balance) || 0;
    const commission = parseFloat(walletData.commission_balance) || 0;
    const balance = parseFloat(walletData.balance) || 0;

    let restant = parseFloat(requestedAmount || 0);
    const dBonus = Math.min(bonus, restant); restant -= dBonus;
    const dCashback = Math.min(cashback, restant); restant -= dCashback;
    const dCommission = Math.min(commission, restant); restant -= dCommission;
    const dBalance = Math.min(balance, restant); restant -= dBalance;

    return { 
        dBonus, 
        dCashback, 
        dCommission, 
        dBalance, 
        totalDebited: parseFloat(requestedAmount || 0) - restant 
    };
};

// --- FONCTION DE SÉCURITÉ AMÉLIORÉE ---
const checkWalletAccess = async (db, userId) => {
    const userDoc = await db.collection('utilisateurs').doc(userId).get();
    if (!userDoc.exists) throw new HttpsError('not-found', 'Utilisateur introuvable.');
    
    const walletDoc = await db.collection('wallets').doc(userId).get();
    if (!walletDoc.exists) throw new HttpsError('not-found', 'Portefeuille inexistant.');
    
    const walletData = walletDoc.data();
    if (walletData.status !== 'active') throw new HttpsError('permission-denied', 'Wallet suspendu.');

    const userData = userDoc.data();
    const roles = userData.roles || [];
    
    const authorizedRoles = ['locataire', 'bailleur', 'super_admin', 'SUPER_ADMIN', 'operations', 'agent'];
    const isAuthorized = roles.some(r => authorizedRoles.includes(r));

    if (!isAuthorized) {
        throw new HttpsError('permission-denied', 'Votre compte n\'est pas habilité pour des transactions financières.');
    }
    
    return walletData;
};

// --- 1. PAIEMENT HYBRIDE ---
exports.initiateHybridPayment = onCall({ region: region }, async (request) => {
    const db = getDb();
    if (!request.auth) throw new HttpsError('unauthenticated', 'Connectez-vous.');
    const userId = request.auth.uid;

    const w = await checkWalletAccess(db, userId);

    const { serviceId, serviceType, totalAmount, metadata, walletAmountRequested, partLocataire } = request.data;
    
    const safeServiceType = serviceType || 'standard'; 

    const amount = parseFloat(totalAmount);
    if (!amount || amount <= 0) throw new HttpsError('invalid-argument', 'Montant invalide.');

    const limiteMaxWallet = parseFloat(partLocataire || 0) * 0.25;
    const montantWalletFinal = Math.min(parseFloat(walletAmountRequested || 0), limiteMaxWallet);

    const deduction = exports.calculateWalletDeduction(w, montantWalletFinal);

    const reliquatPasserelle = Math.round((amount - montantWalletFinal) * 100) / 100;
    const hybridRef = `HYB-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    
    const factureReference = metadata?.factureReference || metadata?.factureId || null;

    await db.collection('pending_payments').doc(hybridRef).set({
        userId, 
        serviceId, 
        serviceType: safeServiceType,
        factureReference: factureReference, 
        amountTotal: amount,
        fromWallet: deduction.dBalance, 
        fromBonus: deduction.dBonus, 
        fromCashback: deduction.dCashback, 
        fromCommission: deduction.dCommission,
        amountToPayGateway: reliquatPasserelle,
        isHybrid: montantWalletFinal > 0,
        status: "awaiting_gateway",
        metadata: metadata || {},
        createdAt: getFieldValue().serverTimestamp()
    });

    return { status: reliquatPasserelle <= 0 ? "INTERNAL_PAYMENT_COMPLETED" : "REQUIRES_EXTERNAL_PAYMENT", amountToPayGateway: reliquatPasserelle, paymentReference: hybridRef };
});

// --- 2. PAIEMENT 100% CASH (STANDARD) ---
exports.initiateStandardPayment = onCall({ region: region }, async (request) => {
    const db = getDb();
    if (!request.auth) throw new HttpsError('unauthenticated', 'Connectez-vous.');
    const userId = request.auth.uid;
    const { bienId, refBien, montantTotal, montantWallet } = request.data;

    await checkWalletAccess(db, userId);

    const factureRef = db.collection('factures').doc();
    const bienRef = db.collection('proprietes').doc(bienId);

    await db.runTransaction(async (t) => {
        t.set(factureRef, {
            clientUid: userId, propertyId: bienId, refBien: refBien, methodePaiement: 'cash',
            status: 'pending', montantTotal: montantTotal, montantAPayer: montantTotal - montantWallet,
            montantWallet: montantWallet, dateCreation: getFieldValue().serverTimestamp()
        });
        t.update(bienRef, { status: 'en_attente_cash' });
    });
    return { factureId: factureRef.id };
});

// --- 3. TRANSFERT P2P SÉCURISÉ ---
exports.transferCredits = onCall({ region: region }, async (request) => {
    const db = getDb();
    if (!request.auth) throw new HttpsError('unauthenticated', 'Connectez-vous.');
    const senderId = request.auth.uid;
    const { receiverPhone, amount } = request.data;

    const senderWallet = await checkWalletAccess(db, senderId);
    if ((senderWallet.balance + senderWallet.bonusBalance + senderWallet.cashback_balance + senderWallet.commission_balance) < amount) {
        throw new HttpsError('failed-precondition', 'Solde insuffisant.');
    }

    const receiverQuery = await db.collection('utilisateurs').where('phoneNumber', '==', receiverPhone).limit(1).get();
    if (receiverQuery.empty) throw new HttpsError('not-found', 'Destinataire introuvable.');
    const receiverId = receiverQuery.docs[0].id;

    await db.runTransaction(async (t) => {
        t.update(db.collection('wallets').doc(senderId), { balance: getFieldValue().increment(-amount) });
        t.update(db.collection('wallets').doc(receiverId), { bonusBalance: getFieldValue().increment(amount) });
        
        const tx = db.collection('transactions').doc();
        t.set(tx, { walletId: senderId, userId: senderId, title: "Transfert P2P", amount: amount, isPositive: false, type: 'p2p_transfer', date: getFieldValue().serverTimestamp() });
    });
    return { status: "success" };
});

// --- 4. FINALISATION & REMBOURSEMENT ---
exports.finalizeHybridTransaction = async (transactionId) => {
    const db = getDb();
    const pendingRef = db.collection('pending_payments').doc(transactionId);
    
    try {
        return await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(pendingRef);
            if (!doc.exists) return false;
            if (doc.data().status !== 'awaiting_gateway') return false;
            
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

            const txRef = db.collection('transactions').doc();
            transaction.set(txRef, {
                walletId: data.userId, userId: data.userId, title: data.isHybrid ? "Achat Hybride" : "Achat Externe",
                amount: data.amountTotal, isPositive: false, type: data.isHybrid ? "ACHAT_HYBRIDE" : "ACHAT_EXTERNE",
                serviceId: data.serviceId, date: getFieldValue().serverTimestamp()
            });
            
            if (data.serviceType && data.serviceType.toUpperCase().includes('VIP')) {
                const expiryDate = new Date();
                expiryDate.setDate(expiryDate.getDate() + 30);
                transaction.update(db.collection('utilisateurs').doc(data.userId), { 
                    "statusVIP": "active",
                    "dateExpirationVIP": admin.firestore.Timestamp.fromDate(expiryDate)
                });
            }
            return true;
        });
    } catch (error) {
        console.error(`💥 Erreur fatale pour ${transactionId}:`, error);
        return false;
    }
};

exports.annulerReservationEtRembourser = onCall({ region: region }, async (request) => {
    const { transactionId } = request.data; 
    const db = getDb();
    
    const pendingSnap = await db.collection('pending_payments')
        .where('factureReference', '==', transactionId)
        .where('status', '==', 'completed')
        .get();
    
    if (pendingSnap.empty) throw new HttpsError('not-found', 'Transaction non trouvée.');
    const doc = pendingSnap.docs[0];
    const data = doc.data();

    await db.runTransaction(async (t) => {
        const walletRef = db.collection('wallets').doc(data.userId);
        t.update(walletRef, {
            balance: getFieldValue().increment(data.fromWallet),
            bonusBalance: getFieldValue().increment(data.fromBonus),
            cashback_balance: getFieldValue().increment(data.fromCashback),
            commission_balance: getFieldValue().increment(data.fromCommission),
            pendingRefund: getFieldValue().increment(data.amountToPayGateway || 0),
            lastUpdate: getFieldValue().serverTimestamp()
        });
        t.update(doc.ref, { status: "refunded" });
        const txRef = db.collection('transactions').doc();
        t.set(txRef, {
            walletId: data.userId, title: "Remboursement Annulation", amount: data.amountTotal,
            isPositive: true, type: "REMBOURSEMENT_ANNULATION", date: getFieldValue().serverTimestamp()
        });
    });
    return { status: "success" };
});