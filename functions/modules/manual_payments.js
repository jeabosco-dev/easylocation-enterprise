// functions/modules/manual_payments.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { finalizeTransactionCore } = require('./transaction_core');
const { calculateWalletDeduction } = require('./payments_hybrid');

exports.finalizeManualPayment = onCall({ region: 'europe-west1' }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Not logged in');
    }

    // Sécurité serveur : l'identité de l'administrateur est extraite du jeton d'authentification
    const verifiedAdminId = request.auth.uid;

    const { factureId, userId, amount, propertyId, ok, sourcePaiement, motif } = request.data;
    const db = admin.firestore();

    // ==========================================
    // 1. CAS DU REJET (ok === false)
    // ==========================================
    if (!ok) {
        await db.runTransaction(async (t) => {
            const factureRef = db.collection('factures').doc(factureId);

            // ----------------------------------------------------
            // ÉTAPE 1 : TOUTES LES LECTURES (READS) EN PREMIER
            // ----------------------------------------------------
            let pendingSnap = null;
            if (propertyId) {
                // Lecture de la réservation en attente avant toute écriture
                pendingSnap = await t.get(
                    db.collection('pending_payments')
                        .where('serviceId', '==', propertyId)
                        .where('userId', '==', userId)
                        .where('status', '==', 'awaiting_gateway')
                        .limit(1)
                );
            }

            // ----------------------------------------------------
            // ÉTAPE 2 : TOUTES LES ÉCRITURES (WRITES) ENSUITE
            // ----------------------------------------------------
            
            // 1. Mettre la facture au statut rejeté
            t.update(factureRef, {
                paymentStatus: 'failed',
                etapeDossier: 'rejete',
                motifRejet: motif || null,
                agentValidationId: verifiedAdminId,
                dateAnnulation: admin.firestore.FieldValue.serverTimestamp()
            });

            // 2. Libération explicite de la propriété & annulation du pending payment
            if (propertyId) {
                // A. Remise en disponibilité du logement
                const propertyRef = db.collection('proprietes').doc(propertyId);
                t.update(propertyRef, {
                    status: 'disponible',
                    reservedAt: admin.firestore.FieldValue.delete()
                });

                // B. Annulation du paiement en attente
                if (pendingSnap && !pendingSnap.empty) {
                    t.update(pendingSnap.docs[0].ref, {
                        status: 'cancelled',
                        processedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                }
            }

            // 3. Créer une trace d'annulation dans le Ledger des transactions
            const txRef = db.collection('transactions').doc();
            t.set(txRef, {
                userId,
                factureId,
                propertyId: propertyId || null,
                amount,
                type: sourcePaiement === 'MANUEL' ? 'ACHAT_MANUEL_REJECTED' : 'ACHAT_CASH_REJECTED',
                isPositive: false,
                method: sourcePaiement || 'CASH',
                metadata: {
                    adminId: verifiedAdminId,
                    motif: motif || null
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
        });

        return { status: 'rejected' };
    }

    // ==========================================
    // 2. CAS DE CONFIRMATION (ok === true)
    // ==========================================
    const [walletDoc, factureDoc] = await Promise.all([
        db.collection('wallets').doc(userId).get(),
        db.collection('factures').doc(factureId).get()
    ]);

    if (!walletDoc.exists) throw new HttpsError('not-found', 'Wallet inexistant');
    if (!factureDoc.exists) throw new HttpsError('not-found', 'Facture inexistante');

    const factureData = factureDoc.data();
    const montantWalletPrevu = factureData.montantWallet || 0;
    const totalAmount = parseFloat(factureData.totalNetUSD || factureData.montantTotal || 0);

    let walletDebits = null;
    if (montantWalletPrevu > 0) {
        const montantWalletFinal = parseFloat(montantWalletPrevu);
        // Récupération de la part locataire (frais de service) pour baser le plafond des promos (25%)
        const baseServiceFees = parseFloat(factureData.partLocataire || 0);
        
        walletDebits = calculateWalletDeduction(walletDoc.data(), montantWalletFinal, 0.25, baseServiceFees);
    }

    const isManuel = sourcePaiement === 'MANUEL';
    const paymentType = isManuel ? 'ACHAT_MANUEL' : 'ACHAT_CASH';

    await finalizeTransactionCore({
        userId,
        factureId,
        amount,
        type: paymentType,
        methodePaiementFinale: paymentType,
        propertyId,
        isHybrid: false,
        metadata: {
            adminId: verifiedAdminId,
            motif: motif || null,
            source: sourcePaiement || 'CASH',
            walletDebits: walletDebits
        }
    });

    return { status: 'success' };
});