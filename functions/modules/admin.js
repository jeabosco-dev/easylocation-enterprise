const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require('firebase-admin');

// Initialisation unique de l'application Firebase Admin
if (admin.apps.length === 0) {
    admin.initializeApp();
}

// On définit les instances une fois pour toutes
const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

/**
 * Cloud Function v2 permettant à un super_admin d'ajouter un agent.
 * S'adapte automatiquement si l'agent a déjà créé son compte sur son téléphone.
 */
const creerAgentEquipe = onCall(async (request) => {
    // 1. Vérification de l'authentification de l'appelant
    if (!request.auth) {
        throw new HttpsError(
            "unauthenticated", 
            "L'utilisateur doit être authentifié pour exécuter cette action."
        );
    }

    // 2. Vérification stricte des droits de l'appelant (Seul un super_admin peut créer un agent)
    const callerUid = request.auth.uid;
    const callerDoc = await db.collection("utilisateurs").doc(callerUid).get();
    
    if (!callerDoc.exists || callerDoc.data().role !== "super_admin") {
        throw new HttpsError(
            "permission-denied", 
            "Accès refusé : Seul un super_admin peut ajouter un membre à l'équipe."
        );
    }

    // 3. Récupération et validation des données envoyées par le Backoffice
    const { 
        emailProfessionnel, 
        passwordBackoffice, 
        nom, 
        postnom, 
        prenom, 
        genre, 
        telephone, 
        ville, 
        roleEquipe 
    } = request.data;

    if (!emailProfessionnel || !passwordBackoffice || !roleEquipe || !prenom || !nom) {
        throw new HttpsError(
            "invalid-argument", 
            "Certains champs obligatoires sont manquants pour la configuration de l'agent."
        );
    }

    const equipeRoles = [
        'super_admin', 'comptable', 'rh', 'tech_support', 
        'marketing', 'operations', 'certificateur', 'logistique'
    ];

    if (!equipeRoles.includes(roleEquipe)) {
        throw new HttpsError(
            "invalid-argument", 
            "Le rôle spécifié n'est pas un rôle administratif valide."
        );
    }

    try {
        let userRecord;
        let finalUid;
        let isExistingAccount = false;

        console.log(`🚀 [ADMIN] Traitement de l'agent : ${emailProfessionnel} (${telephone})`);

        // 4. STRATÉGIE INTELLIGENTE : VÉRIFIER SI LE COMPTE MOBILE EXISTE DÉJÀ VIA LE TÉLÉPHONE
        try {
            userRecord = await auth.getUserByPhoneNumber(telephone);
            finalUid = userRecord.uid;
            isExistingAccount = true;
            console.log(`📱 [ADMIN] Compte mobile existant trouvé (UID: ${finalUid}). Mutation en cours...`);
            
            // On lui greffe l'email professionnel et le mot de passe initial du Backoffice
            await auth.updateUser(finalUid, {
                email: emailProfessionnel,
                password: passwordBackoffice,
                displayName: `${prenom} ${nom}`,
            });
            console.log(`✅ [ADMIN] Accès Web greffés avec succès sur le compte existant.`);

        } catch (authError) {
            // Si le numéro n'est pas trouvé, on crée un tout nouveau compte Auth
            if (authError.code === 'auth/user-not-found') {
                console.log(`🆕 [ADMIN] Aucun compte trouvé pour ce numéro. Création d'un nouveau compte global...`);
                userRecord = await auth.createUser({
                    email: emailProfessionnel,
                    password: passwordBackoffice,
                    displayName: `${prenom} ${nom}`,
                    phoneNumber: telephone || undefined,
                    disabled: false
                });
                finalUid = userRecord.uid;
            } else {
                throw authError; // Relancer si c'est une autre erreur critique
            }
        }

        // 5. CRÉATION OU MISE À JOUR DU DOCUMENT DANS LA COLLECTION 'UTILISATEURS'
        const batch = db.batch();
        const userRef = db.collection("utilisateurs").doc(finalUid);

        // Structure nettoyée : on ne force PAS le champ 'email' global ici pour préserver l'email perso existant
        const agentData = {
            uid: finalUid,
            nom: nom,
            postnom: postnom || "",
            prenom: prenom,
            genre: genre || "Non spécifié",
            telephone: telephone || "",
            email_professionnel: emailProfessionnel,
            password_backoffice: passwordBackoffice,
            role: roleEquipe,
            activeRole: roleEquipe,
            roles: ["locataire", roleEquipe], 
            statut: "actif",
            staffStatus: "validated",
            ville: ville || "Bukavu",
            pays: "RDC",
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        // Si c'est un nouveau compte créé de zéro, on initialise la date de création et l'email standard
        if (!isExistingAccount) {
            agentData.email = emailProfessionnel;
            agentData.createdAt = admin.firestore.FieldValue.serverTimestamp();
        }

        // Le merge: true préserve tout le reste (e-mail d'origine, solde du portefeuille, etc.)
        batch.set(userRef, agentData, { merge: true });
        await batch.commit();

        console.log(`🎉 [ADMIN] Document Firestore synchronisé pour l'UID: ${finalUid}`);

        return {
            success: true,
            uid: finalUid,
            message: isExistingAccount 
                ? `Les accès Web ont été greffés avec succès sur le compte mobile existant de l'agent ${prenom} ${nom}.`
                : `Le nouveau compte de l'agent ${prenom} ${nom} a été créé de zéro avec succès.`
        };

    } catch (error) {
        console.error("❌ [ADMIN] Erreur lors de la configuration de l'agent :", error);
        
        if (error.code === "auth/email-already-exists") {
            throw new HttpsError("already-exists", "Cet e-mail professionnel est déjà utilisé par un autre compte.");
        }
        
        throw new HttpsError("internal", error.message || "Erreur interne lors de la configuration de l'agent.");
    }
});

// Exportation globale
module.exports = { 
    admin, 
    db,               
    auth,             
    getDb: () => db, 
    getAuth: () => auth,
    getMessaging: () => messaging,
    getFieldValue: () => admin.firestore.FieldValue,
    creerAgentEquipe  
};