import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AideSupportPage extends StatefulWidget {
  const AideSupportPage({super.key});

  @override
  State<AideSupportPage> createState() => _AideSupportPageState();
}

class _AideSupportPageState extends State<AideSupportPage> {
  final _nomDisplayCtrl = TextEditingController(); 
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _prefillUserData();
  }

  void _prefillUserData() {
    final userData = Provider.of<UserProfileProvider>(context, listen: false).userData;
    if (userData != null) {
      _nomDisplayCtrl.text = "${userData.prenom} ${userData.nom}";
      _emailCtrl.text = userData.email ?? "";
      _phoneCtrl.text = userData.telephone;
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "L'email est requis";
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return "Format d'email invalide";
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return "Le téléphone est requis";
    if (value.length < 9) return "Numéro trop court";
    return null;
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final userData = Provider.of<UserProfileProvider>(context, listen: false).userData;

    try {
      final Map<String, dynamic> payload = {
        'nom': userData?.nom ?? '',
        'prenom': userData?.prenom ?? '',
        'postNom': userData?.postnom ?? '', 
        'email': _emailCtrl.text.trim(),
        'telephone': _phoneCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
      };

      // ✅ MODIFICATION : Pointage vers la région europe-west1
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('sendSupportEmail')
          .call(payload);

      final bool isSuccess = result.data != null && (result.data['success'] == true);

      if (mounted) {
        if (isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Message envoyé avec succès !"), 
              backgroundColor: Colors.green
            ),
          );
          
          // Retour automatique à l'écran précédent après le succès
          Navigator.pop(context);
          
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Réponse serveur : ${result.data['message'] ?? 'Erreur inconnue'}")),
          );
        }
      }
    } on FirebaseFunctionsException catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace, withScope: (scope) {
        scope.setTag('function_error_code', e.code);
        scope.setContexts('function_details', e.details ?? {});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur Serveur : ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Une erreur imprévue est survenue."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Aide & Support")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Comment pouvons-nous vous aider ?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildField(_nomDisplayCtrl, "Votre Nom complet", Icons.person, readOnly: true),
                  _buildField(_emailCtrl, "Votre Email", Icons.email, validator: _validateEmail),
                  _buildField(_phoneCtrl, "Votre Téléphone", Icons.phone, validator: _validatePhone),
                  const Divider(height: 40),
                  const Text("Détails de votre demande", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _messageCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: "Décrivez votre problème ici...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? "Veuillez saisir un message" : null,
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                      child: const Text("ENVOYER LE MESSAGE", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool readOnly = false, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        readOnly: readOnly,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueGrey),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
