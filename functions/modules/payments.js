const admin = require('firebase-admin');
const { onCall, HttpsError, onRequest } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');

// Initialisation sécurisée
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const getDb = () => admin.firestore();
const getFieldValue = () => admin.firestore.FieldValue;
const region = 'europe-west1';

// --- FONCTION UTILITAIRE : NOTIFICATIONS ---
async function sendNotification(userId, title, body, propertyId = null) {
    const db = getDb();
    const userDoc = await db.collection('utilisateurs').doc(userId).get();
    if (!userDoc.exists) return;

    const token = userDoc.data().fcmToken;
    if (!token) return;

    const message = {
        notification: { title, body },
        token: token,
        data: { propertyId: propertyId || "", type: "RESERVATION" }
    };

    try {
        await admin.messaging().send(message);
    } catch (e) {
        console.error(`Erreur FCM pour l'utilisateur ${userId}:`, e);
    }
}

/**
 * GÉNÉRATION DE L'URL MAXICASH (Version Stabilisée et Sécurisée)
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

    // --- LOGIQUE DE MONTANT ---
    if (amountOverride && amountOverride > 0) {
        montantUSD = amountOverride;
        finalReference = hybridReference || `FAC-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    } 
    else if (factureId) {
        let docSnap = await db.collection('factures').doc(factureId).get();
        if (!docSnap.exists && (factureId.startsWith('BOOST-') || factureId.startsWith('ALERT-'))) {
            docSnap = await db.collection('services').doc(factureId).get();
        }

        if (!docSnap.exists) {
            throw new HttpsError('not-found', 'Document (Facture ou Service) introuvable.');
        }
        
        const data = docSnap.data();
        montantUSD = data.totalUSD || data.prix || (data.totalCDF ? data.totalCDF / 2500 : data.montant || 0);
        finalReference = `FAC-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    } else {
        throw new HttpsError('invalid-argument', 'ID facture ou Montant (amountOverride) manquant.');
    }
    
    if (montantUSD <= 0) throw new HttpsError('internal', 'Montant invalide.');

    const montantCents = Math.round(parseFloat(montantUSD) * 100);

    // --- 2. RÉCUPÉRATION SÉCURISÉE DE LA CONFIGURATION ---
    const configDoc = await db.collection('app_config').doc('maxicash').get();
    if (!configDoc.exists) {
        console.error("❌ Configuration MaxiCash manquante dans Firestore (app_config/maxicash)");
        throw new HttpsError('failed-precondition', 'Le service de paiement est momentanément indisponible.');
    }
    
    const configData = configDoc.data();
    // Priorité au Secret Manager pour le mot de passe, fallback sur Firestore
    const mId = configData.merchantId;
    const mPass = process.env.MAXICASH_MERCHANT_PASSWORD || configData.merchantPassword;

    if (!mId || !mPass) {
        console.error("❌ Identifiants MaxiCash incomplets.");
        throw new HttpsError('internal', 'Erreur de configuration du marchand.');
    }

    const cleanPhone = telephone.replace(/\s+/g, '').replace('+', ''); 

    // --- 3. ENREGISTREMENT DE LA TRACE ---
    await db.collection('paiements').doc(finalReference).set({
        userId: request.auth.uid,
        factureId: factureId || null,
        isHybrid: !!hybridReference || (amountOverride > 0 && !!factureId),
        montantAttenduCents: montantCents,
        statut: 'en_attente',
        dateCreation: getFieldValue().serverTimestamp()
    });

    // --- 4. PAYLOAD MAXICASH ---
    const payload = {
        "PayType": "MaxiCash",
        "MerchantID": mId,
        "MerchantPassword": mPass,
        "Amount": montantCents.toString(),
        "Currency": "USD", 
        "Telephone": cleanPhone,
        "Language": "fr",
        "Reference": finalReference, 
        "SuccessURL": "https://easylocation-be28b.web.app/success",
        "FailureURL": "https://easylocation-be28b.web.app/cancel",
        "CancelURL": "https://easylocation-be28b.web.app/cancel",
        "NotifyURL": `https://maxicashwebhook-eih2f2xgwq-ew.a.run.app?sk=${process.env.MAXICASH_WEBHOOK_SECRET}`
    };

    try {
        const response = await axios.post("https://webapi-test.maxicashapp.com/Integration/PayEntryWeb", payload);
        const logId = response.data.LogID || response.data.ResponseData;
        
        if (!logId || response.data.ResponseStatus === "error") {
            console.error("Détail erreur MaxiCash:", response.data.ResponseError || response.data);
            throw new Error(response.data.ResponseError || "Impossible d'obtenir un LogID");
        }
        
        return { 
            url: `https://api-testbed.maxicashapp.com/payentryweb?logid=${logId}`, 
            reference: finalReference 
        };
    } catch (error) {
        console.error("Erreur MaxiCash:", error.response ? error.response.data : error.message);
        throw new HttpsError('internal', `Erreur lors de la préparation du paiement.`);
    }
});

/**
 * WEBHOOK MAXICASH
 */
exports.maxicashWebhook = onRequest({ region: region, secrets: ["MAXICASH_WEBHOOK_SECRET"] }, async (req, res) => {
    const db = getDb();
    const params = { ...req.query, ...req.body };
    const reference = params.reference || params.Reference;
    const status = params.status || params.Status;
    const sk = params.sk; 

    if (!sk || sk !== process.env.MAXICASH_WEBHOOK_SECRET) return res.status(403).send("Unauthorized");

    try {
        await db.runTransaction(async (transaction) => {
            const paymentRef = db.collection('paiements').doc(reference);
            const paymentDoc = await transaction.get(paymentRef);

            if (!paymentDoc.exists || paymentDoc.data().statut !== 'en_attente') {
                return; 
            }

            const paymentData = paymentDoc.data();
            const isSuccess = status && status.toLowerCase() === 'success';

            transaction.update(paymentRef, { 
                statut: isSuccess ? 'reussi' : 'echec', 
                dateConfirmation: getFieldValue().serverTimestamp(),
                rawResponse: params
            });

            if (isSuccess) {
                if (paymentData.factureId) {
                    const factureRef = db.collection('factures').doc(paymentData.factureId);
                    const factureDoc = await transaction.get(factureRef);
                    
                    if (factureDoc.exists) {
                        transaction.update(factureRef, { 
                            statut: 'payee',
                            paymentStatus: 'paid', 
                            datePaiement: getFieldValue().serverTimestamp()
                        });

                        const fData = factureDoc.data();
                        if (fData.contractId) {
                            const contractRef = db.collection('contrats').doc(fData.contractId);
                            transaction.update(contractRef, {
                                statut: 'actif',
                                lastUpdated: getFieldValue().serverTimestamp()
                            });
                        }
                    }

                    if (paymentData.factureId.startsWith('BOOST-') || paymentData.factureId.startsWith('ALERT-')) {
                        const serviceRef = db.collection('services').doc(paymentData.factureId);
                        transaction.update(serviceRef, {
                            statut: 'PAYE',
                            datePaiement: getFieldValue().serverTimestamp()
                        });
                    }
                }

                if (reference.startsWith('HYB-')) {
                    const paymentsHybrid = require('./payments_hybrid'); 
                    await paymentsHybrid.finalizeHybridTransaction(reference);
                }
            }
        });

        res.status(200).send("OK");
    } catch (e) { 
        console.error("Erreur Webhook:", e);
        res.status(500).send("Error"); 
    }
});

/**
 * TRIGGER MÉTIER : Mise à jour du statut et notifications
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
        const refMaison = newData.refMaison || "votre maison";

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
                        `Votre bien ${refMaison} vient d'être réservé.`,
                        propertyId
                    );
                }
            }
        } catch (error) {
            console.error("Erreur Trigger Notification:", error);
        }
    }
});