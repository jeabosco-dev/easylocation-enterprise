// lib/screens/details_propriete_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus; 
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/models/formulaire_publication_model.dart';
import 'package:easylocation_mvp/models/stats_localite_model.dart'; 
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
import 'package:easylocation_mvp/widgets/verification_request_card.dart';
import 'package:easylocation_mvp/widgets/crowd_discount_bar.dart'; 
import 'package:easylocation_mvp/widgets/urgency_banner.dart'; 

class DetailsProprietePage extends StatefulWidget {
  final List<String> propertiesIds;
  final int initialIndex;
  final String? propertyId; 

  const DetailsProprietePage({
    super.key, 
    required this.propertiesIds, 
    required this.initialIndex,
    this.propertyId, 
  });

  @override
  State<DetailsProprietePage> createState() => _DetailsProprietePageState();
}

class _DetailsProprietePageState extends State<DetailsProprietePage> {
  late int _currentIndex;
  late PageController _pageController; 
  final Set<String> _viewedIds = {}; 
  final PropertyService _propertyService = PropertyService(); 
  
  // Cache pour stocker les performances ("24h", etc.) par ID de propriété
  final Map<String, String> _performanceCache = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Déclenchement pour la première propriété affichée
    _triggerUrgencyLogic(widget.propertiesIds[_currentIndex]);
  }

  /// Logique optimisée : Incrément via Shards (Silencieux) + Récupération Stats Quartier
  Future<void> _triggerUrgencyLogic(String propertyId) async {
    // 1. Incrémenter la vue via les Shards (système distribué anti-concurrence)
    // On le fait même si déjà vu dans la session pour compter chaque ouverture de page
    _propertyService.incrementViewOptimized(propertyId);

    // Si on a déjà les stats de performance en cache pour ce bien, on ne re-interroge pas Firestore
    if (_performanceCache.containsKey(propertyId)) return;

    try {
      // 2. Récupérer les données du bien pour connaître sa localisation précise
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.properties)
          .doc(propertyId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        // 3. Chercher si des stats existent pour ce quartier/commune
        final StatsLocaliteModel? stats = await _propertyService.getLocaliteStats(
          province: data['province'] ?? '',
          ville: data['ville'] ?? '',
          commune: data['commune'] ?? '',
          quartier: data['quartier'] ?? '',
        );

        if (mounted && stats != null) {
          setState(() {
            _performanceCache[propertyId] = "${stats.avgHours}h";
          });
        }
      }
    } catch (e) {
      debugPrint("🚨 Erreur UrgencyLogic : $e");
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // On déclenche la logique pour la nouvelle propriété
    _triggerUrgencyLogic(widget.propertiesIds[index]);
  }

  void _savePropertyToHistory(Property property) async {
    final userProvider = context.read<UserProfileProvider>();
    if (!userProvider.isAuthenticated) return;
    
    FirebaseFirestore.instance
        .collection('historique_locataire')
        .doc(userProvider.userData!.uid)
        .collection('user_history')
        .doc(property.id)
        .set({
          'id': property.id,
          'commune': property.commune,
          'quartier': property.quartier,
          'mainImageUrl': property.mainImageUrl,
          'prix': property.price, 
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void _ouvrirExpertiseEtReserver(Property property) {
    CalculateurExpertise.calculerScore(property);
    final formulaireData = FormulairePublicationModel.fromProperty(property);
    formulaireData.id = property.id; 

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RapportExpertisePage(propriete: formulaireData),
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

    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: widget.propertiesIds.length,
        itemBuilder: (context, index) {
          final String currentId = widget.propertiesIds[index];

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.properties)
                .doc(currentId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Erreur de chargement"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final doc = snapshot.data!;
              if (!doc.exists) return const Center(child: Text("Propriété introuvable"));

              final property = Property.fromMap(doc.data() as Map<String, dynamic>, doc.id);

              if (userProvider.isAuthenticated && userProvider.activeRole == UserRoles.tenant) {
                _savePropertyToHistory(property);
              }

              if (property.status == 'archive') return _buildArchiveScreen();

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
                body: RefreshIndicator(
                  onRefresh: () async => await PropertyService().cleanExpiredReservations(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionImagesPropriete(property: property),
                          const SizedBox(height: 15),

                          const CrowdDiscountBar(), 
                          const SizedBox(height: 15),

                          BarreNavigationPropriete(
                            currentIndex: _currentIndex,
                            totalCount: widget.propertiesIds.length,
                            pageController: _pageController,
                          ),
                          const SizedBox(height: 15),
                          SectionAdressePropriete(property: property),
                          const SizedBox(height: 8),
                          ReferenceBadgeWidget(reference: property.referenceUnique),
                          const SizedBox(height: 20),
                          _buildPriceAndStatusRow(property),

                          // ✅ BANNIÈRE D'URGENCE (Vues en direct via Stream interne + Stats Quartier via Cache)
                          UrgencyBanner(
                            propertyId: property.id, 
                            avgPerformance: _performanceCache[property.id],
                          ),

                          const SizedBox(height: 20),
                          SectionDescriptionDynamique(property: property),
                          const Divider(height: 40),
                          SectionCaracteristiquesPropriete(property: property),
                          
                          const SizedBox(height: 30),
                          const CrowdDiscountBar(), 
                          const SizedBox(height: 10),

                          _buildVisitButton(property, userProvider), 
                          const Divider(height: 50),
                          _buildQuickActions(property, userProvider),
                          const Divider(height: 50),
                          SectionStatistiquesAvis(property: property),
                          const SizedBox(height: 30),
                          SectionProprietesSimilaires(currentProperty: property),
                          
                          if (!property.isVerified) ...[
                            const SizedBox(height: 30),
                            VerificationRequestCard(
                              propertyId: property.id,
                              reference: property.referenceUnique,
                              alreadyRequested: property.hasPriorityRequest ?? false, 
                            ),
                          ],

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
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- Widgets de support (Price, Badges, Buttons, etc.) restent identiques ---
  Widget _buildPriceAndStatusRow(Property property) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            BadgeStatutPropriete(status: property.status),
            if (property.isVerified) ...[
              const SizedBox(width: 8),
              _buildVerifiedBadge(),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                PropertyTypes.getShortLabel(property.typeBien),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${property.price.toStringAsFixed(0)}\$", 
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.w900, 
                color: Theme.of(context).colorScheme.primary,
                height: 1.0,
              )
            ),
            const Text(
              "par mois", 
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)
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
          userRole: userProvider.activeRole ?? UserRoles.tenant, 
          onRefresh: () => setState(() {}),
        ),
        BoutonPartage(property: property),
      ],
    );
  }

  Widget _buildVisitButton(Property property, UserProfileProvider userProvider) {
    final String currentUserId = userProvider.userData?.uid ?? "";
    final bool isLocataire = userProvider.activeRole == UserRoles.tenant;
    
    final String currentStatus = property.status;
    final String? lockedBy = property.lockedBy;

    final bool isMyLock = (currentStatus == PropertyStatus.booking && lockedBy == currentUserId);
    final bool canClick = (currentStatus == PropertyStatus.disponible) || isMyLock;

    return BoutonActionPrincipaleLouer(
      isLoading: userProvider.isLoading,
      label: isMyLock ? "CONTINUER LA RÉSERVATION" : "RÉSERVER CE LOGEMENT",
      onPressed: !canClick ? null : () {
        if (!userProvider.isAuthenticated) {
          _showError("Veuillez vous connecter pour réserver ce logement.");
        } else if (!isLocataire) {
          final bool isOwner = userProvider.userData?.uid == property.bailleurId;
          _showError(isOwner 
            ? "Vous êtes le propriétaire. Basculez en 'Mode Locataire' pour réserver." 
            : "Basculez en 'Mode Locataire' pour réserver ce logement.");
        } else {
          _ouvrirExpertiseEtReserver(property);
        }
      },
    );
  }

  Widget _buildArchiveScreen() {
    return Center(
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