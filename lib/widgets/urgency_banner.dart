// lib/widgets/urgency_banner.dart

import 'package:flutter/material.dart';
import '../services/property_service.dart';

class UrgencyBanner extends StatefulWidget {
  final String propertyId; // ID pour écouter les shards
  final String? avgPerformance; // Ex: "24h" ou "2 jours"

  const UrgencyBanner({
    super.key,
    required this.propertyId,
    this.avgPerformance,
  });

  @override
  State<UrgencyBanner> createState() => _UrgencyBannerState();
}

class _UrgencyBannerState extends State<UrgencyBanner> {
  late Stream<int> _viewStream;

  @override
  void initState() {
    super.initState();
    // On initialise le stream une seule fois pour éviter les clignotements au rebuild
    _viewStream = PropertyService().getDistributedCount(widget.propertyId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _viewStream,
      builder: (context, snapshot) {
        // On récupère le nombre de vues des shards (0 par défaut)
        final int views = snapshot.data ?? 0;

        // Logique d'affichage : On cache si peu de vues et pas de stats quartier
        if (views < 5 && widget.avgPerformance == null) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Preuve sociale (Vues en direct issues des shards)
              Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: Colors.orange.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$views personnes consultent ce bien actuellement",
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              // Ligne 2 : Performance historique (Si disponible)
              if (widget.avgPerformance != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: Colors.orange),
                ),
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "⚡ Rare : Dans ce quartier, les biens similaires se louent en moyenne en ${widget.avgPerformance}.",
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}