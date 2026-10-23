// functions/modules/wallet_payments.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { finalizeTransactionCore } = require('./transaction_core');

if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();

/**
 * VALIDATION 100% WALLET PAR LE CLIENT (Paiement intégral par le solde)
 */
exports.finalizeWalletPayment = onCall({ region: 'europe-west1' }, async (request) => {
    try {
        if (!request.auth) {
            throw new HttpsError('unauthenticated', 'Connectez-vous.');
        }
        const userId = request.auth.uid;
        const { factureId, propertyId, factureData: clientFactureData } = request.data;

        if (!factureId) {
            throw new HttpsError('invalid-argument', 'L\'identifiant de la facture est manquant.');
        }

        const factureRef = db.collection('factures').doc(factureId);
        let factureSnap = await factureRef.get();

        // Si la facture n'existe pas encore et que le client l'a transmise, on la crée en mode 'pending' ou 'initial'
        if (!factureSnap.exists) {
            if (!clientFactureData) {
                throw new HttpsError('not-found', 'Facture introuvable et aucune donnée transmise.');
            }
            // Création initiale de la facture via la Cloud Function
            await factureRef.set({
                ...clientFactureData,
                clientId: userId,
                paymentStatus: 'pending', // On s'assure qu'elle part en pending avant la transaction
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
            factureSnap = await factureRef.get();
        }

        const factureData = factureSnap.data();

        // Sécurité : vérifier que la facture appartient bien à l'utilisateur connecté
        if (factureData.clientId !== userId) {
            throw new HttpsError('permission-denied', 'Accès non autorisé à cette facture.');
        }

        // Vérifier que le montant externe / net à payer est bien 0 (couvert par le wallet)
        const montantExterne = parseFloat(factureData.montantExterne || 0);
        if (montantExterne > 0) {
            throw new HttpsError('failed-precondition', 'Le solde du wallet ne couvre pas l\'intégralité de la facture.');
        }

        // Récupération des montants à débiter depuis la facture
        const walletDebits = {
            dBalance: parseFloat(factureData.montantWallet || factureData.fromWallet || 0),
            dBonus: parseFloat(factureData.fromBonus || 0),
            dCashback: parseFloat(factureData.fromCashback || 0),
            dCommission: parseFloat(factureData.fromCommission || 0)
        };

        const totalAmount = parseFloat(factureData.totalNetUSD || factureData.montantTotal || factureData.loyer || 0);

        // Exécution de la transaction via le Core Ledger unique
        await finalizeTransactionCore({
            userId,
            factureId,
            amount: totalAmount,
            type: 'ACHAT_WALLET',
            propertyId: propertyId || factureData.propertyId,
            isHybrid: false,
            metadata: {
                source: 'WALLET_100_PERCENT',
                walletDebits: walletDebits
            }
        });

        return { status: 'success' };
    } catch (error) {
        console.error("ERREUR CRITIQUE finalizeWalletPayment:", error);
        
        if (error instanceof HttpsError) {
            throw error;
        }
        
        throw new HttpsError('internal', error.message || "Erreur interne du serveur.");
    }
});