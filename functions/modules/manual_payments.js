// functions/modules/manual_payments.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { finalizeTransactionCore } = require('./transaction_core');
const { calculateWalletDeduction } = require('./payments_hybrid');

exports.finalizeManualPayment = onCall({ region: 'europe-west1' }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Not logged in');
    }

    // On ajoute 'sourcePaiement' dans les paramètres attendus (ex: 'CASH' ou 'MANUEL')
    const { factureId, userId, amount, propertyId, ok, sourcePaiement } = request.data;
    const db = admin.firestore();

    // 1. Récupérer les infos du Wallet et le montant Wallet prévu dans la facture
    const [walletDoc, factureDoc] = await Promise.all([
        db.collection('wallets').doc(userId).get(),
        db.collection('factures').doc(factureId).get()
    ]);

    if (!walletDoc.exists) throw new HttpsError('not-found', 'Wallet inexistant');
    if (!factureDoc.exists) throw new HttpsError('not-found', 'Facture inexistante');
    
    const factureData = factureDoc.data();
    const montantWalletPrevu = factureData.montantWallet || 0;
    const totalAmount = parseFloat(factureData.totalNetUSD || factureData.montantTotal || 0);

    let walletDebits = null;

    if (ok && montantWalletPrevu > 0) {
        const limiteMaxWallet = totalAmount * 0.25;
        const montantWalletFinal = Math.min(parseFloat(montantWalletPrevu), limiteMaxWallet);
        walletDebits = calculateWalletDeduction(walletDoc.data(), montantWalletFinal);
    }

    // 2. Définition dynamique du type technique et de la méthode finale
    // Si sourcePaiement est 'MANUEL', on génère 'ACHAT_MANUEL', sinon 'ACHAT_CASH'
    const isManuel = sourcePaiement === 'MANUEL';
    const prefix = isManuel ? 'ACHAT_MANUEL' : 'ACHAT_CASH';
    const paymentType = ok ? prefix : `${prefix}_REJECTED`;
    const methodeFinale = isManuel ? 'ACHAT_MANUEL' : 'ACHAT_CASH';

    // 3. Appel du core avec les données dynamiques
    await finalizeTransactionCore({
        userId,
        factureId,
        amount,
        type: paymentType,
        methodePaiementFinale: methodeFinale,
        propertyId,
        isHybrid: false,
        metadata: {
            adminId: request.data.adminId || null,
            motif: request.data.motif || null,
            source: sourcePaiement || 'CASH', // Garde la source envoyée
            walletDebits: walletDebits
        }
    });

    return { status: ok ? 'success' : 'rejected' };
});