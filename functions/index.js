/**
 * POINT D'ENTRÉE UNIQUE - EasyLocation Cloud Functions
 */
const admin = require('firebase-admin');

if (admin.apps.length === 0) {
    admin.initializeApp();
}

const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({ region: "europe-west1" });

// --- MODULE : ADMINISTRATEURS & BACKOFFICE ---
const adminModule = require('./modules/admin');
exports.creerAgentEquipe = adminModule.creerAgentEquipe;

// --- MODULE : UTILISATEURS & WALLETS ---
const users = require('./modules/users');
exports.onUserCreatedInitializeWallet = users.onUserCreatedInitializeWallet;
exports.onUserRoleUpdated = users.onUserRoleUpdated;
exports.onUserRegisteredLinkContract = users.onUserRegisteredLinkContract;

// --- MODULE : ANALYTICS & FINANCE ---
const finance = require('./modules/finance');
exports.onWalletWrittenUpdateStats = finance.onWalletWrittenUpdateStats;

// --- MODULE : CONTRATS ---
const contracts = require('./modules/contracts');
exports.quickOnboarding = contracts.quickOnboarding;
exports.prolongerBail = contracts.prolongerBail;
exports.cloturerBail = contracts.cloturerBail;
exports.onContractCreated = contracts.onContractCreated;
exports.onFactureValidated = contracts.onFactureValidated;

// --- MODULE : PAIEMENTS ---
const payments = require('./modules/payments');
const paymentsHybrid = require('./modules/payments_hybrid');
const manualPayments = require('./modules/manual_payments');

exports.generateMaxicashUrl = payments.generateMaxicashUrl;
exports.maxicashWebhook = payments.maxicashWebhook;
exports.onPaymentStatusUpdated = payments.onPaymentStatusUpdated;
exports.onFactureClotureeReward = payments.onFactureClotureeReward; 
// Ajout de la fonction manquante pour le déclenchement de la réservation
exports.onFactureReserved = payments.onFactureReserved; 

// Ajout pour la validation manuelle
exports.finalizeManualPayment = manualPayments.finalizeManualPayment;

// Ajouts pour éviter la suppression par Firebase :
exports.initiateHybridPayment = paymentsHybrid.initiateHybridPayment;
exports.initiateStandardPayment = paymentsHybrid.initiateStandardPayment;
exports.transferCredits = paymentsHybrid.transferCredits;
exports.annulerReservationEtRembourser = paymentsHybrid.annulerReservationEtRembourser;
exports.sendCreditsFromPartner = paymentsHybrid.sendCreditsFromPartner;

// --- MODULE : RETRAITS UTILISATEURS ---
const withdrawals = require('./modules/withdrawals');
exports.processWithdrawal = withdrawals.processWithdrawal;
// FONCTIONS AJOUTÉES :
exports.confirmWithdrawal = withdrawals.confirmWithdrawal;
exports.rejectWithdrawal = withdrawals.rejectWithdrawal;

// --- MODULE : PARRAINAGE ---
const referrals = require('./modules/referrals');
exports.onContractFinalizedRewardPartner = referrals.onContractFinalizedRewardPartner;

// --- MODULE : PROPRIÉTÉS ---
const properties = require('./modules/properties');
exports.onNewPropertyCreated = properties.onNewPropertyCreated;
exports.onVipAlertePaidTriggerSearch = properties.onVipAlertePaidTriggerSearch;
exports.onPaiementDeclare = properties.onPaiementDeclare;
exports.onPropertyStatusChangedUpdateStats = properties.onPropertyStatusChangedUpdateStats;
exports.onPropertyUpdated = properties.onPropertyUpdated;
exports.onVisitFinishedNotifyLocataire = properties.onVisitFinishedNotifyLocataire;
// Ajout de l'agrégation des notes
exports.aggregateRatings = properties.aggregateRatings;

// --- MODULE : SERVICES ---
const services = require('./modules/services');
exports.sentryWebhook = services.sentryWebhook;
exports.sendSupportEmail = services.sendSupportEmail;
exports.getGeminiResponse = services.getGeminiResponse;
exports.onRefundPaidNotifyLocataire = services.onRefundPaidNotifyLocataire;
exports.onVisitRequestUpdated = services.onVisitRequestUpdated;
exports.sendNotification = services.sendNotification; 

// --- MODULE : MAINTENANCE ---
const system = require('./modules/system');
exports.checkExpiredCommunityGoals = system.checkExpiredCommunityGoals;
exports.updateCommunityStats = system.updateCommunityStats;
exports.resetDailyCityStats = system.resetDailyCityStats;
exports.cleanExpiredCashPayments = system.cleanExpiredCashPayments;