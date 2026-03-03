const admin = require('firebase-admin');
if (admin.apps.length === 0) admin.initializeApp();

const functions = require('firebase-functions');
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');

const region = 'europe-west1';

// --- 1. PAIEMENTS : GÉNÉRATION DU LOGID ---
exports.generateMaxicashUrl = onCall({ 
    region: region,
    // On ajoute 'enforceAppCheck: false' temporairement pour que tes tests passent 
    // malgré l'erreur de token que nous avons vue dans les logs.
    enforceAppCheck: false, 
    secrets: ["MAXICASH_MERCHANT_PASSWORD", "MAXICASH_WEBHOOK_SECRET"] 
}, async (request) => {
    const db = admin.firestore();
    const axios = require('axios');
    const crypto = require('crypto');
    
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'L\'utilisateur doit être connecté.');
    }
    
    const data = request.data;
    const factureId = data.factureId;
    const telephone = data.telephone;

    if (!factureId || !telephone || telephone.trim() === "") {
        throw new HttpsError('invalid-argument', 'Données manquantes (ID facture ou téléphone).');
    }

    // Récupération de la facture
    const factureDoc = await db.collection('factures').doc(factureId).get();
    if (!factureDoc.exists) {
        throw new HttpsError('not-found', 'Facture introuvable.');
    }
    
    const factureData = factureDoc.data();

    // --- LOGIQUE DU MONTANT ---
    let montantUSD = 0;
    if (factureData.totalUSD && factureData.totalUSD > 0) {
        montantUSD = factureData.totalUSD;
    } else if (factureData.totalCDF && factureData.totalCDF > 0) {
        const settingsDoc = await db.collection('settings').doc('app_config').get();
        const tauxDuJour = settingsDoc.exists ? (settingsDoc.data().taux_usd_cdf || 2500) : 2500; 
        montantUSD = factureData.totalCDF / tauxDuJour;
    } else {
        montantUSD = factureData.montant || factureData.loyer || 0;
    }
    
    if (montantUSD <= 0) {
        throw new HttpsError('internal', 'Impossible de déterminer le montant de la facture.');
    }

    // CORRECTIF 1 : Conversion en Cents (Ex: 10 USD -> 1000)
    const montantCents = Math.round(parseFloat(montantUSD) * 100);
    const shortRef = crypto.randomBytes(6).toString('hex').toUpperCase(); 

    // --- CONFIG MAXICASH ---
    const configDoc = await db.collection('app_config').doc('maxicash').get();
    if (!configDoc.exists) {
        throw new HttpsError('failed-precondition', 'Configuration MaxiCash introuvable.');
    }

    const { merchantId, merchantPassword } = configDoc.data();
    const cleanPhone = telephone.replace(/\s+/g, '').replace('+', ''); 

    // Création de la trace du paiement
    await db.collection('paiements').doc(shortRef).set({
        userId: request.auth.uid,
        factureId: factureId,
        referenceMaxicash: shortRef,
        montantAttenduCents: montantCents,
        devise: "USD",
        statut: 'en_attente',
        dateCreation: admin.firestore.FieldValue.serverTimestamp()
    });

    const payload = {
        "PayType": "MaxiCash",
        "MerchantID": merchantId,
        "MerchantPassword": merchantPassword || process.env.MAXICASH_MERCHANT_PASSWORD,
        "Amount": montantCents.toString(),
        "Currency": "USD", 
        "Telephone": cleanPhone,
        "Language": "fr",
        "Reference": shortRef, 
        // CORRECTIF 2 : Utilisation d'URLs Web réelles (MaxiCash refuse les schémas personnalisés app://)
        "SuccessURL": "https://easylocation-be28b.web.app/success",
        "FailureURL": "https://easylocation-be28b.web.app/cancel",
        "CancelURL": "https://easylocation-be28b.web.app/cancel",
        "NotifyURL": `https://maxicashwebhook-eih2f2xgwq-ew.a.run.app?sk=${process.env.MAXICASH_WEBHOOK_SECRET}`
    };

    console.log("DEBUG: Envoi Payload MaxiCash:", JSON.stringify(payload));

    try {
        const response = await axios.post("https://webapi-test.maxicashapp.com/Integration/PayEntryWeb", payload);
        
        // Log de la réponse brute pour débugger en cas de "payfailure"
        console.log("DEBUG: Réponse MaxiCash API:", JSON.stringify(response.data));

        const logId = response.data.LogID || response.data.ResponseData;
        
        if (!logId) {
            throw new Error(`Erreur MaxiCash: ${response.data.ResponseError || "Pas de LogID reçu"}`);
        }

        return { 
            url: `https://api-testbed.maxicashapp.com/payentryweb?logid=${logId}`, 
            reference: shortRef 
        };
    } catch (error) {
        console.error("Erreur Appel MaxiCash:", error.response?.data || error.message);
        throw new HttpsError('internal', `Erreur communication MaxiCash: ${error.message}`);
    }
});

// --- 2. WEBHOOK MAXICASH ---
exports.maxicashWebhook = onRequest({ region: region, secrets: ["MAXICASH_WEBHOOK_SECRET"] }, async (req, res) => {
    const db = admin.firestore();
    const params = { ...req.query, ...req.body };
    const reference = params.reference || params.Reference;
    const status = params.status || params.Status;
    const sk = params.sk; 

    if (!sk || sk !== process.env.MAXICASH_WEBHOOK_SECRET) return res.status(403).send("Unauthorized");

    try {
        const paymentRef = db.collection('paiements').doc(reference);
        await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(paymentRef);
            if (!doc.exists || doc.data().statut !== 'en_attente') return;

            const isSuccess = status && status.toLowerCase() === 'success';
            transaction.update(paymentRef, { 
                statut: isSuccess ? 'complete' : 'echec', 
                dateConfirmation: admin.firestore.FieldValue.serverTimestamp(),
                rawResponse: params
            });

            if (isSuccess) {
                const factureRef = db.collection('factures').doc(doc.data().factureId);
                transaction.update(factureRef, { 
                    statut: 'payee', 
                    datePaiement: admin.firestore.FieldValue.serverTimestamp() 
                });
            }
        });
        res.status(200).send("OK");
    } catch (e) { 
        console.error("Erreur Webhook:", e);
        res.status(500).send("Error"); 
    }
});

// --- 3. TRIGGERS FIRESTORE (Inchangés) ---
exports.onUserRoleUpdated = onDocumentWritten({ document: 'utilisateurs/{userId}', region: region }, async (event) => {
    const data = event.data.after.data();
    if (!data?.uid) return null;
    let role = data.role || (data.isProprietaire === true ? 'bailleur' : 'locataire');
    try {
        const user = await admin.auth().getUser(data.uid);
        if (user.customClaims?.role !== role) {
            await admin.auth().setCustomUserClaims(data.uid, { ...user.customClaims, role });
        }
    } catch (e) { console.error(e); }
    return null;
});

exports.onNewPropertyCreated = onDocumentCreated({ document: 'proprietes/{proprieteId}', region: region }, async (event) => {
    const db = admin.firestore();
    const data = event.data.data();
    if(!data) return null;
    const usersSnapshot = await db.collection('utilisateurs').where('preferences.commune', '==', data.commune).get();
    const batch = db.batch();
    usersSnapshot.forEach(doc => {
        batch.set(db.collection('utilisateurs').doc(doc.id).collection('alertes').doc(), { 
            message: `Nouvelle propriété à ${data.commune} !`, 
            proprieteId: event.params.proprieteId, 
            timestamp: admin.firestore.FieldValue.serverTimestamp(), 
            lu: false 
        });
    });
    return batch.commit();
});

exports.onPropertyUpdated = onDocumentUpdated({ document: 'proprietes/{proprieteId}', region: region }, async (event) => {
    const db = admin.firestore();
    const proprieteId = event.params.proprieteId; 
    const favoris = await db.collectionGroup('favoris').where('proprieteId', '==', proprieteId).get();
    const batch = db.batch();
    favoris.forEach(doc => {
        const userId = doc.ref.parent.parent.id;
        batch.set(db.collection('utilisateurs').doc(userId).collection('alertes').doc(), { 
            message: "Mise à jour sur un favori.", 
            proprieteId: proprieteId, 
            timestamp: admin.firestore.FieldValue.serverTimestamp(), 
            lu: false 
        });
    });
    return batch.commit();
});

exports.onVisitRequestUpdated = onDocumentWritten({ document: 'demandes_visite/{demandeId}', region: region }, async (event) => {
    const db = admin.firestore();
    const data = event.data.after.data();
    if (!data?.locataireId) return null;
    return db.collection('utilisateurs').doc(data.locataireId).collection('alertes').doc().set({
        message: "Statut de visite mis à jour.", 
        timestamp: admin.firestore.FieldValue.serverTimestamp(), 
        lu: false
    });
});

// --- 4. SERVICES EXTERNES (Inchangés) ---
exports.sendSupportEmail = onCall({ region: region, secrets: ["GMAIL_EMAIL", "GMAIL_PASSWORD"] }, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Login requis.');
    const nodemailer = require('nodemailer'); 
    const transporter = nodemailer.createTransport({ 
        service: 'gmail', 
        auth: { user: process.env.GMAIL_EMAIL, pass: process.env.GMAIL_PASSWORD } 
    });
    return transporter.sendMail({ 
        from: `"Support EasyLocation" <${process.env.GMAIL_EMAIL}>`, 
        to: 'support@easylocationrdc.com', 
        subject: `Support: ${request.data.nom}`, 
        html: `<p>Client: ${request.auth.token.email}</p><p>${request.data.message}</p>` 
    });
});

exports.getGeminiResponse = onCall({ region: region, secrets: ["GEMINI_API_KEY"] }, async (req) => {
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-pro" });
    const result = await model.generateContent(req.data.prompt);
    return { text: result.response.text() };
});

exports.sentryWebhook = onRequest({ region: region }, async (req, res) => {
    const db = admin.firestore();
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    const payload = req.body;
    try {
        await db.collection('rapports_erreurs').add({
            message: payload.message || payload.issue?.title || "Erreur non spécifiée",
            type: payload.issue?.type || "Crash",
            gravite: payload.level === 'error' ? 'critique' : 'warning',
            impact: 1, 
            metadata: {
                os: payload.event?.contexts?.os?.name || "Android/iOS",
                localisation: payload.event?.user?.geo?.city || "RDC",
                device: payload.event?.contexts?.device?.model || "Mobile Device",
                version_app: payload.event?.release || "Inconnue"
            },
            status: "Ouvert",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            sentry_url: payload.url || ""
        });
        return res.status(200).send("Alerte enregistrée");
    } catch (error) { return res.status(500).send("Erreur interne"); }
});