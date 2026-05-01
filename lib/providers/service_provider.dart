// lib/providers/service_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';
import '../constants/constants.dart';

class ServiceProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// 1. MÉTHODE CRITIQUE : Initialise la commande et calcule le prix réel
  Future<String?> creerCommandeInitial(ServiceModel service, List<dynamic> allUpsellServices) async {
    _isLoading = true;
    notifyListeners();

    try {
      double prixFinal = service.prix;
      bool isFinalPercentage = service.isPercentage;

      // Logique spécifique pour le PACK_SERENITE
      if (service.typeService == 'PACK_SERENITE') {
        // 1. On récupère les prix des services de base dans la config
        double prixNettoyage = _extrairePrix(allUpsellServices, 'NETTOYAGE');
        double prixPeinture = _extrairePrix(allUpsellServices, 'PEINTURE');
        double prixDemenagement = _extrairePrix(allUpsellServices, 'DEMENAGEMENT_GOLD');

        // 2. Calcul du total brut
        double totalBrut = prixNettoyage + prixPeinture + prixDemenagement;

        // 3. Application de la réduction (ex: 10% de 80$ = 8$ de réduction)
        // service.prix contient le taux (ex: 10) récupéré depuis Firebase
        double reduction = (totalBrut * service.prix) / 100;
        prixFinal = totalBrut - reduction; 

        // IMPORTANT : Une fois calculé, ce n'est plus un pourcentage mais un prix fixe en $
        isFinalPercentage = false;
      }

      // Préparation des données pour Firestore
      final Map<String, dynamic> commandeData = service.toMap();
      
      // Mise à jour avec les valeurs finales calculées
      commandeData['prix'] = prixFinal;
      commandeData['isPercentage'] = isFinalPercentage;
      commandeData['timestamp'] = FieldValue.serverTimestamp(); // Utilisation du temps serveur

      // Ajout à Firestore
      final docRef = await _db
          .collection(FirestoreCollections.services)
          .add(commandeData);
      
      _isLoading = false;
      notifyListeners();
      
      return docRef.id;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Erreur lors de l'initialisation du service : $e");
      return null;
    }
  }

  /// Fonction utilitaire pour trouver un prix dans la liste upsell_services de Firebase
  double _extrairePrix(List<dynamic> services, String type) {
    try {
      final s = services.firstWhere(
        (element) => element['id'] == type,
        orElse: () => {'prix': 0.0},
      );
      return (s['prix'] as num).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  /// 2. MÉTHODE ANCIENNE (Maintenue pour compatibilité)
  Future<bool> commanderService(ServiceModel service) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection(FirestoreCollections.services).add(service.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Erreur lors de la commande du service : $e");
      return false;
    }
  }

  /// 3. MÉTHODE POUR RÉCUPÉRER LES SERVICES D'UN LOCATAIRE
  Stream<List<ServiceModel>> getServicesByLocataire(String locataireId) {
    return _db
        .collection(FirestoreCollections.services)
        .where('locataireId', isEqualTo: locataireId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromFirestore(doc))
            .toList());
  }

  /// 4. MÉTHODE POUR L'ADMIN
  Stream<List<ServiceModel>> getAllServicesCommandes() {
    return _db
        .collection(FirestoreCollections.services)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromFirestore(doc))
            .toList());
  }

  /// 5. MÉTHODE POUR METTRE À JOUR LE STATUT
  Future<void> updateServiceStatut(String serviceId, String nouveauStatut) async {
    try {
      await _db.collection(FirestoreCollections.services).doc(serviceId).update({
        'statut': nouveauStatut,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erreur mise à jour statut service : $e");
    }
  }
}