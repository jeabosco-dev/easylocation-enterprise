// functions/modules/transaction_core.js

const admin = require('firebase-admin');
if (admin.apps.length === 0) admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

/**
 * CORE LEDGER UNIQUE (TOUS LES PAIEMENTS PASSENT ICI)
 */
exports.finalizeTransactionCore = async ({
    userId,
    factureId,
    amount,
    type, // ACHAT_MANUEL | ACHAT_CASH | ACHAT_MAXICASH
    propertyId,
    isHybrid = false,
    metadata = {} 
}) => {

    const factureRef = db.collection('factures').doc(factureId);
    const propertyRef = propertyId
        ? db.collection('proprietes').doc(propertyId)
        : null;

    const walletRef = db.collection('wallets').doc(userId);

    await db.runTransaction(async (t) => {
        // =====================================================
        // 1. PHASE DE LECTURE (TOUT DOIT ÊTRE ICI EN PREMIER)
        // =====================================================

        // A. Vérification Idempotence sur la facture
        const factureDoc = await t.get(factureRef);
        if (!factureDoc.exists) {
            throw new Error("Facture introuvable.");
        }

        const factureData = factureDoc.data();
        if (factureData.paymentStatus === 'success') {
            throw new Error("Cette facture a déjà été validée et payée.");
        }

        // B. Recherche et lecture sécurisée du Pending Payment
        let pendingPaymentRef = null;
        let pendingData = null;

        if (propertyId) {
            const pendingQuery = db.collection('pending_payments')
                .where('serviceId', '==', propertyId)
                .where('userId', '==', userId)
                .where('status', '==', 'awaiting_gateway')
                .limit(1);

            const pendingSnap = await t.get(pendingQuery);
            if (!pendingSnap.empty) {
                pendingPaymentRef = pendingSnap.docs[0].ref;
                pendingData = pendingSnap.docs[0].data();
            }
        }

        // =====================================================
        // 2. PHASE D'ÉCRITURE (TOUT DOIT ÊTRE APRÈS)
        // =====================================================

        // 1. FACTURE
        t.update(factureRef, {
            paymentStatus: 'success',
            etapeDossier: 'paye',
            datePaiement: FieldValue.serverTimestamp(),
            methodePaiementFinale: type
        });

        // 2. PROPRIETE
        if (propertyRef) {
            t.update(propertyRef, {
                status: 'reserved',
                reservedAt: FieldValue.serverTimestamp()
            });
        }

        // 3. WALLET (DÉBIT SÉCURISÉ & ALIGNEMENT SUR LES NOUVELLES CLÉS DE LA BALANCE)
        // On récupère en priorité `walletDebits`, ou à défaut on extrait les données du pending_payment 
        // en utilisant explicitement dBalance, dBonus, dCashback, dCommission.
        const d = metadata.walletDebits || (pendingData ? (pendingData.walletDebits || {
            dBalance: pendingData.fromWallet || pendingData.dBalance || 0,
            dBonus: pendingData.fromBonus || pendingData.dBonus || 0,
            dCashback: pendingData.fromCashback || pendingData.dCashback || 0,
            dCommission: pendingData.fromCommission || pendingData.dCommission || 0
        }) : null);

        if (d && ((d.dBalance || 0) > 0 || (d.dBonus || 0) > 0 || (d.dCashback || 0) > 0 || (d.dCommission || 0) > 0)) {
            t.update(walletRef, {
                balance: FieldValue.increment(-(d.dBalance || 0)),
                bonusBalance: FieldValue.increment(-(d.dBonus || 0)),
                cashback_balance: FieldValue.increment(-(d.dCashback || 0)),
                commission_balance: FieldValue.increment(-(d.dCommission || 0)),
                lastUpdate: FieldValue.serverTimestamp()
            });
        }

        // 4. SYNCHRONISATION PENDING PAYMENT
        if (pendingPaymentRef) {
            t.update(pendingPaymentRef, {
                status: 'completed',
                processedAt: FieldValue.serverTimestamp(),
                factureReference: factureId
            });
        }

        // 5. LEDGER TRANSACTION UNIQUE
        const txRef = db.collection('transactions').doc();
        t.set(txRef, {
            userId,
            factureId,
            propertyId: propertyId || null,
            amount,
            type,
            isPositive: false,
            method: metadata.source || type, 
            metadata,
            createdAt: FieldValue.serverTimestamp()
        });
    });

    return true;
};