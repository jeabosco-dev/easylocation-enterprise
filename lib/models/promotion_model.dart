// lib/models/promotion_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum PromoType { pourcentage, montantFixe }
enum PromoBeneficiaire { tous, locataire, bailleur, partenaire, prestataire }

class PromotionModel {
  final String id;
  final String titre;
  final String description;
  final String code;
  final PromoType type;
  final PromoBeneficiaire beneficiaire;
  
  final double valeur;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String statut; // 'actif' ou 'inactif'
  
  // ✅ Nouvelle structure : Listes pour permettre sélections multiples
  final List<String> provinces;
  final List<String> villes;
  final List<String> communes;
  final List<String> servicesEligibles;
  final List<String> categoriesEligibles;

  // Champs pour la stratégie "Premier Arrivé"
  final int usageLimit; // 0 = illimité
  final int usageCount;

  PromotionModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.code,
    required this.type,
    required this.beneficiaire,
    required this.valeur,
    required this.dateDebut,
    required this.dateFin,
    required this.statut,
    required this.provinces,
    required this.villes,
    required this.communes,
    required this.servicesEligibles,
    required this.categoriesEligibles,
    this.usageLimit = 0,
    this.usageCount = 0,
  });

  // --- LOGIQUE MÉTIER AJOUTÉE ---

  /// Getter pour vérifier si la promo est valide (dates, statut, limites)
  bool get isValid {
    final now = DateTime.now();
    return statut == 'actif' && 
           now.isAfter(dateDebut) && 
           now.isBefore(dateFin) &&
           (usageLimit == 0 || usageCount < usageLimit);
  }

  /// Vérifie si une zone donnée est éligible à cette promotion
  bool estZoneAutorisee(String province, String ville, String commune) {
    bool pOk = provinces.isEmpty || provinces.contains(province);
    bool vOk = villes.isEmpty || villes.contains(ville);
    bool cOk = communes.isEmpty || communes.contains(commune);
    return pOk && vOk && cOk;
  }

  /// Calcule la remise applicable sur un montant donné
  double calculerRemise(double montantBase) {
    if (type == PromoType.pourcentage) {
      return (montantBase * valeur) / 100;
    } else {
      return valeur; // Montant fixe
    }
  }

  // --- MÉTHODES DE MAPPING ---

  /// Copie avec modification
  PromotionModel copyWith({
    String? id,
    String? titre,
    String? description,
    String? code,
    PromoType? type,
    PromoBeneficiaire? beneficiaire,
    double? valeur,
    DateTime? dateDebut,
    DateTime? dateFin,
    String? statut,
    List<String>? provinces,
    List<String>? villes,
    List<String>? communes,
    List<String>? servicesEligibles,
    List<String>? categoriesEligibles,
    int? usageLimit,
    int? usageCount,
  }) {
    return PromotionModel(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      code: code ?? this.code,
      type: type ?? this.type,
      beneficiaire: beneficiaire ?? this.beneficiaire,
      valeur: valeur ?? this.valeur,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      statut: statut ?? this.statut,
      provinces: provinces ?? this.provinces,
      villes: villes ?? this.villes,
      communes: communes ?? this.communes,
      servicesEligibles: servicesEligibles ?? this.servicesEligibles,
      categoriesEligibles: categoriesEligibles ?? this.categoriesEligibles,
      usageLimit: usageLimit ?? this.usageLimit,
      usageCount: usageCount ?? this.usageCount,
    );
  }

  /// Conversion vers Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'description': description,
      'code': code,
      'type': type.name,
      'beneficiaire': beneficiaire.name,
      'valeur': valeur,
      'date_debut': Timestamp.fromDate(dateDebut),
      'date_fin': Timestamp.fromDate(dateFin),
      'statut': statut,
      'provinces': provinces,
      'villes': villes,
      'communes': communes,
      'servicesEligibles': servicesEligibles,
      'categoriesEligibles': categoriesEligibles,
      'usage_limit': usageLimit,
      'usage_count': usageCount,
    };
  }

  /// Factory depuis Firestore
  factory PromotionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PromotionModel(
      id: doc.id,
      titre: data['titre'] ?? '',
      description: data['description'] ?? '',
      code: data['code'] ?? '',
      type: data['type'] == 'pourcentage' ? PromoType.pourcentage : PromoType.montantFixe,
      beneficiaire: parseBeneficiaire(data['beneficiaire']),
      valeur: (data['valeur'] as num).toDouble(),
      dateDebut: (data['date_debut'] as Timestamp).toDate(),
      dateFin: (data['date_fin'] as Timestamp).toDate(),
      statut: data['statut'] ?? 'inactif',
      provinces: List<String>.from(data['provinces'] ?? []),
      villes: List<String>.from(data['villes'] ?? []),
      communes: List<String>.from(data['communes'] ?? []),
      servicesEligibles: List<String>.from(data['servicesEligibles'] ?? []),
      categoriesEligibles: List<String>.from(data['categoriesEligibles'] ?? []),
      usageLimit: data['usage_limit'] ?? 0,
      usageCount: data['usage_count'] ?? 0,
    );
  }

  static PromoBeneficiaire parseBeneficiaire(String? b) {
    try {
      return PromoBeneficiaire.values.firstWhere((e) => e.name == b);
    } catch (_) {
      return PromoBeneficiaire.tous;
    }
  }
}