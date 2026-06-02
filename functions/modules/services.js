const admin = require('firebase-admin');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const nodemailer = require('nodemailer');

const getFieldValue = () => admin.firestore.FieldValue;
const getDb = () => admin.firestore();
const region = 'europe-west1';

// --- HELPER FUNCTIONS (Logique interne) ---

/**
 * Envoi de notification Push via FCM (Utilitaire interne enrichi)
 * Nettoie les données pour garantir que FCM ne reçoit que des strings
 */
async function _sendPushNotification(userId, title, body, extraData = {}) {
    try {
        const userDoc = await getDb().collection('utilisateurs').doc(userId).get();
        const fcmToken = userDoc.data()?.fcmToken;

        if (!fcmToken) {
            console.log(`[Service:FCM] Aucun token trouvé pour l'utilisateur ${userId}`);
            return null;
        }

        // --- NETTOYAGE : Conversion forcée en chaîne de caractères ---
        const sanitizedData = {};
        for (const [key, value] of Object.entries(extraData)) {
            // Si la valeur est null/undefined, on met une chaîne vide
            sanitizedData[key] = (value === null || value === undefined) ? "" : String(value);
        }
        
        // Ajout des champs système obligatoires
        sanitizedData.click_action = "FLUTTER_NOTIFICATION_CLICK";

        const message = {
            token: fcmToken,
            notification: { title, body },
            android: {
                notification: {
                    channelId: 'easylocation_alerts',
                    priority: 'max',
                    sound: 'default'
                }
            },
            data: sanitizedData
        };

        const response = await admin.messaging().send(message);
        console.log(`[Service:FCM] Notification envoyée avec succès à ${userId}`);
        return response;
    } catch (error) {
        console.error(`[Service:FCM] Erreur d'envoi à ${userId}:`, error);
        return null;
    }
}

/**
 * Envoi d'Email via SMTP
 */
async function _sendEmail({ to, subject, html }) {
    const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: { 
            user: process.env.GMAIL_EMAIL, 
            pass: process.env.GMAIL_PASSWORD 
        }
    });

    return transporter.sendMail({
        from: `"Support EasyLocation" <${process.env.GMAIL_EMAIL}>`,
        to,
        subject,
        html
    });
}

// --- CLOUD FUNCTIONS EXPORTÉES ---

exports.sendNotification = onCall({ region: region }, async (request) => {
    const { userId, title, body, ...rest } = request.data;
    if (!userId || !title || !body) throw new HttpsError('invalid-argument', "Paramètres manquants");
    return await _sendPushNotification(userId, title, body, rest);
});

exports.getGeminiResponse = onCall({ region: region, secrets: ["GEMINI_API_KEY"] }, async (request) => {
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    const prompt = request.data.prompt;
    if (!prompt) throw new HttpsError('invalid-argument', "Aucun prompt fourni.");
    try {
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
        const result = await model.generateContent(prompt);
        return { text: result.response.text() };
    } catch (error) {
        return { text: "Désolé, l'IA rencontre une erreur technique." };
    }
});

exports.sendSupportEmail = onCall({ region: region, secrets: ["GMAIL_EMAIL", "GMAIL_PASSWORD"] }, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Connexion requise.');
    const { nom, message } = request.data;
    const emailClient = request.auth.token.email || "Inconnu";
    await _sendEmail({
        to: 'support@easylocationrdc.com',
        subject: `Support: ${nom}`,
        html: `<p><strong>Client:</strong> ${emailClient}</p><p>${message}</p>`
    });
    return { success: true };
});

exports.onRefundPaidNotifyLocataire = onDocumentUpdated({ document: 'refund_requests/{requestId}', region: region }, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    if (newData?.status === 'paye' && oldData?.status !== 'paye') {
        return _sendPushNotification(newData.userId, "Remboursement effectué ! 💸", `Votre montant de ${newData.netAmount || 0} $ a été versé.`, {
            type: "REFUND",
            amount: String(newData.netAmount || 0)
        });
    }
});

exports.sentryWebhook = onRequest({ region: region }, async (req, res) => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    try {
        const payload = req.body;
        await getDb().collection('rapports_erreurs').add({
            message: payload.message || payload.issue?.title || "Erreur Sentry",
            metadata: {
                os: payload.event?.contexts?.os?.name || "Inconnu",
                device: payload.event?.contexts?.device?.model || "Mobile",
                version: payload.event?.release || "1.0.0"
            },
            status: "Ouvert",
            timestamp: getFieldValue().serverTimestamp()
        });
        res.status(200).send("OK");
    } catch (e) {
        res.status(500).send("Error");
    }
});

// Exportation interne
exports.internal = {
    sendPushNotification: _sendPushNotification,
    sendEmail: _sendEmail
};