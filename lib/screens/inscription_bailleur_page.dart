// lib/screens/inscription_bailleur_page.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easylocation_mvp/screens/verification_otp_page.dart';
import 'package:easylocation_mvp/screens/connexion_page.dart';
import 'package:easylocation_mvp/utils/validations.dart';
import 'package:easylocation_mvp/screens/mentions_legales_page.dart';
import 'package:easylocation_mvp/utils/phone_utils.dart';
import 'package:easylocation_mvp/services/auth_service.dart';
import 'package:easylocation_mvp/services/user_service.dart';
import 'package:easylocation_mvp/services/location_service.dart';
import 'package:easylocation_mvp/widgets/ville_dropdown_field.dart';

class InscriptionBailleurPage extends StatefulWidget {
  const InscriptionBailleurPage({super.key});

  @override
  State<InscriptionBailleurPage> createState() => _InscriptionBailleurPageState();
}

class _InscriptionBailleurPageState extends State<InscriptionBailleurPage> with Validations {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final LocationService _locService = LocationService();

  final FocusNode _telFocusNode = FocusNode();

  final _nomCtrl = TextEditingController();
  final _postnomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  // Contrôleurs pour saisies manuelles
  final _customVilleCtrl = TextEditingController();
  final _customProvinceCtrl = TextEditingController();

  String? _genre;
  String? _selectedProvince; 
  String? _selectedVille; 
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
    _customVilleCtrl.dispose();
    _customProvinceCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getNavigationArguments(String fullPhoneNumber) {
    // Normalisation des données pour éviter les doublons dans la DB
    final String villeFinale = (_selectedVille == 'Autre') 
        ? _customVilleCtrl.text.trim().toLowerCase() 
        : (_selectedVille?.toLowerCase() ?? 'bukavu');
        
    final String provinceFinale = (_selectedProvince == 'Autre') 
        ? _customProvinceCtrl.text.trim().toLowerCase() 
        : (_selectedProvince?.toLowerCase() ?? '');

    return {
      'estInscription': true,
      'estLocataire': false,
      'nom': _nomCtrl.text.trim(),
      'postnom': _postnomCtrl.text.trim(),
      'prenom': _prenomCtrl.text.trim(),
      'genre': _genre!,
      'telephone': fullPhoneNumber,
      'email': _emailCtrl.text.trim(),
      'referrerId': null,
      'adresse_complete': {
        'numero': '',
        'avenue': '',
        'quartier': '',
        'commune': '',
        'ville': villeFinale,
        'province': provinceFinale,
      },
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

    if (_selectedProvince == null) {
      _showError('Veuillez choisir votre province');
      return;
    }

    if (_selectedVille == null) {
      _showError('Veuillez choisir votre ville actuelle');
      return;
    }

    if (!_isAccepted) {
      _showError('Veuillez accepter les mentions légales');
      return;
    }

    final fullPhoneNumber = normalizePhoneNumber(_telCtrl.text);
    setState(() => _isLoading = true);

    try {
      final existingUser = await _userService.getUserByPhoneNumber(fullPhoneNumber);
      
      if (existingUser != null) {
        if (!mounted) return;
        
        if (existingUser.roles.contains('bailleur')) {
          setState(() => _isLoading = false);
          _showExistingUserDialog("Ce numéro possède déjà un compte bailleur.");
          return;
        }

        setState(() => _isLoading = false);
        final bool? confirmMerge = await _showMergeDialog();
        if (confirmMerge != true) return;
        
        setState(() => _isLoading = true);
      }

      final args = _getNavigationArguments(fullPhoneNumber);

      await _authService.verifyNewPhoneNumber(
        phoneNumber: fullPhoneNumber,
        onVerificationCompleted: (credential) {
          if (mounted) _navigateToOtp(args, credential, 'auto_verified');
        },
        onVerificationFailed: (e) {
          if (mounted) {
            _handleAuthError(e);
            setState(() => _isLoading = false);
          }
        },
        codeSent: (verificationId, resendToken) {
          if (mounted) _navigateToOtp(args, null, verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      if (mounted) {
        _showError('Une erreur est survenue lors de la vérification.');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showExistingUserDialog(String message) {
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
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ConnexionPage()));
            },
            child: const Text("Se connecter"),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showMergeDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Compte existant"),
        content: const Text("Vous avez déjà un compte Locataire. Souhaitez-vous ajouter le profil Bailleur à votre identité actuelle ?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Oui, ajouter ce rôle"),
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
          referrerId: args['referrerId'], 
          numeroMaison: args['numeroMaison'],
          avenue: args['avenue'],
          quartier: args['quartier'],
          commune: args['commune'],
          adresseComplete: args['adresse_complete'], 
        ),
      ),
    );
  }

  void _handleAuthError(FirebaseAuthException e) {
    String msg = 'Erreur lors de l\'envoi du SMS.';
    if (e.code == 'invalid-phone-number') msg = 'Numéro de téléphone invalide.';
    if (e.code == 'too-many-requests') msg = 'Trop de tentatives. Réessayez plus tard.';
    _showError(msg);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange[900])
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription — Bailleur"), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle("Informations personnelles"),
                _buildTextField(
                  _nomCtrl, 
                  "Nom", 
                  "Ex. : N’shuti", 
                  validator: (v) => requiredField(v, 'le nom'),
                  inputFormatters: nameInputFormatters,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _postnomCtrl, 
                  "Postnom", 
                  "Ex. : Bahati", 
                  validator: (v) => requiredField(v, 'le postnom'),
                  inputFormatters: nameInputFormatters,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _prenomCtrl, 
                  "Prénom (Optionnel)", 
                  "Ex. : Amani",
                  inputFormatters: nameInputFormatters,
                ),
                const SizedBox(height: 12),
                _buildGenreField(),
                const SizedBox(height: 12),

                FutureBuilder<List<String>>(
                  future: _locService.getProvinces(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                    
                    final provinces = (snapshot.data ?? []).toList();
                    if (!provinces.contains("Autre")) provinces.add("Autre");

                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: "Province", border: OutlineInputBorder()),
                          items: provinces.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          value: _selectedProvince,
                          onChanged: (val) => setState(() { 
                            _selectedProvince = val; 
                            _selectedVille = null; 
                          }),
                          validator: (v) => v == null ? 'Veuillez choisir une province' : null,
                        ),
                        if (_selectedProvince == 'Autre') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _customProvinceCtrl,
                            decoration: const InputDecoration(labelText: "Précisez votre province", border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                            validator: (v) => (_selectedProvince == 'Autre' && (v == null || v.isEmpty)) ? 'Veuillez préciser la province' : null,
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildVilleField(),
                const SizedBox(height: 12),
                _buildPhoneField(),
                const SizedBox(height: 12),
                _buildTextField(_emailCtrl, "Email (Optionnel)", "Ex. : nom@domaine.com", keyboard: TextInputType.emailAddress, validator: emailOptional),
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
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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

  Widget _buildVilleField() {
    return Column(
      children: [
        VilleDropdownField(
          key: ValueKey(_selectedProvince),
          selectedVille: _selectedVille,
          province: _selectedProvince,
          onChanged: (value) => setState(() {
            _selectedVille = value;
            if (value != 'Autre') _customVilleCtrl.clear();
          }),
        ),
        if (_selectedVille == 'Autre') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customVilleCtrl,
            decoration: InputDecoration(
              labelText: "Précisez votre ville",
              hintText: "Ex: Goma, Uvira, Kindu...",
              prefixIcon: const Icon(Icons.location_city, color: Colors.blue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.grey[50],
            ),
            validator: (v) => (_selectedVille == 'Autre' && (v == null || v.isEmpty)) 
                ? 'Veuillez préciser le nom de votre ville' 
                : null,
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)));
  
  Widget _buildTextField(
    TextEditingController ctrl, 
    String label, 
    String hint, {
      TextInputType keyboard = TextInputType.text, 
      String? Function(String?)? validator, 
      IconData? icon,
      List<TextInputFormatter>? inputFormatters,
  }) => TextFormField(
    controller: ctrl, 
    decoration: InputDecoration(
      labelText: label, 
      hintText: hint, 
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null, 
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
      filled: true, 
      fillColor: Colors.grey[50]
    ), 
    keyboardType: keyboard, 
    validator: validator,
    inputFormatters: inputFormatters,
  );

  Widget _buildPhoneField() => TextFormField(controller: _telCtrl, focusNode: _telFocusNode, decoration: InputDecoration(labelText: 'Téléphone', prefixText: '+243 ', prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), helperText: '9 chiffres (ex: 991234567)'), keyboardType: TextInputType.phone, validator: validatePhoneNumber, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)]);
  Widget _buildGenreField() => DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Genre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[50]), value: _genre, items: const [DropdownMenuItem(value: 'Homme', child: Text('Homme')), DropdownMenuItem(value: 'Femme', child: Text('Femme'))], onChanged: (value) => setState(() => _genre = value), validator: (value) => value == null ? 'Sélectionnez votre genre' : null);
  Widget _buildConsentCheckbox() => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.1))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(height: 24, width: 24, child: Checkbox(value: _isAccepted, onChanged: (v) => setState(() => _isAccepted = v ?? false))), const SizedBox(width: 12), Expanded(child: RichText(text: TextSpan(text: 'J\'accepte les ', style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.5), children: [_linkText('Conditions Générales d\'Utilisation', 'assets/legal/cgu.md'), const TextSpan(text: ', la '), _linkText('Politique de Confidentialité', 'assets/legal/politique_confidentialite.md'), const TextSpan(text: ' et la '), _linkText('Politique de Paiement', 'assets/legal/politique_paiement.md')])))]));
  TextSpan _linkText(String label, String path) => TextSpan(text: label, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (context) => MentionsLegalesPage(documentPath: path, pageTitle: label))));
}