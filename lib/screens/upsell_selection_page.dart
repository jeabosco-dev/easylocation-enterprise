// lib/screens/upsell_selection_page.dart
import 'package:flutter/material.dart';
import '../widgets/services_carousel_widget.dart';

class UpsellSelectionPage extends StatelessWidget {
  static const String routeName = '/upsell-selection';

  const UpsellSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Ajout d'un visuel de succès
            const Icon(Icons.celebration_rounded, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "Félicitations !",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              child: Text(
                "Votre visite est validée. Pour vous simplifier la vie, voici nos services partenaires recommandés pour votre emménagement :",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ),
            
            // Carousel de services
            const Expanded(
              child: ServicesCarouselWidget(provenance: 'POST_RESERVATION'),
            ),
            
            // Bouton d'action principal
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("TERMINER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}