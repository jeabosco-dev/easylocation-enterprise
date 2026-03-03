// lib/screens/details_propriete_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus; 
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/models/formulaire_publication_model.dart';
import 'package:easylocation_mvp/screens/rapport_expertise_page.dart';
import 'package:easylocation_mvp/services/calculateur_expertise.dart'; 
import 'package:easylocation_mvp/services/property_service.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:easylocation_mvp/widgets/section_caracteristiques_propriete.dart';
import 'package:easylocation_mvp/widgets/section_images_propriete.dart';
import 'package:easylocation_mvp/widgets/section_description_dynamique.dart';
import 'package:easylocation_mvp/widgets/section_statistiques_avis.dart'; 
import 'package:easylocation_mvp/widgets/bouton_favori.dart'; 
import 'package:easylocation_mvp/widgets/statistique_vue.dart';
import 'package:easylocation_mvp/widgets/bouton_partage.dart';
import 'package:easylocation_mvp/widgets/bouton_noter.dart';
import 'package:easylocation_mvp/widgets/bouton_action_principale_louer.dart';
import 'package:easylocation_mvp/widgets/badge_statut_propriete.dart'; 
import 'package:easylocation_mvp/widgets/bouton_signaler_abus.dart'; 
import 'package:easylocation_mvp/widgets/barre_navigation_propriete.dart';
import 'package:easylocation_mvp/widgets/section_adresse_propriete.dart'; 
import 'package:easylocation_mvp/widgets/section_proprietes_similaires.dart';
import 'package:easylocation_mvp/widgets/reference_badge_widget.dart';

class DetailsProprietePage extends StatefulWidget {
  final List<String> propertiesIds;
  final int initialIndex;

  const DetailsProprietePage({
    super.key, 
    required this.propertiesIds, 
    required this.initialIndex
  });

  @override
  State<DetailsProprietePage> createState() => _DetailsProprietePageState();
}

class _DetailsProprietePageState extends State<DetailsProprietePage> {
  late int _currentIndex;
  late PageController _pageController; 
  Property? _currentProperty;
  bool _isLoadingProperty = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadCurrentProperty(isInitial: true);
  }

  Future<void> _loadCurrentProperty({bool isInitial = false}) async {
    if (!mounted) return;
    if (isInitial) setState(() => _isLoadingProperty = true);

    try {
      // Nettoyage des verrous expirés avant de charger
      await PropertyService().cleanExpiredReservations();

      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.properties) 
          .doc(widget.propertiesIds[_currentIndex])
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _currentProperty = Property.fromFirestore(doc);
          _isLoadingProperty = false;
        });
        
        final userProvider = context.read<UserProfileProvider>();
        if (userProvider.isAuthenticated && userProvider.activeRole == UserRoles.tenant) {
          _savePropertyToHistory(userProvider);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProperty = false);
    }
  }

  void _savePropertyToHistory(UserProfileProvider userProvider) async {
    if (_currentProperty == null || !userProvider.isAuthenticated) return;
    
    FirebaseFirestore.instance
        .collection('historique_locataire')
        .doc(userProvider.userData!.uid)
        .collection('user_history')
        .doc(_currentProperty!.id)
        .set({
          'id': _currentProperty!.id,
          'commune': _currentProperty!.commune,
          'quartier': _currentProperty!.quartier,
          'mainImageUrl': _currentProperty!.mainImageUrl,
          'prix': _currentProperty!.price, 
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _loadCurrentProperty(); 
  }

  FormulairePublicationModel _mapPropertyToFormulaire(Property p) {
    return FormulairePublicationModel.fromProperty(p);
  }

  void _ouvrirExpertiseEtReserver() {
    if (_currentProperty == null) return;

    // Calcul du score avant redirection
    CalculateurExpertise.calculerScore(_currentProperty!);
    final formulaireData = _mapPropertyToFormulaire(_currentProperty!);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RapportExpertisePage(
        propriete: formulaireData,
      ),
    ));
  }

  @override
  void dispose() { 
    _pageController.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProfileProvider>();

    if (_isLoadingProperty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_currentProperty == null) {
      return const Scaffold(body: Center(child: Text("Propriété introuvable")));
    }

    final property = _currentProperty!;

    if (property.status == 'archive') {
      return _buildArchiveScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                property.title.toUpperCase(), 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (property.isVerified) ...[
              const SizedBox(width: 5),
              const Icon(Icons.verified, size: 16, color: Colors.white),
            ],
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: widget.propertiesIds.length,
        itemBuilder: (context, index) {
          return RefreshIndicator(
            onRefresh: () async => await _loadCurrentProperty(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionImagesPropriete(property: property),
                    const SizedBox(height: 15),
                    BarreNavigationPropriete(
                      currentIndex: _currentIndex,
                      totalCount: widget.propertiesIds.length,
                      pageController: _pageController,
                    ),
                    const SizedBox(height: 15),
                    SectionAdressePropriete(property: property),
                    const SizedBox(height: 8),
                    ReferenceBadgeWidget(reference: property.referenceCourte),
                    const SizedBox(height: 20),
                    _buildPriceAndStatusRow(property),
                    const SizedBox(height: 25),
                    SectionDescriptionDynamique(property: property),
                    const Divider(height: 40),
                    SectionCaracteristiquesPropriete(property: property),
                    const SizedBox(height: 30),
                    _buildVisitButton(userProvider), // Le bouton intelligent est ici
                    const Divider(height: 50),
                    _buildQuickActions(property, userProvider),
                    const Divider(height: 50),
                    SectionStatistiquesAvis(property: property),
                    const SizedBox(height: 30),
                    SectionProprietesSimilaires(currentProperty: property),
                    const SizedBox(height: 40),
                    BoutonSignalerAbus(
                      propertyId: property.id,
                      color: Colors.redAccent.withOpacity(0.8),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceAndStatusRow(Property property) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            BadgeStatutPropriete(statut: property.status),
            if (property.isVerified) ...[
              const SizedBox(width: 8),
              _buildVerifiedBadge(),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${property.price.toStringAsFixed(0)}\$", 
              style: TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.w900, 
                color: Theme.of(context).colorScheme.primary,
                height: 1.0,
              )
            ),
            const Text(
              "par mois", 
              style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified, color: Colors.blue, size: 14),
          SizedBox(width: 4),
          Text("VÉRIFIÉ", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Property property, UserProfileProvider userProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StatistiqueVue(property: property),
        BoutonFavori(property: property),
        BoutonNoter(
          property: property, 
          userRole: userRoleMapping(userProvider.activeRole), 
          onRefresh: () => setState(() {}),
        ),
        BoutonPartage(property: property),
      ],
    );
  }

  // Helper pour convertir le rôle si nécessaire (ajustez selon votre modèle BoutonNoter)
  String userRoleMapping(dynamic role) => role.toString();

  /// ✅ LE BOUTON MIS À JOUR (LOGIQUE INTELLIGENTE)
  Widget _buildVisitButton(UserProfileProvider userProvider) {
    final String currentUserId = userProvider.userData?.uid ?? "";
    final bool isLocataire = userProvider.activeRole == UserRoles.tenant;
    
    // Récupération des données de verrouillage depuis Firestore
    final String currentStatus = _currentProperty?.status ?? PropertyStatus.disponible;
    final String? lockedBy = _currentProperty?.lockedBy;

    // LOGIQUE CRUCIALE : 
    // On peut cliquer si c'est DISPONIBLE 
    // OU si c'est en BOOKING mais que c'est NOUS qui l'avons verrouillé.
    final bool isMyLock = (currentStatus == PropertyStatus.booking && lockedBy == currentUserId);
    final bool canClick = (currentStatus == PropertyStatus.disponible) || isMyLock;

    return BoutonActionPrincipaleLouer(
      isLoading: _isLoadingProperty || userProvider.isLoading,
      // On passe un texte différent si c'est un retour en arrière
      label: isMyLock ? "CONTINUER LA RÉSERVATION" : "RÉSERVER CE LOGEMENT",
      onPressed: !canClick ? null : () {
        if (!userProvider.isAuthenticated) {
          _showError("Veuillez vous connecter pour réserver ce logement.");
        } else if (!isLocataire) {
          final bool isOwner = userProvider.userData?.uid == _currentProperty?.bailleurId;
          _showError(isOwner 
            ? "Vous êtes le propriétaire. Basculez en 'Mode Locataire' pour réserver." 
            : "Basculez en 'Mode Locataire' pour réserver ce logement.");
        } else {
          _ouvrirExpertiseEtReserver();
        }
      },
    );
  }

  Widget _buildArchiveScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey),
              const SizedBox(height: 24),
              const Text("Annonce non disponible", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                "Cette propriété a été archivée par le bailleur ou n'est plus sur le marché pour le moment.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Retourner au Marketplace"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}