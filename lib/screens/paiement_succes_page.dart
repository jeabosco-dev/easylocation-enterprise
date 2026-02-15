// lib/screens/paiement_succes_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/facture_model.dart';
import '../services/pdf_service.dart';
import '../providers/user_profile_provider.dart';

class PaiementSuccesPage extends StatefulWidget {
  const PaiementSuccesPage({super.key});

  @override
  State<PaiementSuccesPage> createState() => _PaiementSuccesPageState();
}

class _PaiementSuccesPageState extends State<PaiementSuccesPage> {
  bool _isSaving = true;

  @override
  void initState() {
    super.initState();
    // On lance l'enregistrement automatique dès l'affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enregistrerFactureFirestore();
    });
  }

  /// ✅ ENREGISTREMENT AUTOMATIQUE DANS FIRESTORE (Version Harmonisée)
  Future<void> _enregistrerFactureFirestore() async {
    final provider = context.read<UserProfileProvider>();
    final facture = provider.lastFactureGenere;

    if (facture == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    try {
      // HARMONISATION : On prépare les données pour l'historique permanent
      final Map<String, dynamic> dataToSave = facture.toMap();
      
      // On force le statut en 'validé' car nous sommes sur la page de succès
      dataToSave['statut'] = 'validé';
      dataToSave['paymentStatus'] = 'validé'; 
      
      // On s'assure que la date est exploitable pour le tri de l'historique
      dataToSave['dateCreation'] = DateTime.now().toIso8601String();

      await FirebaseFirestore.instance
          .collection('factures')
          .add(dataToSave);
      
      debugPrint("✅ Facture enregistrée comme 'validé' dans Firestore");
    } catch (e) {
      debugPrint("🚨 Erreur enregistrement facture : $e");
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProfileProvider>();
    final FactureModel? facture = userProvider.lastFactureGenere;
    final double taux = userProvider.tauxChange;

    if (facture == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _quitterEtNettoyer(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 120),
              const SizedBox(height: 25),
              const Text(
                "Paiement Confirmé !",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                "Votre réservation a été enregistrée avec succès. Notre équipe va vous contacter pour la remise des clés.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 15),
              ),
              const SizedBox(height: 40),

              // ✅ INDICATEUR DE SAUVEGARDE CLOUD
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _isSaving ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text("Sécurisation du reçu...", 
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400)),
                    ],
                  ),
                ),
              ),

              _buildActionButton(
                context,
                label: "SAUVEGARDER MON REÇU",
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFF0D47A1),
                onPressed: () {
                  PdfService.genererEtPartagerFacture(
                    facture,
                    estPaye: true,
                    tauxApplique: taux,
                  );
                },
              ),

              const SizedBox(height: 15),

              _buildActionButton(
                context,
                label: "PARTAGER LE REÇU",
                icon: Icons.share_rounded,
                color: Colors.green.shade700,
                onPressed: () {
                  PdfService.genererEtPartagerFacture(
                    facture,
                    estPaye: true,
                    tauxApplique: taux,
                  );
                },
              ),

              const SizedBox(height: 50),

              SizedBox(
                width: 200,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _quitterEtNettoyer(context),
                  child: Text(
                    "RETOUR À L'ACCUEIL",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _quitterEtNettoyer(BuildContext context) {
    context.read<UserProfileProvider>().setLastFacture(null);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildActionButton(BuildContext context,
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
