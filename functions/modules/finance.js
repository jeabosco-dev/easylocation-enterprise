// functions/modules/finance.js
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getDb, getFieldValue } = require('./admin');

const region = 'europe-west1';

/**
 * Trigger : Met à jour la masse monétaire et le compte utilisateur global
 * à chaque création ou modification dans la collection 'wallets'.
 */
exports.onWalletWrittenUpdateStats = onDocumentWritten({
    document: 'wallets/{userId}',
    region: region
}, async (event) => {
    const db = getDb();

    // 1. Si le document est supprimé, on ne fait rien
    if (!event.data.after.exists()) return null;

    const afterData = event.data.after.data();
    const beforeData = event.data.before.exists() ? event.data.before.data() : null;

    // Fonction de calcul alignée sur votre WalletModel
    const calculateTotal = (data) => {
        return (data.balance || 0) + 
               (data.bonusBalance || 0) + 
               (data.cashback_balance || 0) + 
               (data.commission_balance || 0);
    };

    const newTotal = calculateTotal(afterData);
    const oldTotal = beforeData ? calculateTotal(beforeData) : 0;
    const diff = newTotal - oldTotal;

    // Préparation de la mise à jour atomique
    const updatePayload = {};
    
    // A. Mise à jour de la masse monétaire si le solde total a changé
    if (diff !== 0) {
        updatePayload.total_easy_credits = getFieldValue().increment(diff);
    }

    // B. Mise à jour du compteur utilisateur SI c'est une création (pas de 'before')
    if (!beforeData) {
        updatePayload.users_count = getFieldValue().increment(1);
    }

    // C. Ajout du timestamp de dernière mise à jour
    updatePayload.last_updated = getFieldValue().serverTimestamp();

    try {
        await db.collection('metadata').doc('global_finance').update(updatePayload);
        console.log(`[FINANCE] Statistiques mises à jour. Diff solde: ${diff.toFixed(2)}$, Création: ${!beforeData}`);
    } catch (e) {
        console.error("Erreur mise à jour stats monétaires :", e);
    }
});