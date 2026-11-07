// functions/modules/wallet_payments.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { finalizeTransactionCore } = require('./transaction_core');

if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();

/**
 * FONCTION INTERNE DE CALCUL DE DÉBIT (Arrondi propre à 2 décimales)
 * Ordre de priorité : Balance -> Bonus -> Cashback -> Commission
 */
const calculateWalletDeductionForPayment = (walletData, requestedAmount) => {
    const balance = parseFloat(walletData.balance) || 0;
    const bonus = (walletData.bonusExpiryDate && new Date() > walletData.bonusExpiryDate.toDate()) ? 0 : (parseFloat(walletData.bonusBalance) || 0);
    const cashback = parseFloat(walletData.cashback_balance) || 0;
    const commission = parseFloat(walletData.commission_balance) || 0;

    let restant = parseFloat(requestedAmount || 0);

    console.log(`🔍 [DEBUG WALLET] Soldes disponibles - Balance: ${balance}, Bonus: ${bonus}, Cashback: ${cashback}, Commission: ${commission}, Demandé: ${restant}`);

    // ÉTAPE 1 : Balance principale (Remboursements / Argent réel)
    const dBalance = Math.min(balance, restant);
    restant = Math.round((restant - dBalance) * 100) / 100;

    // ÉTAPE 2 : Bonus
    let dBonus = 0;
    if (restant > 0 && bonus > 0) {
        dBonus = Math.min(bonus, restant);
        restant = Math.round((restant - dBonus) * 100) / 100;
    }

    // ÉTAPE 3 : Cashback
    let dCashback = 0;
    if (restant > 0 && cashback > 0) {
        dCashback = Math.min(cashback, restant);
        restant = Math.round((restant - dCashback) * 100) / 100;
    }

    // ÉTAPE 4 : Commission
    let dCommission = 0;
    if (restant > 0 && commission > 0) {
        dCommission = Math.min(commission, restant);
        restant = Math.round((restant - dCommission) * 100) / 100;
    }

    const totalDebited = Math.round((parseFloat(requestedAmount || 0) - restant) * 100) / 100;
    console.log(`🔍 [DEBUG WALLET] Résultat calcul - Débité total: ${totalDebited}, Reste à régler: ${restant}`);

    return {
        dBalance: Math.round(dBalance * 100) / 100,
        dBonus: Math.round(dBonus * 100) / 100,
        dCashback: Math.round(dCashback * 100) / 100,
        dCommission: Math.round(dCommission * 100) / 100,
        totalDebited: totalDebited,
        resteARégler: Math.round(restant * 100) / 100
    };
};

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

        console.log(`📥 [DEBUG PAIEMENT] Début finalizeWalletPayment pour la facture: ${factureId}, utilisateur: ${userId}`);

        if (!factureId) {
            throw new HttpsError('invalid-argument', 'L\'identifiant de la facture est manquant.');
        }

        const factureRef = db.collection('factures').doc(factureId);
        let factureSnap = await factureRef.get();

        if (!factureSnap.exists) {
            if (!clientFactureData) {
                throw new HttpsError('not-found', 'Facture introuvable et aucune donnée transmise.');
            }
            await factureRef.set({
                ...clientFactureData,
                clientId: userId,
                paymentStatus: 'pending',
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
            factureSnap = await factureRef.get();
        }

        const factureData = factureSnap.data();

        if (factureData.clientId !== userId) {
            throw new HttpsError('permission-denied', 'Accès non autorisé à cette facture.');
        }

        // 🛠️ CORRECTION DU CALCUL DU MONTANT : On regarde totalUSD, puis totalNetUSD (si > 0), puis loyer
        const totalAmount = parseFloat(factureData.totalUSD || factureData.totalNetUSD || factureData.montantTotal || factureData.loyer || 0);
        
        console.log(`📊 [DEBUG FACTURE] Valeurs brutes lues -> totalUSD: ${factureData.totalUSD}, totalNetUSD: ${factureData.totalNetUSD}, montantWallet: ${factureData.montantWallet}`);
        console.log(`🎯 [DEBUG FACTURE] Montant total retenu pour la facture (totalAmount): ${totalAmount}`);

        // --- LECTURE DU WALLET ET CALCUL INTELLIGENT DE LA DÉDUCTION ---
        const walletRef = db.collection('wallets').doc(userId);
        const walletDoc = await walletRef.get();

        if (!walletDoc.exists) {
            throw new HttpsError('not-found', 'Portefeuille introuvable.');
        }

        const currentWallet = walletDoc.data();

        // 🧠 CALCUL DE LA DÉDUCTION
        const deduction = calculateWalletDeductionForPayment(currentWallet, totalAmount);

        console.log(`⚖️ [DEBUG COMPARAISON] Total requis: ${totalAmount} | Total couvert par le wallet: ${deduction.totalDebited}`);

        // Si le total disponible dans le wallet ne couvre pas entièrement le montant de la facture
        if (deduction.totalDebited < totalAmount) {
            console.warn(`❌ [DEBUG ERREUR] Solde insuffisant ! Requis: ${totalAmount}, Disponible couvert: ${deduction.totalDebited}`);
            throw new HttpsError('failed-precondition', `Le solde total de votre portefeuille est insuffisant pour couvrir cette facture. Requis: ${totalAmount}, Couvert: ${deduction.totalDebited}`);
        }

        // --- CALCUL DU RELIQUAT ET DU TÉMOIN ANTI-FRAUDE ---
        const currentReliquat = parseFloat(currentWallet.reliquatRemboursement || 0);
        const nouveauReliquat = Math.max(0, Math.round((currentReliquat - deduction.dBalance) * 100) / 100);
        const aUtiliseSonRemboursement = deduction.dBalance > 0;
        const nouveauHasReinvested = aUtiliseSonRemboursement ? true : Boolean(currentWallet.hasReinvested);

        const walletDebits = {
            dBalance: deduction.dBalance,
            dBonus: deduction.dBonus,
            dCashback: deduction.dCashback,
            dCommission: deduction.dCommission,
            reliquatRemboursement: Number(nouveauReliquat.toFixed(2)),
            hasReinvested: Boolean(nouveauHasReinvested)
        };

        // --- EXÉCUTION DE LA TRANSACTION UNIQUE VIA LE CORE LEDGER ---
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

        console.log(`✅ [DEBUG SUCCÈS] Paiement 100% wallet validé avec succès pour ${factureId}`);
        return { status: 'success' };
    } catch (error) {
        console.error("❌ ERREUR CRITIQUE finalizeWalletPayment:", error);
        if (error instanceof HttpsError) {
            throw error;
        }
        throw new HttpsError('internal', error.message || "Erreur interne du serveur.");
    }
});