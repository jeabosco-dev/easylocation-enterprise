// lib/widgets/section_images_propriete.dart

import 'package:flutter/material.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SectionImagesPropriete extends StatefulWidget {
  final Property property;

  const SectionImagesPropriete({super.key, required this.property});

  @override
  State<SectionImagesPropriete> createState() => _SectionImagesProprieteState();
}

class _SectionImagesProprieteState extends State<SectionImagesPropriete> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Identifie dynamiquement le nom de la pièce selon l'URL affichée
  String _getImageLabel(String url) {
    final p = widget.property;

    if (url == p.mainImageUrl) return "Vue principale";
    
    // Vérification dans les images des chambres
    if (p.chambresImageUrls.isNotEmpty && p.chambresImageUrls.contains(url)) {
      if (p.chambresImageUrls.length == 1) return "Chambre";
      return "Chambre ${p.chambresImageUrls.indexOf(url) + 1}";
    }

    // Vérification dans les images spécifiques (Salon, Cuisine, etc.)
    if (p.specificImageUrls.isNotEmpty && p.specificImageUrls.containsValue(url)) {
      try {
        String key = p.specificImageUrls.entries
            .firstWhere((entry) => entry.value == url)
            .key;

        switch (key) {
          case 'salonImage': return "Salon";
          case 'cuisineImage': return "Cuisine";
          case 'toiletteParentaleImage': return "Toilette Parentale";
          case 'garageImage': return "Garage";
          case 'depotImage': return "Dépôt";
          case 'courRecreationImage': return "Cour de récréation";
          default: return "Aperçu";
        }
      } catch (e) {
        return "Aperçu";
      }
    }
    return "Aperçu";
  }

  @override
  Widget build(BuildContext context) {
    // Fusion et filtrage des URLs (Image principale + Galerie)
    final List<String> allImages = [
      if (widget.property.mainImageUrl != null && widget.property.mainImageUrl!.isNotEmpty) 
        widget.property.mainImageUrl!,
      ...widget.property.imageUrls
    ].where((url) => url.isNotEmpty && url.startsWith('http')).toSet().toList();

    if (allImages.isEmpty) {
      return _buildPlaceholder();
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // --- VISIONNEUSE PRINCIPALE ---
            SizedBox(
              height: 280,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: allImages.length,
                  onPageChanged: (index) => setState(() => _currentImageIndex = index),
                  itemBuilder: (context, index) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // IMAGE AVEC MISE EN CACHE PRO (Pleine résolution pour l'affichage principal)
                        CachedNetworkImage(
                          imageUrl: allImages[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[100],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => _buildErrorWidget(),
                        ),
                        _buildWatermark(),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Label dynamique (Haut Gauche) - ex: "Salon"
            Positioned(
              top: 15,
              left: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getImageLabel(allImages[_currentImageIndex]),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Compteur de photos (Haut Droite)
            if (allImages.length > 1)
              Positioned(
                top: 15,
                right: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${_currentImageIndex + 1} / ${allImages.length}",
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),

            // Indicateur de points (Bas)
            if (allImages.length > 1)
              Positioned(
                bottom: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(allImages.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: _currentImageIndex == index ? 16 : 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(_currentImageIndex == index ? 1.0 : 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
        
        // --- GALERIE DE MINIATURES (SCROLLABLE) ---
        if (allImages.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              height: 55,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allImages.length,
                itemBuilder: (context, index) {
                  bool isSelected = _currentImageIndex == index;
                  return GestureDetector(
                    onTap: () => _pageController.animateToPage(index, 
                        duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      width: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: allImages[index],
                          fit: BoxFit.cover,
                          // ✅ OPTIMISATION MÉMOIRE : Redimensionne l'image en mémoire pour les vignettes
                          memCacheWidth: 150, 
                          errorWidget: (context, url, error) => const Icon(Icons.error, size: 20),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // --- WIDGETS DE SECOURS ---

  Widget _buildPlaceholder() {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey),
          SizedBox(height: 10),
          Text("Aucune photo disponible", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40)),
    );
  }

  Widget _buildWatermark() {
    return Center(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.15,
          child: RotationTransition(
            turns: const AlwaysStoppedAnimation(-35 / 360),
            child: const Text(
              "EasyLocation\n+243 972 129 520",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
