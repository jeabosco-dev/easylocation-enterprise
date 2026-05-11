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

/**
 * --- FONCTION UTILITAIRE : NOTIFICATIONS ---
 * Envoie une alerte Push via FCM au locataire ou au bailleur
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
 * Appelé par l'app Flutter pour obtenir le lien de paiement
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

    // Cas spécifique (Boost ou Ajustement manuel)
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
            throw new HttpsError('not-found', 'Document introuvable.');
        }
        
        const data = docSnap.data();
        montantUSD = data.totalUSD || data.prix || (data.totalCDF ? data.totalCDF / 2500 : data.montant || 0);
        finalReference = `FAC-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    } else {
        throw new HttpsError('invalid-argument', 'ID facture ou Montant manquant.');
    }
    
    if (montantUSD <= 0) throw new HttpsError('internal', 'Montant invalide.');

    const montantCents = Math.round(parseFloat(montantUSD) * 100);

    const configDoc = await db.collection('app_config').doc('maxicash').get();
    if (!configDoc.exists) {
        throw new HttpsError('failed-precondition', 'Configuration MaxiCash manquante dans Firestore.');
    }
    
    const configData = configDoc.data();
    const mId = configData.merchantId;
    const mPass = process.env.MAXICASH_MERCHANT_PASSWORD || configData.merchantPassword;

    const cleanPhone = telephone.replace(/\s+/g, '').replace('+', ''); 

    // Enregistrement de l'intention de paiement
    await db.collection('paiements').doc(finalReference).set({
        userId: request.auth.uid,
        factureId: factureId || null,
        montantAttenduCents: montantCents,
        statut: 'en_attente',
        dateCreation: getFieldValue().serverTimestamp()
    });

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
        "NotifyURL": `https://maxicashwebhook-eih2f2xgwq-ew.a.run.app?sk=${process.env.MAXICASH_WEBHOOK_SECRET}`
    };

    try {
        const response = await axios.post("https://webapi-test.maxicashapp.com/Integration/PayEntryWeb", payload);
        const logId = response.data.LogID || response.data.ResponseData;
        
        return { 
            url: `https://api-testbed.maxicashapp.com/payentryweb?logid=${logId}`, 
            reference: finalReference 
        };
    } catch (error) {
        console.error("Erreur Appel MaxiCash API:", error);
        throw new HttpsError('internal', `Erreur préparation paiement.`);
    }
});

/**
 * 2. WEBHOOK MAXICASH
 * Reçoit la confirmation de paiement de MaxiCash et met à jour la DB
 */
exports.maxicashWebhook = onRequest({ region: region, secrets: ["MAXICASH_WEBHOOK_SECRET"] }, async (req, res) => {
    const db = getDb();
    const params = { ...req.query, ...req.body };
    const reference = params.reference || params.Reference;
    const status = params.status || params.Status;
    const sk = params.sk; 

    // Sécurité par Secret Key
    if (!sk || sk !== process.env.MAXICASH_WEBHOOK_SECRET) {
        return res.status(403).send("Unauthorized");
    }

    try {
        await db.runTransaction(async (transaction) => {
            const paymentRef = db.collection('paiements').doc(reference);
            const paymentDoc = await transaction.get(paymentRef);

            if (!paymentDoc.exists || paymentDoc.data().statut !== 'en_attente') {
                return; 
            }

            const paymentData = paymentDoc.data();
            const isSuccess = status && status.toLowerCase() === 'success';

            // Mise à jour du document Paiement
            transaction.update(paymentRef, { 
                statut: isSuccess ? 'reussi' : 'echec', 
                dateConfirmation: getFieldValue().serverTimestamp(),
                rawResponse: params
            });

            if (isSuccess && paymentData.factureId) {
                const factureRef = db.collection('factures').doc(paymentData.factureId);
                const factureDoc = await transaction.get(factureRef);
                
                if (factureDoc.exists) {
                    // Action A: On valide la facture (ceci va déclencher le trigger onPaymentStatusUpdated)
                    transaction.update(factureRef, { 
                        statut: 'payee',
                        paymentStatus: 'paid',
                        etapeDossier: 'paye',
                        datePaiement: getFieldValue().serverTimestamp()
                    });

                    // Si lié à un contrat, on l'active
                    const fData = factureDoc.data();
                    if (fData.contractId) {
                        const contractRef = db.collection('contrats').doc(fData.contractId);
                        transaction.update(contractRef, {
                            statut: 'actif',
                            lastUpdated: getFieldValue().serverTimestamp()
                        });
                    }
                }

                // Cas des Services (Boost/Alert)
                if (paymentData.factureId.startsWith('BOOST-') || paymentData.factureId.startsWith('ALERT-')) {
                    const serviceRef = db.collection('services').doc(paymentData.factureId);
                    transaction.update(serviceRef, {
                        statut: 'PAYE',
                        datePaiement: getFieldValue().serverTimestamp()
                    });
                }
            }
        });

        res.status(200).send("OK");
    } catch (e) { 
        console.error("Erreur Webhook Transaction:", e);
        res.status(500).send("Error"); 
    }
});

/**
 * 3. TRIGGER MÉTIER (onPaymentStatusUpdated)
 * Réagit dès que paymentStatus devient 'paid' pour verrouiller le bien et notifier
 */
exports.onPaymentStatusUpdated = onDocumentUpdated({ 
    document: 'factures/{factureId}', 
    region: region 
}, async (event) => {
    const db = getDb();
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    // On ne réagit que si le statut passe à 'paid'
    if (newData.paymentStatus === 'paid' && oldData.paymentStatus !== 'paid') {
        const propertyId = newData.propertyId;
        const locataireId = newData.userId;
        const refMaison = newData.refMaison || "votre logement";

        try {
            // 1. Verrouiller la propriété
            if (propertyId) {
                await db.collection('proprietes').doc(propertyId).update({
                    status: 'reserved',
                    lastUpdated: getFieldValue().serverTimestamp()
                });
                console.log(`🏠 Propriété ${propertyId} marquée comme RESERVED.`);
            }

            // 2. Notifier le Locataire
            await sendNotification(locataireId, 
                "Paiement Validé ! ✅", 
                `Votre réservation pour la maison ${refMaison} est confirmée.`,
                propertyId
            );

            // 3. Notifier le Bailleur
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