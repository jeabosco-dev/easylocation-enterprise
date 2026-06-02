const admin = require('firebase-admin');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const nodemailer = require('nodemailer');

/**
 * Accès "Lazy" à FieldValue et à la DB
 * Évite les variables globales lourdes à l'initialisation
 */
const getFieldValue = () => admin.firestore.FieldValue;
const getDb = () => admin.firestore();
const region = 'europe-west1';

// --- HELPER FUNCTIONS (Logique interne) ---

/**
 * Envoi de notification Push via FCM (Utilitaire interne)
 */
async function _sendPushNotification(userId, title, body, data = {}) {
    try {
        const userDoc = await getDb().collection('utilisateurs').doc(userId).get();
        const fcmToken = userDoc.data()?.fcmToken;

        if (!fcmToken) {
            console.log(`[Service:FCM] Aucun token trouvé pour l'utilisateur ${userId}`);
            return null;
        }

        const message = {
            notification: { title, body },
            token: fcmToken,
            data: { 
                ...data,
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
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
 * Envoi d'Email via SMTP (Utilitaire interne)
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

/**
 * Fonction Callable exposée pour Flutter
 * Permet d'envoyer des notifications depuis le client (Admin ou autre)
 */
exports.sendNotification = onCall({ region: region }, async (request) => {
    const { userId, title, body, propertyId, contractId } = request.data;

    if (!userId || !title || !body) {
        throw new HttpsError('invalid-argument', "Paramètres manquants (userId, title, body)");
    }

    // Construction du payload de données pour la redirection mobile
    const dataPayload = {
        type: contractId ? "NOTIFICATION_CONTRAT" : "NOTIFICATION_GENERIQUE",
        propertyId: propertyId || "",
        contractId: contractId || ""
    };

    return await _sendPushNotification(userId, title, body, dataPayload);
});

/**
 * Appel à l'API Gemini depuis l'application Flutter (Lazy Loaded)
 */
exports.getGeminiResponse = onCall({ 
    region: region, 
    secrets: ["GEMINI_API_KEY"] 
}, async (request) => {
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    
    const prompt = request.data.prompt;
    if (!prompt) throw new HttpsError('invalid-argument', "Aucun prompt fourni.");

    try {
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
        const result = await model.generateContent(prompt);
        return { text: result.response.text() };
    } catch (error) {
        console.error("Erreur Gemini:", error);
        return { text: "Désolé, l'IA rencontre une erreur technique." };
    }
});

/**
 * Envoi d'un mail de support de l'application vers l'administration
 */
exports.sendSupportEmail = onCall({ 
    region: region, 
    secrets: ["GMAIL_EMAIL", "GMAIL_PASSWORD"] 
}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Connexion requise.');
    
    const { nom, message } = request.data;
    const emailClient = request.auth.token.email || "Inconnu";

    try {
        await _sendEmail({
            to: 'support@easylocationrdc.com',
            subject: `Support: ${nom}`,
            html: `<p><strong>Client:</strong> ${emailClient}</p><p>${message}</p>`
        });
        return { success: true };
    } catch (error) {
        console.error("Erreur Email Support:", error);
        return { success: false };
    }
});

/**
 * Trigger : Notifier le locataire quand son remboursement passe à l'état payé
 */
exports.onRefundPaidNotifyLocataire = onDocumentUpdated({
    document: 'refund_requests/{requestId}',
    region: region
}, async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData?.status === 'paye' && oldData?.status !== 'paye') {
        const userId = newData.userId;
        const montant = newData.netAmount || 0;

        return _sendPushNotification(
            userId,
            "Remboursement effectué ! 💸",
            `Votre montant de ${montant} $ a été versé sur votre compte.`,
            { type: "REFUND_PAID" }
        );
    }
    return null;
});

/**
 * Webhook d'écoute et de journalisation des erreurs de production (Sentry)
 */
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

// Exportation pour utilisation par index.js
exports.internal = {
    sendPushNotification: _sendPushNotification,
    sendEmail: _sendEmail
};