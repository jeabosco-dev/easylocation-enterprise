import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VerrouCodeConduite {
  static void afficherEngagement(BuildContext context, String userUid) {
    showDialog(
      context: context,
      barrierDismissible: false, // L'agent NE PEUT PAS fermer sans signer
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gpp_good, color: Colors.blue),
            SizedBox(width: 10),
            Text("Engagement Éthique"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "En tant qu'agent de EasyLocation, vous avez accès à des données sensibles (Contacts propriétaires, prix négociés, documents).\n",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Divider(),
              _regleItem("Confidentialité", "Je m'engage à ne jamais partager les numéros des clients hors de l'agence."),
              _regleItem("Intégrité", "Je m'interdis toute transaction directe avec un client sans passer par l'agence."),
              _regleItem("Protection", "Toute fuite de données peut entraîner des poursuites et une révocation d'accès."),
              const SizedBox(height: 15),
              const Text(
                "En cliquant sur 'J'ACCEPTE', vous certifiez l'exactitude de cet engagement.",
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              minimumSize: const Size(double.infinity, 45),
            ),
            onPressed: () async {
              // Mise à jour de Firestore
              String dateAujourdhui = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
              
              await FirebaseFirestore.instance.collection('utilisateurs').doc(userUid).update({
                'certification_conduite': true,
                'date_signature': dateAujourdhui,
              });

              Navigator.pop(context); // Ferme le popup et libère l'accès
            },
            child: const Text("J'ACCEPTE ET JE M'ENGAGE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static Widget _regleItem(String titre, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 12),
                children: [
                  TextSpan(text: "$titre : ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
