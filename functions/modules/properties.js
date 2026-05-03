const admin = require('firebase-admin');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
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
 * (Minuscules, sans accents, sans espaces)
 */
const slugify = (text) => {
    if (!text) return 'inconnu';
    return text
        .toString()
        .normalize("NFD")                   // Décompose les caractères accentués
        .replace(/[\u0300-\u036f]/g, "")    // Supprime les accents
        .toLowerCase()
        .trim()
        .replace(/\s+/g, '')                // Supprime tous les espaces
        .replace(/[^a-z0-9]/g, '');         // Supprime les caractères spéciaux restants
};

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
 * 2. Notification de fin de visite
 */
exports.onVisitFinishedNotifyLocataire = onDocumentUpdated({ 
    document: 'visites/{visiteId}', 
    region: region 
}, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData.statut === 'terminee' && oldData.statut !== 'terminee') {
        const locataireId = newData.clientId || newData.locataireId;
        const propertyId = newData.propertyId;

        if (!locataireId) return null;

        try {
            await db.collection('utilisateurs').doc(locataireId).collection('alertes').add({
                message: `La visite est terminée. Quelle est votre décision ?`,
                type: "DECISION_VISITE",
                propertyId: propertyId,
                timestamp: getFieldValue().serverTimestamp(),
                lu: false
            });

            await services.internal.sendPushNotification(
                locataireId,
                "Visite terminée ! 🏠",
                "Qu'avez-vous pensé de la maison ? Donnez votre réponse.",
                { propertyId: propertyId || "", type: "DECISION_VISITE" }
            );
        } catch (error) {
            console.error("❌ Erreur notification fin de visite:", error);
        }
    }
});

/**
 * 3. RECHERCHE AUTOMATIQUE VIP (Trigger de paiement)
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
 * 5. SELF-LEARNING : Mise à jour des stats de performance (Urgency Logic)
 */
exports.onPropertyStatusChangedUpdateStats = onDocumentUpdated({
    document: 'proprietes/{propertyId}',
    region: region
}, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData.status === 'loué' && oldData.status !== 'loué') {
        const createdAt = newData.createdAt; 
        const rentedAt = admin.firestore.Timestamp.now();

        if (!createdAt) return null;

        const diffInMs = rentedAt.toMillis() - createdAt.toMillis();
        const hoursElapsed = Math.floor(diffInMs / (1000 * 60 * 60));

        // Application du slugify pour un ID propre (ex: rdc_sudkivu_bukavu_ibanda)
        const provinceSlug = slugify(newData.province);
        const villeSlug = slugify(newData.ville);
        const communeSlug = slugify(newData.commune);
        
        const statsDocId = `rdc_${provinceSlug}_${villeSlug}_${communeSlug}`;
        const statsRef = db.collection('stats_localites').doc(statsDocId);

        try {
            await db.runTransaction(async (transaction) => {
                const statsDoc = await transaction.get(statsRef);

                if (!statsDoc.exists) {
                    transaction.set(statsRef, {
                        avg_hours: hoursElapsed,
                        total_rented: 1,
                        last_update: rentedAt,
                        commune: newData.commune, // On garde le nom propre pour l'affichage UI
                        ville: newData.ville
                    });
                } else {
                    const currentData = statsDoc.data();
                    const oldTotal = currentData.total_rented || 0;
                    const oldAvg = currentData.avg_hours || 0;

                    const newTotal = oldTotal + 1;
                    const newAvg = Math.floor(((oldAvg * oldTotal) + hoursElapsed) / newTotal);

                    transaction.update(statsRef, {
                        avg_hours: newAvg,
                        total_rented: newTotal,
                        last_update: rentedAt
                    });
                }
            });
            console.log(`📈 Stats mises à jour : ${statsDocId} (${hoursElapsed}h)`);
        } catch (e) {
            console.error("❌ Erreur transaction stats_localites :", e);
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