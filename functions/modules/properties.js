const admin = require('firebase-admin');
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const services = require('./services'); // Import du module de services centralisé

// Initialisation sécurisée
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();
const getFieldValue = () => admin.firestore.FieldValue;
const region = 'europe-west1';

/**
 * Fonction utilitaire pour "slugifier" les noms de localités
 */
const slugify = (text) => {
    if (!text) return 'inconnu';
    return text
        .toString()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .trim()
        .replace(/\s+/g, '')
        .replace(/[^a-z0-9]/g, '');
};

// --- 0. AGRÉGATION DES NOTES (Cœur logique serveur) ---

/**
 * Trigger : Met à jour la moyenne des notes (averageRating) 
 * chaque fois qu'un avis est ajouté, modifié ou supprimé.
 */
exports.aggregateRatings = onDocumentWritten({
    document: 'proprietes/{propertyId}/comments/{userId}',
    region: region
}, async (event) => {
    const propertyId = event.params.propertyId;
    const propertyRef = db.collection('proprietes').doc(propertyId);
    const commentsRef = propertyRef.collection('comments');

    try {
        const snapshot = await commentsRef.get();
        
        let totalRating = 0;
        let count = 0;

        snapshot.forEach(doc => {
            const data = doc.data();
            if (data.rating) {
                totalRating += data.rating;
                count++;
            }
        });

        await propertyRef.update({
            totalRating: totalRating,
            ratingCount: count,
            averageRating: count > 0 ? (totalRating / count) : 0
        });

        console.log(`[PROPERTIES] Note mise à jour pour ${propertyId} : ${count} avis.`);
    } catch (error) {
        console.error(`[PROPERTIES] Erreur agrégation notes pour ${propertyId} :`, error);
    }
});

/**
 * 1. Notification lorsqu'une nouvelle propriété est créée
 */
exports.onNewPropertyCreated = onDocumentCreated({ 
    document: 'proprietes/{proprieteId}', 
    region: region 
}, async (event) => {
    const data = event.data.data();
    const proprieteId = event.params.proprieteId;

    if (!data.commune) return null;

    const usersSnapshot = await db.collection('utilisateurs')
        .where('preferences.commune', '==', data.commune)
        .get();

    const batch = db.batch();
    
    for (const doc of usersSnapshot.docs) {
        const alerteRef = db.collection('utilisateurs').doc(doc.id).collection('alertes').doc();
        batch.set(alerteRef, { 
            message: `Nouvelle maison disponible à ${data.commune} !`, 
            proprieteId: proprieteId, 
            type: "NOUVELLE_PROPRIETE",
            timestamp: getFieldValue().serverTimestamp(),
            lu: false 
        });

        await services.internal.sendPushNotification(
            doc.id,
            "Nouvelle Maison ! 🏠",
            `Une nouvelle propriété vient d'être publiée à ${data.commune}.`,
            { proprieteId: proprieteId, type: "NOUVELLE_PROPRIETE" }
        );
    }

    return batch.commit();
});

/**
 * 2. Suivi de l'étape du dossier de visite
 */
exports.onFactureEtapeUpdated = onDocumentUpdated({
    document: 'factures/{factureId}',
    region: region
}, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (!newData) return null;

    const locataireId = newData.clientId || newData.userId;
    if (!locataireId) return null;

    const etapeNouvelle = newData.etapeDossier;
    const etapeAncienne = oldData ? oldData.etapeDossier : null;

    if (etapeNouvelle === 'visite_terminee' && etapeAncienne !== 'visite_terminee') {
        const propertyId = newData.propertyId || "";

        try {
            await db.collection('utilisateurs').doc(locataireId).collection('alertes').add({
                message: "La visite sur le terrain est terminée. Quelle est votre décision finale ?",
                type: "DECISION_VISITE",
                propertyId: propertyId,
                timestamp: getFieldValue().serverTimestamp(),
                lu: false
            });

            await services.internal.sendPushNotification(
                locataireId,
                "Visite terminée ! 🏠",
                "Qu'avez-vous pensé de la maison ? Donnez votre réponse.",
                { propertyId: propertyId, type: "DECISION_VISITE" }
            );
            
            console.log(`[Trigger:Facture] Visite validée et notifiée pour le client ${locataireId}`);
        } catch (error) {
            console.error("❌ Erreur lors du trigger de suivi de facture:", error);
        }
    }
    return null;
});

/**
 * 3. RECHERCHE AUTOMATIQUE VIP
 */
exports.onVipAlertePaidTriggerSearch = onDocumentUpdated({
    document: 'factures/{factureId}',
    region: region
}, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData.paymentStatus === 'paid' && oldData.paymentStatus !== 'paid' && newData.type === 'VIP_ALERTE') {
        const userId = newData.userId;
        try {
            const userDoc = await db.collection('utilisateurs').doc(userId).get();
            if (!userDoc.exists) return null;
            
            const prefs = userDoc.data().preferences || {};
            const { budgetMax, chambres, commune, typeBien } = prefs;
            const communeSearch = commune ? commune.toLowerCase() : null;

            let query = db.collection('proprietes')
                .where('status', '==', 'disponible')
                .limit(40);
            
            if (communeSearch) query = query.where('commune_search', '==', communeSearch);
            if (typeBien) query = query.where('typeBien', '==', typeBien);
            
            const snapshot = await query.get();
            const matches = [];

            snapshot.forEach(doc => {
                const prop = doc.data();
                const matchBudget = budgetMax ? (Number(prop.loyer) <= Number(budgetMax)) : true;
                const matchChambres = chambres ? (Number(prop.chambres) >= Number(chambres)) : true;
                if (matchBudget && matchChambres) matches.push({ id: doc.id, ...prop });
            });

            const alerteRef = db.collection('utilisateurs').doc(userId).collection('alertes').doc();
            
            if (matches.length > 0) {
                await alerteRef.set({
                    title: "Match VIP trouvé ! 🏠",
                    message: `Nous avons trouvé ${matches.length} propriétés pour vous.`,
                    type: "VIP_MATCH",
                    propertyId: matches[0].id,
                    timestamp: getFieldValue().serverTimestamp(),
                    lu: false
                });

                await services.internal.sendPushNotification(
                    userId,
                    "Match VIP trouvé ! 💎",
                    `Bonne nouvelle ! ${matches.length} maisons correspondent à vos critères.`,
                    { propertyId: matches[0].id, type: "VIP_MATCH" }
                );
            } else {
                await alerteRef.set({
                    title: "Recherche VIP activée 🚀",
                    message: "Nous scannons le marché pour vous !",
                    type: "VIP_WAITING",
                    timestamp: getFieldValue().serverTimestamp(),
                    lu: false
                });

                await services.internal.sendPushNotification(
                    userId,
                    "Alerte VIP Activée 🚀",
                    "Aucun match immédiat, mais nous vous préviendrons dès qu'une pépite arrive."
                );
            }
        } catch (error) {
            console.error("❌ Erreur lors de la recherche VIP:", error);
        }
    }
});

/**
 * 4. Notification lors d'un paiement déclaré
 */
exports.onPaiementDeclare = onDocumentCreated({ 
    document: 'transactions/{transactionId}', 
    region: region 
}, async (event) => {
    const data = event.data.data();
    if (!data.bailleurId) return null;

    return services.internal.sendPushNotification(
        data.bailleurId,
        "🔔 Nouveau paiement déclaré",
        `Locataire ${data.locataireNom || 'Inconnu'} : ${data.nbMois || 0} mois versés.`,
        { transactionId: event.params.transactionId, type: "PAIEMENT_ATTENTE" }
    );
});

/**
 * 5. SELF-LEARNING : Mise à jour des stats et Notification remise de clés
 */
exports.onPropertyStatusChangedUpdateStats = onDocumentUpdated({
    document: 'proprietes/{propertyId}',
    region: region
}, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData.status === 'rented' && oldData.status !== 'rented') {
        
        const locataireId = newData.lastLocataireId;
        const bailleurId = newData.bailleurId;
        const refMaison = newData.numeroMaison || "votre logement";

        if (locataireId) {
            await services.internal.sendPushNotification(
                locataireId,
                "Félicitations pour votre nouveau logement ! 🏠",
                "Les clés vous ont été remises. Profitez bien de votre nouveau chez-vous !",
                { propertyId: event.params.propertyId, type: "PROPERTY_RENTED" }
            );
        }

        if (bailleurId) {
            await services.internal.sendPushNotification(
                bailleurId,
                "Bien loué avec succès ! 🔑",
                `Votre maison ${refMaison} est maintenant officiellement occupée.`,
                { propertyId: event.params.propertyId, type: "PROPERTY_RENTED_BAILLEUR" }
            );
        }

        const createdAt = newData.createdAt; 
        const rentedAt = admin.firestore.Timestamp.now();

        if (createdAt) {
            const diffInMs = rentedAt.toMillis() - createdAt.toMillis();
            const hoursElapsed = Math.floor(diffInMs / (1000 * 60 * 60));

            const statsDocId = `rdc_${slugify(newData.province)}_${slugify(newData.ville)}_${slugify(newData.commune)}`;
            const statsRef = db.collection('stats_localites').doc(statsDocId);

            try {
                await db.runTransaction(async (transaction) => {
                    const statsDoc = await transaction.get(statsRef);
                    if (!statsDoc.exists) {
                        transaction.set(statsRef, { avg_hours: hoursElapsed, total_rented: 1, last_update: rentedAt, commune: newData.commune, ville: newData.ville });
                    } else {
                        const data = statsDoc.data();
                        const newTotal = (data.total_rented || 0) + 1;
                        const newAvg = Math.floor(((data.avg_hours || 0) * (data.total_rented || 0) + hoursElapsed) / newTotal);
                        transaction.update(statsRef, { avg_hours: newAvg, total_rented: newTotal, last_update: rentedAt });
                    }
                });
            } catch (e) {
                console.error("❌ Erreur stats :", e);
            }
        }
    }
    return null;
});

/**
 * 6. Mise à jour des FAVORIS
 */
exports.onPropertyUpdated = onDocumentUpdated({ 
    document: 'proprietes/{proprieteId}', 
    region: region 
}, async (event) => {
    const proprieteId = event.params.proprieteId;
    
    const favorisSnapshot = await db.collectionGroup('favoris')
        .where('proprieteId', '==', proprieteId)
        .get();

    if (favorisSnapshot.empty) return null;

    const batch = db.batch();
    
    for (const doc of favorisSnapshot.docs) {
        const userId = doc.ref.parent.parent.id;
        const alerteRef = db.collection('utilisateurs').doc(userId).collection('alertes').doc();

        batch.set(alerteRef, { 
            message: "Mise à jour sur un de vos favoris !", 
            proprieteId: proprieteId, 
            type: "MAJ_FAVORI",
            timestamp: getFieldValue().serverTimestamp(),
            lu: false 
        });

        await services.internal.sendPushNotification(
            userId,
            "Mise à jour Favoris ⭐",
            "Des modifications ont été apportées à une maison que vous suivez.",
            { proprieteId: proprieteId, type: "MAJ_FAVORI" }
        );
    }

    return batch.commit();
});