// lib/controllers/formulaire_publication_controller.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/formulaire_publication_model.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class FormulairePublicationController extends ChangeNotifier {
  FormulairePublicationModel _data;
  final picker.ImagePicker _picker = picker.ImagePicker();

  // ✅ CONTRÔLEURS POUR LES CHAMPS TEXTE
  late TextEditingController provinceSpecifiqueCtrl; // Ajouté
  late TextEditingController villeSpecifiqueCtrl;
  late TextEditingController communeSpecifiqueCtrl;
  late TextEditingController quartierSpecifiqueCtrl;
  late TextEditingController avenueSpecifiqueCtrl;
  late TextEditingController descriptionCtrl;
  late TextEditingController numeroMaisonCtrl;
  late TextEditingController niveauEtageCtrl;

  // ✅ INFOS PROPRIÉTAIRE
  late TextEditingController nomProprioCtrl;
  late TextEditingController postnomProprioCtrl;
  late TextEditingController prenomProprioCtrl;
  late TextEditingController telProprioCtrl;
  late TextEditingController emailProprioCtrl;
  late TextEditingController statutLegalAutreCtrl;
  late TextEditingController statutProAutreCtrl;

  FormulairePublicationController({
    required FormulairePublicationModel initialData,
    required String currentUserId,
  }) : _data = initialData {
    if (_data.bailleurId == null || _data.bailleurId!.isEmpty) {
      _data = _data.copyWith(bailleurId: currentUserId);
    }

    // ✅ INITIALISATION DES CONTROLEURS
    provinceSpecifiqueCtrl = TextEditingController(text: _data.provinceSpecifique); // Ajouté
    villeSpecifiqueCtrl = TextEditingController(text: _data.villeSpecifique);
    communeSpecifiqueCtrl = TextEditingController(text: _data.communeSpecifique);
    quartierSpecifiqueCtrl = TextEditingController(text: _data.quartierSpecifique);
    avenueSpecifiqueCtrl = TextEditingController(text: _data.avenueSpecifique);
    descriptionCtrl = TextEditingController(text: _data.description);
    numeroMaisonCtrl = TextEditingController(text: _data.numeroMaison);
    niveauEtageCtrl = TextEditingController(text: _data.niveauEtage?.toString() ?? "");
    
    nomProprioCtrl = TextEditingController(text: _data.nomProprietaire);
    postnomProprioCtrl = TextEditingController(text: _data.postnomProprietaire);
    prenomProprioCtrl = TextEditingController(text: _data.prenomProprietaire);
    telProprioCtrl = TextEditingController(text: _data.telephoneProprietaire);
    emailProprioCtrl = TextEditingController(text: _data.emailProprietaire);
    statutLegalAutreCtrl = TextEditingController(text: _data.statutLegalAutre);
    statutProAutreCtrl = TextEditingController(text: _data.statutProAutre);

    setFormInProgress(true);
    checkLostData();
  }

  @override
  void dispose() {
    provinceSpecifiqueCtrl.dispose(); // Ajouté
    villeSpecifiqueCtrl.dispose();
    communeSpecifiqueCtrl.dispose();
    quartierSpecifiqueCtrl.dispose();
    avenueSpecifiqueCtrl.dispose();
    descriptionCtrl.dispose();
    numeroMaisonCtrl.dispose();
    niveauEtageCtrl.dispose();
    nomProprioCtrl.dispose();
    postnomProprioCtrl.dispose();
    prenomProprioCtrl.dispose();
    telProprioCtrl.dispose();
    emailProprioCtrl.dispose();
    statutLegalAutreCtrl.dispose();
    statutProAutreCtrl.dispose();
    super.dispose();
  }

  FormulairePublicationModel get data => _data;

  // --- 📸 GESTION DES PHOTOS ---

  Future<void> pickImage(String type) async {
    try {
      final picker.XFile? pickedFile = await _picker.pickImage(
        source: picker.ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String fileName = "${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFile.path)}";
        final File savedImage = await File(pickedFile.path).copy('${appDocDir.path}/$fileName');
        
        final ImageSource source = ImageSource(file: picker.XFile(savedImage.path));

        if (type == 'chambre') {
          List<ImageSource> currentChambres = List.from(_data.chambresImages);
          currentChambres.add(source);
          updateData(chambresImages: currentChambres);
        } else {
          _assignImageToField(type, source);
        }
      }
    } catch (e) {
      if (kDebugMode) print("❌ Erreur lors de la prise de photo: $e");
    }
  }

  void removeChambreImage(int index) {
    List<ImageSource> currentChambres = List.from(_data.chambresImages);
    if (index >= 0 && index < currentChambres.length) {
      currentChambres.removeAt(index);
      updateData(chambresImages: currentChambres);
    }
  }

  Future<void> checkLostData() async {
    try {
      final picker.LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final File savedImage = await File(response.file!.path).copy(
        '${appDocDir.path}/lost_${p.basename(response.file!.path)}'
      );
      
      updateData(mainImage: ImageSource(file: picker.XFile(savedImage.path)));
    } catch (e) {
      if (kDebugMode) print("❌ Erreur récupération LostData: $e");
    }
  }

  void _assignImageToField(String type, ImageSource source) {
    switch (type) {
      case 'main': updateData(mainImage: source); break;
      case 'salon': updateData(salonImage: source); break;
      case 'cuisine': updateData(cuisineImage: source); break;
      case 'toilette': updateData(toiletteParentaleImage: source); break;
      case 'garage': updateData(garageImage: source); break;
      case 'cour': updateData(courRecreationImage: source); break;
      case 'depot': updateData(depotImage: source); break;
      default: updateData(mainImage: source);
    }
  }

  // --- 💾 PERSISTANCE ---
  Future<void> setFormInProgress(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('form_in_progress', value);
    } catch (e) {
      if (kDebugMode) print("❌ Erreur SharedPreferences: $e");
    }
  }

  Future<void> clearFormProgress() async {
    await setFormInProgress(false);
  }

  Future<void> resetData(String currentUserId) async {
    _data = FormulairePublicationModel(bailleurId: currentUserId);
    notifyListeners();
  }

  // --- 📝 MISE À JOUR DES DONNÉES ---
  void updateData({
    ImageSource? mainImage,
    String? typeBien, 
    String? province,
    String? ville,
    String? commune,
    String? quartier,
    String? avenue,
    String? provinceSpecifique, // Ajouté
    String? villeSpecifique,
    String? communeSpecifique,
    String? quartierSpecifique,
    String? avenueSpecifique,
    String? numeroMaison,
    double? price,
    int? garantieIdeale,
    int? garantieMinimale,
    bool? disponibiliteImmediate,
    DateTime? dateDisponibilite,
    bool? maisonEnEtage,
    int? niveauEtage,
    String? description,
    int? nombreChambres,
    bool? hasSalon,
    bool? hasCuisine,
    bool? hasToiletteParentale,
    String? selectedTypeSol,
    Object? cuisineImage = FormulairePublicationModelSentinel,
    Object? toiletteParentaleImage = FormulairePublicationModelSentinel,
    Object? salonImage = FormulairePublicationModelSentinel,
    Object? garageImage = FormulairePublicationModelSentinel,
    Object? courRecreationImage = FormulairePublicationModelSentinel,
    Object? depotImage = FormulairePublicationModelSentinel,
    List<ImageSource>? chambresImages,
    bool? hasGarage,
    bool? hasCourRecreation,
    bool? hasDepot,
    bool? maisonEnclos,
    bool? possibiliteAnimaux,
    String? typeMaison,
    bool? hasEau,
    bool? compteurEau,
    String? electricite,
    bool? accessibiliteVoiture,
    bool? bailleurHabiteAvec,
    int? nombreMenages,
    bool? estReactif,
    String? bailleurId,
    String? nomProprietaire,
    String? postnomProprietaire,
    String? prenomProprietaire,
    String? telephoneProprietaire,
    String? emailProprietaire,
    String? statutLegal,
    String? statutLegalAutre,
    String? statutProfessionnel,
    String? statutProAutre,
  }) {
    bool? finalDispoImmediate = disponibiliteImmediate;
    DateTime? finalDate = dateDisponibilite;

    if (disponibiliteImmediate == true) {
      finalDate = null;
    } else if (dateDisponibilite != null) {
      finalDispoImmediate = false;
    }

    _data = _data.copyWith(
      mainImage: mainImage,
      typeBien: typeBien, 
      province: province,
      provinceSpecifique: provinceSpecifique,
      ville: ville,
      villeSpecifique: villeSpecifique,
      commune: commune,
      communeSpecifique: communeSpecifique,
      quartier: quartier,
      quartierSpecifique: quartierSpecifique,
      avenue: avenue,
      avenueSpecifique: avenueSpecifique,
      numeroMaison: numeroMaison,
      price: price,
      garantieIdeale: garantieIdeale,
      garantieMinimale: garantieMinimale,
      disponibiliteImmediate: finalDispoImmediate,
      dateDisponibilite: finalDate ?? (disponibiliteImmediate == true ? null : _data.dateDisponibilite),
      maisonEnEtage: maisonEnEtage,
      niveauEtage: niveauEtage,
      description: description,
      nombreChambres: nombreChambres,
      hasSalon: hasSalon,
      hasCuisine: hasCuisine,
      hasToiletteParentale: hasToiletteParentale,
      selectedTypeSol: selectedTypeSol,
      cuisineImage: cuisineImage,
      toiletteParentaleImage: toiletteParentaleImage,
      salonImage: salonImage,
      garageImage: garageImage,
      courRecreationImage: courRecreationImage,
      depotImage: depotImage,
      chambresImages: chambresImages,
      hasGarage: hasGarage,
      hasCourRecreation: hasCourRecreation,
      hasDepot: hasDepot,
      maisonEnclos: maisonEnclos,
      possibiliteAnimaux: possibiliteAnimaux,
      typeMaison: typeMaison,
      hasEau: hasEau,
      compteurEau: compteurEau,
      electricite: electricite,
      accessibiliteVoiture: accessibiliteVoiture,
      bailleurHabiteAvec: bailleurHabiteAvec,
      nombreMenages: nombreMenages,
      estReactif: estReactif,
      bailleurId: bailleurId,
      nomProprietaire: nomProprietaire,
      postnomProprietaire: postnomProprietaire,
      prenomProprietaire: prenomProprietaire,
      telephoneProprietaire: telephoneProprietaire,
      emailProprietaire: emailProprietaire,
      statutLegal: statutLegal,
      statutLegalAutre: statutLegalAutre,
      statutProfessionnel: statutProfessionnel,
      statutProAutre: statutProAutre,
    );

    // ✅ SYNCHRONISATION DES CONTROLLERS
    if (provinceSpecifique != null && provinceSpecifiqueCtrl.text != provinceSpecifique) provinceSpecifiqueCtrl.text = provinceSpecifique; // Ajouté
    if (villeSpecifique != null && villeSpecifiqueCtrl.text != villeSpecifique) villeSpecifiqueCtrl.text = villeSpecifique;
    if (communeSpecifique != null && communeSpecifiqueCtrl.text != communeSpecifique) communeSpecifiqueCtrl.text = communeSpecifique;
    if (quartierSpecifique != null && quartierSpecifiqueCtrl.text != quartierSpecifique) quartierSpecifiqueCtrl.text = quartierSpecifique;
    if (avenueSpecifique != null && avenueSpecifiqueCtrl.text != avenueSpecifique) avenueSpecifiqueCtrl.text = avenueSpecifique;
    if (description != null && descriptionCtrl.text != description) descriptionCtrl.text = description;
    if (numeroMaison != null && numeroMaisonCtrl.text != numeroMaison) numeroMaisonCtrl.text = numeroMaison;
    if (niveauEtage != null && niveauEtageCtrl.text != niveauEtage.toString()) niveauEtageCtrl.text = niveauEtage.toString();
    
    // ✅ Sync Propriétaire
    if (nomProprietaire != null && nomProprioCtrl.text != nomProprietaire) nomProprioCtrl.text = nomProprietaire;
    if (postnomProprietaire != null && postnomProprioCtrl.text != postnomProprietaire) postnomProprioCtrl.text = postnomProprietaire;
    if (prenomProprietaire != null && prenomProprioCtrl.text != prenomProprietaire) prenomProprioCtrl.text = prenomProprietaire;
    if (telephoneProprietaire != null && telProprioCtrl.text != telephoneProprietaire) telProprioCtrl.text = telephoneProprietaire;
    if (emailProprietaire != null && emailProprioCtrl.text != emailProprietaire) emailProprioCtrl.text = emailProprietaire;
    if (statutLegalAutre != null && statutLegalAutreCtrl.text != statutLegalAutre) statutLegalAutreCtrl.text = statutLegalAutre;
    if (statutProAutre != null && statutProAutreCtrl.text != statutProAutre) statutProAutreCtrl.text = statutProAutre;

    notifyListeners();
  }

  // --- 🧹 GETTERS DE NETTOYAGE ---
  String get villeFinale => (data.ville == "Autre") ? (data.villeSpecifique ?? "") : (data.ville ?? "");
  String get communeFinale => (data.commune == "Autre" || data.ville == "Autre") ? (data.communeSpecifique ?? "") : (data.commune ?? "");
  String get quartierFinal => (data.quartier == "Autre" || data.commune == "Autre" || data.ville == "Autre") ? (data.quartierSpecifique ?? "") : (data.quartier ?? "");
  String get avenueFinale => (data.avenue == "Autre" || data.quartier == "Autre" || data.commune == "Autre" || data.ville == "Autre") ? (data.avenueSpecifique ?? "") : (data.avenue ?? "");

  // --- 🚀 MÉTHODE PRÉPARATION FIREBASE ---
  Map<String, dynamic> prepareDataForFirebase() {
    return {
      'province': data.province,
      'provinceSpecifique': data.provinceSpecifique,
      'ville': villeFinale,
      'commune': communeFinale,
      'quartier': quartierFinal,
      'avenue': avenueFinale,
      'numeroMaison': data.numeroMaison,
      'price': data.price ?? 0.0,
      'nombreChambres': data.nombreChambres ?? 0,
      'garantieIdeale': data.garantieIdeale ?? 0,
      'garantieMinimale': data.garantieMinimale ?? 0,
      'description': data.description ?? "",
      'disponibiliteImmediate': data.disponibiliteImmediate ?? false,
      'dateDisponibilite': (data.disponibiliteImmediate == true) ? null : data.dateDisponibilite,
      'selectedTypeSol': data.selectedTypeSol ?? "Non spécifié",
      'typeMaison': data.typeMaison ?? "Non spécifié",
      
      // ✅ HARMONISATION
      'typeBien': data.typeBien ?? PropertyTypes.all.first, 
      
      'maisonEnEtage': data.maisonEnEtage ?? false,
      'niveauEtage': data.niveauEtage ?? 0,
      'labelEtage': _getLabelEtage(data.niveauEtage),
      'hasSalon': data.hasSalon ?? false,
      'hasCuisine': data.hasCuisine ?? false,
      'hasToiletteParentale': data.hasToiletteParentale ?? false,
      'hasGarage': data.hasGarage ?? false,
      'hasCourRecreation': data.hasCourRecreation ?? false,
      'hasDepot': data.hasDepot ?? false,
      'status': 'disponible', 
      'estLouee': false,
      'isVerified': false,
      'bailleurHabiteAvec': data.bailleurHabiteAvec ?? false,
      'views': 0,
      'bailleurId': data.bailleurId,
      'nomProprietaire': data.nomProprietaire,
      'postnomProprietaire': data.postnomProprietaire,
      'prenomProprietaire': data.prenomProprietaire,
      'telephoneProprietaire': data.telephoneProprietaire,
      'emailProprietaire': data.emailProprietaire,
      'statutLegal': data.statutLegal,
      'statutLegalAutre': data.statutLegalAutre,
      'statutProfessionnel': data.statutProfessionnel,
      'statutProAutre': data.statutProAutre,
      'maisonEnclos': data.maisonEnclos ?? false,
      'electricite': data.electricite ?? "Non spécifié",
      'hasEau': data.hasEau ?? false,
      'compteurEau': data.compteurEau ?? false,
      'accessibiliteVoiture': data.accessibiliteVoiture ?? false,
      'nombreMenages': data.nombreMenages ?? 1,
      'estReactif': data.estReactif ?? false,
      'possibiliteAnimaux': data.possibiliteAnimaux ?? false,
      'searchKeywords': [
        data.province?.toLowerCase(),
        villeFinale.toLowerCase(),
        communeFinale.toLowerCase(),
        quartierFinal.toLowerCase(),
        (data.typeBien ?? PropertyTypes.all.first).toLowerCase(), 
        data.selectedTypeSol?.toLowerCase(),
      ].where((e) => e != null && e.isNotEmpty).toList(),
    };
  }

  String _getLabelEtage(int? niveau) {
    if (niveau == 99) return "Grenier";
    if (niveau == 0 || niveau == null) return "Rez-de-chaussée";
    if (niveau == 1) return "1er étage";
    return "$niveau ème étage";
  }
}