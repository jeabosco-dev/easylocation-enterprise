// lib/providers/contract_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; 
import 'package:intl/intl.dart';
import '../models/contract_model.dart';
import '../models/payment_model.dart'; 
import '../services/config_service.dart';
import 'package:easylocation_mvp/utils/phone_utils.dart'; 

class ContractProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  
  ContractModel? _locataireActiveContract; 
  bool _isLoading = false;
  List<ContractModel> _bailleurContracts = [];
  List<ContractModel> _allContracts = []; 
  int _totalAlertes = 0;

  // Getters
  ContractModel? get locataireActiveContract => _locataireActiveContract;
  bool get isLoading => _isLoading;
  List<ContractModel> get bailleurContracts => _bailleurContracts;
  List<ContractModel> get allContracts => _allContracts;
  int get totalAlertes => _totalAlertes;
  
  // Alias pour la compatibilité avec vos écrans existants
  ContractModel? get activeContract => _locataireActiveContract;

  // ==========================================================
  // 1. GESTION DES JOURNAUX & MIGRATION
  // ==========================================================

  Future<bool> updateJournalDetails({
    required String contractId,
    required String ville,
    required String commune,
    required String quartier,
    required String avenue,
    required String numeroMaison,
    required double loyer,
    required DateTime startDate,
    required DateTime endDate,
    String? nomLocataire,
    String? telLocataire,
    String? nomBailleur,
    String? telBailleur,
    String? adresseComplete,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final String adresse = adresseComplete ?? "$numeroMaison $avenue, $quartier, $commune, $ville";

      Map<String, dynamic> updates = {
        'refMaison': adresse,
        'loyerMensuel': loyer,
        'ville': ville,
        'commune': commune,
        'quartier': quartier,
        'avenue': avenue,
        'numMaison': numeroMaison,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nomLocataire != null) updates['locataireNom'] = nomLocataire;
      if (telLocataire != null) updates['locataireTel'] = normalizePhoneNumber(telLocataire);
      if (nomBailleur != null) updates['bailleurNom'] = nomBailleur;
      if (telBailleur != null) updates['bailleurTel'] = normalizePhoneNumber(telBailleur);

      await _db.collection('contrats').doc(contractId).update(updates);
      await loadAllActiveContractsForAdmin();
      
      return true;
    } catch (e) {
      debugPrint("Erreur updateJournalDetails: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> importerContratExistant({
    required String bailleurId, // Ici on reçoit l'UID Firebase du bailleur
    required Map<String, dynamic> data,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      // CORRECTION : On utilise l'UID brut (bailleurId) au lieu de normaliser
      final String locatTel = normalizePhoneNumber(data['locataireTel'] ?? "");
      final String adresseComplete = "${data['numMaison'] ?? ''} ${data['avenue'] ?? ''}, ${data['quartier'] ?? ''}, ${data['commune'] ?? ''}, ${data['ville'] ?? ''}";

      DocumentReference propRef = await _db.collection('proprietes').add({
        'adresseComplete': adresseComplete,
        'bailleurId': bailleurId, 
        'loyerMensuel': data['loyer'],
        'status': 'louée',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('contrats').add({
        'propertyId': propRef.id,
        'refMaison': adresseComplete,
        'bailleurId': bailleurId, 
        'locataireNom': data['locataireNom'],
        'locataireTel': locatTel,
        'loyerMensuel': data['loyer'],
        'statut': 'actif', 
        'startDate': Timestamp.fromDate(data['startDate'] ?? DateTime.now()),
        'endDate': Timestamp.fromDate((data['startDate'] ?? DateTime.now()).add(const Duration(days: 365))),
        'prochainPaiement': Timestamp.fromDate(DateTime.now()), 
        'createdAt': FieldValue.serverTimestamp(),
        'ville': data['ville'],
        'commune': data['commune'],
        'quartier': data['quartier'],
        'avenue': data['avenue'],
        'numMaison': data['numMaison'],
      });
      
      // CORRECTION : On utilise l'UID brut pour rafraîchir
      await listenToBailleurContracts(bailleurId);
      return true;
    } catch (e) {
      debugPrint("Erreur importerContratExistant: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ... (Garder les autres méthodes inchangées jusqu'à listenToBailleurContracts)

  /// Écoute les contrats en tant que BAILLEUR
  Future<void> listenToBailleurContracts(String uid) async {
    _isLoading = true;
    notifyListeners();
    
    // CORRECTION : Suppression de la normalisation. On utilise l'UID brut.
    try {
      final snapshot = await _db.collection('contrats')
          .where('bailleurId', isEqualTo: uid)
          .where('statut', isEqualTo: 'actif')
          .get();
          
      _bailleurContracts = snapshot.docs.map((doc) => ContractModel.fromMap(doc.data(), doc.id)).toList();
      
      print("DEBUG: Contrats trouvés pour le bailleur $uid : ${_bailleurContracts.length}");
    } catch (e) {
      print("⚠️ Erreur lors du chargement bailleur : $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ... (Reste du fichier inchangé)
  Future<void> activerJournalLocation({
    required String adresse,
    required String nomBailleur,
    required String telBailleur,
    required double loyer,
    required String locataireId,
    required DateTime startDate,
    required DateTime endDate,
    String? ville,
    String? commune,
    String? quartier,
    String? avenue,
    String? numeroMaison,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('contrats').add({
        'refMaison': adresse, 
        'bailleurNom': nomBailleur, 
        'bailleurTel': normalizePhoneNumber(telBailleur),
        'loyerMensuel': loyer,
        'locataireId': normalizePhoneNumber(locataireId),
        'locataireNom': 'Mon Journal', 
        'statut': 'actif', 
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate), 
        'prochainPaiement': Timestamp.fromDate(startDate), 
        'typeContrat': 'journal_perso', 
        'createdAt': FieldValue.serverTimestamp(),
        'ville': ville,
        'commune': commune,
        'quartier': quartier,
        'avenue': avenue,
        'numMaison': numeroMaison,
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<PaymentModel>> getPaymentHistory(String contratId) async {
    try {
      final snapshot = await _db.collection('contrats')
          .doc(contratId)
          .collection('historique_paiements')
          .orderBy('datePaiement', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => PaymentModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint("Erreur getPaymentHistory: $e");
      return [];
    }
  }

  Future<void> declarerPaiementHorsApp({
    required String contratId,
    required double montantVerse,
    required String modePaiement, 
    required DateTime datePaiement,
    String? preuvePhotoUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final docRef = _db.collection('contrats').doc(contratId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) throw "Le contrat n'existe pas.";

      final data = docSnap.data()!;
      final double loyerMensuel = (data['loyerMensuel'] ?? 0).toDouble();
      final double soldeActuel = (data['soldeActuel'] ?? 0).toDouble();
      final DateTime prochainPaiementActuel = (data['prochainPaiement'] as Timestamp).toDate();

      double nouveauSolde = soldeActuel + montantVerse;
      int moisAGagner = 0;

      while (nouveauSolde >= loyerMensuel && loyerMensuel > 0) {
        nouveauSolde -= loyerMensuel;
        moisAGagner++;
      }

      DateTime nouvelleDateEcheance = prochainPaiementActuel;
      if (moisAGagner > 0) {
        int totalMonths = prochainPaiementActuel.month + moisAGagner;
        int newYear = prochainPaiementActuel.year + (totalMonths - 1) ~/ 12;
        int newMonth = (totalMonths - 1) % 12 + 1;
        
        int newDay = prochainPaiementActuel.day;
        int lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        if (newDay > lastDayOfNewMonth) newDay = lastDayOfNewMonth;

        nouvelleDateEcheance = DateTime(newYear, newMonth, newDay);
      }

      await docRef.collection('historique_paiements').add({
        'montant': montantVerse,
        'datePaiement': Timestamp.fromDate(datePaiement),
        'modePaiement': modePaiement,
        'statut': 'validé',
        'preuvePhoto': preuvePhotoUrl,
        'soldeApresPaiement': nouveauSolde,
        'type': 'loyer',
        'nbMoisPayes': moisAGagner,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await docRef.update({
        'soldeActuel': nouveauSolde,
        'prochainPaiement': Timestamp.fromDate(nouvelleDateEcheance),
        'lastPaymentDate': Timestamp.fromDate(datePaiement),
        'dernierNombreMoisPayes': moisAGagner, 
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> creerDemandePaiement({
    required String contratId,
    required int nbMois,
    String? reference,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final docSnap = await _db.collection('contrats').doc(contratId).get();
      if (!docSnap.exists) throw "Le contrat n'existe pas.";
      final data = docSnap.data()!;
      final double loyer = (data['loyerMensuel'] ?? 0).toDouble();

      await _db.collection('transactions').add({
        'contratId': contratId,
        'locataireId': data['locataireId'],
        'bailleurId': data['bailleurId'],
        'montantTotal': loyer * nbMois,
        'nbMois': nbMois,
        'reference': reference ?? "Paiement Cash",
        'statut': 'en_attente', 
        'dateCreation': FieldValue.serverTimestamp(),
        'type': 'loyer',
      });

      await _db.collection('contrats').doc(contratId).update({
        'enAttenteValidation': true,
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cloturerBail(String contratId, String propertyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _functions.httpsCallable('cloturerBail').call({
        'contractId': contratId,
        'propertyId': propertyId, 
      });
      if (result.data['success'] == true) {
        _bailleurContracts.removeWhere((c) => c.id == contratId);
        _allContracts.removeWhere((c) => c.id == contratId);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> prolongerBail(String contratId, int nombreDeMois) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _functions.httpsCallable('prolongerBail').call({
        'contractId': contratId,
        'nbMois': nombreDeMois,
      });
      if (result.data['success'] == true) {
        await _db.collection('contrats').doc(contratId).update({
          'enAttenteValidation': false,
        });
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateContractStartDate(String contratId, DateTime newStartDate) async {
    _isLoading = true;
    notifyListeners();
    try {
      final docRef = _db.collection('contrats').doc(contratId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return false;
      
      final data = docSnap.data()!;
      final DateTime oldStart = (data['startDate'] as Timestamp).toDate();
      final DateTime oldEnd = (data['endDate'] as Timestamp).toDate();
      
      int dureeMois = ((oldEnd.year - oldStart.year) * 12) + (oldEnd.month - oldStart.month);
      DateTime newEndDate = DateTime(newStartDate.year, newStartDate.month + dureeMois, newStartDate.day);

      await docRef.update({
        'startDate': Timestamp.fromDate(newStartDate),
        'endDate': Timestamp.fromDate(newEndDate),
        'prochainPaiement': Timestamp.fromDate(newStartDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await loadAllActiveContractsForAdmin(); 
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> accepterContrat(String contratId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('contrats').doc(contratId).update({
        'statut': 'actif', 
        'dateConfirmationLocataire': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) { return false; }
    finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> demanderSortie(String contractId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('contrats').doc(contractId).update({
        'demandeSortie': true,
        'dateDemandeSortie': FieldValue.serverTimestamp(),
      });
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<bool> updateRappels({
    required String contractId,
    required bool pushEnabled,
    required bool smsEnabled,
    required int frequenceJours,
    required int rappelFinBailMois,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('contrats').doc(contractId).update({
        'notifications.pushActive': pushEnabled,
        'notifications.smsActive': smsEnabled,
        'notifications.frequenceJours': frequenceJours,
        'notifications.rappelFinBailMois': rappelFinBailMois,
      });
      return true;
    } catch (e) { return false; }
    finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> loadAllActiveContractsForAdmin() async {
    _isLoading = true;
    notifyListeners();
    try {
      final snapshot = await _db.collection('contrats').where('statut', isEqualTo: 'actif').get();
      _allContracts = snapshot.docs.map((doc) => ContractModel.fromMap(doc.data(), doc.id)).toList();
      _totalAlertes = _allContracts.where((c) => c.joursRestantsLoyer <= 60).length;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> listenToLocataireContracts(String uid) async {
    _isLoading = true;
    notifyListeners();
    
    print("DEBUG: Tentative de chargement contrat locataire pour UID: $uid");

    try {
      final snapshot = await _db.collection('contrats')
          .where('locataireId', isEqualTo: uid)
          .where('statut', isEqualTo: 'actif')
          .get();

      if (snapshot.docs.isNotEmpty) {
        _locataireActiveContract = ContractModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
        print("✅ Contrat locataire trouvé !");
      } else {
        _locataireActiveContract = null;
        print("❌ Aucun contrat actif trouvé pour cet UID de locataire.");
      }
    } catch (e) {
      print("⚠️ Erreur lors du chargement locataire : $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkAndGenerateInvoice(String uid, dynamic contract, dynamic config) async {
    debugPrint("ℹ️ checkAndGenerateInvoice appelé.");
  }
}