// C:\Users\LANGE\easylocation_mvp\functions\modules\partners.js

const admin = require('firebase-admin');

/**
 * Traite la commission d'un partenaire B2B lors d'un paiement réussi.
 * @param {Object} db - Instance Firestore
 * @param {string} partnerId - ID du partenaire (ex: PART-...)
 * @param {Object} paiement - Données du paiement
 */
async function processPartnerCommission(db, partnerId, paiement) {
    const partnerRef = db.collection('partenaires').doc(partnerId);
    
    try {
        await db.runTransaction(async (t) => {
            const partnerDoc = await t.get(partnerRef);
            
            if (!partnerDoc.exists) {
                console.warn(`⚠️ Partenaire ${partnerId} non trouvé.`);
                return;
            }

            const partnerData = partnerDoc.data();
            
            // --- VERROU DE SÉCURITÉ DOUBLE (is_active + status) ---
            // On bloque si is_active est explicitement false OU si le statut n'est pas 'active'
            if (partnerData.is_active === false || partnerData.status !== 'active') {
                console.log(`ℹ️ Partenaire ${partnerId} est inactif ou suspendu (Status: ${partnerData.status}). Pas de commission.`);
                return;
            }

            // Calcul de la commission (nom du champ : commission_rate)
            // 5% par défaut si le champ est vide
            const rate = partnerData.commission_rate || 0.05;
            const montantCommission = paiement.montant * rate;

            // 1. Mise à jour du solde et des compteurs (Champs harmonisés avec Firestore)
            t.update(partnerRef, {
                solde_commission: admin.firestore.FieldValue.increment(montantCommission),
                total_conversions: admin.firestore.FieldValue.increment(1),
                last_activity: admin.firestore.FieldValue.serverTimestamp()
            });

            // 2. Création d'un audit de commission (Historique pour SGA SARLU)
            const auditRef = db.collection('audit_commissions').doc();
            t.set(auditRef, {
                partner_id: partnerId,
                paiement_id: paiement.id || "N/A",
                montant_paiement: paiement.montant,
                commission_gagnee: montantCommission,
                taux_applique: rate,
                date: admin.firestore.FieldValue.serverTimestamp(),
                statut: 'en_attente_paiement' 
            });
        });

        console.log(`✅ Commission de ${partnerId} calculée avec succès.`);
    } catch (error) {
        console.error("❌ Erreur transaction Partenaire :", error);
    }
}

module.exports = { processPartnerCommission };