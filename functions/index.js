const admin = require('firebase-admin');
if (admin.apps.length === 0) admin.initializeApp();

const db = admin.firestore();
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');

const region = 'europe-west1';

// --- 1. PAIEMENTS : GÉNÉRATION DU LOGID ---
exports.generateMaxicashUrl = onCall({ 
    region: region,
    secrets: ["MAXICASH_MERCHANT_PASSWORD", "MAXICASH_WEBHOOK_SECRET"] 
}, async (request) => {
    const axios = require('axios');
    const crypto = require('crypto');
    
    if (!request.auth) throw new HttpsError('unauthenticated', 'Authentification requise.');
    
    const { montant: montantBrut, devise, telephone } = request.data;
    if (!montantBrut || !telephone) {
        throw new HttpsError('invalid-argument', 'Montant ou téléphone manquant.');
    }

    const shortRef = crypto.randomBytes(4).toString('hex').toUpperCase(); 
    const emailGenerique = "paiement@easylocation.cd";

    const configDoc = await db.collection('app_config').doc('maxicash').get();
    if (!configDoc.exists) throw new HttpsError('failed-precondition', 'Configuration manquante.');
    
    const { merchantId } = configDoc.data();
    const merchantPassword = process.env.MAXICASH_MERCHANT_PASSWORD;
    const webhookSecret = process.env.MAXICASH_WEBHOOK_SECRET;

    const montantCents = Math.round(parseFloat(montantBrut) * 100).toString();
    const cleanPhone = telephone.replace(/\s+/g, ''); 

    await db.collection('paiements').doc(shortRef).set({
        userId: request.auth.uid,
        referenceMaxicash: shortRef,
        montant: montantBrut,
        devise: devise || "USD",
        statut: 'en_attente',
        telephone: cleanPhone,
        dateCreation: admin.firestore.FieldValue.serverTimestamp()
    });

    const notifyUrl = `https://${region}-easylocation-be28b.cloudfunctions.net/maxicashWebhook?sk=${webhookSecret}`;

    try {
        const response = await axios.post("https://webapi-test.maxicashme.com/Integration/PayEntryWeb", {
            "PayType": "MaxiCash",
            "MerchantID": merchantId,
            "MerchantPassword": merchantPassword,
            "Amount": montantCents,
            "Currency": "maxiDollar",
            "Telephone": cleanPhone,
            "Email": emailGenerique,
            "Language": "fr",
            "Reference": shortRef, 
            "SuccessURL": "easylocation://success",
            "FailureURL": "easylocation://cancel",
            "CancelURL": "easylocation://cancel",
            "NotifyURL": notifyUrl
        });

        const logId = response.data.LogID || response.data.ResponseData;

        if (response.data.ResponseStatus !== "success" || !logId) {
            console.error("Réponse MaxiCash invalide:", response.data);
            throw new Error(response.data.ResponseError || "Erreur lors de la génération du LogID.");
        }

        const redirectUrl = `https://api-testbed.maxicashme.com/payentryweb?logid=${logId}`;
        return { url: redirectUrl };

    } catch (error) {
        console.error("Erreur Appel API MaxiCash:", error.message);
        throw new HttpsError('internal', `Erreur de communication: ${error.message}`);
    }
});

// --- 2. PAIEMENTS : WEBHOOK ---
exports.maxicashWebhook = onRequest({ 
    region: region,
    secrets: ["MAXICASH_WEBHOOK_SECRET"] 
}, async (req, res) => {
    const { reference, status, transactionid, sk } = req.query;
    
    if (!sk || sk !== process.env.MAXICASH_WEBHOOK_SECRET) return res.status(403).send("Forbidden");
    if (!reference) return res.status(400).send("No reference");

    try {
        const paymentRef = db.collection('paiements').doc(reference);
        const doc = await paymentRef.get();

        if (!doc.exists) return res.status(404).send("Not found");

        await paymentRef.update({
            statut: status === 'success' ? 'complete' : 'echec',
            maxicashTransactionId: transactionid || "",
            dateConfirmation: admin.firestore.FieldValue.serverTimestamp()
        });

        return res.status(200).send("OK");
    } catch (error) { 
        return res.status(500).send("Error"); 
    }
});

// --- 3. LOGIQUE MÉTIER (Rôles, Propriétés, Alertes) ---
exports.onUserRoleUpdated = onDocumentWritten({ document: 'utilisateurs/{userId}', region: region }, async (event) => {
    const data = event.data.after.data();
    if (!data?.uid) return null;
    let role = data.role || (data.isProprietaire === true ? 'bailleur' : 'locataire');
    try {
        const user = await admin.auth().getUser(data.uid);
        if (user.customClaims?.role !== role) {
            await admin.auth().setCustomUserClaims(data.uid, { ...user.customClaims, role });
        }
    } catch (e) { console.error("Erreur Claims:", e); }
    return null;
});

exports.onNewPropertyCreated = onDocumentCreated({ document: 'proprietes/{proprieteId}', region: region }, async (event) => {
    const data = event.data.data();
    if(!data) return null;
    const users = await db.collection('utilisateurs').where('preferences.commune', '==', data.commune).get();
    const batch = db.batch();
    users.forEach(doc => {
        batch.set(db.collection('utilisateurs').doc(doc.id).collection('alertes').doc(), {
            message: "Nouvelle propriété dans votre zone !", 
            timestamp: admin.firestore.FieldValue.serverTimestamp(), 
            lu: false
        });
    });
    return batch.commit();
});

exports.onPropertyUpdated = onDocumentUpdated({ document: 'proprietes/{proprieteId}', region: region }, async (event) => {
    const favoris = await db.collectionGroup('favoris').where('proprieteId', '==', event.data.after.id).get();
    const batch = db.batch();
    favoris.forEach(doc => {
        batch.set(db.collection('utilisateurs').doc(doc.ref.parent.parent.id).collection('alertes').doc(), {
            message: "Mise à jour d'un de vos favoris.", 
            timestamp: admin.firestore.FieldValue.serverTimestamp(), 
            lu: false
        });
    });
    return batch.commit();
});

exports.onVisitRequestUpdated = onDocumentWritten({ document: 'demandes_visite/{demandeId}', region: region }, async (event) => {
    const data = event.data.after.data();
    if (!data?.locataireId) return null;
    return db.collection('utilisateurs').doc(data.locataireId).collection('alertes').doc().set({
        message: "Statut de visite mis à jour.", 
        timestamp: admin.firestore.FieldValue.serverTimestamp(), 
        lu: false
    });
});

// --- 4. SERVICES EXTERNES ---
const sendEmailInternal = async (subject, html, toEmail) => {
    const nodemailer = require('nodemailer'); 
    const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: { user: process.env.GMAIL_EMAIL, pass: process.env.GMAIL_PASSWORD },
    });
    return transporter.sendMail({
        from: `"EasyLocation" <${process.env.GMAIL_EMAIL}>`,
        to: toEmail, subject, html
    });
};

exports.sendSupportEmail = onCall({ region: region, secrets: ["GMAIL_EMAIL", "GMAIL_PASSWORD"] }, async (req) => {
    return sendEmailInternal(`Support: ${req.data.nom}`, `<p>${req.data.message}</p>`, 'support@easylocationrdc.com');
});

exports.getGeminiResponse = onCall({ region: region, secrets: ["GEMINI_API_KEY"] }, async (req) => {
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-pro" });
    const result = await model.generateContent(req.data.prompt);
    return { text: result.response.text() };
});

// --- 5. OBSERVATOIRE TECH : WEBHOOK SENTRY ---
exports.sentryWebhook = onRequest({ region: region }, async (req, res) => {
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
                localisation: payload.event?.user?.geo?.city || "RDC (Multi)",
                device: payload.event?.contexts?.device?.model || "Mobile Device",
                version_app: payload.event?.release || "Inconnue"
            },
            status: "Ouvert",
            // Cette ligne est cruciale pour le TTL (Nettoyage automatique)
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            sentry_url: payload.url || ""
        });

        return res.status(200).send("Alerte enregistrée dans l'Observatoire");
    } catch (error) {
        console.error("Erreur Observatoire:", error);
        return res.status(500).send("Erreur interne");
    }
});