// lib/pages/maisons_publiees_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:provider/provider.dart'; 
import 'package:easylocation_mvp/providers/booking_timer_provider.dart'; 

// ✅ Imports pour les nouveaux widgets et modèles
import 'package:easylocation_mvp/widgets/bouton_filtre_badge.dart'; // <-- TON NOUVEAU WIDGET
import 'package:easylocation_mvp/models/filtre_propriete_model.dart'; 
import 'package:easylocation_mvp/widgets/filtre_avance_bottom_sheet.dart'; 

import 'package:easylocation_mvp/models/property_model.dart' hide PropertyStatus; 
import 'package:easylocation_mvp/services/firestore_service.dart' hide PropertyStatus, FirestoreCollections; 
import 'package:easylocation_mvp/services/property_service.dart'; 
import 'package:easylocation_mvp/widgets/carte_propriete_widget.dart';
import 'package:easylocation_mvp/constants/constants.dart'; 
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
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchProperties(isInitial: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreTimerIfNeeded();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreTimerIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reservation = await PropertyService().checkUserActiveReservation(user.uid);

    if (reservation != null && mounted) {
      final timerProvider = Provider.of<BookingTimerProvider>(context, listen: false);
      
      int remainingSeconds = reservation['remainingSeconds'];
      String propertyId = reservation['propertyId'];
      
      timerProvider.startTimer(
        propertyId, 
        DateTime.now().millisecondsSinceEpoch, 
        minutes: (remainingSeconds / 60).ceil()
      );
    }
  }

  Future<void> _fetchProperties({bool isRefresh = false, bool isInitial = false}) async {
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      if (isRefresh || isInitial) { 
        await PropertyService().cleanExpiredReservations(); 
      }

      // ✅ Utilise le PropertyService avec tous les nouveaux filtres (chambres, elec, etc.)
      final resultats = await PropertyService().searchProperties(_filtreActuel);

      if (mounted) {
        setState(() {
          _properties.clear();
          _properties.addAll(resultats);
        });
      }
    } catch (e) {
      debugPrint("🚨 Erreur lors de la récupération : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Logique d'ouverture avec récupération du résultat
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
              TextSpan(
                text: 'Marketplace', 
                style: TextStyle(color: Colors.blue[800]), 
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // ✅ APPEL DE TON NOUVEAU WIDGET ICI
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

  // (Le reste de tes méthodes _buildListView, _buildEmptyState, etc. reste identique)

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _properties.length,
      itemBuilder: (context, index) {
        return CarteProprieteWidget(
          property: _properties[index], 
          index: index, 
          allPropertiesIds: _properties.map((p) => p.id).toList()
        );
      },
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
            _isLoading ? "Exploration du Market..." : "${_properties.length} offres disponibles", 
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800], fontSize: 14)
          ),
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 14, color: Colors.blue[700]),
              const SizedBox(width: 4),
              Text(
                "Garantie Easy", 
                style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.bold)
              ),
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
    if (!_filtreActuel.isAnyFilterActive()) return const SizedBox.shrink();
    
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
