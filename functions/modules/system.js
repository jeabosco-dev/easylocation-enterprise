const { onSchedule } = require("firebase-functions/v2/scheduler");
const { db, admin } = require('./admin');

/**
 * Nettoyage automatique des challenges expirés
 * S'exécute toutes les 60 minutes
 */
exports.checkExpiredCommunityGoals = onSchedule({
    schedule: 'every 60 minutes',
    region: 'europe-west1'
}, async (event) => {
    const now = new Date();

    try {
        const snapshot = await db.collection('community_goals')
            .where('statut', '==', 'en_cours')
            .where('deadline', '<', now)
            .get();

        if (snapshot.empty) {
            console.log('--- Aucun challenge expiré ---');
            return null;
        }

        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.update(doc.ref, { statut: 'expire' });
        });

        await batch.commit();
        console.log(`✅ ${snapshot.size} challenges marqués comme expirés.`);
        return null;
    } catch (error) {
        console.error("❌ Erreur maintenance challenges :", error);
        return null;
    }
});

/**
 * ✅ Mise à jour automatique des statistiques communautaires (Audit)
 * S'exécute chaque jour à minuit.
 */
exports.updateCommunityStats = onSchedule({
    schedule: '0 0 * * *',
    timeZone: 'Africa/Lubumbashi',
    region: 'europe-west1'
}, async (event) => {
    console.log('--- Début de la mise à jour des statistiques ---');

    try {
        // 1. Compter les locataires
        const locatairesSnapshot = await db.collection('utilisateurs')
            .where('role', '==', 'locataire')
            .count()
            .get();
        const totalLocataires = locatairesSnapshot.data().count;

        // 2. Compter les bailleurs
        const bailleursSnapshot = await db.collection('utilisateurs')
            .where('role', '==', 'bailleur')
            .count()
            .get();
        const totalBailleurs = bailleursSnapshot.data().count;

        // 3. Mettre à jour le document app_config
        await db.collection('settings').doc('app_config').update({
            'community_stats.total_locataires': totalLocataires,
            'community_stats.total_bailleurs': totalBailleurs,
            'community_stats.last_updated': admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`✅ Stats mises à jour : ${totalLocataires} locataires, ${totalBailleurs} bailleurs.`);
        return null;
    } catch (error) {
        console.error("❌ Erreur lors de la mise à jour des stats :", error);
        return null;
    }
});

/**
 * ✅ NOUVEAU : Reset quotidien des compteurs "ajouts_aujourdhui" par ville (Social Proof)
 * S'exécute chaque jour à minuit.
 */
exports.resetDailyCityStats = onSchedule({
    schedule: '0 0 * * *',
    timeZone: 'Africa/Lubumbashi',
    region: 'europe-west1'
}, async (event) => {
    console.log('--- Début du reset des statistiques journalières par ville ---');

    try {
        const snapshot = await db.collection('stats_locales').get();
        
        if (snapshot.empty) {
            console.log('--- Aucune statistique de ville à réinitialiser ---');
            return null;
        }

        const batch = db.batch();
        snapshot.docs.forEach(doc => {
            batch.update(doc.ref, { 
                ajouts_aujourdhui: 0,
                derniere_mise_a_jour: admin.firestore.FieldValue.serverTimestamp()
            });
        });

        await batch.commit();
        console.log(`✅ Reset terminé pour ${snapshot.size} villes.`);
        return null;
    } catch (error) {
        console.error("❌ Erreur resetDailyCityStats :", error);
        return null;
    }
});