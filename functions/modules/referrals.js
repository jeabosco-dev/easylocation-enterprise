/**
 * MODULE : PARRAINAGE & PARTENAIRES (Win-Win Strategy)
 * Chemin : functions/modules/referrals.js
 * Description : Gère les commissions d'acquisition et les bonus filleuls basés sur les pourcentages (Harmonisé avec referrerId).
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
            // Récupération de la configuration globale pour les taux de parrainage (%)
            const configDoc = await db.collection('settings').doc('app_config').get();
            const configData = configDoc.exists ? configDoc.data() : {};
            const referralConfig = configData.referral_config || {};

            // Vérification si le parrainage est actif
            const isReferralActive = referralConfig.is_active === true;
            
            // Taux configurés (ex: 5.0 pour 5% et 2.5 pour 2.5%)
            const defaultReferrerRate = Number(referralConfig.referrer_rate ?? referralConfig.referrer_reward ?? 5.0) / 100;
            const defaultRefereeRate = Number(referralConfig.referee_rate ?? referralConfig.referee_reward ?? 2.5) / 100;

            if (!isReferralActive) {
                console.log("ℹ️ Le programme de parrainage est actuellement suspendu dans la configuration.");
                return;
            }

            // --- LOGIQUE A : COMMISSION SUR LA PART LOCATAIRE (Parrain / Partenaire B2B) ---
            if (partnerIdLocataire && locataireId) {
                const previousLocContracts = await db.collection('contrats')
                    .where('locataireId', '==', locataireId)
                    .where('statut', 'in', ['actif', 'cloture'])
                    .get();

                if (previousLocContracts.size <= 1) {
                    const assietteLoc = Number(newData.commissionLocataire || 0); 
                    await verserCommission(partnerIdLocataire, assietteLoc, locataireId, event.params.contratId, "ACQUISITION_LOCATAIRE", defaultReferrerRate);
                } else {
                    console.log(`ℹ️ SKIP : Locataire ${locataireId} déjà client.`);
                }
            }

            // --- LOGIQUE B : COMMISSION SUR LA PART BAILLEUR (Parrain C2C ou B2B) ---
            const bailleurDoc = await db.collection('utilisateurs').doc(bailleurId).get();
            const bailleurUserData = bailleurDoc.exists ? bailleurDoc.data() : {};
            // 🔍 Lecture unifiée avec referrerId (et fallback de sécurité sur l'objet referral.id ou l'ancien format)
            const parrainBailleurId = bailleurUserData.referrerId || bailleurUserData.referrer_id || (bailleurUserData.referral ? bailleurUserData.referral.id : null);

            if (parrainBailleurId && bailleurId) {
                const previousBailleurContracts = await db.collection('contrats')
                    .where('bailleurId', '==', bailleurId)
                    .where('statut', 'in', ['actif', 'cloture'])
                    .get();

                if (previousBailleurContracts.size <= 1) {
                    const assietteBai = Number(newData.commissionBailleur || 0);
                    await verserCommission(parrainBailleurId, assietteBai, bailleurId, event.params.contratId, "ACQUISITION_BAILLEUR", defaultReferrerRate);
                } else {
                    console.log(`ℹ️ SKIP : Bailleur ${bailleurId} déjà actif par le passé.`);
                }
            }

            // --- LOGIQUE C : BONUS POUR LE FILLEUL (Win-Win C2C) ---
            const locataireDoc = await db.collection('utilisateurs').doc(locataireId).get();
            const locataireUserData = locataireDoc.exists ? locataireDoc.data() : {};
            // 🔍 Lecture unifiée avec referrerId
            const parrainLocataireId = locataireUserData.referrerId || locataireUserData.referrer_id || newData.parrainId || (locataireUserData.referral ? locataireUserData.referral.id : null);

            if (parrainLocataireId && locataireId && defaultRefereeRate > 0) {
                const previousLocContracts = await db.collection('contrats')
                    .where('locataireId', '==', locataireId)
                    .where('statut', 'in', ['actif', 'cloture'])
                    .get();

                // On applique le bonus du filleul uniquement sur son premier contrat actif
                if (previousLocContracts.size <= 1) {
                    const assietteLoc = Number(newData.commissionLocataire || 0);
                    const bonusFilleul = assietteLoc * defaultRefereeRate;

                    if (bonusFilleul > 0) {
                        const walletRef = db.collection('wallets').doc(locataireId);
                        
                        const batch = db.batch();
                        // Créditer le wallet du filleul (en cashback ou solde promotionnel)
                        batch.set(walletRef, {
                            'cashback_balance': getFieldValue().increment(bonusFilleul),
                            'last_update': getFieldValue().serverTimestamp()
                        }, { merge: true });

                        // Logger l'opération dans le sous-document operations du wallet
                        const logRef = walletRef.collection('operations').doc();
                        batch.set(logRef, {
                            amount: bonusFilleul,
                            type: "BONUS_FILLEUL",
                            contrat_id: event.params.contratId,
                            taux_applique: defaultRefereeRate,
                            timestamp: getFieldValue().serverTimestamp()
                        });

                        // Créer un audit global des commissions de parrainage
                        const auditRef = db.collection('audit_commissions').doc();
                        batch.set(auditRef, {
                            partner_id: parrainLocataireId, // Le parrain lié
                            filleul_id: locataireId,
                            contrat_id: event.params.contratId,
                            montant_assiette: assietteLoc,
                            bonus_filleul: bonusFilleul,
                            taux_applique: defaultRefereeRate,
                            date: getFieldValue().serverTimestamp(),
                            type: "BONUS_FILLEUL",
                            statut: "valide"
                        });

                        await batch.commit();
                        console.log(`✅ SUCCESS [BONUS_FILLEUL] : ${bonusFilleul} USD versés au filleul ${locataireId}`);
                    }
                }
            }

        } catch (error) {
            console.error("❌ ERREUR lors du traitement des commissions :", error);
        }
    }
});

/**
 * Fonction interne pour traiter le versement et l'audit basé sur un pourcentage (%)
 */
async function verserCommission(partnerId, montantAssiette, sourceId, contratId, type, globalRate) {
    const partnerRef = db.collection('partenaires').doc(partnerId);
    const partnerDoc = await partnerRef.get();

    if (!partnerDoc.exists || montantAssiette <= 0) return;
    
    const partnerData = partnerDoc.data();
    if (partnerData.status !== 'active' && partnerData.is_active !== true) {
        console.log(`ℹ️ Partenaire/Parrain ${partnerId} inactif.`);
        return;
    }

    const rawPartnerRate = partnerData.commission_rate;
    const ratePercentage = (rawPartnerRate !== undefined && rawPartnerRate !== null) 
        ? Number(rawPartnerRate) / 100 
        : globalRate;

    const commissionFinale = montantAssiette * ratePercentage;

    if (commissionFinale > 0) {
        // 1. Mise à jour atomique du solde du parrain/partenaire
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
            montant_assiette: montantAssiette,
            commission_gagnee: commissionFinale,
            taux_applique: ratePercentage,
            date: getFieldValue().serverTimestamp(),
            type: type,
            statut: "valide"
        });

        console.log(`✅ SUCCESS [${type}] : ${commissionFinale} USD (${ratePercentage * 100}%) versés pour ${partnerId}`);
    }
}