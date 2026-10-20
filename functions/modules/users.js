// functions/modules/users.js
const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { Timestamp } = require('firebase-admin/firestore');
const { getDb, getAuth, getFieldValue } = require('./admin');

const region = 'europe-west1';

// --- 1. GESTION DU WALLET (PORTEFEUILLE) ---

/**
 * Initialise le Wallet et offre les crédits de bienvenue
 * avec montant, statut et durée configurables depuis le Backoffice (settings/app_config).
 */
exports.onUserCreatedInitializeWallet = onDocumentCreated({ 
    document: 'utilisateurs/{userId}', 
    region: region 
}, async (event) => {
    const db = getDb();
    const userId = event.params.userId;
    const userData = event.data.data();
    const walletRef = db.collection('wallets').doc(userId);

    const role = userData.role || 'locataire';
    const isLocataire = role === 'locataire';

    // 🔄 1. Lecture dynamique de la configuration depuis Firestore
    let bonusAmount = 0;
    let bonusDurationDays = 0;
    let isBonusActive = false;

    try {
        const configDoc = await db.collection('settings').doc('app_config').get();
        if (configDoc.exists) {
            const configData = configDoc.data();
            const wb = configData.welcome_bonus || {};
            bonusAmount = Number(wb.amount || 0);
            bonusDurationDays = Number(wb.duration_days || 0);
            isBonusActive = wb.status === 'active' || wb.is_active === true;
        }
    } catch (configErr) {
        console.error("⚠️ Impossible de lire app_config, fallback aux valeurs par défaut :", configErr);
        bonusAmount = 5;
        bonusDurationDays = 30;
        isBonusActive = true;
    }

    // Le bonus n'est appliqué que si le bonus est actif dans le Backoffice ET qu'il s'agit d'un locataire
    const MONTANT_BIENVENUE = (isLocataire && isBonusActive) ? bonusAmount : 0; 

    try {
        await db.runTransaction(async (transaction) => {
            const walletDoc = await transaction.get(walletRef);
            
            if (!walletDoc.exists) {
                let expiryTimestamp = null;

                if (isLocataire && isBonusActive && MONTANT_BIENVENUE > 0 && bonusDurationDays > 0) {
                    const expiryDate = new Date();
                    expiryDate.setDate(expiryDate.getDate() + bonusDurationDays);
                    expiryTimestamp = Timestamp.fromDate(expiryDate);
                }

                transaction.set(walletRef, {
                    userId: userId,
                    phoneNumber: userData.telephone || "", 
                    userName: userData.nom || "Utilisateur",
                    balance: 0.0,
                    bonusBalance: MONTANT_BIENVENUE,
                    bonusExpiryDate: expiryTimestamp,
                    cashback_balance: 0.0,
                    commission_balance: 0.0,
                    pendingRefund: 0.0,
                    currency: "USD",
                    lastUpdate: getFieldValue().serverTimestamp(),
                    status: "active",
                    welcomeBonusApplied: isLocataire && isBonusActive && MONTANT_BIENVENUE > 0,
                    accountType: role
                });

                if (isLocataire && isBonusActive && MONTANT_BIENVENUE > 0) {
                    const historyRef = walletRef.collection('operations').doc();
                    transaction.set(historyRef, {
                        type: "CADEAU_BIENVENUE",
                        montant: MONTANT_BIENVENUE,
                        date: getFieldValue().serverTimestamp(),
                        description: "Bonus de bienvenue EasyLocation"
                    });
                }
            }
        });
        console.log(`✅ Wallet initialisé pour ${userId} (Rôle: ${role}, Bonus: ${MONTANT_BIENVENUE}$, Durée: ${bonusDurationDays}j)`);
    } catch (error) {
        console.error(`❌ Erreur initialisation Wallet pour ${userId}:`, error);
    }
});

// --- 2. GESTION DES RÔLES (CUSTOM CLAIMS) ---

exports.onUserRoleUpdated = onDocumentWritten({ 
    document: 'utilisateurs/{userId}', 
    region: region 
}, async (event) => {
    const auth = getAuth();
    const data = event.data.after.data();
    if (!data?.uid) return null;

    let role = data.role || (data.isProprietaire === true ? 'bailleur' : 'locataire');

    try {
        const user = await auth.getUser(data.uid);
        if (user.customClaims?.role !== role) {
            await auth.setCustomUserClaims(data.uid, { 
                ...user.customClaims, 
                role: role 
            });
            console.log(`🔑 Rôle mis à jour (${role}) pour l'utilisateur : ${data.uid}`);
        }
    } catch (e) { 
        console.error("❌ Erreur lors de la mise à jour des claims:", e); 
    }
});

// --- 3. FUSION DES COMPTES (ASYMMETRIC CONTRACTS) ---

exports.onUserRegisteredLinkContract = onDocumentCreated({
    document: 'utilisateurs/{userId}',
    region: region
}, async (event) => {
    const db = getDb();
    const userData = event.data.data();
    const phone = userData.telephone;

    if (!phone) return null;

    try {
        const pendingContracts = await db.collection('contrats')
            .where('isAsymmetric', '==', true)
            .get();

        const batch = db.batch();
        let found = false;

        pendingContracts.forEach(doc => {
            const contract = doc.data();
            if (contract.locatairePhone === phone || contract.bailleurPhone === phone) {
                const updateData = {
                    isAsymmetric: false,
                    lastUpdated: getFieldValue().serverTimestamp()
                };

                if (contract.locatairePhone === phone) updateData.locataireId = event.params.userId;
                if (contract.bailleurPhone === phone) updateData.bailleurId = event.params.userId;

                batch.update(doc.ref, updateData);
                found = true;
            }
        });

        if (found) {
            await batch.commit();
            console.log(`🔗 Contrat lié avec succès au numéro ${phone}`);
        }
    } catch (error) {
        console.error("❌ Erreur lors de la fusion du contrat:", error);
    }
});