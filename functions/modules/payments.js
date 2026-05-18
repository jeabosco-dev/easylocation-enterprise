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
 * --- FONCTION UTILITAIRE : NOTIFICATIONS ---
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
        notification: { title, body },
        token: token,
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
        "Amount": montantCents.toString(), // Doit être en centimes sous forme de String
        "Currency": "USD", 
        "Telephone": String(cleanPhone),
        "Language": "fr",
        "Reference": String(finalReference), 
        "SuccessURL": "https://easylocation-be28b.web.app/success",
        "FailureURL": "https://easylocation-be28b.web.app/cancel",
        // ✅ Réintroduction critique du CancelURL
        "CancelURL": "https://easylocation-be28b.web.app/cancel",
        "NotifyURL": `https://maxicashwebhook-eih2f2xgwq-ew.a.run.app?sk=${process.env.MAXICASH_WEBHOOK_SECRET}`
    };

    // 🚨 LOGS DU PAYLOAD AVANT ENVOI
    console.log("========== PAYLOAD MAXICASH ==========");
    console.log(JSON.stringify(payload, null, 2));
    console.log("======================================");

    try {
        const response = await axios.post("https://webapi-test.maxicashapp.com/Integration/PayEntryWeb", payload);
        
        // 🚨 LOGS DE LA RÉPONSE BRUTE
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
        
        // 🚨 LOGS DE L'URL GÉNÉRÉE ET DU LOG ID
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
 * 2. WEBHOOK MAXICASH (Séquentiel & Sécurisé)
 */
exports.maxicashWebhook = onRequest({ region: region, secrets: ["MAXICASH_WEBHOOK_SECRET"] }, async (req, res) => {
    const db = getDb();
    const params = { ...req.query, ...req.body };
    const reference = params.reference || params.Reference;
    const status = params.status || params.Status;
    const sk = params.sk; 

    if (!sk || sk !== process.env.MAXICASH_WEBHOOK_SECRET) {
        return res.status(403).send("Unauthorized");
    }

    if (!reference) {
        return res.status(400).send("Reference manquante");
    }

    try {
        // --- ÉTAPE 1 : TOUTES LES LECTURES & ÉCRITURES PRINCIPALES DANS LA TRANSACTION ---
        await db.runTransaction(async (transaction) => {
            const paymentRef = db.collection('paiements').doc(reference);
            const paymentDoc = await transaction.get(paymentRef);

            if (!paymentDoc.exists || paymentDoc.data().statut !== 'en_attente') {
                return; // Document inexistant ou déjà traité
            }

            const paymentData = paymentDoc.data();
            const isSuccess = status && status.toLowerCase() === 'success';

            let factureDoc = null;
            let factureRef = null;
            let serviceRef = null;
            let contractRef = null;

            if (isSuccess && paymentData.factureId) {
                if (paymentData.factureId.startsWith('BOOST-') || paymentData.factureId.startsWith('ALERT-')) {
                    serviceRef = db.collection('services').doc(paymentData.factureId);
                } else {
                    factureRef = db.collection('factures').doc(paymentData.factureId);
                    factureDoc = await transaction.get(factureRef); // LECTURE

                    if (factureDoc.exists && factureDoc.data().contractId) {
                        contractRef = db.collection('contrats').doc(factureDoc.data().contractId);
                    }
                }
            }

            // Mise à jour du document dans la collection 'paiements' avec le statut 'complete' synchronisé
            transaction.update(paymentRef, { 
                statut: isSuccess ? 'complete' : 'echec', 
                dateConfirmation: getFieldValue().serverTimestamp(),
                rawResponse: params
            });

            if (isSuccess && paymentData.factureId) {
                // Cas d'une facture classique
                if (factureRef && factureDoc && factureDoc.exists) {
                    transaction.update(factureRef, { 
                        statut: 'payee',
                        paymentStatus: 'paid',
                        etapeDossier: 'paye',
                        datePaiement: getFieldValue().serverTimestamp()
                    });

                    // Si un contrat est lié, on l'active
                    if (contractRef) {
                        transaction.update(contractRef, {
                            statut: 'actif',
                            lastUpdated: getFieldValue().serverTimestamp()
                        });
                    }
                }

                // Cas d'un service (Boost/Alerte)
                if (serviceRef) {
                    transaction.update(serviceRef, {
                        statut: 'PAYE',
                        datePaiement: getFieldValue().serverTimestamp()
                    });
                }
            }
        });

        // --- ÉTAPE 2 : EXÉCUTION DU BLOC HYBRIDE APRES LA FERMETURE DE LA TRANSACTION ---
        const isSuccess = status && status.toLowerCase() === 'success';
        if (isSuccess && reference.startsWith('HYB-')) {
            console.log(`Déclenchement séquentiel de la finalisation hybride pour : ${reference}`);
            await paymentsHybrid.finalizeHybridTransaction(reference);
        }

        return res.status(200).send("OK");
    } catch (e) { 
        console.error("Erreur Webhook Transaction:", e);
        return res.status(500).send("Error"); 
    }
});

/**
 * 3. TRIGGER MÉTIER
 */
exports.onPaymentStatusUpdated = onDocumentUpdated({ 
    document: 'factures/{factureId}', 
    region: region 
}, async (event) => {
    const db = getDb();
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData.paymentStatus === 'paid' && oldData.paymentStatus !== 'paid') {
        const propertyId = newData.propertyId;
        const locataireId = newData.userId;
        const refMaison = newData.refMaison || "votre logement";

        try {
            if (propertyId) {
                await db.collection('proprietes').doc(propertyId).update({
                    status: 'reserved',
                    lastUpdated: getFieldValue().serverTimestamp()
                });
            }

            await sendNotification(locataireId, 
                "Paiement Validé ! ✅", 
                `Votre réservation pour la maison ${refMaison} est confirmée.`,
                propertyId
            );

            if (propertyId) {
                const propDoc = await db.collection('proprietes').doc(propertyId).get();
                if (propDoc.exists && propDoc.data().bailleurId) {
                    await sendNotification(propDoc.data().bailleurId, 
                        "Maison Réservée ! 🏠", 
                        `Votre bien ${refMaison} vient d'être réservé par un client.`,
                        propertyId
                    );
                }
            }
        } catch (error) {
            console.error("Erreur dans le Trigger Métier:", error);
        }
    }
});