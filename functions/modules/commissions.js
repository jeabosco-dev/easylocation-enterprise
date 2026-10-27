const { admin, db, getFieldValue } = require('./admin');
const region = 'europe-west1';
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');

/**
 * TRIGGER PARRAINAGE & RECOMPENSES COMMISSION (SUR BASE NETTE ET DOUBLE TRAÇABILITÉ)
 */
exports.onFactureClotureeReward = onDocumentUpdated({ 
    document: 'factures/{factureId}', 
    region: region 
}, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    const estCloture = newData.etapeDossier === 'cloture' && oldData.etapeDossier !== 'cloture';
    const estValide = newData.confirmationLocataire === 'valide';
    
    if (estCloture && estValide && !newData.bonusApplied) {
        const locataireId = newData.clientId || newData.userId || newData.locataireId;
        const factureIdClair = newData.id || event.params.factureId;
        
        try {
            // 1. Récupération du profil utilisateur
            const userDoc = await db.collection('utilisateurs').doc(locataireId).get();
            const userData = userDoc.exists ? userDoc.data() : {};
            
            // ✅ Recherche hybride du referrerId (map referral OU racine)
            const referrerId = userData.referral?.referrerId || userData.referrerId;

            if (referrerId) {
                // 2. Récupération de la configuration globale
                const configDoc = await db.collection('settings').doc('app_config').get();
                const configData = configDoc.exists ? configDoc.data() : {};
                const refConfig = configData.referral_config || {};

                // Vérifier si le programme est actif
                if (refConfig.is_active === false) {
                    console.log("⚠️ Programme de parrainage désactivé dans app_config.");
                    return;
                }

                // Taux en pourcentage
                const referrerRate = refConfig.referrer_rate ?? refConfig.referrer_reward ?? 0.0;
                const refereeRate = refConfig.referee_rate ?? refConfig.referee_reward ?? 0.0;

                // 🎯 1. Calcul sur Base Nette : totalNetUSD - commissionBailleur
                const totalNet = newData.totalNetUSD || 0;
                const comBailleur = newData.commissionBailleur || 0;
                const baseCommission = Math.max(0, totalNet - comBailleur);

                // Si pas de totalNetUSD, fallback sur la commission explicite
                const assietteCalcul = baseCommission > 0 ? baseCommission : (newData.commissionUSD || newData.fraisService || 0.0);

                // Calcul des montants
                const bonusParrain = (assietteCalcul * referrerRate) / 100;
                const bonusFilleul = (assietteCalcul * refereeRate) / 100;

                const batch = db.batch();

                // 🎯 2. Traitement du Parrain (Wallet + Operations + Transactions)
                if (bonusParrain > 0) {
                    const parrainWalletRef = db.collection('wallets').doc(referrerId);
                    
                    // A. Solde wallet -> versé dans 'commission_balance'
                    batch.set(parrainWalletRef, {
                        'commission_balance': admin.firestore.FieldValue.increment(bonusParrain),
                        'lastUpdate': getFieldValue().serverTimestamp()
                    }, { merge: true });

                    // B. Operations del wallet
                    const parrainOpRef = parrainWalletRef.collection('operations').doc();
                    batch.set(parrainOpRef, {
                        amount: bonusParrain,
                        type: "PARRAINAGE_REWARD",
                        factureId: factureIdClair,
                        filleulId: locataireId,
                        timestamp: getFieldValue().serverTimestamp()
                    });

                    // C. Collection racine transactions
                    const txParrainRef = db.collection('transactions').doc();
                    batch.set(txParrainRef, {
                        walletId: referrerId,
                        userId: referrerId,
                        participants: [referrerId, locataireId],
                        title: "Bonus Parrainage",
                        amount: bonusParrain,
                        isPositive: true,
                        type: "depot",
                        status: "success",
                        referenceFacture: factureIdClair,
                        date: getFieldValue().serverTimestamp(),
                        description: `Gain de parrainage suite à la validation de facture par le filleul`
                    });
                }

                // 🎯 3. Traitement du Filleul (Wallet + Operations + Transactions)
                if (bonusFilleul > 0) {
                    const filleulWalletRef = db.collection('wallets').doc(locataireId);

                    // A. Solde wallet -> versé dans 'commission_balance'
                    batch.set(filleulWalletRef, {
                        'commission_balance': admin.firestore.FieldValue.increment(bonusFilleul),
                        'lastUpdate': getFieldValue().serverTimestamp()
                    }, { merge: true });

                    // B. Operations del wallet
                    const filleulOpRef = filleulWalletRef.collection('operations').doc();
                    batch.set(filleulOpRef, {
                        amount: bonusFilleul,
                        type: "PARRAINAGE_BONUS_FILLEUL",
                        factureId: factureIdClair,
                        parrainId: referrerId,
                        timestamp: getFieldValue().serverTimestamp()
                    });

                    // C. Collection racine transactions
                    const txFilleulRef = db.collection('transactions').doc();
                    batch.set(txFilleulRef, {
                        walletId: locataireId,
                        userId: locataireId,
                        participants: [locataireId, referrerId],
                        title: "Bonus d'Invitation",
                        amount: bonusFilleul,
                        isPositive: true,
                        type: "depot",
                        status: "success",
                        referenceFacture: factureIdClair,
                        date: getFieldValue().serverTimestamp(),
                        description: `Bonus de bienvenue suite à votre première réservation parrainée`
                    });
                }

                // Verrouillage anti-doublon
                batch.update(event.data.after.ref, { 'bonusApplied': true });
                
                await batch.commit();
                console.log(`✅ [COMMISSIONS/PARRAINAGE] Traité pour facture ${factureIdClair} : Parrain ${referrerId} (+${bonusParrain.toFixed(2)}$ dans commission_balance) & Filleul ${locataireId} (+${bonusFilleul.toFixed(2)}$ dans commission_balance)`);
            }
        } catch (error) { 
            console.error("💥 Erreur bonus clôture:", error); 
        }
    }
});