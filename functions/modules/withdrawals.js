// functions/modules/withdrawals.js
const { onCall } = require("firebase-functions/v2/https");
const admin = require('firebase-admin');

const db = admin.firestore();

/**
 * Fonction utilitaire pour convertir un montant en centimes (évite les erreurs d'arrondi)
 */
function toCents(amount) {
    return Math.round((Number(amount) || 0) * 100);
}

/**
 * Calcule de manière sécurisée les frais de service côté backend
 */
function calculateBackendFee(walletData, source, requestedAmount, standardFee) {
    const mainBalance = Number(walletData.balance) || 0.0;
    const commissionBalance = Number(walletData.commission_balance) || 0.0;
    const reliquatDisponible = Number(walletData.reliquatRemboursement) || 0.0;

    // 1. Source Commissions seule : Toujours exonérée
    if (source === 'commission') {
        return 0.0;
    }

    // 2. Traitement du solde principal utilisé (directement ou via 'both')
    let mainAmountDrawn = 0.0;

    if (source === 'main') {
        mainAmountDrawn = requestedAmount;
    } else if (source === 'both') {
        // Si la balance principale est nulle, tout provient des commissions (0$ frais)
        if (mainBalance <= 0) {
            mainAmountDrawn = 0.0;
        } else if (mainBalance >= requestedAmount) {
            mainAmountDrawn = requestedAmount;
        } else {
            // Le retrait dépasse la balance principale, seule la part 'main' est sujette aux frais
            mainAmountDrawn = mainBalance;
        }
    }

    // Si aucune somme de la balance principale n'est touchée, pas de frais
    if (mainAmountDrawn <= 0) {
        return 0.0;
    }

    // 3. Vérification des exonérations de reliquat/réinvestissement sur la part 'main'
    if (reliquatDisponible > 0 && walletData.hasReinvested) {
        const reqCentimes = toCents(mainAmountDrawn);
        const reliquatCentimes = toCents(reliquatDisponible);

        if (reqCentimes > 0 && reqCentimes <= reliquatCentimes) {
            return 0.0;
        }
    }

    return standardFee;
}

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
    const { amount, accountInfo, source = 'main' } = request.data;
    console.log(`Données reçues: amount=${amount}, source=${source}, userId=${userId}`);

    if (!amount || amount <= 0) throw new Error("Montant invalide.");

    try {
        // 1. Récupérer le profil utilisateur et son portefeuille pour sécuriser le calcul des frais
        const userDoc = await db.collection('utilisateurs').doc(userId).get();
        if (!userDoc.exists) throw new Error("Profil utilisateur introuvable.");
        const userData = userDoc.data();

        const walletDoc = await db.collection('wallets').doc(userId).get();
        if (!walletDoc.exists) throw new Error("Portefeuille introuvable.");
        const walletData = walletDoc.data();

        // 2. Récupérer les frais standards depuis la configuration (par défaut 10.00 ou selon Firestore)
        const configDoc = await db.collection('config').doc('settings').get();
        const standardFee = configDoc.exists ? (configDoc.data().refundServiceFee || 10.0) : 10.0;

        // 3. Calcul sécurisé des frais par le backend (on ignore le fee envoyé par le client)
        const secureFee = calculateBackendFee(walletData, source, amount, standardFee);

        const withdrawalRef = await db.collection('withdraw_requests').add({
            userId: userId,
            prenom: userData.prenom ?? "Non renseigné",
            nom: userData.nom ?? "Non renseigné",
            telephone: userData.telephone ?? "Non renseigné",
            amount: amount,
            fee: secureFee,
            accountInfo: accountInfo,
            source: source,
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            method: accountInfo === 'RETRAIT_BUREAU' ? 'OFFICE' : 'MOBILE_MONEY'
        });

        console.log(`✅ Demande créée avec succès : ${withdrawalRef.id} avec des frais sécurisés de ${secureFee}`);
        return { success: true, requestId: withdrawalRef.id };
    } catch (error) {
        console.error("❌ Erreur lors de la création de la demande :", error);
        throw new Error(error.message || "Erreur serveur lors de la demande de retrait.");
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

        // Récupérer les frais de configuration globaux au cas où un recalcul est nécessaire
        const configDoc = await db.collection('config').doc('settings').get();
        const standardFee = configDoc.exists ? (configDoc.data().refundServiceFee || 10.0) : 10.0;

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
            const source = withdrawalData.source || 'main';

            console.log("Lecture wallet...");
            const walletRef = db.collection('wallets').doc(userId);
            const walletDoc = await transaction.get(walletRef);

            console.log("wallet existe ?", walletDoc.exists);
            if (!walletDoc.exists) throw new Error("Erreur : Portefeuille utilisateur inexistant.");
            
            const walletData = walletDoc.data();

            // 🛡️ RE-CALCUL SÉCURISÉ DES FRAIS CÔTÉ BACKEND LORS DE LA CONFIRMATION
            const fee = calculateBackendFee(walletData, source, amount, standardFee);
            const totalToDeduct = amount + fee;
            
            console.log("===== CONTROLE SOLDE PAR POCHE =====");
            console.log({
                source,
                amount,
                fee,
                totalToDeduct,
                balance: walletData.balance,
                commission_balance: walletData.commission_balance,
                reliquatRemboursement: walletData.reliquatRemboursement,
            });

            let walletUpdateField = {};
            let reliquatConsumed = 0;

            // Détermination du solde et débit selon la source
            if (source === 'commission') {
                const currentCommission = walletData.commission_balance ?? 0;
                if (currentCommission < totalToDeduct) {
                    throw new Error("Erreur : Solde de commissions insuffisant.");
                }
                walletUpdateField = {
                    commission_balance: admin.firestore.FieldValue.increment(-totalToDeduct)
                };
            } else if (source === 'both') {
                const totalAvailable = (walletData.balance ?? 0) + (walletData.commission_balance ?? 0);
                if (totalAvailable < totalToDeduct) {
                    throw new Error("Erreur : Solde total insuffisant.");
                }
                const currentBalance = walletData.balance ?? 0;
                if (currentBalance >= totalToDeduct) {
                    walletUpdateField = {
                        balance: admin.firestore.FieldValue.increment(-totalToDeduct)
                    };
                } else {
                    const remaining = totalToDeduct - currentBalance;
                    walletUpdateField = {
                        balance: 0,
                        commission_balance: admin.firestore.FieldValue.increment(-remaining)
                    };
                }
                // Si la balance principale est touchée, on calcule la part de reliquat consommée
                const reliquatDisp = walletData.reliquatRemboursement ?? 0;
                if (reliquatDisp > 0 && currentBalance > 0) {
                    reliquatConsumed = Math.min(reliquatDisp, totalToDeduct);
                }
            } else {
                const currentBalance = walletData.balance ?? 0;
                if (currentBalance < totalToDeduct) {
                    throw new Error("Erreur : Solde de la balance principale insuffisant.");
                }
                walletUpdateField = {
                    balance: admin.firestore.FieldValue.increment(-totalToDeduct)
                };
                // Calcul du reliquat consommé pour déduire l'exonération utilisée
                const reliquatDisp = walletData.reliquatRemboursement ?? 0;
                if (reliquatDisp > 0) {
                    reliquatConsumed = Math.min(reliquatDisp, totalToDeduct);
                }
            }

            // Si du reliquat a été consommé, on met à jour sa valeur pour éviter les réutilisations frauduleuses
            if (reliquatConsumed > 0) {
                const newReliquat = Math.max(0, (walletData.reliquatRemboursement ?? 0) - reliquatConsumed);
                walletUpdateField.reliquatRemboursement = newReliquat;
            }

            // 1. Mise à jour du portefeuille
            transaction.update(walletRef, {
                ...walletUpdateField,
                lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
                last_update: admin.firestore.FieldValue.serverTimestamp(),
            });

            // 2. Journal interne dans la sous-collection operations
            const logRef = walletRef.collection('operations').doc();
            transaction.set(logRef, {
                amount: totalToDeduct,
                type: "WITHDRAWAL",
                source: source,
                requestId: requestId,
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });

            // 3. Enregistrement dans la collection globale 'transactions'
            const transactionRef = db.collection('transactions').doc();
            transaction.set(transactionRef, {
                walletId: userId,
                userId: userId,
                participants: [userId],
                title: "Retrait d'argent",
                amount: amount,
                fee: fee,
                totalDeducted: totalToDeduct,
                source: source,
                isPositive: false,
                type: "withdrawal",
                status: "success",
                description: `Retrait vers ${withdrawalData.accountInfo}`,
                date: admin.firestore.FieldValue.serverTimestamp(),
                relatedWithdrawalId: requestId
            });

            // 4. Clôture de la demande de retrait avec statut approved et les frais sécurisés recalculés
            transaction.update(withdrawalRef, {
                status: 'approved',
                fee: fee, // Sauvegarde des frais officiels validés par le backend
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });

        console.log("ETAPE 10 : Succès final");
        return { success: true };

    } catch (e) {
        console.error("============== ERREUR COMPLETE ==============");
        console.error("Message :", e.message);
        console.error("Stack :", e.stack);
        throw new Error(e.message);
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