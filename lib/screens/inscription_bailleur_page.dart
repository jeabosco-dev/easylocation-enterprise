import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easylocation_mvp/screens/verification_otp_page.dart';
import 'package:easylocation_mvp/screens/connexion_page.dart';
import 'package:easylocation_mvp/utils/validations.dart';
import 'package:easylocation_mvp/screens/mentions_legales_page.dart';
import 'package:easylocation_mvp/services/auth_service.dart'; 
import 'package:easylocation_mvp/utils/phone_utils.dart';

class InscriptionBailleurPage extends StatefulWidget {
  const InscriptionBailleurPage({super.key});

  @override
  State<InscriptionBailleurPage> createState() => _InscriptionBailleurPageState();
}

class _InscriptionBailleurPageState extends State<InscriptionBailleurPage> with Validations {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService(); 

  final FocusNode _telFocusNode = FocusNode();

  final _nomCtrl = TextEditingController();
  final _postnomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  String? _genre;
  bool _isLoading = false;
  bool _isAccepted = false;

  @override
  void dispose() {
    _telFocusNode.dispose();
    _nomCtrl.dispose();
    _postnomCtrl.dispose();
    _prenomCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }
  
  Map<String, dynamic> _getNavigationArguments(String fullPhoneNumber) {
    return {
      'estInscription': true,
      'estLocataire': false, 
      'nom': _nomCtrl.text.trim(),
      'postnom': _postnomCtrl.text.trim(),
      'prenom': _prenomCtrl.text.trim(),
      'genre': _genre!,
      'telephone': fullPhoneNumber,
      'email': _emailCtrl.text.trim(),
      // Envoi de chaînes vides pour respecter le contrat de données sans collecter l'info
      'numeroMaison': '',
      'avenue': '',
      'quartier': '',
      'commune': '',
    };
  }

  Future<void> _submitAndSendOtp() async {
    if (_isLoading) return; 
    
    if (_formKey.currentState?.validate() != true) return;
    
    if (_genre == null) {
      _showError('Veuillez sélectionner votre genre');
      return;
    }

    if (!_isAccepted) {
      _showError('Veuillez accepter les mentions légales');
      return;
    }

    final fullPhoneNumber = normalizePhoneNumber(_telCtrl.text); 
    setState(() => _isLoading = true);

    try {
      await _authService.checkRegistrationAvailability(fullPhoneNumber);
      final args = _getNavigationArguments(fullPhoneNumber);

      await _authService.verifyNewPhoneNumber(
        phoneNumber: fullPhoneNumber,
        onVerificationCompleted: (PhoneAuthCredential credential) {
          if (mounted) _navigateToOtp(args, credential, 'auto_verified');
        },
        onVerificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            _handleAuthError(e);
            setState(() => _isLoading = false);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) _navigateToOtp(args, null, verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } on UiException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showExistingUserDialog(fullPhoneNumber, e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Une erreur inattendue est survenue.');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showExistingUserDialog(String phone, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Compte déjà existant", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _telCtrl.clear();
              FocusScope.of(this.context).requestFocus(_telFocusNode);
            },
            child: const Text("Modifier le numéro"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (context) => const ConnexionPage())
              );
            },
            child: const Text("Se connecter"),
          ),
        ],
      ),
    );
  }

  void _navigateToOtp(Map<String, dynamic> args, PhoneAuthCredential? cred, String vid) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationOtpPage(
          verificationId: vid,
          autoCredential: cred,
          estInscription: args['estInscription'],
          estLocataire: args['estLocataire'],
          nom: args['nom'],
          postnom: args['postnom'],
          prenom: args['prenom'],
          genre: args['genre'],
          telephone: args['telephone'],
          email: args['email'],
          numeroMaison: args['numeroMaison'],
          avenue: args['avenue'],
          quartier: args['quartier'],
          commune: args['commune'],
        ),
      ),
    );
  }

  void _handleAuthError(FirebaseAuthException e) {
    String msg = 'Erreur lors de l\'envoi du SMS.';
    if (e.code == 'invalid-phone-number') msg = 'Le numéro saisi est invalide.';
    if (e.code == 'too-many-requests') msg = 'Trop de tentatives. Réessayez plus tard.';
    _showError(msg);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.orange[800])
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inscription — Bailleur"),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle("Informations personnelles"),
                
                _buildTextField(_nomCtrl, "Nom", "Ex. : N’shuti", 
                    validator: (v) => requiredField(v, 'le nom')),
                const SizedBox(height: 12),
                
                _buildTextField(_postnomCtrl, "Postnom", "Ex. : Bahati", 
                    validator: (v) => requiredField(v, 'le postnom')),
                const SizedBox(height: 12),
                
                _buildTextField(_prenomCtrl, "Prénom (Optionnel)", "Ex. : Amani"),
                const SizedBox(height: 12),
                
                _buildGenreField(),
                const SizedBox(height: 12),
                
                _buildPhoneField(),
                const SizedBox(height: 12),
                
                _buildTextField(_emailCtrl, "Email (Optionnel)", "Ex. : nom@domaine.com", 
                    keyboard: TextInputType.emailAddress, validator: emailOptional),
                
                const SizedBox(height: 32),
                
                _buildConsentCheckbox(),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (_isAccepted && !_isLoading) ? _submitAndSendOtp : null,
                    icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline),
                    label: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Vérifier et s'inscrire", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String hint, {TextInputType keyboard = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label, 
        hintText: hint, 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: keyboard,
      validator: validator,
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _telCtrl,
      focusNode: _telFocusNode,
      decoration: InputDecoration(
        labelText: 'Téléphone',
        prefixText: '+243 ',
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        helperText: '9 chiffres sans le 0 initial',
      ),
      keyboardType: TextInputType.phone,
      validator: validatePhoneNumber,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
    );
  }

  Widget _buildGenreField() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Genre', 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      value: _genre,
      items: const [
        DropdownMenuItem(value: 'Homme', child: Text('Homme')),
        DropdownMenuItem(value: 'Femme', child: Text('Femme')),
      ],
      onChanged: (value) => setState(() => _genre = value),
      validator: (value) => value == null ? 'Sélectionnez votre genre' : null,
    );
  }

  Widget _buildConsentCheckbox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: _isAccepted,
              onChanged: (v) => setState(() => _isAccepted = v ?? false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: 'J\'accepte les ',
                style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.5),
                children: [
                  _linkText('Conditions Générales d\'Utilisation', 'assets/legal/cgu.md'),
                  const TextSpan(text: ', la '),
                  _linkText('Politique de Confidentialité', 'assets/legal/politique_confidentialite.md'),
                  const TextSpan(text: ' et la '),
                  _linkText('Politique de Paiement', 'assets/legal/politique_paiement.md'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _linkText(String label, String path) {
    return TextSpan(
      text: label,
      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()
        ..onTap = () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MentionsLegalesPage(documentPath: path, pageTitle: label)),
        ),
    );
  }
}
