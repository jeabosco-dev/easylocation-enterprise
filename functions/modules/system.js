// C:\Users\LANGE\easylocation_mvp\functions\modules\system.js
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { db, admin } = require('./admin');

/**
 * Nettoyage automatique des challenges expirés
 * S'exécute toutes les 60 minutes
 */
exports.checkExpiredCommunityGoals = onSchedule({
    schedule: 'every 60 minutes',
    region: 'europe-west1'
}, async (event) => {
    const now = new Date();

    try {
        const snapshot = await db.collection('community_goals')
            .where('statut', '==', 'en_cours')
            .where('deadline', '<', now)
            .get();

        if (snapshot.empty) {
            console.log('--- Aucun challenge expiré ---');
            return null;
        }

        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.update(doc.ref, { statut: 'expire' });
        });

        await batch.commit();
        console.log(`✅ ${snapshot.size} challenges marqués comme expirés.`);
        return null;
    } catch (error) {
        console.error("❌ Erreur maintenance challenges :", error);
        return null;
    }
});

/**
 * ✅ Mise à jour automatique des statistiques communautaires (Audit)
 * S'exécute chaque jour à minuit.
 */
exports.updateCommunityStats = onSchedule({
    schedule: '0 0 * * *',
    timeZone: 'Africa/Lubumbashi',
    region: 'europe-west1'
}, async (event) => {
    console.log('--- Début de la mise à jour des statistiques ---');

    try {
        // 1. Compter les locataires
        const locatairesSnapshot = await db.collection('utilisateurs')
            .where('role', '==', 'locataire')
            .count()
            .get();
        const totalLocataires = locatairesSnapshot.data().count;

        // 2. Compter les bailleurs
        const bailleursSnapshot = await db.collection('utilisateurs')
            .where('role', '==', 'bailleur')
            .count()
            .get();
        const totalBailleurs = bailleursSnapshot.data().count;

        // 3. Mettre à jour le document app_config
        await db.collection('settings').doc('app_config').update({
            'community_stats.total_locataires': totalLocataires,
            'community_stats.total_bailleurs': totalBailleurs,
            'community_stats.last_updated': admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`✅ Stats mises à jour : ${totalLocataires} locataires, ${totalBailleurs} bailleurs.`);
        return null;
    } catch (error) {
        console.error("❌ Erreur lors de la mise à jour des stats :", error);
        return null;
    }
});

/**
 * ✅ NOUVEAU : Reset quotidien des compteurs "ajouts_aujourdhui" par ville (Social Proof)
 * S'exécute chaque jour à minuit.
 */
exports.resetDailyCityStats = onSchedule({
    schedule: '0 0 * * *',
    timeZone: 'Africa/Lubumbashi',
    region: 'europe-west1'
}, async (event) => {
    console.log('--- Début du reset des statistiques journalières par ville ---');

    try {
        const snapshot = await db.collection('stats_locales').get();
        
        if (snapshot.empty) {
            console.log('--- Aucune statistique de ville à réinitialiser ---');
            return null;
        }

        const batch = db.batch();
        snapshot.docs.forEach(doc => {
            batch.update(doc.ref, { 
                ajouts_aujourdhui: 0,
                derniere_mise_a_jour: admin.firestore.FieldValue.serverTimestamp()
            });
        });

        await batch.commit();
        console.log(`✅ Reset terminé pour ${snapshot.size} villes.`);
        return null;
    } catch (error) {
        console.error("❌ Erreur resetDailyCityStats :", error);
        return null;
    }
});

/**
 * ✅ NOUVEAU : Nettoyage automatique des réservations Cash expirées
 * S'exécute toutes les 10 minutes.
 * Repasse le bien en disponible, expire la facture et recrédite le wallet si nécessaire.
 */
exports.cleanExpiredCashPayments = onSchedule({
    schedule: 'every 10 minutes',
    region: 'europe-west1'
}, async (event) => {
    const now = new Date();

    try {
        // 1. Récupérer toutes les factures cash en attente et expirées
        const expiredFacturesSnapshot = await db.collection('factures')
            .where('methodePaiement', '==', 'cash')
            .where('status', '==', 'pending')
            .where('dateExpiration', '<', now)
            .get();

        if (expiredFacturesSnapshot.empty) {
            console.log('--- [CRON] Aucune facture cash expirée à nettoyer ---');
            return null;
        }

        console.log(`=== [CRON] ${expiredFacturesSnapshot.size} facture(s) expirée(s) trouvée(s). Début du traitement... ===`);

        // 2. Traiter chaque facture de manière isolée via une transaction
        for (const factureDoc of expiredFacturesSnapshot.docs) {
            const factureData = factureDoc.data();
            const factureId = factureDoc.id;
            
            const clientUid = factureData.clientUid;
            const propertyId = factureData.propertyId;
            const montantWallet = Number(factureData.montantWallet || 0);

            const walletRef = db.collection('wallets').doc(clientUid);
            const bienRef = db.collection('proprietes').doc(propertyId);
            const factureRef = db.collection('factures').doc(factureId);

            try {
                await db.runTransaction(async (transaction) => {
                    const walletSnap = await transaction.get(walletRef);
                    const bienSnap = await transaction.get(bienRef);

                    if (!bienSnap.exists) {
                        console.error(`[CRON] Propriété ${propertyId} introuvable pour la facture ${factureId}`);
                    }

                    // A. Restitution des fonds sur le Wallet (si montantWallet > 0)
                    if (montantWallet > 0 && walletSnap.exists) {
                        const paidFromBonus = Number(factureData.details?.paidFromBonus || 0);
                        const paidFromBalance = Number(factureData.details?.paidFromBalance || (montantWallet - paidFromBonus));

                        transaction.update(walletRef, {
                            balance: admin.firestore.FieldValue.increment(paidFromBalance),
                            bonusBalance: admin.firestore.FieldValue.increment(paidFromBonus),
                            lastUpdate: admin.firestore.FieldValue.serverTimestamp()
                        });

                        // Générer la transaction d'annulation dans l'historique
                        const txRefundRef = db.collection('transactions').doc();
                        transaction.set(txRefundRef, {
                            walletId: clientUid,
                            userId: clientUid,
                            participants: [clientUid],
                            title: `Restitution acompte (Expiré - Réf: ${factureData.refBien || ""})`,
                            amount: montantWallet,
                            isPositive: true,
                            date: admin.firestore.FieldValue.serverTimestamp(),
                            type: 'cash_mixed_refund',
                            details: {
                                factureId: factureId,
                                refundedToBonus: paidFromBonus,
                                refundedToBalance: paidFromBalance
                            }
                        });
                    }

                    // B. Mettre à jour le statut de la facture vers 'expired'
                    transaction.update(factureRef, {
                        status: 'expired',
                        dateModification: admin.firestore.FieldValue.serverTimestamp()
                    });

                    // C. Libérer le bien immobilier
                    if (bienSnap.exists) {
                        transaction.update(bienRef, {
                            status: 'disponible'
                        });
                    }
                });

                console.log(`✅ Facture ${factureId} nettoyée avec succès. Bien ${propertyId} libérer.`);
            } catch (transactionError) {
                console.error(`❌ Échec de la transaction pour la facture ${factureId}:`, transactionError);
            }
        }

        console.log('=== [CRON] Fin du traitement de nettoyage Cash ===');
        return null;
    } catch (error) {
        console.error('❌ Erreur globale lors de l\'exécution du Cron Cash :', error);
        return null;
    }
});

/**
 * ✅ OPTIMISÉ : Nettoyage automatique du solde bonus expiré
 * S'exécute 1 fois par jour à 02h00 du matin (économique et suffisant).
 * Remet bonusBalance à 0 et réinitialise bonusExpiryDate dès que la date limite est atteinte.
 */
exports.cleanExpiredWelcomeBonus = onSchedule({
    schedule: '0 2 * * *',
    timeZone: 'Africa/Lubumbashi',
    region: 'europe-west1'
}, async (event) => {
    const now = new Date();

    try {
        const expiredWalletsSnapshot = await db.collection('wallets')
            .where('bonusBalance', '>', 0)
            .where('bonusExpiryDate', '<', now)
            .get();

        if (expiredWalletsSnapshot.empty) {
            console.log('--- [CRON BONUS] Aucun bonus expiré à nettoyer ---');
            return null;
        }

        console.log(`=== [CRON BONUS] ${expiredWalletsSnapshot.size} wallet(s) avec bonus expiré trouvé(s). ===`);

        for (const walletDoc of expiredWalletsSnapshot.docs) {
            const walletId = walletDoc.id;
            const walletData = walletDoc.data();
            const montantPerdu = Number(walletData.bonusBalance || 0);

            if (montantPerdu <= 0) continue;

            const walletRef = db.collection('wallets').doc(walletId);

            try {
                await db.runTransaction(async (transaction) => {
                    // A. Réinitialiser bonusBalance et bonusExpiryDate
                    transaction.update(walletRef, {
                        bonusBalance: 0.0,
                        bonusExpiryDate: null,
                        lastUpdate: admin.firestore.FieldValue.serverTimestamp()
                    });

                    // B. Historique dans les opérations du portefeuille
                    const historyRef = walletRef.collection('operations').doc();
                    transaction.set(historyRef, {
                        type: "EXPIRATION_BONUS",
                        montant: montantPerdu,
                        date: admin.firestore.FieldValue.serverTimestamp(),
                        description: `Expiration du solde bonus (${montantPerdu.toFixed(2)} USD)`
                    });

                    // C. Historique dans la collection globale des transactions
                    const txRef = db.collection('transactions').doc();
                    transaction.set(txRef, {
                        walletId: walletId,
                        userId: walletId,
                        participants: [walletId],
                        title: `Bonus expiré (${montantPerdu.toFixed(2)} \$)`,
                        amount: montantPerdu,
                        isPositive: false,
                        date: admin.firestore.FieldValue.serverTimestamp(),
                        type: 'bonus_expiration',
                        details: {
                            expiredAmount: montantPerdu
                        }
                    });
                });

                console.log(`✅ Bonus de ${montantPerdu}$ expiré et réinitialisé pour le wallet ${walletId}`);
            } catch (txError) {
                console.error(`❌ Échec de l'expiration du bonus pour ${walletId}:`, txError);
            }
        }

        return null;
    } catch (error) {
        console.error('❌ Erreur lors du nettoyage des bonus expirés :', error);
        return null;
    }
});