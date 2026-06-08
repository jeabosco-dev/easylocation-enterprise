// functions/modules/users.js
const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
// Importation des outils depuis ton module central admin.js
const { getDb, getAuth, getFieldValue } = require('./admin');

const region = 'europe-west1';

// --- 1. GESTION DU WALLET (PORTEFEUILLE) ---

/**
 * Initialise le Wallet et offre les crédits de bienvenue 
 * dès la création du profil utilisateur.
 */
exports.onUserCreatedInitializeWallet = onDocumentCreated({ 
    document: 'utilisateurs/{userId}', 
    region: region 
}, async (event) => {
    const db = getDb(); // Utilisation du getter modulaire
    const userId = event.params.userId;
    const userData = event.data.data();
    const walletRef = db.collection('wallets').doc(userId);

    const MONTANT_BIENVENUE = 5; // Bonus en USD

    try {
        await db.runTransaction(async (transaction) => {
            const walletDoc = await transaction.get(walletRef);
            
            if (!walletDoc.exists) {
                // Création du Wallet avec la nouvelle structure séparée
                transaction.set(walletRef, {
                    userId: userId,
                    phoneNumber: userData.telephone || "", 
                    userName: userData.nom || "Utilisateur",
                    balance: 0.0,                  // ✅ Solde réel à 0
                    bonusBalance: MONTANT_BIENVENUE, // ✅ Bonus séparé
                    cashback_balance: 0.0,
                    commission_balance: 0.0,
                    pendingRefund: 0.0,
                    currency: "USD",
                    lastUpdate: getFieldValue().serverTimestamp(),
                    status: "active",
                    welcomeBonusApplied: true,
                    accountType: userData.role || 'locataire'
                });

                // Historisation de l'opération
                const historyRef = walletRef.collection('operations').doc();
                transaction.set(historyRef, {
                    type: "CADEAU_BIENVENUE",
                    montant: MONTANT_BIENVENUE,
                    date: getFieldValue().serverTimestamp(),
                    description: "Bonus de bienvenue EasyLocation"
                });
            }
        });
        console.log(`✅ Wallet + Bonus (${MONTANT_BIENVENUE}$) initialisés pour : ${userId}`);
    } catch (error) {
        console.error(`❌ Erreur initialisation Wallet pour ${userId}:`, error);
    }
});

// --- 2. GESTION DES RÔLES (CUSTOM CLAIMS) ---

/**
 * Synchronise le rôle Firestore avec les Custom Claims de Firebase Auth
 * pour sécuriser l'accès côté client (Rules & UI).
 */
exports.onUserRoleUpdated = onDocumentWritten({ 
    document: 'utilisateurs/{userId}', 
    region: region 
}, async (event) => {
    const auth = getAuth(); // Utilisation du getter modulaire
    const data = event.data.after.data();
    if (!data?.uid) return null;

    // Logique de détermination du rôle
    let role = data.role || (data.isProprietaire === true ? 'bailleur' : 'locataire');

    try {
        const user = await auth.getUser(data.uid);
        // On ne met à jour que si le claim a changé pour économiser des ressources
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

/**
 * Lie un utilisateur qui vient de s'inscrire à des contrats pré-existants
 * créés via son numéro de téléphone (onboarding rapide).
 */
exports.onUserRegisteredLinkContract = onDocumentCreated({
    document: 'utilisateurs/{userId}',
    region: region
}, async (event) => {
    const db = getDb(); // Utilisation du getter modulaire
    const userData = event.data.data();
    const phone = userData.telephone;

    if (!phone) return null;

    try {
        // Recherche des contrats "orphelins" (asymétriques)
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