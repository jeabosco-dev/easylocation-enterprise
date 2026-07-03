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

    // Recherche du pending payment AVANT la transaction
    let pendingPaymentRef = null;
    if (propertyId) {
        const pendingSnap = await db
            .collection('pending_payments')
            .where('serviceId', '==', propertyId)
            .where('userId', '==', userId)
            .where('status', '==', 'awaiting_gateway')
            .limit(1)
            .get();

        if (!pendingSnap.empty) {
            pendingPaymentRef = pendingSnap.docs[0].ref;
        }
    }

    await db.runTransaction(async (t) => {
        // =====================================================
        // 1. PHASE DE LECTURE (TOUT DOIT ÊTRE ICI EN PREMIER)
        // =====================================================
        let pendingData = null;
        if (pendingPaymentRef) {
            const pendingDoc = await t.get(pendingPaymentRef);
            if (pendingDoc.exists) {
                pendingData = pendingDoc.data();
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

        // 3. WALLET (MISE À JOUR SÉCURISÉE)
        if (pendingData) {
            const d = pendingData.walletDebits || {
                dBalance: pendingData.fromWallet || 0,
                dBonus: pendingData.fromBonus || 0,
                dCashback: pendingData.fromCashback || 0,
                dCommission: pendingData.fromCommission || 0
            };

            t.update(walletRef, {
                balance: FieldValue.increment(-(d.dBalance || 0)),
                bonusBalance: FieldValue.increment(-(d.dBonus || 0)),
                cashback_balance: FieldValue.increment(-(d.dCashback || 0)),
                commission_balance: FieldValue.increment(-(d.dCommission || 0)),
                lastUpdate: FieldValue.serverTimestamp()
            });
        } else if (metadata.walletDebits) {
            const { dBalance, dBonus, dCashback, dCommission } = metadata.walletDebits;
            t.update(walletRef, {
                balance: FieldValue.increment(-(dBalance || 0)),
                bonusBalance: FieldValue.increment(-(dBonus || 0)),
                cashback_balance: FieldValue.increment(-(dCashback || 0)),
                commission_balance: FieldValue.increment(-(dCommission || 0)),
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
            // Utilisation de la source passée en metadata si elle existe, sinon fallback sur le type
            method: metadata.source || type, 
            metadata,
            createdAt: FieldValue.serverTimestamp()
        });
    });

    return true;
};