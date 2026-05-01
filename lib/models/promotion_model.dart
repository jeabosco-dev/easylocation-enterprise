// lib/models/promotion_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum PromoType { pourcentage, montantFixe }
enum PromoTarget { commission, total, demenagement, easyCredit }

class PromotionModel {
  final String id;
  final String titre;         // Ex: "Lancement Goma"
  final String description;   // Ex: "-50% pour les 100 premiers locataires"
  final String code;          // Ex: "GOMA2026"
  final PromoType type;
  final PromoTarget target;
  final double valeur;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String statut;        // 'actif' ou 'inactif'
  
  // ✅ Liste des villes autorisées (Expansion RDC)
  final List<String>? villes; 

  // Champs pour la stratégie "Premier Arrivé"
  final int usageLimit;       // Nombre total de places disponibles
  final int usageCount;       // Nombre de places déjà consommées

  PromotionModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.code,
    required this.type,
    required this.target,
    required this.valeur,
    required this.dateDebut,
    required this.dateFin,
    required this.statut,
    this.villes,
    this.usageLimit = 0,      // 0 = illimité
    this.usageCount = 0,
  });

  /// ✅ LOGIQUE : Vérifie si la promo est valide (Dates + Statut + Stock)
  bool get isValid {
    final maintenant = DateTime.now();
    
    // 1. Vérification du statut
    bool statutActif = statut == 'actif';
    
    // 2. Vérification de la période
    bool periodeValide = maintenant.isAfter(dateDebut) && maintenant.isBefore(dateFin);
    
    // 3. Vérification des places disponibles (si une limite est définie)
    bool resteDesPlaces = usageLimit > 0 ? (usageCount < usageLimit) : true;

    return statutActif && periodeValide && resteDesPlaces;
  }

  /// ✅ LOGIQUE : Vérifie si la ville du client est autorisée
  bool estVilleAutorisee(String villeClient) {
    // Si la liste est nulle ou vide, on considère que c'est National (ouvert à tous)
    if (villes == null || villes!.isEmpty) return true;
    
    // On compare en minuscules pour éviter les erreurs de saisie/casse
    return villes!.any((v) => v.toLowerCase().trim() == villeClient.toLowerCase().trim());
  }

  /// Calcule le montant de la remise à déduire
  double calculerRemise(double montantBase) {
    if (type == PromoType.pourcentage) {
      return montantBase * (valeur / 100);
    } else {
      // Pour montantFixe, on ne peut pas donner une remise supérieure au prix
      return valeur > montantBase ? montantBase : valeur;
    }
  }

  /// Conversion des données Firestore vers le Modèle
  factory PromotionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PromotionModel(
      id: doc.id,
      titre: data['titre'] ?? '',
      description: data['description'] ?? '',
      code: data['code'] ?? '',
      type: data['type'] == 'pourcentage' 
          ? PromoType.pourcentage 
          : PromoType.montantFixe,
      target: _parseTarget(data['target']),
      valeur: (data['valeur'] as num).toDouble(),
      dateDebut: (data['date_debut'] as Timestamp).toDate(),
      dateFin: (data['date_fin'] as Timestamp).toDate(),
      statut: data['statut'] ?? 'inactif',
      // Récupération de la liste des villes
      villes: data['villes'] != null ? List<String>.from(data['villes']) : null,
      usageLimit: data['usage_limit'] ?? 0,
      usageCount: data['usage_count'] ?? 0,
    );
  }

  /// Helper interne pour mapper le target proprement
  static PromoTarget _parseTarget(String? target) {
    switch (target) {
      case 'easyCredit':
        return PromoTarget.easyCredit;
      case 'total':
        return PromoTarget.total;
      case 'demenagement':
        return PromoTarget.demenagement;
      default:
        return PromoTarget.commission;
    }
  }
}