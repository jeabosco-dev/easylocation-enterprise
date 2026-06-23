// lib/services/location_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Cache mis à jour pour stocker les données par ID de province
  final Map<String, Map<String, dynamic>> _cache = {};

  /// Récupère la liste de toutes les provinces disponibles dans la collection
  Future<List<String>> getProvinces() async {
    try {
      // On récupère tous les documents de la collection 'zones_geographiques'
      QuerySnapshot snapshot = await _db.collection('zones_geographiques').get();
      
      // On retourne la liste des IDs de documents (ex: 'sud-kivu', 'kinshasa')
      return snapshot.docs.map((doc) => doc.id).toList()..sort();
    } catch (e) {
      debugPrint("❌ Erreur lors du chargement des provinces : $e");
      return [];
    }
  }

  /// Récupère la structure pour une province donnée depuis Firestore et la met en cache
  Future<Map<String, dynamic>> _fetchData(String provinceId) async {
    // Normalisation : on force la conversion en minuscules pour correspondre aux IDs Firestore
    final id = provinceId.toLowerCase();
    
    // Si on a déjà les données en cache, on les retourne
    if (_cache.containsKey(id)) return _cache[id]!;
    
    try {
      DocumentSnapshot doc = await _db
          .collection('zones_geographiques')
          .doc(id) // Utilisation de l'id normalisé
          .get(const GetOptions(source: Source.serverAndCache));
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // On récupère la map 'villes' du document
        final villes = data['villes'] as Map<String, dynamic>? ?? {};
        _cache[id] = villes;
        return villes;
      }
    } catch (e) {
      debugPrint("❌ Erreur lors du chargement des zones pour $provinceId : $e");
    }
    return {};
  }

  /// Retourne la liste des Villes pour une province donnée
  Future<List<String>> getVilles(String provinceId) async {
    final villesMap = await _fetchData(provinceId);
    return villesMap.keys.toList()..sort();
  }

  /// Retourne la liste des Communes pour une ville donnée dans une province
  Future<List<String>> getCommunes(String provinceId, String ville) async {
    final villesMap = await _fetchData(provinceId);
    final communesMap = villesMap[ville] as Map<String, dynamic>? ?? {};
    return communesMap.keys.toList()..sort();
  }

  /// Retourne la liste des Quartiers pour une commune donnée
  Future<List<String>> getQuartiers(String provinceId, String ville, String commune) async {
    final villesMap = await _fetchData(provinceId);
    final communesMap = villesMap[ville] as Map<String, dynamic>? ?? {};
    final quartiersMap = communesMap[commune] as Map<String, dynamic>? ?? {};
    return quartiersMap.keys.toList()..sort();
  }

  /// Retourne les Avenues pour un quartier donné
  Future<List<String>> getAvenues(String provinceId, String ville, String commune, String quartier) async {
    final villesMap = await _fetchData(provinceId);
    final communesMap = villesMap[ville] as Map<String, dynamic>? ?? {};
    final quartiersMap = communesMap[commune] as Map<String, dynamic>? ?? {};
    
    // On extrait le tableau d'avenues ou on retourne ['Autre'] par défaut
    final List<dynamic> avenues = quartiersMap[quartier] as List<dynamic>? ?? ['Autre'];
    return avenues.map((e) => e.toString()).toList();
  }

  /// Optionnel : Vide le cache si tu veux forcer une nouvelle lecture
  void clearCache() {
    _cache.clear();
  }
}