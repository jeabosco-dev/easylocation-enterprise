// lib/screens/maisons_publiees_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/booking_timer_provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/services/config_service.dart';

import 'package:easylocation_mvp/widgets/bouton_filtre_badge.dart';
import 'package:easylocation_mvp/models/filtre_propriete_model.dart';
import 'package:easylocation_mvp/widgets/filtre_avance_bottom_sheet.dart';
import 'package:easylocation_mvp/widgets/crowd_discount_bar.dart';
import 'package:easylocation_mvp/widgets/social_proof_banner.dart';
import 'package:easylocation_mvp/widgets/sticky_section_header.dart';

import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus;
import 'package:easylocation_mvp/services/firestore_service.dart' hide PropertyStatus, FirestoreCollections;
import 'package:easylocation_mvp/services/property_service.dart';
import 'package:easylocation_mvp/widgets/carte_propriete_widget.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';
import 'A_propos_de_nous_page.dart';

class MaisonsPublieesPage extends StatefulWidget {
  const MaisonsPublieesPage({super.key});

  @override
  State<MaisonsPublieesPage> createState() => _MaisonsPublieesPageState();
}

class _MaisonsPublieesPageState extends State<MaisonsPublieesPage> {
  FiltreProprieteModel _filtreActuel = FiltreProprieteModel();
  final List<Property> _properties = [];
  bool _isLoading = false;
  bool _hasMore = true; 
  DocumentSnapshot? _lastDocument; 
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScalingAndData();
      _restoreTimerIfNeeded();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      if (!_isLoading && _hasMore) {
        _fetchProperties();
      }
    }
  }

  Future<void> _initializeScalingAndData() async {
    final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
    final configService = Provider.of<ConfigService>(context, listen: false);

    String villeCible = userProvider.userVille;
    await configService.init(newCity: villeCible);

    _fetchProperties(isInitial: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreTimerIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final reservation = await PropertyService().checkUserActiveReservation(user.uid);

      if (reservation != null && mounted) {
        final timerProvider = Provider.of<BookingTimerProvider>(context, listen: false);
        
        if (timerProvider.isActive && timerProvider.currentPropertyId == reservation['propertyId']) {
          return;
        }

        int remainingSeconds = reservation['remainingSeconds'];
        String propertyId = reservation['propertyId'];
        
        timerProvider.startTimer(
          propertyId, 
          DateTime.now().millisecondsSinceEpoch, 
          null, 
          minutes: (remainingSeconds / 60).ceil()
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⏳ Votre session de réservation est toujours active"),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("🚨 Erreur restauration timer : $e");
    }
  }

  Future<void> _fetchProperties({bool isRefresh = false, bool isInitial = false}) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      if (isRefresh || isInitial) { 
        _properties.clear();
        _hasMore = true;
        _lastDocument = null;
        await PropertyService().cleanExpiredReservations(); 
        await PropertyService().cleanOldRentedProperties();
      }

      final result = await PropertyService().searchProperties(
        _filtreActuel,
        lastDocument: _lastDocument,
      );

      final properties = result["properties"];
      if (properties is! List<Property>) {
        throw Exception("searchProperties() a retourné un résultat invalide.");
      }

      final List<Property> newProperties = properties;
      final DocumentSnapshot? nextLastDocument = result["lastDocument"] as DocumentSnapshot?;

      if (mounted) {
        setState(() {
          if (newProperties.isEmpty) {
            _hasMore = false;
          } else {
            _properties.addAll(newProperties);
            _lastDocument = nextLastDocument;
          }
        });
      }
    } catch (e) {
      debugPrint("🚨 Erreur lors de la récupération : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFilterSheet() async {
    final result = await showModalBottomSheet<FiltreProprieteModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FiltreAvanceBottomSheet(initialFiltre: _filtreActuel),
    );

    if (result != null) {
      setState(() {
        _filtreActuel = result;
      });
      _fetchProperties(isRefresh: true);
    }
  }

  Map<String, List<Property>> _groupProperties() {
    final Map<String, List<Property>> grouped = {
      PropertyStatus.disponible: [],
      PropertyStatus.booking: [],
      PropertyStatus.enAttentePaiement: [],
      PropertyStatus.reserved: [],
      PropertyStatus.rented: [],
    };

    for (var property in _properties) {
      if (grouped.containsKey(property.status)) {
        grouped[property.status]!.add(property);
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            children: [
              const TextSpan(text: 'Easy '),
              TextSpan(text: 'Marketplace', style: TextStyle(color: Colors.blue[800])),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
            child: BoutonFiltreBadge(
              count: _filtreActuel.activeFiltersCount, 
              onTap: _openFilterSheet,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline), 
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AProposDeNousPage()))
          ),
        ],
      ),
      body: Column(
        children: [
          const CrowdDiscountBar(), 
          const SocialProofBanner(),
          _buildActiveFiltersBadge(),
          _buildResultCountBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchProperties(isRefresh: true),
              child: _isLoading && _properties.isEmpty
                  ? _buildSkeletonLoader() 
                  : (_properties.isEmpty ? _buildEmptyState() : _buildListView()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    final grouped = _groupProperties();
    final sections = [
      PropertyStatus.disponible, 
      PropertyStatus.booking, 
      PropertyStatus.enAttentePaiement, 
      PropertyStatus.reserved, 
      PropertyStatus.rented
    ];

    Map<String, dynamic> getSectionMeta(String status) {
      switch (status) {
        case PropertyStatus.disponible: return {"title": "DISPONIBLES", "color": Colors.green, "icon": Icons.home_work};
        case PropertyStatus.booking: return {"title": "EN COURS", "color": Colors.orange, "icon": Icons.timer};
        case PropertyStatus.enAttentePaiement: return {"title": "PAIEMENTS", "color": Colors.blue, "icon": Icons.payments};
        case PropertyStatus.reserved: return {"title": "RÉSERVÉS", "color": Colors.purple, "icon": Icons.lock};
        case PropertyStatus.rented: return {"title": "LOUÉS", "color": Colors.red, "icon": Icons.key};
        default: return {"title": "AUTRES", "color": Colors.grey, "icon": Icons.info};
      }
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ...sections.expand((status) {
          final list = grouped[status] ?? [];
          if (list.isEmpty) return [const SliverToBoxAdapter(child: SizedBox.shrink())];

          final meta = getSectionMeta(status);

          return [
            SliverPersistentHeader(
              pinned: true,
              delegate: StickySectionHeader(
                title: meta["title"],
                icon: meta["icon"],
                color: meta["color"],
                count: list.length,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => CarteProprieteWidget(
                  property: list[index],
                  index: index,
                  allPropertiesIds: _properties.map((p) => p.id).toList()
                ),
                childCount: list.length,
              ),
            ),
          ];
        }),
        if (_hasMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildResultCountBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _isLoading && _properties.isEmpty ? "Exploration..." : "${_properties.length} propriétés", 
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800], fontSize: 14)
          ),
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 14, color: Colors.blue[700]),
              const SizedBox(width: 4),
              Text("Garantie Easy", style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 3,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
        const SizedBox(height: 20),
        const Center(child: Text("Aucun résultat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("Essayez de modifier vos filtres ou la zone de recherche.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
        Center(
          child: ElevatedButton(
            onPressed: () { 
              setState(() => _filtreActuel.reset()); 
              _fetchProperties(isRefresh: true); 
            },
            child: const Text("Réinitialiser"),
          ),
        )
      ],
    );
  }

  Widget _buildActiveFiltersBadge() {
    if (!_filtreActuel.hasActiveFilters) return const SizedBox.shrink();
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_filtreActuel.province != null && _filtreActuel.province != "Toutes") 
             _buildFilterChip(_filtreActuel.province!, () { 
               setState(() => _filtreActuel.province = "Toutes"); 
               _fetchProperties(isRefresh: true); 
             }),
          if (_filtreActuel.ville != null && _filtreActuel.ville != "Toutes")
             _buildFilterChip(_filtreActuel.ville == "Autre" ? _filtreActuel.villeSpecifique ?? "Ville" : _filtreActuel.ville!, () {
               setState(() => _filtreActuel.ville = "Toutes");
               _fetchProperties(isRefresh: true);
             }),
          if (_filtreActuel.maxPrice != null)
             _buildFilterChip("Budget Max: ${_filtreActuel.maxPrice}\$", () {
               setState(() => _filtreActuel.maxPrice = null);
               _fetchProperties(isRefresh: true);
             }),
          if (_filtreActuel.nbChambres != null)
             _buildFilterChip("${_filtreActuel.nbChambres == 4 ? '4+' : _filtreActuel.nbChambres} Chambres", () {
               setState(() => _filtreActuel.nbChambres = null);
               _fetchProperties(isRefresh: true);
             }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)), 
        onDeleted: onDeleted,
        deleteIconColor: Colors.blue[800],
        backgroundColor: const Color(0xFFF0F7FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}