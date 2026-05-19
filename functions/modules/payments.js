const admin = require('firebase-admin');
const { onCall, HttpsError, onRequest } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');

// Importation propre des modules complémentaires
const paymentsHybrid = require('./payments_hybrid'); 

// Initialisation sécurisée
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const getDb = () => admin.firestore();
const getFieldValue = () => admin.firestore.FieldValue;
const region = 'europe-west1';

/**
 * --- FONCTION UTILITAIRE : NOTIFICATIONS AVEC SUPPORTS DU PUSH FORCE (VIBRATION / SON) ---
 */
async function sendNotification(userId, title, body, propertyId = null) {
    const db = getDb();
    const userDoc = await db.collection('utilisateurs').doc(userId).get();
    if (!userDoc.exists) return;

    const token = userDoc.data().fcmToken;
    if (!token) {
        console.log(`Pas de token FCM pour l'utilisateur ${userId}`);
        return;
    }

    const message = {
        token: token,
        notification: { 
            title: title, 
            body: body 
        },
        android: {
            notification: {
                channelId: 'easylocation_alerts', // ✅ Aligné sur le canal configuré dans Flutter
                priority: 'max',                  // ✅ Requis pour faire surgir et vibrer immédiatement
                sound: 'default'                  // ✅ Déclenche le son et la vibration système par défaut
            }
        },
        data: { 
            propertyId: propertyId || "", 
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            type: "RESERVATION" 
        }
    };

    try {
        await admin.messaging().send(message);
        console.log(`✅ Notification envoyée à ${userId}`);
    } catch (e) {
        console.error(`❌ Erreur FCM pour l'utilisateur ${userId}:`, e);
    }
}

/**
 * 1. GÉNÉRATION DE L'URL MAXICASH
 */
exports.generateMaxicashUrl = onCall({ 
    region: region,
    enforceAppCheck: false, 
    secrets: ["MAXICASH_MERCHANT_PASSWORD", "MAXICASH_WEBHOOK_SECRET"] 
}, async (request) => {
    const axios = require('axios');
    const crypto = require('crypto');
    const db = getDb();
    
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'L\'utilisateur doit être connecté.');
    }
    
    const { factureId, telephone, hybridReference, amountOverride } = request.data;

    if (!telephone || telephone.trim() === "") {
        throw new HttpsError('invalid-argument', 'Téléphone manquant.');
    }

    let montantUSD = 0;
    let finalReference = "";

    // --- LOGIQUE DE MONTANT & DE RÉFÉRENCE CORRIGÉE ---
    if (amountOverride && amountOverride > 0) {
        montantUSD = amountOverride;
        finalReference = hybridReference || `FAC-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    } 
    else if (factureId) {
        let docSnap = await db.collection('factures').doc(factureId).get();
        if (!docSnap.exists) {
            docSnap = await db.collection('services').doc(factureId).get();
        }

        if (!docSnap.exists) {
            throw new HttpsError('not-found', `Document ${factureId} introuvable.`);
        }
        
        const d = docSnap.data();
        montantUSD = d.totalUSD || d.prix || d.montant || (d.totalCDF ? d.totalCDF / 2500 : 0);
        
        finalReference = `FAC-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    } else {
        throw new HttpsError('invalid-argument', 'ID facture ou Montant manquant.');
    }
    
    if (montantUSD <= 0) throw new HttpsError('internal', 'Montant calculé invalide.');

    // Règle MaxiCash : Conversion stricte en centimes (entier)
    const montantCents = Math.round(parseFloat(montantUSD) * 100);

    // --- CONFIGURATION MAXICASH ---
    const configDoc = await db.collection('app_config').doc('maxicash').get();
    if (!configDoc.exists) {
        throw new HttpsError('failed-precondition', 'Config Firestore manquante.');
    }
    
    const configData = configDoc.data();
    const mId = configData.merchantId;
    const mPass = process.env.MAXICASH_MERCHANT_PASSWORD || configData.merchantPassword;
    
    if (!mId || !mPass) throw new HttpsError('internal', 'Identifiants marchand MaxiCash incomplets.');

    const cleanPhone = telephone.replace(/\s+/g, '').replace('+', ''); 

    // Enregistrement du paiement avec statut 'en_attente'
    await db.collection('paiements').doc(finalReference).set({
        userId: request.auth.uid,
        factureId: factureId || null,
        isHybrid: !!hybridReference || (amountOverride > 0 && !!factureId),
        montantAttenduCents: montantCents,
        statut: 'en_attente',
        dateCreation: getFieldValue().serverTimestamp()
    });

    // Construction du payload avec CancelURL réintroduit
    const payload = {
        "PayType": "MaxiCash",
        "MerchantID": String(mId),
        "MerchantPassword": String(mPass),
        "Amount": montantCents.toString(), 
        "Currency": "USD", 
        "Telephone": String(cleanPhone),
        "Language": "fr",
        "Reference": String(finalReference), 
        "SuccessURL": "https://easylocation-be28b.web.app/success",
        "FailureURL": "https://easylocation-be28b.web.app/cancel",
        "CancelURL": "https://easylocation-be28b.web.app/cancel",
        "NotifyURL": `https://maxicashwebhook-eih2f2xgwq-ew.a.run.app?sk=${process.env.MAXICASH_WEBHOOK_SECRET}`
    };

    console.log("========== PAYLOAD MAXICASH ==========");
    console.log(JSON.stringify(payload, null, 2));
    console.log("======================================");

    try {
        const response = await axios.post("https://webapi-test.maxicashapp.com/Integration/PayEntryWeb", payload);
        
        console.log("========== REPONSE MAXICASH ==========");
        console.log(JSON.stringify(response.data, null, 2));
        console.log("======================================");

        if (!response.data) {
            throw new Error("Aucune donnée reçue de la part de MaxiCash.");
        }

        const logId = response.data.LogID || response.data.ResponseData;
        
        if (!logId || response.data.Status === "Failed" || response.data.ResponseStatus === "error") {
            console.error("Réponse MaxiCash Échec:", response.data);
            throw new Error(response.data.Message || response.data.ResponseError || "Identifiants MaxiCash ou paramètres refusés");
        }
        
        console.log("LOG ID RECU:", logId);
        console.log("URL FINALE:", `https://api-testbed.maxicashapp.com/payentryweb?logid=${logId}`);

        return { 
            url: `https://api-testbed.maxicashapp.com/payentryweb?logid=${logId}`, 
            reference: finalReference 
        };
    } catch (error) {
        console.error("Erreur Appel MaxiCash API:", error.message);
        throw new HttpsError('internal', `MaxiCash: ${error.message}`);
    }
});

/**
 * 2. WEBHOOK MAXICASH (Séquentiel & Sécurisé avec Logs de Débug)
 */
exports.maxicashWebhook = onRequest({ region: region, secrets: ["MAXICASH_WEBHOOK_SECRET"] }, async (req, res) => {
    const db = getDb();
    const params = { ...req.query, ...req.body };
    const reference = params.reference || params.Reference;
    const status = params.status || params.Status;
    const sk = params.sk; 

    console.log("=== 📥 WEBHOOK MAXICASH ENTRANT ===");
    console.log(`- ID de Paiement extrait (reference): ${reference}`);
    console.log(`- Statut extrait (status): ${status}`);
    console.log(`- Paramètres bruts complets:`, JSON.stringify(params, null, 2));

    if (!sk || sk !== process.env.MAXICASH_WEBHOOK_SECRET) {
        console.error("❌ ÉCHEC AUTHENTIFICATION WEBHOOK : Secret invalide.");
        return res.status(403).send("Unauthorized");
    }

    if (!reference) {
        console.error("❌ PARAMÈTRE MANQUANT : Aucune référence trouvée.");
        return res.status(400).send("Reference manquante");
    }

    // Normalisation préventive de la casse pour le paramètre 'ville' s'il existe dans la requête MaxiCash
    if (params.ville) {
        params.ville = params.ville.trim().toLowerCase();
    }
    if (params.Ville) {
        params.Ville = params.Ville.trim().toLowerCase();
    }

    try {
        console.log(`⏳ Lancement de la transaction Firestore pour la référence [${reference}]...`);
        
        await db.runTransaction(async (transaction) => {
            const paymentRef = db.collection('paiements').doc(reference);
            const paymentDoc = await transaction.get(paymentRef);

            if (!paymentDoc.exists) {
                console.error(`❌ ERREUR LOGIQUE : Le document de paiement [${reference}] n'existe pas dans la collection 'paiements' !`);
                return; 
            }

            const paymentData = paymentDoc.data();
            console.log(`ℹ️ Statut actuel du paiement dans Firestore : "${paymentData.statut}"`);

            if (paymentData.statut !== 'en_attente') {
                console.warn(`⚠️ ALERTE : Le paiement [${reference}] a déjà été traité (Statut: ${paymentData.statut}). Annulation de la mise à jour pour éviter les doublons.`);
                return; 
            }

            const isSuccess = status && status.toLowerCase() === 'success';
            console.log(`🎯 Résultat interprété : isSuccess = ${isSuccess} (Statut reçu: "${status}")`);

            let factureDoc = null;
            let factureRef = null;
            let serviceRef = null;
            let contractRef = null;

            if (isSuccess && paymentData.factureId) {
                console.log(`🔍 Liaison détectée avec la facture/service ID : ${paymentData.factureId}`);
                if (paymentData.factureId.startsWith('BOOST-') || paymentData.factureId.startsWith('ALERT-')) {
                    console.log(`📌 Type identifié : Service (Boost/Alerte)`);
                    serviceRef = db.collection('services').doc(paymentData.factureId);
                } else {
                    console.log(`📌 Type identifié : Facture Classique`);
                    factureRef = db.collection('factures').doc(paymentData.factureId);
                    factureDoc = await transaction.get(factureRef); 

                    if (factureDoc.exists) {
                        const fData = factureDoc.data();
                        console.log(`✅ Facture trouvée. Etape actuelle: "${fData.etapeDossier}"`);
                        if (fData.contractId) {
                            console.log(`🔗 Contrat associé trouvé : ${fData.contractId}`);
                            contractRef = db.collection('contrats').doc(fData.contractId);
                        }
                    } else {
                        console.error(`❌ ERREUR COMPORTEMENT : Le document facture [${paymentData.factureId}] est introuvable !`);
                    }
                }
            }

            // Mise à jour du document de paiement (avec les params normalisés en minuscules inclus dans rawResponse)
            const nouveauStatutPaiement = isSuccess ? 'complete' : 'echec';
            console.log(`🔄 Firestore : Passage du paiement [${reference}] au statut "${nouveauStatutPaiement}"`);
            transaction.update(paymentRef, { 
                statut: nouveauStatutPaiement, 
                dateConfirmation: getFieldValue().serverTimestamp(),
                rawResponse: params
            });

            if (isSuccess && paymentData.factureId) {
                if (factureRef && factureDoc && factureDoc.exists) {
                    console.log(`🔄 Firestore : Mise à jour de la facture [${paymentData.factureId}] -> statut: "payee", etapeDossier: "paye"`);
                    
                    // Récupération sécurisée et normalisation en minuscules de la ville de la facture pour éviter les conflits au stockage
                    const currentVille = factureDoc.data().ville ? factureDoc.data().ville.trim().toLowerCase() : "bukavu";

                    transaction.update(factureRef, { 
                        statut: 'payee',
                        paymentStatus: 'paid',
                        etapeDossier: 'paye',
                        ville: currentVille, // Force la ville de la facture en minuscules au moment du paiement réussi
                        datePaiement: getFieldValue().serverTimestamp()
                    });

                    if (contractRef) {
                        console.log(`🔄 Firestore : Activation du contrat [${factureDoc.data().contractId}] -> statut: "actif"`);
                        transaction.update(contractRef, {
                            statut: 'actif',
                            lastUpdated: getFieldValue().serverTimestamp()
                        });
                    }
                }

                if (serviceRef) {
                    console.log(`🔄 Firestore : Mise à jour du service [${paymentData.factureId}] -> statut: "PAYE"`);
                    transaction.update(serviceRef, {
                        statut: 'PAYE',
                        datePaiement: getFieldValue().serverTimestamp()
                    });
                }
            }
        });

        console.log("=== 💾 TRANSACTION FIRESTORE APPLIQUÉE ET VALIDÉE ENTIÈREMENT ===");

        const isSuccess = status && status.toLowerCase() === 'success';
        if (isSuccess && reference.startsWith('HYB-')) {
            console.log(`🚀 Déclenchement séquentiel de la finalisation hybride pour : ${reference}`);
            await paymentsHybrid.finalizeHybridTransaction(reference);
        }

        return res.status(200).send("OK");
    } catch (e) { 
        console.error("💥 CRASH DURANT LA TRANSACTION FIRESTORE DU WEBHOOK :", e);
        return res.status(500).send("Error"); 
    }
});

/**
 * 3. TRIGGER MÉTIER (ADAPTÉ AUX CHAMPS FIRESTORE REELS : clientId & paymentStatus)
 */
exports.onPaymentStatusUpdated = onDocumentUpdated({ 
    document: 'factures/{factureId}', 
    region: region 
}, async (event) => {
    const db = getDb();
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    const newStatus = (newData.paymentStatus || "").toLowerCase();
    const oldStatus = (oldData.paymentStatus || "").toLowerCase();

    console.log(`[Trigger] Modification détectée sur la facture. Ancien paymentStatus: "${oldStatus}", Nouveau paymentStatus: "${newStatus}"`);

    // S'active si le statut passe à 'paid' ou 'success'
    if ((newStatus === 'paid' || newStatus === 'success') && oldStatus !== 'paid' && oldStatus !== 'success') {
        const propertyId = newData.propertyId;
        
        // Extraction sécurisée depuis le bon champ Firestore : clientId
        const locataireId = newData.clientId || newData.userId || newData.locataireId;
        const refMaison = newData.refMaison || "votre logement";

        console.log(`[Trigger] Facture payée validée. Client/Locataire ID extrait: ${locataireId}, Propriété ID: ${propertyId}`);

        // Sécurité stricte pour empêcher les plantages sur documentPath
        if (!locataireId) {
            console.error("❌ Impossible d'envoyer la notification : Le champ 'clientId' (ou ses alias) est introuvable ou vide dans la facture.");
            return;
        }

        try {
            if (propertyId) {
                const propRef = db.collection('proprietes').doc(propertyId);
                const propDoc = await propRef.get();
                
                let updatePayload = {
                    status: 'reserved',
                    lastUpdated: getFieldValue().serverTimestamp()
                };

                // Normalisation de la ville en minuscules
                if (propDoc.exists && propDoc.data().ville) {
                    updatePayload.ville = propDoc.data().ville.trim().toLowerCase();
                }

                await propRef.update(updatePayload);
                console.log(`✅ Statut de la propriété [${propertyId}] mis à jour vers 'reserved'.`);
            }

            // --- Envoi de la notification au locataire ---
            console.log(`⏳ Envoi de la notification FCM au locataire [${locataireId}]...`);
            await sendNotification(locataireId, 
                "Paiement Validé ! ✅", 
                `Votre réservation pour la maison ${refMaison} est confirmée.`,
                propertyId
            );

            // --- Envoi de la notification au bailleur ---
            if (propertyId) {
                const propDoc = await db.collection('proprietes').doc(propertyId).get();
                
                // Récupération dynamique du bailleur (facture ou document propriété)
                const bailleurId = newData.bailleurId || (propDoc.exists ? propDoc.data().bailleurId : null);
                
                if (bailleurId) {
                    console.log(`⏳ Envoi de la notification FCM au bailleur [${bailleurId}]...`);
                    await sendNotification(bailleurId, 
                        "Maison Réservée ! 🏠", 
                        `Votre bien ${refMaison} vient d'être réservé par un client.`,
                        propertyId
                    );
                } else {
                    console.warn(`⚠️ Aucun bailleurId valide trouvé dans la facture ou dans le document de propriété [${propertyId}]`);
                }
            }
        } catch (error) {
            console.error("💥 Erreur interne lors du traitement des notifications du Trigger:", error);
        }
    }
});