// lib/models/partner_model.dart

class PartnerModel {
  final String id;
  final String nom;
  final String type;
  final double commissionRate;
  final double soldeCommission;
  final int totalConversions;
  final bool isActive;

  PartnerModel({
    required this.id,
    required this.nom,
    required this.type,
    required this.commissionRate,
    required this.soldeCommission,
    required this.totalConversions,
    required this.isActive,
  });

  // ✅ Conversion de Firestore vers l'objet Dart (Lecture)
  factory PartnerModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return PartnerModel(
      id: documentId,
      nom: data['nom'] ?? '',
      type: data['type'] ?? 'Autre',
      // Harmonisation avec les noms snake_case de votre console Firebase
      commissionRate: (data['commission_rate'] ?? 0.05).toDouble(),
      soldeCommission: (data['solde_commission'] ?? 0.0).toDouble(),
      totalConversions: (data['total_conversions'] ?? 0).toInt(),
      isActive: data['is_active'] ?? true,
    );
  }

  // ✅ Conversion de l'objet Dart vers Firestore (Écriture)
  // Indispensable pour que vos updates depuis l'admin utilisent les bons noms de champs
  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'type': type,
      'commission_rate': commissionRate,
      'solde_commission': soldeCommission,
      'total_conversions': totalConversions,
      'is_active': isActive,
    };
  }
}