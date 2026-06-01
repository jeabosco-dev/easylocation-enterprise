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
 * Alignée sur la nouvelle gouvernance d'EasyLocation (AGENT et SUPER_ADMIN).
 */
const creerAgentEquipe = onCall(async (request) => {
    // 1. Vérification de l'authentification de l'appelant
    if (!request.auth) {
        throw new HttpsError(
            "unauthenticated", 
            "L'utilisateur doit être authentifié pour exécuter cette action."
        );
    }

    // 2. Vérification stricte des droits de l'appelant
    const callerUid = request.auth.uid;
    const callerDoc = await db.collection("utilisateurs").doc(callerUid).get();
    
    // Acceptation du rôle de l'appelant en majuscules ou minuscules par sécurité
    if (!callerDoc.exists || (callerDoc.data().role !== "SUPER_ADMIN" && callerDoc.data().role !== "super_admin")) {
        throw new HttpsError(
            "permission-denied", 
            "Accès refusé : Seul un SUPER_ADMIN peut ajouter un membre à l'équipe."
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
        roleEquipe,
        direction // Récupération du pôle d'affectation envoyé par Flutter
    } = request.data;

    if (!emailProfessionnel || !passwordBackoffice || !roleEquipe || !prenom || !nom || !direction) {
        throw new HttpsError(
            "invalid-argument", 
            "Certains champs obligatoires (incluant le département) sont manquants."
        );
    }

    // ✅ ALIGNEMENT HARMONISÉ : Acceptation des rôles en MAJUSCULES conformes au modèle Flutter
    const equipeRoles = ['AGENT', 'SUPER_ADMIN'];

    if (!equipeRoles.includes(roleEquipe.toUpperCase())) {
        throw new HttpsError(
            "invalid-argument", 
            "Le rôle spécifié n'est pas un rôle administratif valide (Attendu : AGENT ou SUPER_ADMIN)."
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

        // 5. CRÉATION OU MISE À JOUR SÉCURISÉE DU DOCUMENT DANS LA COLLECTION 'UTILISATEURS'
        const userRef = db.collection("utilisateurs").doc(finalUid);

        // Détermination propre de la valeur du champ "role" principal pour ne pas bloquer l'app mobile
        const finalRoleRoot = roleEquipe.toUpperCase() === 'SUPER_ADMIN' ? 'super_admin' : 'locataire';
        const roleToPush = roleEquipe.toUpperCase() === 'SUPER_ADMIN' ? 'super_admin' : 'operations';

        if (isExistingAccount) {
            // ✅ SÉCURITÉ PROFILE MOBILE : Si le compte existe, on fait une mise à jour ciblée (Update)
            // On ne touche à aucun champ d'adresse (commune, quartier, avenue, numeroMaison) préexistant !
            await userRef.update({
                email_professionnel: emailProfessionnel,
                password_backoffice: passwordBackoffice,
                activeRole: roleEquipe.toUpperCase(),
                role: finalRoleRoot, // Préserve une valeur de rôle compatible avec l'app mobile
                direction: direction.toUpperCase(),
                statut_web: "active",
                staffStatus: "validated",
                statut: "actif",
                ville: ville || "Bukavu",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                // ✅ AJOUT NON DESTRUCTIF : On pousse les accès d'équipe au tableau existant sans écraser bailleur/locataire
                roles: admin.firestore.FieldValue.arrayUnion("locataire", roleEquipe.toUpperCase(), roleToPush)
            });
            console.log(`🎉 [ADMIN] Profil existant mis à jour par UPDATE sans altération des champs d'adresse.`);
        } else {
            // Si c'est un compte totalement neuf, on peut utiliser l'écriture initiale sécurisée
            const agentNewData = {
                uid: finalUid,
                nom: nom,
                postnom: postnom || "",
                prenom: prenom,
                genre: genre || "Homme",
                telephone: telephone || "",
                email: emailProfessionnel,
                email_professionnel: emailProfessionnel,
                password_backoffice: passwordBackoffice,
                role: finalRoleRoot,
                activeRole: roleEquipe.toUpperCase(),
                direction: direction.toUpperCase(),
                roles: ["locataire", roleEquipe.toUpperCase(), roleToPush], 
                statut: "actif",
                staffStatus: "validated",
                statut_web: "active",
                ville: ville || "Bukavu",
                pays: "RDC",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            };
            await userRef.set(agentNewData);
            console.log(`🎉 [ADMIN] Nouveau profil d'agent créé de zéro avec succès.`);
        }

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