// lib/models/service_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/facture_model.dart'; 

class ServiceModel {
  final String id;
  final String locataireId;
  final String? locataireTel;
  final String? nomClient;           
  final String typeService;          
  final String statut;               
  final double prix;                 // <--- Le champ existe bien ici
  final DateTime? dateSouhaitee;
  final String provenance;           
  final DateTime? timestamp;
  final String? urlPreuve;           
  final Map<String, dynamic>? metadata; 
  final String? commentairesAdmin;   

  final String nomAffichage;
  final String? description;
  final bool isPercentage;

  ServiceModel({
    required this.id,
    required this.locataireId,
    this.locataireTel,
    this.nomClient,                  
    required this.typeService,
    required this.statut,
    required this.prix,
    this.dateSouhaitee,
    required this.provenance,
    this.timestamp,
    this.urlPreuve,
    this.metadata,                   
    this.commentairesAdmin,          
    required this.nomAffichage,
    this.description,
    this.isPercentage = false,
  });

  // --- ✅ MÉTHODE DE MAPPING ---
  FactureModel toFacture({String? propertyId, String? nomClient}) {
    return FactureModel(
      id: this.id,
      clientId: this.locataireId,
      propertyId: propertyId ?? "SERVICE_EXTERNE",
      nomClient: nomClient ?? this.nomClient ?? "Client EasyLocation",
      telClient: this.locataireTel ?? "Non spécifié",
      refMaison: propertyId != null ? "Service sur Bien" : "Service : ${this.nomAffichage}",
      nomOffre: this.nomAffichage,
      comLocatairePercent: 0.0,
      comBailleurPercent: 0.0,
      loyer: this.prix,
      dateCreation: DateTime.now(),
      paymentStatus: this.statut == 'PAYE' ? 'paid' : 'pending',
    );
  }

  // --- MÉTHODE COPYWITH MISE À JOUR ---
  ServiceModel copyWith({
    String? id,
    String? statut,
    double? prix, // <--- AJOUTÉ : Maintenant tu peux modifier le prix
    DateTime? dateSouhaitee,
    String? locataireTel,
    String? nomClient,
    String? urlPreuve,
    Map<String, dynamic>? metadata,
    String? commentairesAdmin,
    String? nomAffichage, // AJOUTÉ pour plus de flexibilité
  }) {
    return ServiceModel(
      id: id ?? this.id,
      locataireId: this.locataireId,
      locataireTel: locataireTel ?? this.locataireTel,
      nomClient: nomClient ?? this.nomClient,
      typeService: this.typeService,
      statut: statut ?? this.statut,
      prix: prix ?? this.prix, // <--- UTILISÉ : prix passé en paramètre ou prix actuel
      dateSouhaitee: dateSouhaitee ?? this.dateSouhaitee,
      provenance: this.provenance,
      timestamp: this.timestamp,
      urlPreuve: urlPreuve ?? this.urlPreuve,
      metadata: metadata ?? this.metadata,
      commentairesAdmin: commentairesAdmin ?? this.commentairesAdmin,
      nomAffichage: nomAffichage ?? this.nomAffichage,
      description: this.description,
      isPercentage: this.isPercentage,
    );
  }

  // --- TRANSFORMER LA CONFIG FIREBASE EN MODELES (Carrousel) ---
  factory ServiceModel.fromConfig(Map<String, dynamic> map) {
    return ServiceModel(
      id: '',
      locataireId: '',
      locataireTel: null,
      typeService: map['id'] ?? '',
      statut: 'PROPOSE',
      prix: (map['prix'] is num) ? (map['prix'] as num).toDouble() : 0.0,
      provenance: 'DASHBOARD',
      nomAffichage: map['nom'] ?? '',
      description: map['description'] ?? '',
      isPercentage: map['is_percentage'] ?? false,
    );
  }

  // --- LOGIQUE FIRESTORE (Lecture) ---
  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return ServiceModel(
      id: doc.id,
      locataireId: data['locataireId'] ?? '',
      locataireTel: data['locataireTel'],
      nomClient: data['nomClient'],           
      typeService: data['typeService'] ?? '',
      statut: data['statut'] ?? 'PROPOSE',
      prix: (data['prix'] is num) ? (data['prix'] as num).toDouble() : 0.0,
      dateSouhaitee: data['dateSouhaitee'] != null
          ? (data['dateSouhaitee'] as Timestamp).toDate()
          : null,
      provenance: data['provenance'] ?? 'DASHBOARD',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : null,
      urlPreuve: data['urlPreuve'],
      metadata: data['metadata'] != null 
          ? Map<String, dynamic>.from(data['metadata']) 
          : null,                   
      commentairesAdmin: data['commentairesAdmin'], 
      nomAffichage: data['nomAffichage'] ?? '',
      description: data['description'],
      isPercentage: data['isPercentage'] ?? false,
    );
  }

  // --- LOGIQUE FIRESTORE (Écriture) ---
  Map<String, dynamic> toMap() {
    return {
      'locataireId': locataireId,
      'locataireTel': locataireTel,
      'nomClient': nomClient,                 
      'typeService': typeService,
      'statut': statut,
      'prix': prix,
      'dateSouhaitee': dateSouhaitee != null ? Timestamp.fromDate(dateSouhaitee!) : null,
      'provenance': provenance,
      'nomAffichage': nomAffichage,
      'description': description,
      'isPercentage': isPercentage,
      'urlPreuve': urlPreuve,
      'metadata': metadata,                    
      'commentairesAdmin': commentairesAdmin, 
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
    };
  }

  // --- GETTERS UI ---
  String get libelle {
    if (nomAffichage.isNotEmpty) return nomAffichage;
    switch (typeService) {
      case 'NETTOYAGE': return "Nettoyage Installation";
      case 'PEINTURE': return "Peinture & Rafraîchissement";
      case 'DEMENAGEMENT':
      case 'DEMENAGEMENT_STD': return "Déménagement Standard";
      case 'DEMENAGEMENT_PREMIUM': return "Déménagement Porte-à-Porte";
      case 'DEMENAGEMENT_GOLD': return "Déménagement Gold (Installation)";
      case 'PACK_SERENITE': return "Pack Sérénité Totale";
      default: return typeService;
    }
  }

  Color get colorStatut {
    switch (statut) {
      case 'COMMANDE': return Colors.orange;
      case 'PAYE': return Colors.green;
      case 'EN_COURS': return Colors.blue;
      case 'TERMINE': return Colors.grey;
      case 'ANNULE': return Colors.red;
      default: return Colors.grey.shade400;
    }
  }
}