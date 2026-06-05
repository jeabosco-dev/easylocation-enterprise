const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
// On importe admin, db et getFieldValue depuis votre fichier de configuration centrale
const { admin, db, getFieldValue } = require('./admin');

const region = 'europe-west1';

/**
 * CONSTANTES DE NORMALISATION
 */
const STATUS_ACTIF = 'active';

/**
 * Calcul sécurisé pour ajouter des mois à une date
 */
function addMonthsSecure(date, months) {
    const d = new Date(date.getTime());
    const expectedMonth = (d.getMonth() + months) % 12;
    d.setMonth(d.getMonth() + months);
    
    if (d.getMonth() !== expectedMonth && d.getMonth() !== (expectedMonth < 0 ? expectedMonth + 12 : expectedMonth)) {
        d.setDate(0);
    }
    return d;
}

/**
 * TRIGGER: Calcul et distribution du Cashback/Remise centralisé dans la collection 'wallets'
 */
exports.onFactureValidated = onDocumentUpdated("factures/{factureId}", async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Vérifie si la confirmation passe à 'valide'
    if (after.confirmationLocataire === 'valide' && before.confirmationLocataire !== 'valide') {
        
        try {
            const configDoc = await db.collection('settings').doc('app_config').get();
            if (!configDoc.exists) return null;
            const config = configDoc.data().loyalty_config;

            const cashbackLocataire = (after.commissionLocataire || 0) * ((config?.locataire_cashback_percent || 0) / 100);
            const remiseBailleur = (after.commissionBailleur || 0) * ((config?.bailleur_discount_percent || 0) / 100);

            const batch = db.batch();

            // 1. Distribution au Locataire (vers collection wallets)
            if (after.clientId) {
                const walletRef = db.collection('wallets').doc(after.clientId);
                
                batch.set(walletRef, {
                    'cashback_balance': admin.firestore.FieldValue.increment(cashbackLocataire),
                    'last_update': getFieldValue().serverTimestamp()
                }, { merge: true });
                
                const logRef = walletRef.collection('operations').doc();
                batch.set(logRef, {
                    amount: cashbackLocataire,
                    type: "CASHBACK_VALIDATION",
                    factureId: after.id,
                    timestamp: getFieldValue().serverTimestamp()
                });
            }

            // 2. Distribution au Bailleur (vers collection wallets)
            if (after.bailleurId) {
                const walletRef = db.collection('wallets').doc(after.bailleurId);
                
                batch.set(walletRef, {
                    'commission_balance': admin.firestore.FieldValue.increment(remiseBailleur),
                    'last_update': getFieldValue().serverTimestamp()
                }, { merge: true });
                
                const logRef = walletRef.collection('operations').doc();
                batch.set(logRef, {
                    amount: remiseBailleur,
                    type: "REMISE_COMMISSION",
                    factureId: after.id,
                    timestamp: getFieldValue().serverTimestamp()
                });
            }

            // 3. Mise à jour facture
            batch.update(event.data.after.ref, {
                montantCashback: cashbackLocataire,
                dateDistributionCashback: getFieldValue().serverTimestamp()
            });

            await batch.commit();
            console.log(`[CASHBACK] Distribué pour facture ${after.id} dans la collection wallets`);
        } catch (e) {
            console.error("Erreur calcul cashback:", e);
        }
    }
    return null;
});

/**
 * Création rapide d'une propriété et d'un contrat lié
 */
exports.quickOnboarding = onCall({ region: region }, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Authentification requise.');

    const { propertyData, tenantData, startDate, dureeBail } = request.data;

    try {
        return await db.runTransaction(async (transaction) => {
            const propRef = db.collection('proprietes').doc();
            transaction.set(propRef, {
                ...propertyData,
                bailleurId: request.auth.uid,
                status: 'louée',
                estLouee: true,
                createdAt: getFieldValue().serverTimestamp(),
                lastUpdated: getFieldValue().serverTimestamp()
            });

            const contractRef = db.collection('contrats').doc();
            const start = new Date(startDate);
            const end = addMonthsSecure(start, parseInt(dureeBail));

            transaction.set(contractRef, {
                propertyId: propRef.id,
                bailleurId: request.auth.uid,
                locataireId: null,
                locataireNom: tenantData.nom,
                locataireTel: tenantData.phone,
                ville: propertyData.ville || "Bukavu",
                startDate: admin.firestore.Timestamp.fromDate(start),
                endDate: admin.firestore.Timestamp.fromDate(end),
                prochainPaiement: admin.firestore.Timestamp.fromDate(start),
                loyerMensuel: propertyData.loyer,
                status: STATUS_ACTIF,
                isAsymmetric: true,
                createdAt: getFieldValue().serverTimestamp()
            });

            return { success: true, propertyId: propRef.id, contractId: contractRef.id };
        });
    } catch (e) {
        console.error("Erreur QuickOnboarding:", e);
        throw new HttpsError('internal', e.message);
    }
});

/**
 * Prolonge la durée d'un bail existant
 */
exports.prolongerBail = onCall({ region: region }, async (request) => {
    const { contractId, nbMois } = request.data;
    if (!contractId || !nbMois) throw new HttpsError('invalid-argument', 'Paramètres manquants.');

    try {
        return await db.runTransaction(async (transaction) => {
            const contractRef = db.collection('contrats').doc(contractId);
            const contractDoc = await transaction.get(contractRef);
            if (!contractDoc.exists) throw new Error("Contrat introuvable");

            const data = contractDoc.data();
            const currentEndDate = (data.endDate || data.dateFin).toDate();
            const currentProchainPaiement = data.prochainPaiement.toDate();

            const newEndDate = addMonthsSecure(currentEndDate, parseInt(nbMois));
            const newProchainPaiement = addMonthsSecure(currentProchainPaiement, parseInt(nbMois));

            transaction.update(contractRef, {
                endDate: admin.firestore.Timestamp.fromDate(newEndDate),
                prochainPaiement: admin.firestore.Timestamp.fromDate(newProchainPaiement),
                statutPaiement: 'paye',
                dernierNombreMoisPayes: parseInt(nbMois),
                lastUpdated: getFieldValue().serverTimestamp()
            });

            const historiqueRef = contractRef.collection('historique_paiements').doc();
            transaction.set(historiqueRef, {
                type: "PROLONGATION",
                dateOperation: getFieldValue().serverTimestamp(),
                montantTotal: (data.loyerMensuel || 0) * nbMois,
                nbMoisAjoutes: nbMois,
                referenceMaison: data.propertyId ? data.propertyId.substring(0, 6).toUpperCase() : "N/A",
                status: 'validé'
            });

            return { success: true, message: "Bail prolongé avec succès" };
        });
    } catch (e) {
        console.error("Erreur ProlongerBail:", e);
        throw new HttpsError('internal', e.message);
    }
});

/**
 * Clôture un bail et remet la propriété en "disponible"
 */
exports.cloturerBail = onCall({ region: region }, async (request) => {
    const { contractId, propertyId } = request.data;
    if (!contractId || !propertyId) throw new HttpsError('invalid-argument', 'ID manquant.');

    try {
        await db.runTransaction(async (transaction) => {
            const contractRef = db.collection('contrats').doc(contractId);
            const propertyRef = db.collection('proprietes').doc(propertyId);
            const now = new Date();
            const monthId = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
            const statsRef = db.collection('admin_analytics').doc(monthId);

            transaction.update(contractRef, { status: 'cloture', dateCloture: getFieldValue().serverTimestamp() });
            transaction.update(propertyRef, { status: 'disponible', estLouee: false, currentTenantId: null, lastUpdated: getFieldValue().serverTimestamp() });
            transaction.set(statsRef, {
                totalRotations: admin.firestore.FieldValue.increment(1),
                dernierEvenement: getFieldValue().serverTimestamp(),
                mois: monthId
            }, { merge: true });
        });
        return { success: true };
    } catch (e) {
        console.error("Erreur CloturerBail:", e);
        throw new HttpsError('internal', e.message);
    }
});

/**
 * Trigger création contrat (Legacy)
 */
exports.onContractCreated = onDocumentCreated("contrats/{contractId}", async (event) => {
    const data = event.data.data();
    if (data.status === STATUS_ACTIF || data.statut === 'actif') {
        console.log(`[CONTRACT] Nouveau contrat actif: ${event.params.contractId}`);
    }
    return null;
});