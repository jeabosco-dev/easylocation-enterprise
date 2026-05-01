const admin = require('firebase-admin');
const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');

/**
 * Accès "Lazy" à FieldValue pour éviter d'initialiser 
 * le SDK Firestore au top-level (prévention timeout).
 */
const getFieldValue = () => admin.firestore.FieldValue;
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
    const db = admin.firestore();
    const userId = event.params.userId;
    const userData = event.data.data();
    const walletRef = db.collection('wallets').doc(userId);

    const MONTANT_BIENVENUE = 5; // Bonus en USD

    try {
        await db.runTransaction(async (transaction) => {
            const walletDoc = await transaction.get(walletRef);
            
            if (!walletDoc.exists) {
                // Création du Wallet
                transaction.set(walletRef, {
                    userId: userId,
                    phoneNumber: userData.phoneNumber || "", 
                    userName: userData.nom || "Utilisateur",
                    balance: MONTANT_BIENVENUE, 
                    currency: "USD",
                    lastUpdate: getFieldValue().serverTimestamp(),
                    status: "active",
                    welcomeBonusApplied: true
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
    const data = event.data.after.data();
    if (!data?.uid) return null;

    // Logique de détermination du rôle
    let role = data.role || (data.isProprietaire === true ? 'bailleur' : 'locataire');

    try {
        const user = await admin.auth().getUser(data.uid);
        // On ne met à jour que si le claim a changé pour économiser des ressources
        if (user.customClaims?.role !== role) {
            await admin.auth().setCustomUserClaims(data.uid, { 
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
    const db = admin.firestore();
    const userData = event.data.data();
    const phone = userData.phoneNumber;

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