// lib/providers/service_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';
import 'user_profile_provider.dart'; // 👈 Import nécessaire pour récupérer le profil et la géolocalisation
import 'package:easylocation_mvp/constants/all_constants.dart';

class ServiceProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// 1. MÉTHODE CRITIQUE : Initialise la commande et calcule le prix réel tout en injectant la géolocalisation
  Future<String?> creerCommandeInitial(
    ServiceModel service, 
    List<dynamic> allUpsellServices, {
    UserProfileProvider? userProfileProvider, // 👈 Optionnel : pour capter la vraie localisation
  }) async {
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

        // 3. Application de la réduction
        double reduction = (totalBrut * service.prix) / 100;
        prixFinal = totalBrut - reduction; 

        // IMPORTANT : Une fois calculé, ce n'est plus un pourcentage mais un prix fixe en $
        isFinalPercentage = false;
      }

      // Préparation des données pour Firestore
      final Map<String, dynamic> commandeData = service.toMap();
      
      // Récupération de la vraie localisation depuis l'utilisateur connecté si disponible
      final userModel = userProfileProvider?.userData;
      
      // ✅ Injection de la VRAIE géolocalisation de l'utilisateur (avec repli de sécurité)
      commandeData['province'] = userModel?.province ?? 'Sud-Kivu';
      commandeData['ville'] = userModel?.ville ?? 'Bukavu';
      commandeData['commune'] = userModel?.commune ?? '';

      // Mise à jour avec les valeurs finales calculées et les champs d'éligibilité promo
      commandeData['prix'] = prixFinal;
      commandeData['isPercentage'] = isFinalPercentage;
      commandeData['timestamp'] = FieldValue.serverTimestamp(); // Utilisation du temps serveur

      // Normalisation des champs pour correspondre aux critères du FactureModel / PromotionValidationService
      final serviceId = (service.typeService).trim().toUpperCase();
      commandeData[FactureFields.typeService] = serviceId;
      commandeData['serviceEligible'] = serviceId;
      commandeData['categorieBien'] = serviceId;
      commandeData['categorieEligible'] = serviceId;

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
    if (locataireId.isEmpty) {
      return const Stream.empty();
    }

    return _db
        .collection(FirestoreCollections.services)
        .where('locataireId', isEqualTo: locataireId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((e) {
          debugPrint("ServiceProvider (getServicesByLocataire) Error: $e");
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromFirestore(doc))
            .toList());
  }

  /// 4. MÉTHODE POUR L'ADMIN (Écoute la collection centralisée 'factures' des services)
  Stream<List<ServiceModel>> getAllServicesCommandes() {
    return _db
        .collection('factures') // 👈 On écoute la collection centralisée des factures
        .where('propertyId', isEqualTo: 'SERVICE') // 👈 On filtre uniquement sur les services annexes
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .handleError((e) {
          debugPrint("ServiceProvider (getAllServicesCommandes) Error: $e");
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromFactureFirestore(doc)) // 👈 Utilisation du factory de conversion adapté
            .toList());
  }

  /// 5. MÉTHODE POUR METTRE À JOUR LE STATUT (Cible la collection 'factures')
  Future<void> updateServiceStatut(String serviceId, String nouveauStatut) async {
    try {
      await _db.collection('factures').doc(serviceId).update({
        'paymentStatus': nouveauStatut == 'PAYE' ? 'paid' : nouveauStatut.toLowerCase(),
        'statut': nouveauStatut, // Pour compatibilité si le champ est présent
        'dateUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erreur mise à jour statut service : $e");
    }
  }
}