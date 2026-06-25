part of 'property_service.dart';

extension PropertyServiceSearch on PropertyService {
  
  // -----------------------------------------------------------------
  // 🔥 RECHERCHE ET STREAMS (MODE PREUVE SOCIALE)
  // -----------------------------------------------------------------
  
  Future<List<Property>> searchProperties(FiltreProprieteModel filtre) async {
    try {
      Query query = db.collection(propertyCollection);

      if (filtre.queryReference != null && filtre.queryReference!.trim().isNotEmpty) {
        query = query.where('id', isEqualTo: filtre.queryReference!.trim().toUpperCase());
      } 
      else {
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

        // --- Normalisation des champs géographiques ---
        
        if (filtre.province != null && filtre.province != "Toutes") {
          query = query.where('province', isEqualTo: filtre.province!.trim().toLowerCase());
        }
        
        if (filtre.ville != null && filtre.ville != "Toutes") {
          final villeRecherche = (filtre.ville == "Autre") ? filtre.villeSpecifique : filtre.ville;
          query = query.where('ville', isEqualTo: villeRecherche?.trim().toLowerCase());
        }
        
        if (filtre.commune != null && filtre.commune != "Toutes") {
          final communeRecherche = (filtre.commune == "Autre") ? filtre.communeSpecifique : filtre.commune;
          query = query.where('commune', isEqualTo: communeRecherche?.trim().toLowerCase());
        }

        // Note : Si vous ajoutez quartier/avenue dans FiltreProprieteModel, 
        // appliquez la même logique ici :
        // if (filtre.quartier != null && filtre.quartier!.isNotEmpty) {
        //   query = query.where('quartier', isEqualTo: filtre.quartier!.trim().toLowerCase());
        // }

        // ----------------------------------------------

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

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return [];

      final inputs = snapshot.docs
          .map((doc) => _ParsingInput(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      List<Property> properties = await compute(_handleListParsing, inputs);

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

      properties.sort((a, b) {
        int cmp = (b.sortIndex).compareTo(a.sortIndex);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });

      return properties;

    } catch (e, stackTrace) {
      debugPrint("🚨 Erreur searchProperties : $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
      return [];
    }
  }

  Stream<List<Property>> getAvailablePropertiesStream() {
    return db.collection(propertyCollection)
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
    final snapshot = await db.collection(propertyCollection).where('bailleurId', isEqualTo: bailleurId).get();
    final inputs = snapshot.docs.map((doc) => _ParsingInput(doc.data() as Map<String, dynamic>, doc.id)).toList();
    return await compute(_handleListParsing, inputs);
  }
}