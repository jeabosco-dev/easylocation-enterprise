// lib/services/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Récupération et jointure des données pour un audit Excel complet
  Future<List<Map<String, dynamic>>> getFullContratsReport() async {
    List<Map<String, dynamic>> rapportComplet = [];

    try {
      // 1. Récupérer les contrats
      QuerySnapshot contratsSnap = await _db
          .collection('contrats')
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in contratsSnap.docs) {
        Map<String, dynamic> contrat = doc.data() as Map<String, dynamic>;
        
        String bailleurId = contrat['bailleur_id'] ?? contrat['bailleurId'] ?? '';
        String locataireId = contrat['locataireId'] ?? ''; 
        String propertyId = contrat['propertyId'] ?? '';

        // 2. Récupérations croisées (Bailleur, Propriété, Locataire)
        final results = await Future.wait([
          _db.collection('utilisateurs').doc(bailleurId).get(),
          _db.collection('proprietes').doc(propertyId).get(),
          locataireId.isNotEmpty 
            ? _db.collection('utilisateurs').doc(locataireId).get() 
            : Future.value(null),
        ]);

        DocumentSnapshot bailleurDoc = results[0] as DocumentSnapshot;
        DocumentSnapshot propertyDoc = results[1] as DocumentSnapshot;
        DocumentSnapshot? locataireDoc = results[2] as DocumentSnapshot?;

        // Formatage sécurisé de la date
        String dateFormatted = 'N/A';
        if (contrat['createdAt'] != null && contrat['createdAt'] is Timestamp) {
          dateFormatted = DateFormat('dd/MM/yyyy').format((contrat['createdAt'] as Timestamp).toDate());
        }

        // Logique de récupération des contacts locataire
        String nomLocataire = contrat['locataireNom'] ?? 'N/A';
        String telLocataire = contrat['locatairePhone'] ?? 'N/A';

        if (locataireId.isNotEmpty && locataireDoc != null && locataireDoc.exists) {
          final locData = locataireDoc.data() as Map<String, dynamic>;
          nomLocataire = locData['nom'] ?? nomLocataire;
          telLocataire = locData['telephone'] ?? telLocataire;
        }

        // Extraction de l'adresse du bien
        Map<String, dynamic> adresseData = {};
        if (propertyDoc.exists) {
           final propData = propertyDoc.data() as Map<String, dynamic>;
           if (propData['adresse'] != null) {
             adresseData = propData['adresse'] as Map<String, dynamic>;
           } else {
             adresseData = propData;
           }
        }

        // Construction de la ligne avec les clés attendues par ExportService
        Map<String, dynamic> ligneRapport = {
          'date_signature': dateFormatted,
          'statut_contrat': (contrat['statut'] ?? 'ACTIF').toString().toUpperCase(),
          'loyer_mensuel': contrat['loyerMensuel'] ?? 0.0,
          'bailleur_nom': bailleurDoc.exists ? (bailleurDoc.data() as Map)['nom'] : 'Inconnu',
          'bailleur_tel': bailleurDoc.exists ? (bailleurDoc.data() as Map)['telephone'] : 'N/A',
          'locataire_nom': nomLocataire,
          'locataire_tel': telLocataire,
          'adresse_bien': adresseData, 
        };

        rapportComplet.add(ligneRapport);
      }
    } catch (e) {
      debugPrint("🚨 Erreur Rapport Admin : $e");
    }

    return rapportComplet;
  }
}