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
    metadata = {} // Attendu : { walletDebits: { dBalance, dBonus, dCashback, dCommission } }
}) => {

    const factureRef = db.collection('factures').doc(factureId);
    const propertyRef = propertyId
        ? db.collection('proprietes').doc(propertyId)
        : null;

    const walletRef = db.collection('wallets').doc(userId);

    // =====================================================
    // RECHERCHE DU PENDING PAYMENT AVANT LA TRANSACTION
    // =====================================================

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

        // =================================================
        // 1. FACTURE
        // =================================================

        t.update(factureRef, {
            paymentStatus: 'success',
            etapeDossier: 'paye',
            datePaiement: FieldValue.serverTimestamp(),
            methodePaiementFinale: type
        });

        // =================================================
        // 2. PROPRIETE
        // =================================================

        if (propertyRef) {
            t.update(propertyRef, {
                status: 'reserved',
                reservedAt: FieldValue.serverTimestamp()
            });
        }

        // =================================================
        // 3. WALLET (MISE À JOUR GÉNÉRIQUE)
        // =================================================

        if (metadata.walletDebits) {
            const { dBalance, dBonus, dCashback, dCommission } = metadata.walletDebits;
            t.update(walletRef, {
                balance: FieldValue.increment(-(dBalance || 0)),
                bonusBalance: FieldValue.increment(-(dBonus || 0)),
                cashback_balance: FieldValue.increment(-(dCashback || 0)),
                commission_balance: FieldValue.increment(-(dCommission || 0)),
                lastUpdate: FieldValue.serverTimestamp()
            });
        } else if (isHybrid) {
            // Fallback pour compatibilité si metadata n'est pas encore implémenté partout
            t.update(walletRef, {
                lastUpdate: FieldValue.serverTimestamp()
            });
        }

        // =================================================
        // 4. SYNCHRONISATION PENDING PAYMENT
        // =================================================

        if (pendingPaymentRef) {
            t.update(pendingPaymentRef, {
                status: 'completed',
                processedAt: FieldValue.serverTimestamp(),
                factureReference: factureId
            });
        }

        // =================================================
        // 5. LEDGER TRANSACTION UNIQUE
        // =================================================

        const txRef = db.collection('transactions').doc();

        t.set(txRef, {
            userId,
            factureId,
            propertyId: propertyId || null,
            amount,
            type,
            isPositive: false,
            method: type,
            metadata,
            createdAt: FieldValue.serverTimestamp()
        });
    });

    return true;
};