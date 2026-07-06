// lib/functions/modules/withdrawals.js
const { onCall } = require("firebase-functions/v2/https");
const admin = require('firebase-admin');

const db = admin.firestore();

/**
 * Vérifie que l'utilisateur connecté est autorisé à utiliser
 * les fonctions d'administration.
 */
async function verifyBackofficeAdmin(request) {
    if (!request.auth) {
        throw new Error("Utilisateur non authentifié.");
    }

    const userRef = db.collection("utilisateurs").doc(request.auth.uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        throw new Error("Profil administrateur introuvable.");
    }

    const user = userDoc.data();

    console.log("=== CONTROLE RBAC ===");
    console.log({
        uid: request.auth.uid,
        role: user.role,
        direction: user.direction,
        staffStatus: user.staffStatus,
    });

    const isAuthorized =
        user.role === "super_admin" ||
        user.direction === "SUPER_ADMIN";

    if (!isAuthorized) {
        throw new Error("Accès refusé : droits insuffisants.");
    }

    return user;
}

/**
 * Callable Function : processWithdrawal
 */
exports.processWithdrawal = onCall(async (request) => {
    console.log("=== processWithdrawal appelée ===");
    if (!request.auth) throw new Error("Utilisateur non authentifié.");

    const userId = request.auth.uid;
    const { amount, fee, accountInfo } = request.data;
    console.log(`Données reçues: amount=${amount}, userId=${userId}`);

    if (!amount || amount <= 0) throw new Error("Montant invalide.");

    try {
        const userDoc = await db.collection('utilisateurs').doc(userId).get();
        if (!userDoc.exists) throw new Error("Profil utilisateur introuvable.");

        const userData = userDoc.data();

        const withdrawalRef = await db.collection('withdraw_requests').add({
            userId: userId,
            prenom: userData.prenom ?? "Non renseigné",
            nom: userData.nom ?? "Non renseigné",
            telephone: userData.telephone ?? "Non renseigné",
            amount: amount,
            fee: fee,
            accountInfo: accountInfo,
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            method: accountInfo === 'RETRAIT_BUREAU' ? 'OFFICE' : 'MOBILE_MONEY'
        });

        console.log(`✅ Demande créée avec succès : ${withdrawalRef.id}`);
        return { success: true, requestId: withdrawalRef.id };
    } catch (error) {
        console.error("❌ Erreur lors de la création de la demande :", error);
        throw new Error("Erreur serveur lors de la demande de retrait.");
    }
});

/**
 * Callable Function : confirmWithdrawal
 */
exports.confirmWithdrawal = onCall(async (request) => {
    console.log("===== ETAPE 1 (Début confirmWithdrawal) =====");
    
    try {
        console.log("ETAPE 3 : Vérification des droits");
        await verifyBackofficeAdmin(request);
        console.log("ETAPE 4 : Droits validés");

        console.log("ETAPE 7 : Récupération requestId");
        const { requestId } = request.data;

        console.log("ETAPE 8 : requestId reçu =", requestId);
        if (!requestId) throw new Error("ID de demande manquant.");

        console.log("ETAPE 9 : Début transaction");
        await db.runTransaction(async (transaction) => {
            console.log("Lecture withdrawal...");
            const withdrawalRef = db.collection('withdraw_requests').doc(requestId);
            const withdrawalDoc = await transaction.get(withdrawalRef);

            console.log("withdrawal existe ?", withdrawalDoc.exists);
            if (!withdrawalDoc.exists) throw new Error("Demande introuvable.");
            
            const withdrawalData = withdrawalDoc.data();

            if (withdrawalData.status !== 'pending') {
                throw new Error("Erreur : Ce retrait est déjà traité ou annulé.");
            }

            const userId = withdrawalData.userId;
            const amount = withdrawalData.amount;
            const fee = withdrawalData.fee || 0;
            const totalToDeduct = amount + fee;

            console.log("Lecture wallet...");
            const walletRef = db.collection('wallets').doc(userId);
            const walletDoc = await transaction.get(walletRef);

            console.log("wallet existe ?", walletDoc.exists);
            if (!walletDoc.exists) throw new Error("Erreur : Portefeuille utilisateur inexistant.");
            
            const walletData = walletDoc.data();
            
            console.log("===== CONTROLE SOLDE =====");
            console.log({
                amount,
                fee,
                totalToDeduct,
                balance: walletData.balance,
                walletData,
            });

            console.log("Vérification du solde...");
            const currentBalance = walletData.balance ?? 0;
            if (currentBalance < totalToDeduct) {
                throw new Error("Erreur : Solde insuffisant.");
            }

            console.log("Débit wallet...");
            transaction.update(walletRef, {
                balance: admin.firestore.FieldValue.increment(-totalToDeduct),
                lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log("Création transaction...");
            const transactionRef = db.collection('transactions').doc();
            transaction.set(transactionRef, {
                userId: userId,
                type: 'withdrawal',
                amount: amount,
                fee: fee,
                totalDeducted: totalToDeduct,
                status: 'completed',
                description: `Retrait vers ${withdrawalData.accountInfo}`,
                date: admin.firestore.FieldValue.serverTimestamp(),
                relatedWithdrawalId: requestId
            });

            console.log("Mise à jour withdrawal...");
            transaction.update(withdrawalRef, {
                status: 'completed',
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });

        console.log("ETAPE 10 : Succès final");
        return { success: true };

    } catch (e) {
        console.error("============== ERREUR COMPLETE ==============");
        console.error("Message :", e.message);
        console.error("Stack :", e.stack);
        console.error("Objet :", e);
        throw e;
    }
});

/**
 * Callable Function : rejectWithdrawal
 */
exports.rejectWithdrawal = onCall(async (request) => {
    console.log("=== rejectWithdrawal appelée ===");
    
    await verifyBackofficeAdmin(request);

    const { requestId, reason } = request.data;
    console.log(`Rejet demande ${requestId} pour motif: ${reason}`);

    try {
        const withdrawalRef = db.collection('withdraw_requests').doc(requestId);
        
        await db.runTransaction(async (transaction) => {
            const withdrawalDoc = await transaction.get(withdrawalRef);
            
            if (!withdrawalDoc.exists) throw new Error("Demande introuvable.");
            if (withdrawalDoc.data().status !== 'pending') {
                throw new Error("Cette demande n'est plus en attente.");
            }

            transaction.update(withdrawalRef, {
                status: 'rejected',
                rejectionReason: reason || "Aucune raison fournie",
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });

        console.log(`❌ Retrait ${requestId} rejeté.`);
        return { success: true };
    } catch (error) {
        console.error("❌ Erreur lors du rejet :", error);
        throw new Error(error.message);
    }
});