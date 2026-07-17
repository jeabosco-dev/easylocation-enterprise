import 'package:flutter/material.dart';

/// ============================================================================
/// StickySectionHeader
/// ----------------------------------------------------------------------------
/// En-tête de section utilisé avec SliverPersistentHeader.
/// ============================================================================

class StickySectionHeader extends SliverPersistentHeaderDelegate {
  final String title;
  final IconData icon;
  final Color color;
  final int count;

  StickySectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
  });

  static const double _headerHeight = 58;

  @override
  double get minExtent => _headerHeight;

  @override
  double get maxExtent => _headerHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.25),
          ),
          boxShadow: [
            if (overlapsContent)
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              // --- CORRECTION DU BADGE ICI ---
              Container(
                constraints: const BoxConstraints(
                  minWidth: 26, // Assure une largeur minimale pour un cercle
                  minHeight: 26, // Assure une hauteur minimale pour un cercle
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center, // Centre parfaitement le chiffre
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant StickySectionHeader oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.icon != icon ||
        oldDelegate.color != color ||
        oldDelegate.count != count;
  }
}