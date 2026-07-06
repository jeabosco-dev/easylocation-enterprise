const admin = require('firebase-admin');
const { onCall, HttpsError, onRequest } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { defineString } = require('firebase-functions/params');
const axios = require('axios');
const crypto = require('crypto');

// Importation des modules locaux
const paymentsHybrid = require('./payments_hybrid'); 
const services = require('./services'); 
const manualPayments = require('./manual_payments');

// --- 1. CONFIGURATION DYNAMIQUE ---
const maxicashMode = defineString('MAXICASH_MODE', { default: 'test' });

const MC_CONFIG = {
    test: {
        baseUrl: "https://api-testbed.maxicashapp.com",
        webApi: "https://webapi-test.maxicashapp.com/Integration/PayEntryWeb"
    },
    prod: {
        baseUrl: "https://api.maxicashapp.com",
        webApi: "https://webapi.maxicashapp.com/Integration/PayEntryWeb"
    }
};

// Fonction utilitaire pour accéder à la configuration au moment de l'exécution
const getMC = () => {
    const mode = maxicashMode.value();
    return MC_CONFIG[mode] || MC_CONFIG.test;
};

// Initialisation sécurisée
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const getDb = () => admin.firestore();
const getFieldValue = () => admin.firestore.FieldValue;
const region = 'europe-west1';

/**
 * 1. GÉNÉRATION DE L'URL MAXICASH (INSTRUMENTÉE)
 */
exports.generateMaxicashUrl = onCall({ 
    region: region,
    enforceAppCheck: true, 
    secrets: ["MAXICASH_MERCHANT_PASSWORD", "MAXICASH_WEBHOOK_SECRET"] 
}, async (request) => {
    console.log("========== DEBUT generateMaxicashUrl ==========");
    console.log("UID :", request.auth?.uid);
    console.log("request.data :", request.data);

    const db = getDb();
    const MC = getMC();
    console.log("Configuration MaxiCash :", MC);
    
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'L\'utilisateur doit être connecté.');
    }
    
    const { factureId, telephone, hybridReference, amountOverride } = request.data;

    if (!telephone || telephone.trim() === "") {
        throw new HttpsError('invalid-argument', 'Téléphone manquant.');
    }

    let montantUSD = 0;
    let finalReference = "";
    let factureReference = factureId || null;

    console.log("Lecture facture...");
    if (amountOverride && amountOverride > 0) {
        montantUSD = amountOverride;
        finalReference = hybridReference ? hybridReference : `FAC-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
        
        if (hybridReference) {
            const pendingSnap = await db.collection('pending_payments').doc(hybridReference).get();
            if (pendingSnap.exists) {
                const d = pendingSnap.data();
                factureReference = d.factureReference || factureReference;
            }
        }
    } else if (factureId) {
        let docSnap = await db.collection('factures').doc(factureId).get();
        if (!docSnap.exists) docSnap = await db.collection('services').doc(factureId).get();
        if (!docSnap.exists) throw new HttpsError('not-found', `Document ${factureId} introuvable.`);
        const d = docSnap.data();
        montantUSD = d.totalUSD || d.prix || d.montant || (d.totalCDF ? d.totalCDF / 2500 : 0);
        finalReference = `FAC-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    } else {
        throw new HttpsError('invalid-argument', 'ID facture ou Montant manquant.');
    }
    
    if (montantUSD <= 0) throw new HttpsError('internal', 'Montant calculé invalide.');
    const montantCents = Math.round(parseFloat(montantUSD) * 100);

    console.log("Montant USD :", montantUSD);
    console.log("Montant cents :", montantCents);

    const configDoc = await db.collection('app_config').doc('maxicash').get();
    if (!configDoc.exists) throw new HttpsError('failed-precondition', 'Config Firestore manquante.');
    
    const configData = configDoc.data();
    const mId = configData.merchantId;
    const mPass = process.env.MAXICASH_MERCHANT_PASSWORD;
    
    // Vérification de la présence des secrets
    console.log("Merchant ID présent :", !!mId);
    console.log("Mot de passe présent :", !!mPass);
    
    console.log("Merchant :", mId);
    console.log("Référence :", finalReference);

    if (!mId || !mPass) throw new HttpsError('internal', 'Identifiants marchand MaxiCash incomplets.');

    const cleanPhone = telephone.replace(/\s+/g, '').replace('+', ''); 
    console.log("Téléphone :", cleanPhone);

    console.log("Création document paiements...");
    await db.collection('paiements').doc(finalReference).set({
        userId: request.auth.uid,
        factureReference: factureReference, 
        hybridReference: hybridReference || null,
        montantAttenduCents: montantCents,
        statut: 'en_attente',
        dateCreation: getFieldValue().serverTimestamp()
    });
    console.log("Paiement enregistré.");

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

    try {
        console.log("Envoi vers MaxiCash...");
        console.log("Payload:", JSON.stringify(payload));
        
        const response = await axios.post(
            MC.webApi, 
            payload, 
            {
                headers: { "Content-Type": "application/json" },
                timeout: 30000
            }
        );
        
        console.log("Réponse MaxiCash :");
        console.log(JSON.stringify(response.data));
        
        if (!response.data || response.data.ResponseStatus !== "success") {
            throw new Error(response.data?.ResponseError || "Erreur MaxiCash");
        }
        
        const logId = response.data.ResponseData;
        console.log("URL retournée :", `${MC.baseUrl}/payentryweb?logid=${logId}`);
        
        return { url: `${MC.baseUrl}/payentryweb?logid=${logId}`, reference: finalReference };
    } catch (error) {
        console.error("ERREUR COMPLETE");
        console.error(error);
        console.error(error.response?.data);
        console.error(error.response?.status);
        console.error(error.stack);
        throw new HttpsError('internal', `MaxiCash: ${error.message}`);
    }
});

/**
 * 2. WEBHOOK MAXICASH (ROBUSTE)
 */
exports.maxicashWebhook = onRequest({ region: region, secrets: ["MAXICASH_WEBHOOK_SECRET"] }, async (req, res) => {
    const db = getDb();
    const params = { ...req.query, ...req.body };
    
    const reference = params.reference || params.Reference;
    const status = params.status || params.Status;

    if (!params.sk || params.sk !== process.env.MAXICASH_WEBHOOK_SECRET) return res.status(403).send("Unauthorized");
    if (!reference) return res.status(400).send("Reference manquante");

    let hybridReferenceToFinalize = null;

    try {
        if (status && status.toLowerCase() === 'success') {
            await db.runTransaction(async (transaction) => {
                const paymentRef = db.collection('paiements').doc(reference);
                const paymentDoc = await transaction.get(paymentRef);
                
                if (!paymentDoc.exists || paymentDoc.data().statut !== 'en_attente') return;
                const paymentData = paymentDoc.data();

                let factureDoc = null;
                let factureRef = null;
                if (paymentData.factureReference) {
                    factureRef = db.collection('factures').doc(paymentData.factureReference);
                    factureDoc = await transaction.get(factureRef);
                }

                transaction.update(paymentRef, { 
                    statut: 'valide',
                    paymentStatus: 'success',
                    datePaiement: getFieldValue().serverTimestamp()
                });

                let isActuallyHybrid = false;
                if (factureDoc && factureDoc.exists) {
                    const f = factureDoc.data();
                    isActuallyHybrid = (f.montantWallet || 0) > 0 && (f.montantExterne || 0) > 0;

                    transaction.update(factureRef, {
                        paymentStatus: 'success',
                        etapeDossier: 'paye'
                    });
                }

                if (isActuallyHybrid && paymentData.hybridReference) {
                    hybridReferenceToFinalize = paymentData.hybridReference;
                    transaction.update(paymentRef, { statusHybride: "pending_finalization" });
                } else {
                    const txRef = db.collection('transactions').doc();
                    transaction.set(txRef, {
                        userId: paymentData.userId,
                        walletId: paymentData.userId,
                        factureId: paymentData.factureReference,
                        title: "Achat Externe",
                        amount: paymentData.montantAttenduCents / 100,
                        isPositive: false,
                        type: "ACHAT_EXTERNE",
                        date: getFieldValue().serverTimestamp(),
                        source: "MaxiCash"
                    });
                }
            });
        }

        if (hybridReferenceToFinalize) {
            const ok = await paymentsHybrid.finalizeHybridTransaction(hybridReferenceToFinalize);
            if (ok) {
                await db.collection('paiements').doc(reference).update({
                    statusHybride: "completed",
                    dateFinalisation: getFieldValue().serverTimestamp()
                });
            } else {
                console.error(`Impossible de finaliser le paiement hybride ${hybridReferenceToFinalize}`);
            }
        }

        return res.status(200).send("OK");
    } catch (e) { 
        console.error("Erreur Webhook MaxiCash:", e);
        return res.status(500).send("Error"); 
    }
});

/**
 * 3. TRIGGER PAIEMENT
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

    if ((newStatus === 'paid' || newStatus === 'success') && oldStatus !== 'paid' && oldStatus !== 'success') {
        const { propertyId, contractId, clientId, userId, locataireId, refMaison = "votre logement" } = newData;
        const targetLocataireId = clientId || userId || locataireId;

        try {
            await services.internal.sendPushNotification(targetLocataireId, "Paiement Validé ! ✅", `Votre réservation pour la maison ${refMaison} est confirmée.`, { propertyId, contractId });
            if (propertyId) {
                const propDoc = await db.collection('proprietes').doc(propertyId).get();
                const bailleurId = newData.bailleurId || (propDoc.exists ? propDoc.data().bailleurId : null);
                if (bailleurId) {
                    await services.internal.sendPushNotification(bailleurId, "Maison Réservée ! 🏠", `Votre bien ${refMaison} vient d'être réservé par un client.`, { propertyId, contractId });
                }
            }
        } catch (error) { console.error("💥 Erreur Notification Trigger:", error); }
    }
});

/**
 * 4. TRIGGER PARRAINAGE
 */
exports.onFactureClotureeReward = onDocumentUpdated({ 
    document: 'factures/{factureId}', 
    region: region 
}, async (event) => {
    const db = getDb();
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    const estCloture = newData.etapeDossier === 'cloture' && oldData.etapeDossier !== 'cloture';
    const estValide = newData.confirmationLocataire === 'valide';
    
    if (estCloture && estValide && !newData.bonusApplied) {
        const locataireId = newData.clientId || newData.userId || newData.locataireId;
        
        try {
            const userDoc = await db.collection('utilisateurs').doc(locataireId).get();
            const referrerId = userDoc.data()?.referrerId;

            if (referrerId) {
                const batch = db.batch();
                batch.update(db.collection('wallets').doc(referrerId), { 
                    'bonusBalance': getFieldValue().increment(4),
                    'lastUpdate': getFieldValue().serverTimestamp()
                });
                batch.update(db.collection('wallets').doc(locataireId), { 
                    'bonusBalance': getFieldValue().increment(3),
                    'lastUpdate': getFieldValue().serverTimestamp()
                });
                batch.update(event.data.after.ref, { 'bonusApplied': true });
                
                await batch.commit();
                console.log(`✅ Bonus parrainage versé : Parrain ${referrerId} & Filleul ${locataireId}`);
            }
        } catch (error) { console.error("💥 Erreur bonus clôture:", error); }
    }
});

/**
 * 5. AUTOMATISATION : Mise à jour du statut de la propriété
 */
exports.onFactureReserved = onDocumentUpdated({ 
    document: 'factures/{factureId}', 
    region: region 
}, async (event) => {
    const db = getDb();
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (newData.paymentStatus === 'success' && oldData.paymentStatus !== 'success') {
        const propertyId = newData.propertyId;
        if (propertyId) {
            try {
                await db.collection('proprietes').doc(propertyId).update({
                    status: 'reserved',
                    reservedAt: getFieldValue().serverTimestamp(),
                    updatedAt: getFieldValue().serverTimestamp()
                });
                console.log(`✅ Propriété ${propertyId} réservée automatiquement via facture ${event.params.factureId}`);
            } catch (error) {
                console.error(`💥 Erreur lors de la réservation automatique :`, error);
            }
        }
    }
});