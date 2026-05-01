import 'package:cloud_firestore/cloud_firestore.dart';
import 'facture_model.dart'; 

class ContractModel {
  final String id;
  final String? factureId; 
  final String locataireId;
  final String locataireNom;
  final String? locatairePostnom; 
  final String? locatairePrenom;    
  final String? locataireTel; 
  final String bailleurId;
  final String? nomBailleur; 
  final String? bailleurTel;
  final String refMaison;
  final String? propertyId;
  final double loyerMensuel;
  final int nbMoisGarantie;

  // ✅ PILIER 1 : LES DATES CLÉS (Harmonisation)
  final DateTime startDate;          // Prise d'effet (Date début bail)
  final DateTime endDate;            // Fin du contrat (Date théorique de fin de bail)
  final DateTime prochainPaiement;   // Date d'expiration (Fin de validité du loyer payé)

  // ✅ PILIER 2 : PROLONGATION & HISTORIQUE
  final int dernierNombreMoisPayes;  // ex: 3 (pour afficher "+3 mois")
  final DateTime? dateDernierPaiement; // Date à laquelle l'argent a été versé

  final String status;
  final String statutPaiement;
  final bool enAttenteValidation;
  final String? typeContrat; // 'journal_perso' ou null

  // ✅ LOGIQUE DE SOLDE & FLEXIBILITÉ
  final double soldeActuel; // Positif = Avance, Négatif = Dette/Arriéré
  final List<String> documentsUrls; // Scans des reçus papier ou preuves de paiement

  // ✅ PILIER 3 : ANTICIPATION & RAPPELS
  final Map<String, dynamic>? notifications;
  final bool notificationsActives;
  final int rappelFinBailMois;
  final int rappelPaiementJours;

  // --- Champs Localisation ---
  final String? ville;
  final String? commune;
  final String? quartier;
  final String? avenue;
  final String? numeroMaison;
  final String? province;

  ContractModel({
    required this.id,
    this.factureId,
    required this.locataireId,
    required this.locataireNom,
    this.locatairePostnom,
    this.locatairePrenom,
    this.locataireTel,
    required this.bailleurId,
    this.nomBailleur,
    this.bailleurTel,
    required this.refMaison,
    this.propertyId,
    required this.loyerMensuel,
    this.nbMoisGarantie = 3, 
    required this.startDate,
    required this.endDate,
    required this.prochainPaiement,
    this.dernierNombreMoisPayes = 0,
    this.dateDernierPaiement,
    required this.status,
    this.statutPaiement = 'paye',
    this.enAttenteValidation = false,
    this.typeContrat,
    this.soldeActuel = 0.0,
    this.documentsUrls = const [],
    this.notifications,
    this.notificationsActives = true,
    this.rappelFinBailMois = 2,
    this.rappelPaiementJours = 3,
    this.ville,
    this.commune,
    this.quartier,
    this.avenue,
    this.numeroMaison,
    this.province,
  });

  // ✅ GETTERS LOGIQUES POUR L'UI
  String? get bailleurNom => nomBailleur;
  bool get aUneDette => soldeActuel < 0;
  bool get aUneAvance => soldeActuel > 0;
  double get montantDette => aUneDette ? soldeActuel.abs() : 0.0;

  // Retourne le jour anniversaire du paiement (basé sur la prise d'effet)
  int get jourEcheance => startDate.day;

  // Formattage intelligent de l'adresse
  String get adresseComplete {
    List<String> parts = [];
    if (numeroMaison != null && numeroMaison!.isNotEmpty) parts.add("N° $numeroMaison");
    if (avenue != null && avenue!.isNotEmpty) parts.add("Ave $avenue");
    if (quartier != null && quartier!.isNotEmpty) parts.add("Q. $quartier");
    if (commune != null && commune!.isNotEmpty) parts.add("Com. $commune");
    if (ville != null && ville!.isNotEmpty) parts.add(ville!);
    
    return parts.isEmpty ? (refMaison.isNotEmpty ? refMaison : "Adresse non renseignée") : parts.join(", ");
  }

  // ✅ ALIAS POUR LA COMPATIBILITÉ UI (Résout tes erreurs de compilation)
  int get joursRestants => joursRestantsLoyer;

  // Calcul des jours restants avant expiration du loyer (Critique pour le locataire)
  int get joursRestantsLoyer {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(prochainPaiement.year, prochainPaiement.month, prochainPaiement.day);
    return expiry.difference(today).inDays;
  }

  // Calcul de la durée contractuelle formatée
  String get dureeMoyenne {
    final difference = endDate.difference(startDate).inDays;
    final mois = (difference / 30.44).toStringAsFixed(1);
    return "$mois mois";
  }

  int get dureeTotaleMois {
    return ((endDate.year - startDate.year) * 12) + (endDate.month - startDate.month);
  }

  factory ContractModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ContractModel(
      id: documentId,
      factureId: data['factureId'],
      locataireId: data['locataireId'] ?? '',
      locataireNom: data['locataireNom'] ?? 'Locataire',
      locatairePostnom: data['locatairePostnom'], 
      locatairePrenom: data['locatairePrenom'],   
      locataireTel: data['locataireTel'], 
      bailleurId: data['bailleurId'] ?? '',
      nomBailleur: data['nomBailleur'],
      bailleurTel: data['bailleurTel'],
      propertyId: data['propertyId'],
      refMaison: data['refMaison'] ?? data['propertyId'] ?? '', 
      loyerMensuel: (data['loyerMensuel'] ?? data['montantLoyer'] ?? 0).toDouble(),
      nbMoisGarantie: data['nbMoisGarantie'] ?? 3,
      // Sécurité sur les dates
      startDate: (data['startDate'] is Timestamp) ? (data['startDate'] as Timestamp).toDate() : DateTime.now(),
      endDate: (data['endDate'] is Timestamp) ? (data['endDate'] as Timestamp).toDate() : DateTime.now(),
      prochainPaiement: (data['prochainPaiement'] is Timestamp) ? (data['prochainPaiement'] as Timestamp).toDate() : DateTime.now(),
      dernierNombreMoisPayes: data['dernierNombreMoisPayes'] ?? 0,
      dateDernierPaiement: (data['dateDernierPaiement'] is Timestamp) ? (data['dateDernierPaiement'] as Timestamp).toDate() : null,
      status: data['status'] ?? data['statut'] ?? 'active',
      statutPaiement: data['statutPaiement'] ?? 'paye',
      enAttenteValidation: data['enAttenteValidation'] ?? false,
      typeContrat: data['typeContrat'],
      soldeActuel: (data['soldeActuel'] ?? 0.0).toDouble(),
      documentsUrls: List<String>.from(data['documentsUrls'] ?? []),
      notifications: data['notifications'] as Map<String, dynamic>?,
      notificationsActives: data['notificationsActives'] ?? true,
      rappelFinBailMois: data['rappelFinBailMois'] ?? 2,
      rappelPaiementJours: data['rappelPaiementJours'] ?? 3,
      ville: data['ville'],
      commune: data['commune'],
      quartier: data['quartier'],
      avenue: data['avenue'],
      numeroMaison: data['numeroMaison'],
      province: data['province'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'factureId': factureId,
      'locataireId': locataireId,
      'locataireNom': locataireNom,
      'locatairePostnom': locatairePostnom, 
      'locatairePrenom': locatairePrenom,    
      'locataireTel': locataireTel,
      'bailleurId': bailleurId,
      'nomBailleur': nomBailleur,
      'bailleurTel': bailleurTel,
      'refMaison': refMaison,
      'propertyId': propertyId,
      'loyerMensuel': loyerMensuel,
      'nbMoisGarantie': nbMoisGarantie,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'prochainPaiement': Timestamp.fromDate(prochainPaiement),
      'dernierNombreMoisPayes': dernierNombreMoisPayes,
      'dateDernierPaiement': dateDernierPaiement != null ? Timestamp.fromDate(dateDernierPaiement!) : null,
      'status': status, 
      'statutPaiement': statutPaiement,
      'enAttenteValidation': enAttenteValidation,
      'typeContrat': typeContrat,
      'soldeActuel': soldeActuel,
      'documentsUrls': documentsUrls,
      'notifications': notifications,
      'notificationsActives': notificationsActives,
      'rappelFinBailMois': rappelFinBailMois,
      'rappelPaiementJours': rappelPaiementJours,
      'ville': ville,
      'commune': commune,
      'quartier': quartier,
      'avenue': avenue,
      'numeroMaison': numeroMaison,
      'province': province,
      'updatedAt': FieldValue.serverTimestamp(), 
    };
  }

  FactureModel toFacture() {
    return FactureModel(
      id: factureId ?? id,
      propertyId: propertyId ?? '',
      refMaison: refMaison,
      clientId: locataireId,
      nomClient: locataireNom,
      telClient: locataireTel ?? '',
      bailleurId: bailleurId,
      nomBailleur: nomBailleur ?? 'Bailleur',
      telBailleur: bailleurTel ?? '',
      loyer: loyerMensuel,
      nbMoisGarantie: nbMoisGarantie,
      nomOffre: 'Contrat Actif', 
      comLocatairePercent: 0, 
      comBailleurPercent: 0,
      paymentStatus: 'paid',
      dateCreation: startDate, 
    );
  }
}