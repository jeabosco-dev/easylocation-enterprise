import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easylocation_mvp/services/delete_account_service.dart';
import '../screens/onboarding_page.dart';

class DeleteAccountDialog extends StatefulWidget {
  final String userRole;
  const DeleteAccountDialog({Key? key, required this.userRole}) : super(key: key);

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final DeleteAccountService _deleteService = DeleteAccountService();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _deleteService.deleteUserAccount(
        reason: _reasonController.text,
        role: widget.userRole,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre compte a été supprimé avec succès. Au plaisir de vous revoir ! 👋'),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnboardingPage()),
          (Route<dynamic> route) => false,
        );
      }
    } on Exception catch (e) {
      String message;
      if (e.toString().contains('re-login')) {
        message = 'Veuillez vous reconnecter pour supprimer votre compte. C\'est une mesure de sécurité.';
        Navigator.of(context).pop();
      } else {
        message = 'Une erreur est survenue lors de la suppression: ${e.toString()}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le reste du code du widget AlertDialog est le même
    return AlertDialog(
      title: const Text("Supprimer votre compte"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Nous sommes désolés de vous voir partir. Votre avis est précieux. Pouvez-vous nous dire pourquoi vous souhaitez supprimer votre compte ?",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Entrez votre raison ici...",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez expliquer votre raison.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                "Attention : Cette action est irréversible et supprimera toutes vos données liées à ce compte.",
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleDeleteAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text("Confirmer la suppression"),
        ),
      ],
    );
  }
}
