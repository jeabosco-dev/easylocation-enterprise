import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

class ChangementPasswordDialog extends StatefulWidget {
  const ChangementPasswordDialog({super.key});

  @override
  State<ChangementPasswordDialog> createState() => _ChangementPasswordDialogState();
}

class _ChangementPasswordDialogState extends State<ChangementPasswordDialog> {
  final _ancienPasswordController = TextEditingController();
  final _nouveauPasswordController = TextEditingController();
  final _confirmationPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureAncien = true;
  bool _obscureNouveau = true;
  bool _obscureConfirme = true;

  @override
  void dispose() {
    _ancienPasswordController.dispose();
    _nouveauPasswordController.dispose();
    _confirmationPasswordController.dispose();
    super.dispose();
  }

  Future<void> _modifierMotDePasse() async {
    final ancienPassword = _ancienPasswordController.text.trim();
    final nouveauPassword = _nouveauPasswordController.text.trim();
    final confirmationPassword = _confirmationPasswordController.text.trim();

    if (ancienPassword.isEmpty || nouveauPassword.isEmpty || confirmationPassword.isEmpty) {
      _showSnackBar("Veuillez remplir tous les champs", Colors.orange);
      return;
    }

    if (nouveauPassword != confirmationPassword) {
      _showSnackBar("La confirmation ne correspond pas au nouveau mot de passe.", Colors.red);
      return;
    }
    
    if (nouveauPassword.length < 6) {
      _showSnackBar("Le mot de passe doit contenir au moins 6 caractères.", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        _showSnackBar("Erreur : Aucun utilisateur connecté via Auth.", Colors.red);
        return;
      }

      // Recherche du document dans la collection avec l'UID de Firebase Auth
      DocumentReference userRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.utilisateurs) // ✅ Utilisé la constante de collection
          .doc(currentUser.uid);
          
      DocumentSnapshot userDoc = await userRef.get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        // ✅ ALIGNÉ : Récupération via la constante centralisée
        final String savedPassword = data[UserFields.passwordBackoffice] ?? '';

        if (savedPassword != ancienPassword) {
          _showSnackBar("L'ancien mot de passe est incorrect.", Colors.red);
          return;
        }

        // ✅ ALIGNÉ : Mise à jour sécurisée dans Firestore via UserFields
        await userRef.update({
          UserFields.passwordBackoffice: nouveauPassword,
        });

        if (mounted) {
          _showSnackBar("Mot de passe modifié avec succès !", Colors.green);
          Navigator.of(context).pop(); // Ferme la boîte de dialogue
        }
      } else {
        _showSnackBar("Impossible de trouver votre profil utilisateur.", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Une erreur est survenue lors de la modification.", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.lock_reset, color: Color(0xFF1E293B), size: 28),
          const SizedBox(width: 10),
          const Text("Modifier mon mot de passe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Container(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min, // ✅ Placé ici : s'adapte à la taille du contenu
          children: [
            _buildPasswordField(
              controller: _ancienPasswordController,
              label: "Mot de passe actuel",
              obscureText: _obscureAncien,
              onToggle: () => setState(() => _obscureAncien = !_obscureAncien),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _nouveauPasswordController,
              label: "Nouveau mot de passe",
              obscureText: _obscureNouveau,
              onToggle: () => setState(() => _obscureNouveau = !_obscureNouveau),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmationPasswordController,
              label: "Confirmer le nouveau mot de passe",
              obscureText: _obscureConfirme,
              onToggle: () => setState(() => _obscureConfirme = !_obscureConfirme),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text("ANNULER", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _modifierMotDePasse,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading 
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("VALIDER"),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Colors.blueGrey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: const Icon(Icons.key, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: onToggle,
        ),
      ),
    );
  }
}