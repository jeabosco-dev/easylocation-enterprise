import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importation nécessaire
import 'package:easylocation_mvp/services/auth_service.dart';

class BoutonLiaisonAdminWidget extends StatefulWidget {
  const BoutonLiaisonAdminWidget({super.key});

  @override
  State<BoutonLiaisonAdminWidget> createState() => _BoutonLiaisonAdminWidgetState();
}

class _BoutonLiaisonAdminWidgetState extends State<BoutonLiaisonAdminWidget> {
  bool _isLinking = false;

  Future<void> _effectuerLiaison() async {
    setState(() => _isLinking = true);
    
    try {
      final authService = AuthService();
      
      // RÉCUPÉRATION SÉCURISÉE DEPUIS LE FICHIER .ENV
      // On utilise dotenv.get() pour lire les valeurs définies dans ton fichier C:\Users\LANGE\easylocation_mvp\.env
      final String adminEmail = dotenv.get('ADMIN_EMAIL', fallback: "");
      final String adminPassword = dotenv.get('ADMIN_PASSWORD', fallback: "");

      if (adminEmail.isEmpty || adminPassword.isEmpty) {
        throw Exception("Identifiants admin introuvables dans le fichier .env");
      }

      // EXÉCUTION DE LA LIAISON
      await authService.linkEmailToPhoneAccount(
        email: adminEmail,
        password: adminPassword, 
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Succès ! Ton accès Web est activé."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Erreur : ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurple.shade100, width: 2),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded, color: Colors.deepPurple, size: 20),
              SizedBox(width: 8),
              Text(
                "PANNEAU DE CONFIGURATION ADMIN",
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: _isLinking 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.admin_panel_settings),
              label: Text(_isLinking ? "Liaison en cours..." : "ACTIVER MON ACCÈS ADMIN"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _isLinking ? null : _effectuerLiaison,
            ),
          ),
        ],
      ),
    );
  }
}
