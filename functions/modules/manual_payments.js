const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { finalizeTransactionCore } = require('./transaction_core');
const { calculateWalletDeduction } = require('./payments_hybrid');

exports.finalizeManualPayment = onCall({ region: 'europe-west1' }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Not logged in');
    }

    const { factureId, userId, amount, propertyId, ok } = request.data;
    const db = admin.firestore();

    // 1. Récupérer les infos du Wallet et le montant Wallet prévu dans la facture
    const [walletDoc, factureDoc] = await Promise.all([
        db.collection('wallets').doc(userId).get(),
        db.collection('factures').doc(factureId).get()
    ]);

    if (!walletDoc.exists) throw new HttpsError('not-found', 'Wallet inexistant');
    
    const factureData = factureDoc.data();
    const montantWalletPrevu = factureData.montantWallet || 0;

    let walletDebits = null;

    // 2. Si le paiement est validé (ok) et qu'il y a un montant Wallet, on calcule le débit
    if (ok && montantWalletPrevu > 0) {
        walletDebits = calculateWalletDeduction(walletDoc.data(), montantWalletPrevu);
    }

    // 3. Définition du type
    const paymentType = ok ? 'ACHAT_CASH' : 'ACHAT_CASH_REJECTED';

    // 4. Appel du core avec les données du Wallet
    await finalizeTransactionCore({
        userId,
        factureId,
        amount,
        type: paymentType,
        propertyId,
        isHybrid: false,
        metadata: {
            adminId: request.data.adminId || null,
            motif: request.data.motif || null,
            source: 'CASH',
            walletDebits: walletDebits // C'est ici que le débit est injecté !
        }
    });

    return { status: ok ? 'success' : 'rejected' };
});