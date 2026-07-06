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
    
    return { walletData, userData };
};

// --- 1. PAIEMENT HYBRIDE ---
exports.initiateHybridPayment = onCall({ region: region }, async (request) => {
    const db = getDb();
    if (!request.auth) throw new HttpsError('unauthenticated', 'Connectez-vous.');
    const userId = request.auth.uid;

    const { walletData: w } = await checkWalletAccess(db, userId);
    const { serviceId, serviceType, walletAmountRequested, totalAmountToPay, montantRemise, metadata } = request.data;
    
    if (!serviceId) throw new HttpsError('invalid-argument', 'Le serviceId est manquant.');

    let amountTotal = parseFloat(totalAmountToPay || 0);
    if (amountTotal <= 0) {
        const propertyDoc = await db.collection('proprietes').doc(serviceId).get();
        if (!propertyDoc.exists) throw new HttpsError('not-found', 'Propriété introuvable.');
        amountTotal = parseFloat(propertyDoc.data().price || 0);
    }
    
    const safeMontantRemise = parseFloat(montantRemise || 0);
    const limiteMaxWallet = amountTotal * 0.25;
    const montantWalletFinal = Math.min(parseFloat(walletAmountRequested || 0), limiteMaxWallet);
    const deduction = exports.calculateWalletDeduction(w, montantWalletFinal);

    let reliquatPasserelle = amountTotal - deduction.totalDebited - safeMontantRemise;
    reliquatPasserelle = Math.max(0, Math.round(reliquatPasserelle * 100) / 100);
    
    const hybridRef = `HYB-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    const factureReference = metadata?.factureReference || metadata?.factureId || null;

    await db.collection('pending_payments').doc(hybridRef).set({
        userId, serviceId, serviceType: serviceType || 'standard',
        factureReference, amountTotal, montantRemise: safeMontantRemise,
        fromWallet: deduction.dBalance, fromBonus: deduction.dBonus, 
        fromCashback: deduction.dCashback, fromCommission: deduction.dCommission,
        amountToPayGateway: reliquatPasserelle,
        isHybrid: deduction.totalDebited > 0 || safeMontantRemise > 0,
        status: "awaiting_gateway",
        metadata: metadata || {},
        createdAt: getFieldValue().serverTimestamp()
    });

    return { 
        status: reliquatPasserelle <= 0 ? "INTERNAL_PAYMENT_COMPLETED" : "REQUIRES_EXTERNAL_PAYMENT", 
        amountToPayGateway: reliquatPasserelle, 
        paymentReference: hybridRef 
    };
});

// --- 2. PAIEMENT 100% CASH (STANDARD) ---
exports.initiateStandardPayment = onCall({ region: region }, async (request) => {
    const db = getDb();
    if (!request.auth) throw new HttpsError('unauthenticated', 'Connectez-vous.');
    const { bienId, refBien, montantTotal, montantWallet } = request.data;
    await checkWalletAccess(db, request.auth.uid);

    const factureRef = db.collection('factures').doc();
    await db.runTransaction(async (t) => {
        t.set(factureRef, {
            clientId: request.auth.uid, propertyId: bienId, refBien: refBien, methodePaiement: 'cash',
            status: 'pending', montantTotal: montantTotal, montantAPayer: montantTotal - montantWallet,
            montantWallet: montantWallet, dateCreation: getFieldValue().serverTimestamp()
        });
        t.update(db.collection('proprietes').doc(bienId), { status: 'en_attente_cash' });
    });
    return { factureId: factureRef.id };
});

// --- 3. TRANSFERT P2P SÉCURISÉ ---
exports.transferCredits = onCall({ region: region }, async (request) => {
    const db = getDb();
    if (!request.auth) throw new HttpsError('unauthenticated', 'Vous devez être connecté.');
    const senderUid = request.auth.uid;
    const { receiverPhone, amount } = request.data;

    const transferAmount = parseFloat(amount);
    if (isNaN(transferAmount) || transferAmount <= 0) {
        throw new HttpsError('invalid-argument', 'Montant invalide.');
    }

    const senderAuth = await checkWalletAccess(db, senderUid);
    const senderName = senderAuth.userData.displayName || "Expéditeur";

    return await db.runTransaction(async (transaction) => {
        const indexRef = db.collection('phone_index').doc(receiverPhone);
        const indexSnap = await transaction.get(indexRef);
        if (!indexSnap.exists) throw new HttpsError('not-found', 'Destinataire introuvable.');

        const receiverUid = indexSnap.data().uid;
        if (senderUid === receiverUid) throw new HttpsError('invalid-argument', 'Impossible de transférer vers soi-même.');

        const receiverUserDoc = await transaction.get(db.collection('utilisateurs').doc(receiverUid));
        const receiverName = receiverUserDoc.data().displayName || "Destinataire";

        const senderWalletRef = db.collection('wallets').doc(senderUid);
        const senderSnap = await transaction.get(senderWalletRef);
        const receiverWalletRef = db.collection('wallets').doc(receiverUid);
        const receiverWalletSnap = await transaction.get(receiverWalletRef);

        const walletData = senderSnap.data();
        const deduction = exports.calculateWalletDeduction(walletData, transferAmount);
        
        if (deduction.totalDebited < transferAmount) throw new HttpsError('failed-precondition', 'Solde insuffisant.');

        transaction.update(senderWalletRef, { 
            balance: getFieldValue().increment(-deduction.dBalance),
            bonusBalance: getFieldValue().increment(-deduction.dBonus),
            cashback_balance: getFieldValue().increment(-deduction.dCashback),
            commission_balance: getFieldValue().increment(-deduction.dCommission),
            lastUpdate: getFieldValue().serverTimestamp() 
        });
        
        transaction.update(receiverWalletRef, { 
            balance: getFieldValue().increment(deduction.dBalance),
            bonusBalance: getFieldValue().increment(deduction.dBonus),
            cashback_balance: getFieldValue().increment(deduction.dCashback),
            commission_balance: getFieldValue().increment(deduction.dCommission),
            lastUpdate: getFieldValue().serverTimestamp() 
        });

        const participants = [senderUid, receiverUid];

        const txSenderRef = db.collection('transactions').doc();
        transaction.set(txSenderRef, {
            walletId: senderUid, userId: senderUid, title: "Transfert P2P", amount: transferAmount, 
            isPositive: false, type: 'p2p_transfer', date: getFieldValue().serverTimestamp(),
            senderId: senderUid, senderName: senderName,
            receiverId: receiverUid, receiverName: receiverName,
            participants: participants
        });

        const txReceiverRef = db.collection('transactions').doc();
        transaction.set(txReceiverRef, {
            walletId: receiverUid, userId: receiverUid, title: "Transfert P2P", amount: transferAmount, 
            isPositive: true, type: 'p2p_transfer', date: getFieldValue().serverTimestamp(),
            senderId: senderUid, senderName: senderName,
            receiverId: receiverUid, receiverName: receiverName,
            participants: participants
        });

        return { success: true, message: "Transfert effectué avec succès." };
    });
});

// --- 4. FINALISATION & REMBOURSEMENT ---
exports.finalizeHybridTransaction = async (transactionId) => {
    const db = getDb();
    const pendingRef = db.collection('pending_payments').doc(transactionId);
    try {
        return await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(pendingRef);
            if (!doc.exists || doc.data().status !== 'awaiting_gateway') return false;
            const data = doc.data();
            
            transaction.update(db.collection('wallets').doc(data.userId), {
                balance: getFieldValue().increment(-data.fromWallet),
                bonusBalance: getFieldValue().increment(-data.fromBonus),
                cashback_balance: getFieldValue().increment(-data.fromCashback),
                commission_balance: getFieldValue().increment(-data.fromCommission),
                lastUpdate: getFieldValue().serverTimestamp()
            });
            transaction.update(pendingRef, { status: "completed", completedAt: getFieldValue().serverTimestamp() });
            
            const txRef = db.collection('transactions').doc();
            transaction.set(txRef, {
                walletId: data.userId, 
                userId: data.userId, 
                title: data.isHybrid ? "Achat Hybride" : "Achat Externe",
                amount: data.amountToPayGateway ?? data.amountTotal,
                amountGateway: data.amountToPayGateway,
                amountWallet: (data.fromWallet || 0) + (data.fromBonus || 0) + (data.fromCashback || 0) + (data.fromCommission || 0),
                amountTotal: data.amountTotal,
                isPositive: false, 
                type: data.isHybrid ? "ACHAT_HYBRIDE" : "ACHAT_EXTERNE",
                serviceId: data.serviceId, 
                date: getFieldValue().serverTimestamp()
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
    } catch (error) { console.error(error); return false; }
};

exports.annulerReservationEtRembourser = onCall({ region: region }, async (request) => {
    const transactionId = request.data?.transactionId;

    if (!transactionId) {
        throw new HttpsError('invalid-argument', 'transactionId manquant.');
    }
    
    const db = getDb();
    const factureRef = db.collection('factures').doc(transactionId);
    
    return await db.runTransaction(async (t) => {
        const factureSnap = await t.get(factureRef);
        if (!factureSnap.exists) throw new HttpsError('not-found', 'Facture non trouvée.');
        
        const facture = factureSnap.data();
        
        // --- SÉCURITÉ : Empêcher un double remboursement ---
        if (facture.remboursementEffectue === true) {
            throw new HttpsError(
                "failed-precondition",
                "Déjà remboursé."
            );
        }
        
        const userId = facture.clientId; 
        const montantExterne = parseFloat(facture.montantExterne || 0);
        const montantWallet = parseFloat(facture.montantWallet || 0);

        const pendingSnap = await t.get(db.collection('pending_payments')
            .where('factureReference', '==', transactionId)
            .where('status', '==', 'completed'));

        // Remboursement
        t.update(db.collection('wallets').doc(userId), {
            balance: getFieldValue().increment(montantExterne),
            commission_balance: getFieldValue().increment(montantWallet),
            lastUpdate: getFieldValue().serverTimestamp()
        });

        // Mise à jour de la facture (On garde le statut métier intact)
        t.update(factureRef, {
            remboursementEffectue: true,
            dateRemboursement: getFieldValue().serverTimestamp(),
        });

        // Mise à jour du statut si le pending_payment existe
        if (!pendingSnap.empty) {
            t.update(pendingSnap.docs[0].ref, { status: "refunded" });
        }
        
        // Transaction
        const txRef = db.collection('transactions').doc();
        t.set(txRef, {
            walletId: userId, 
            userId: userId,
            title: "Remboursement Annulation", 
            amount: montantExterne + montantWallet,
            isPositive: true, 
            type: "remboursement", 
            date: getFieldValue().serverTimestamp()
        });

        return { status: "success" };
    });
});

// --- 5. TRANSFERT DE CRÉDITS DEPUIS UN PARTENAIRE ---
exports.sendCreditsFromPartner = onCall({ region: region }, async (request) => {
    const db = getDb();
    if (!request.auth) throw new HttpsError('unauthenticated', 'Connectez-vous.');
    
    const { partnerId, receiverPhone, amount } = request.data;
    const transferAmount = parseFloat(amount);

    if (!partnerId || !receiverPhone || isNaN(transferAmount) || transferAmount <= 0) {
        throw new HttpsError('invalid-argument', 'Paramètres manquants ou invalides.');
    }

    const partnerDoc = await db.collection('partenaires').doc(partnerId).get();
    if (!partnerDoc.exists) throw new HttpsError('not-found', 'Partenaire introuvable.');

    return await db.runTransaction(async (transaction) => {
        const indexRef = db.collection('phone_index').doc(receiverPhone);
        const indexSnap = await transaction.get(indexRef);
        if (!indexSnap.exists) throw new HttpsError('not-found', 'Destinataire introuvable.');

        const receiverUid = indexSnap.data().uid;
        const receiverWalletRef = db.collection('wallets').doc(receiverUid);
        
        transaction.update(receiverWalletRef, {
            balance: getFieldValue().increment(transferAmount),
            lastUpdate: getFieldValue().serverTimestamp()
        });

        const txRef = db.collection('transactions').doc();
        transaction.set(txRef, {
            walletId: receiverUid,
            userId: receiverUid,
            title: "Crédit partenaire reçu",
            amount: transferAmount,
            isPositive: true,
            type: 'partner_credit',
            partnerId: partnerId,
            date: getFieldValue().serverTimestamp()
        });

        return { success: true, message: "Crédits transférés avec succès." };
    });
});