const admin = require('firebase-admin');

// Initialisation unique du SDK Admin
if (admin.apps.length === 0) {
    admin.initializeApp();
}

/**
 * Accès "Lazy" aux services Firebase.
 * On ne crée l'instance que si la fonction est appelée.
 */
const getDb = () => admin.firestore();
const getAuth = () => admin.auth();
const getMessaging = () => admin.messaging();
const getFieldValue = () => admin.firestore.FieldValue;

// ✅ Exportation cohérente
module.exports = { 
    admin, 
    getDb, 
    getAuth, 
    getMessaging, 
    getFieldValue 
};