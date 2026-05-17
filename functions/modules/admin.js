const admin = require('firebase-admin');

if (admin.apps.length === 0) {
    admin.initializeApp();
}

// On définit les instances une fois pour toutes
const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

module.exports = { 
    admin, 
    db,               // ✅ Ajouté pour system.js et payments.js
    auth,             // ✅ Ajouté pour la cohérence
    getDb: () => db, 
    getAuth: () => auth,
    getMessaging: () => messaging,
    getFieldValue: () => admin.firestore.FieldValue 
};