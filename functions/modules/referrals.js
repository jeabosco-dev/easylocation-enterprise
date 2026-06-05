/**
 * MODULE : PARRAINAGE & PARTENAIRES (Win-Win Strategy)
 * Chemin : C : \Users\LANGE\easylocation_mvp\functions\modules\referrals.js
 * Description : Gère les commissions d'acquisition basées sur les parts encaissées par EasyLocation.
 */

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require('firebase-admin');

// Initialisation sécurisée
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();
const getFieldValue = () => admin.firestore.FieldValue;

/**
 * TRIGGER : Lorsqu'un contrat passe en statut 'actif'.
 */
exports.onContractFinalizedRewardPartner = onDocumentUpdated("contrats/{contratId}", async (event) => {
    const newData = event.data.after.data();
    const previousData = event.data.before.data();

    // 1. Déclenchement uniquement si le statut passe à 'actif'
    if (newData.statut === 'actif' && previousData.statut !== 'actif') {
        
        const locataireId = newData.locataireId; 
        const bailleurId = newData.bailleurId;
        const partnerIdLocataire = newData.partnerId; // Partenaire lié au locataire/contrat

        try {
            // --- LOGIQUE A : COMMISSION SUR LA PART LOCATAIRE ---
            if (partnerIdLocataire && locataireId) {
                const previousLocContracts = await db.collection('contrats')
                    .where('locataireId', '==', locataireId)
                    .where('statut', 'in', ['actif', 'cloture'])
                    .get();

                if (previousLocContracts.size <= 1) {
                    // Assiette = La part que EasyLocation a perçue du locataire
                    const assietteLoc = newData.commissionLocataire || 0; 
                    await verserCommission(partnerIdLocataire, assietteLoc, locataireId, event.params.contratId, "ACQUISITION_LOCATAIRE");
                } else {
                    console.log(`ℹ️ SKIP : Locataire ${locataireId} déjà client.`);
                }
            }

            // --- LOGIQUE B : COMMISSION SUR LA PART BAILLEUR (Scan Referrer) ---
            const bailleurDoc = await db.collection('utilisateurs').doc(bailleurId).get();
            const parrainBailleurId = bailleurDoc.data()?.referrer_id;

            if (parrainBailleurId) {
                const previousBailleurContracts = await db.collection('contrats')
                    .where('bailleurId', '==', bailleurId)
                    .where('statut', 'in', ['actif', 'cloture'])
                    .get();

                if (previousBailleurContracts.size <= 1) {
                    // Assiette = La part que EasyLocation a perçue du bailleur (retenue sur garantie)
                    const assietteBai = newData.commissionBailleur || 0;
                    await verserCommission(parrainBailleurId, assietteBai, bailleurId, event.params.contratId, "ACQUISITION_BAILLEUR");
                } else {
                    console.log(`ℹ️ SKIP : Bailleur ${bailleurId} déjà actif par le passé.`);
                }
            }

        } catch (error) {
            console.error("❌ ERREUR lors du traitement des commissions :", error);
        }
    }
});

/**
 * Fonction interne pour traiter le versement et l'audit
 */
async function verserCommission(partnerId, montantAssiette, sourceId, contratId, type) {
    const partnerRef = db.collection('partenaires').doc(partnerId);
    const partnerDoc = await partnerRef.get();

    if (!partnerDoc.exists || montantAssiette <= 0) return;
    
    const partnerData = partnerDoc.data();
    if (partnerData.status !== 'active' && partnerData.is_active !== true) {
        console.log(`ℹ️ Partenaire ${partnerId} inactif.`);
        return;
    }

    // Le partenaire touche un pourcentage de la commission encaissée par EasyLocation
    // Par défaut 10% de la part EasyLocation (ajustable selon tes besoins)
    const rate = partnerData.commission_rate || 0.10; 
    const commissionFinale = montantAssiette * rate;

    if (commissionFinale > 0) {
        // 1. Mise à jour atomique du solde du partenaire
        await partnerRef.update({
            solde_commission: getFieldValue().increment(commissionFinale),
            total_conversions: getFieldValue().increment(1),
            last_activity: getFieldValue().serverTimestamp()
        });

        // 2. Création de l'audit pour la comptabilité EasyLocation
        await db.collection('audit_commissions').add({
            partner_id: partnerId,
            contrat_id: contratId,
            source_user_id: sourceId, 
            montant_assiette: montantAssiette, // La part EasyLocation qui a servi de base
            commission_gagnee: commissionFinale, // Le gain réel du partenaire
            taux_applique: rate,
            date: getFieldValue().serverTimestamp(),
            type: type,
            statut: "valide"
        });

        console.log(`✅ SUCCESS [${type}] : ${commissionFinale} USD pour ${partnerId}`);
    }
}