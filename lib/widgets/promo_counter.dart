import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCounter extends StatelessWidget {
  final String promoId;

  const PromoCounter({super.key, required this.promoId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('promotions').doc(promoId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox();
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();

        var data = snapshot.data!.data() as Map<String, dynamic>;
        
        int limit = data['usage_limit'] ?? 0;
        int count = data['usage_count'] ?? 0;
        
        if (limit <= 0) return const SizedBox();

        int restants = limit - count;
        double progression = (count / limit).clamp(0.0, 1.0);

        if (restants <= 0) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Désolé, cette offre est victime de son succès !",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50]!.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "OFFRE LIMITÉE",
                        style: TextStyle(
                          color: Colors.red[700],
                          // ✅ CORRECTION ICI : FontWeight.w900 au lieu de FontWeight.black
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "$restants places restantes",
                    style: TextStyle(
                      color: Colors.red[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progression,
                  minHeight: 10,
                  backgroundColor: Colors.red[100],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red[700]!),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Dépêchez-vous, premier arrivé, premier servi !",
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      },
    );
  }
}