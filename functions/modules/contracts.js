const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
// On importe admin, db et getFieldValue depuis votre fichier de configuration centrale
const { admin, db, getFieldValue } = require('./admin');

const region = 'europe-west1';

/**
 * CONSTANTES DE NORMALISATION
 * Utiliser 'active' pour la compatibilité avec le Provider Flutter
 */
const STATUS_ACTIF = 'active';

/**
 * Calcul sécurisé pour ajouter des mois à une date 
 * (Gère correctement les fins de mois comme le 31 janvier + 1 mois = 28/29 février)
 */
function addMonthsSecure(date, months) {
    const d = new Date(date.getTime());
    const expectedMonth = (d.getMonth() + months) % 12;
    d.setMonth(d.getMonth() + months);
    
    // Correction si JS saute un mois (ex: 31 jan -> 3 mars)
    if (d.getMonth() !== expectedMonth && d.getMonth() !== (expectedMonth < 0 ? expectedMonth + 12 : expectedMonth)) {
        d.setDate(0);
    }
    return d;
}

/**
 * Création rapide d'une propriété et d'un contrat lié (Bailleur)
 */
exports.quickOnboarding = onCall({ region: region }, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Authentification requise.');

    const { 
        propertyData, 
        tenantData,   
        startDate,
        dureeBail
    } = request.data;

    try {
        return await db.runTransaction(async (transaction) => {
            const propRef = db.collection('proprietes').doc();
            transaction.set(propRef, {
                ...propertyData,
                bailleurId: request.auth.uid,
                status: 'louée',
                estLouee: true,
                createdAt: getFieldValue().serverTimestamp(),
                lastUpdated: getFieldValue().serverTimestamp()
            });

            const contractRef = db.collection('contrats').doc();
            
            // ✅ GESTION DES DATES SÉCURISÉE
            const start = new Date(startDate);
            const end = addMonthsSecure(start, parseInt(dureeBail));

            transaction.set(contractRef, {
                propertyId: propRef.id,
                bailleurId: request.auth.uid,
                locataireId: null,
                locataireNom: tenantData.nom,
                locataireTel: tenantData.phone, // "Tel" pour cohérence avec le Provider Flutter
                ville: propertyData.ville || "Bukavu", 
                startDate: admin.firestore.Timestamp.fromDate(start),
                endDate: admin.firestore.Timestamp.fromDate(end),
                prochainPaiement: admin.firestore.Timestamp.fromDate(start),
                loyerMensuel: propertyData.loyer,
                status: STATUS_ACTIF, // Centralisé via constante
                isAsymmetric: true,
                createdAt: getFieldValue().serverTimestamp()
            });

            return { success: true, propertyId: propRef.id, contractId: contractRef.id };
        });
    } catch (e) {
        console.error("Erreur QuickOnboarding:", e);
        throw new HttpsError('internal', e.message);
    }
});

/**
 * Prolonge la durée d'un bail existant
 */
exports.prolongerBail = onCall({ region: region }, async (request) => {
    const { contractId, nbMois } = request.data;

    if (!contractId || !nbMois) {
        throw new HttpsError('invalid-argument', 'Paramètres manquants.');
    }

    try {
        return await db.runTransaction(async (transaction) => {
            const contractRef = db.collection('contrats').doc(contractId);
            const contractDoc = await transaction.get(contractRef);

            if (!contractDoc.exists) throw new Error("Contrat introuvable");

            const data = contractDoc.data();
            
            // ✅ RECUPERATION FLEXIBLE (Supporte startDate/endDate ou dateDebut/dateFin)
            const currentEndDate = (data.endDate || data.dateFin).toDate();
            const currentProchainPaiement = data.prochainPaiement.toDate();

            const newEndDate = addMonthsSecure(currentEndDate, parseInt(nbMois));
            const newProchainPaiement = addMonthsSecure(currentProchainPaiement, parseInt(nbMois));

            transaction.update(contractRef, {
                endDate: admin.firestore.Timestamp.fromDate(newEndDate),
                prochainPaiement: admin.firestore.Timestamp.fromDate(newProchainPaiement),
                statutPaiement: 'paye',
                dernierNombreMoisPayes: parseInt(nbMois),
                lastUpdated: getFieldValue().serverTimestamp()
            });

            const historiqueRef = contractRef.collection('historique_paiements').doc();
            transaction.set(historiqueRef, {
                type: "PROLONGATION",
                dateOperation: getFieldValue().serverTimestamp(),
                montantTotal: (data.loyerMensuel || 0) * nbMois,
                nbMoisAjoutes: nbMois,
                referenceMaison: data.propertyId ? data.propertyId.substring(0, 6).toUpperCase() : "N/A",
                status: 'validé'
            });

            return { success: true, message: "Bail prolongé avec succès" };
        });
    } catch (e) {
        console.error("Erreur ProlongerBail:", e);
        throw new HttpsError('internal', e.message);
    }
});

/**
 * Clôture un bail et remet la propriété en "disponible"
 */
exports.cloturerBail = onCall({ region: region }, async (request) => {
    const { contractId, propertyId } = request.data;

    if (!contractId || !propertyId) {
        throw new HttpsError('invalid-argument', 'ID manquant.');
    }

    try {
        await db.runTransaction(async (transaction) => {
            const contractRef = db.collection('contrats').doc(contractId);
            const propertyRef = db.collection('proprietes').doc(propertyId);
            
            const now = new Date();
            const monthId = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
            const statsRef = db.collection('admin_analytics').doc(monthId);

            transaction.update(contractRef, { 
                status: 'cloture', 
                dateCloture: getFieldValue().serverTimestamp() 
            });

            transaction.update(propertyRef, {
                status: 'disponible',
                estLouee: false,
                currentTenantId: null,
                lastUpdated: getFieldValue().serverTimestamp()
            });

            transaction.set(statsRef, {
                totalRotations: admin.firestore.FieldValue.increment(1),
                dernierEvenement: getFieldValue().serverTimestamp(),
                mois: monthId
            }, { merge: true });

        });
        return { success: true };
    } catch (e) {
        console.error("Erreur CloturerBail:", e);
        throw new HttpsError('internal', e.message);
    }
});

// --- DÉCLENCHEURS AUTOMATIQUES (TRIGGERS) ---

/**
 * Déclencheur automatique lors de la création d'un contrat
 */
exports.onContractCreated = onDocumentCreated("contrats/{contractId}", async (event) => {
    const data = event.data.data();

    // Vérification stricte via la constante (supporte aussi 'actif' pour la migration)
    if (data.status === STATUS_ACTIF || data.statut === 'actif') {
        
        const tenantId = data.locataireId; 
        const ownerId = data.bailleurId;   
        const totalAmount = data.loyerMensuel || 0;
        const villeBrute = data.ville || "Bukavu";

        try {
            const configDoc = await db.collection('settings').doc('app_config').get();
            
            if (!configDoc.exists) {
                console.error("Configuration introuvable dans settings/app_config");
                return null;
            }

            const configData = configDoc.data();
            const tauxLocataire = configData.loyalty_config?.locataire_cashback_percent || 0;
            const tauxBailleur = configData.loyalty_config?.bailleur_discount_percent || 0;

            const batch = db.batch();

            // 1. GESTION LOCATAIRE (Cashback / Points)
            if (tenantId) {
                const pointsLocataire = totalAmount * (tauxLocataire / 100);
                const tenantRef = db.collection('utilisateurs').doc(tenantId);
                
                batch.update(tenantRef, {
                    'wallet_points': admin.firestore.FieldValue.increment(pointsLocataire),
                    'last_loyalty_update': getFieldValue().serverTimestamp()
                });

                const logTenantRef = tenantRef.collection('wallet_history').doc();
                batch.set(logTenantRef, {
                    amount: pointsLocataire,
                    type: "CASHBACK_LOYALTY",
                    reason: `Récompense pour nouveau bail (${villeBrute})`,
                    timestamp: getFieldValue().serverTimestamp()
                });
            }

            // 2. GESTION BAILLEUR (Crédit Commission)
            if (ownerId) {
                const creditBailleur = totalAmount * (tauxBailleur / 100);
                const ownerRef = db.collection('utilisateurs').doc(ownerId);
                
                batch.update(ownerRef, {
                    'commission_credit': admin.firestore.FieldValue.increment(creditBailleur),
                    'last_commission_update': getFieldValue().serverTimestamp()
                });

                const logOwnerRef = ownerRef.collection('commission_history').doc();
                batch.set(logOwnerRef, {
                    amount: creditBailleur,
                    type: "COMMISSION_CREDIT",
                    reason: "Bonus nouveau contrat enregistré",
                    timestamp: getFieldValue().serverTimestamp()
                });
            }

            // 3. STATISTIQUES LOCALES (Social Proof)
            const villeDocId = villeBrute.toLowerCase().trim();
            const cityStatsRef = db.collection('stats_locales').doc(villeDocId);

            batch.set(cityStatsRef, {
                total_loges: admin.firestore.FieldValue.increment(1),
                ajouts_aujourdhui: admin.firestore.FieldValue.increment(1),
                derniere_mise_a_jour: getFieldValue().serverTimestamp(),
                nom_ville: villeBrute 
            }, { merge: true });

            console.log(`[TRIGGER] Commissions et Social Proof traités pour ${villeBrute}`);
            return await batch.commit();

        } catch (error) {
            console.error("Erreur fatale Trigger:", error);
            return null;
        }
    }
    return null;
});