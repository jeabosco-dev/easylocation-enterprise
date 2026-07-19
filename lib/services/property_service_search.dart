part of 'property_service.dart';

extension PropertyServiceSearch on PropertyService {
  
  // -----------------------------------------------------------------
  // 🔥 RECHERCHE PAGINÉE (Optimisée avec retour de document pour pagination)
  // -----------------------------------------------------------------
  
  Future<Map<String, dynamic>> searchProperties(FiltreProprieteModel filtre, {DocumentSnapshot? lastDocument}) async {
    try {
      Query query = db.collection(propertyCollection);

      // --- FILTRE DE SÉCURITÉ OBLIGATOIRE ---
      // On exclut les biens masqués par l'administration
      query = query.where('moderationStatus', isEqualTo: 'visible');

      // Si on cherche par référence, on ne pagine pas
      if (filtre.queryReference != null && filtre.queryReference!.trim().isNotEmpty) {
        query = query.where('id', isEqualTo: filtre.queryReference!.trim().toUpperCase());
      } else {
        query = query.where(FirestoreFields.status, whereIn: [
          PropertyStatus.disponible, 
          PropertyStatus.booking,
          PropertyStatus.enAttentePaiement,
          PropertyStatus.reserved,
          PropertyStatus.rented, 
        ]);

        if (filtre.typeBien != null && filtre.typeBien != "Tous" && filtre.typeBien != "Toutes" && filtre.typeBien!.isNotEmpty) {
          query = query.where('typeBien', isEqualTo: filtre.typeBien);
        }

        if (filtre.provinceKey != null && filtre.provinceKey!.isNotEmpty) query = query.where('provinceKey', isEqualTo: filtre.provinceKey);
        if (filtre.villeKey != null && filtre.villeKey!.isNotEmpty) query = query.where('villeKey', isEqualTo: filtre.villeKey);
        if (filtre.communeKey != null && filtre.communeKey!.isNotEmpty) query = query.where('communeKey', isEqualTo: filtre.communeKey);
        if (filtre.quartierKey != null && filtre.quartierKey!.isNotEmpty) query = query.where('quartierKey', isEqualTo: filtre.quartierKey);
        if (filtre.avenueKey != null && filtre.avenueKey!.isNotEmpty) query = query.where('avenueKey', isEqualTo: filtre.avenueKey);

        if (filtre.nbChambres != null && filtre.nbChambres! < 4) {
          query = query.where('nombreChambres', isEqualTo: filtre.nbChambres);
        }
        if (filtre.hasCuisine) query = query.where('hasCuisine', isEqualTo: true);
        if (filtre.hasSalon) query = query.where('hasSalon', isEqualTo: true);
        if (filtre.hasToiletteParentale) query = query.where('hasToiletteParentale', isEqualTo: true);
        if (filtre.maisonEnEtage) query = query.where('maisonEnEtage', isEqualTo: true);
        if (filtre.isEnclos) query = query.where('maisonEnclos', isEqualTo: true);
        if (filtre.bailleurAbsent) query = query.where('bailleurHabiteAvec', isEqualTo: false);
      }

      // ✅ APPLICATION DE LA PAGINATION
      query = query.orderBy('createdAt', descending: true);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      query = query.limit(10);

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        return {"properties": <Property>[], "lastDocument": null};
      }

      List<Property> properties = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Property.fromMap(data, doc.id);
      }).toList();

      // Filtrage côté client
      properties = properties.where((p) {
        if (filtre.maxPrice != null && filtre.maxPrice! > 0 && p.price > filtre.maxPrice!) return false;
        if (filtre.nbChambres == 4 && p.nombreChambres < 4) return false;
        if (filtre.garentieIdeale && p.garantieMinimale > 6) return false;
        if (filtre.hasEau && !p.hasEau) return false;
        if (filtre.hasGarage && !p.hasGarage) return false;
        if (filtre.hasCourRecreation && !p.hasCourRecreation) return false;
        if (filtre.hasDepot && !p.hasDepot) return false;
        if (filtre.accessibiliteVoiture && !p.accessibiliteVoiture) return false;
        if (filtre.peuDeMenages && (p.nombreMenages ?? 0) > 2) return false;
        return true;
      }).toList();

      return {
        "properties": properties,
        "lastDocument": snapshot.docs.last
      };

    } catch (e) {
      debugPrint("🚨 Erreur searchProperties : $e");
      return {"properties": <Property>[], "lastDocument": null};
    }
  }

  Stream<List<Property>> getAvailablePropertiesStream() {
    return db.collection(propertyCollection)
        .where('moderationStatus', isEqualTo: 'visible') // ✅ Ajout du filtre
        .where(FirestoreFields.status, whereIn: [
          PropertyStatus.disponible, 
          PropertyStatus.booking,
          PropertyStatus.enAttentePaiement,
          PropertyStatus.reserved,
          PropertyStatus.rented 
        ])
        .snapshots()
        .asyncMap((snapshot) async {
          final inputs = snapshot.docs.map((doc) => _ParsingInput(doc.data() as Map<String, dynamic>, doc.id)).toList();
          List<Property> list = await compute(_handleListParsing, inputs);
          
          list.sort((a, b) {
            int cmp = (b.sortIndex).compareTo(a.sortIndex);
            if (cmp != 0) return cmp;
            return b.createdAt.compareTo(a.createdAt);
          });
          return list;
        });
  }

  Future<List<Property>> getBailleurProperties(String bailleurId) async {
    // Note : Ici tu peux choisir de laisser voir au bailleur ses propres biens même masqués,
    // ou de filtrer. Si tu filtres, ajoute : .where('moderationStatus', isEqualTo: 'visible')
    final snapshot = await db.collection(propertyCollection)
        .where('bailleurId', isEqualTo: bailleurId)
        .get();
    final inputs = snapshot.docs.map((doc) => _ParsingInput(doc.data() as Map<String, dynamic>, doc.id)).toList();
    return await compute(_handleListParsing, inputs);
  }
}