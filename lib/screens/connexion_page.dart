// lib/screens/connexion_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easylocation_mvp/screens/verification_otp_page.dart';
import 'package:easylocation_mvp/screens/inscription_locataire_page.dart';
import 'package:easylocation_mvp/screens/inscription_bailleur_page.dart';
import 'package:easylocation_mvp/utils/validations.dart';
import 'package:easylocation_mvp/services/auth_service.dart';
import 'package:easylocation_mvp/services/user_service.dart';
import 'package:easylocation_mvp/utils/phone_utils.dart';
import 'package:easylocation_mvp/models/user_model.dart';

class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> with Validations {
  final _formKey = GlobalKey<FormState>();
  final _telCtrl = TextEditingController();
  final FocusNode _loginFocusNode = FocusNode();

  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedNumber();
  }

  Future<void> _loadSavedNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedPhone = prefs.getString('remembered_phone');
    
    if (savedPhone != null && mounted) {
      setState(() {
        _telCtrl.text = savedPhone.replaceFirst('+243', '').trim();
        _rememberMe = true;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loginFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _telCtrl.dispose();
    _loginFocusNode.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final String fullPhoneNumber = normalizePhoneNumber(_telCtrl.text);

    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('remembered_phone', fullPhoneNumber);
    } else {
      await prefs.remove('remembered_phone');
    }

    try {
      final UserModel? userData = await _userService.getUserByPhoneNumber(fullPhoneNumber);
      
      if (userData == null) {
        if (!mounted) return;
        _showSnackBar("Ce numéro n'est pas reconnu. Veuillez créer un compte.");
        setState(() => _isLoading = false);
        return;
      }

      final bool isUniqueLocataire = userData.roles.length == 1 && userData.roles.first == 'locataire';

      await _authService.verifyNewPhoneNumber(
        phoneNumber: fullPhoneNumber,
        timeout: const Duration(seconds: 60),
        onVerificationCompleted: (PhoneAuthCredential credential) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VerificationOtpPage(
                verificationId: '', 
                autoCredential: credential,
                estInscription: false,
                userData: userData, 
                estLocataire: isUniqueLocataire,
                telephone: fullPhoneNumber,
                nom: userData.nom,
                postnom: userData.postnom,
                genre: userData.genre ?? 'M',
                
                // ✅ RÉCUPÉRATION DE L'ADRESSE EXISTANTE OU MAP VIDE
                adresseComplete: userData.adresseComplete ?? {}, 
                
                // Champs plats pour compatibilité
                numeroMaison: '',
                avenue: '',
                quartier: '',
                commune: '',
                referrerId: null,
              ),
            ),
          );
        },
        onVerificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          _handleAuthError(e);
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerificationOtpPage(
                verificationId: verificationId,
                estInscription: false,
                userData: userData, 
                estLocataire: isUniqueLocataire,
                telephone: fullPhoneNumber,
                nom: userData.nom,
                postnom: userData.postnom,
                genre: userData.genre ?? 'M',
                
                // ✅ RÉCUPÉRATION DE L'ADRESSE EXISTANTE OU MAP VIDE
                adresseComplete: userData.adresseComplete ?? {},
                
                numeroMaison: '',
                avenue: '',
                quartier: '',
                commune: '',
                referrerId: null,
              ),
            ),
          );
          setState(() => _isLoading = false);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Oups ! Une erreur s'est produite lors de la connexion.");
      setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'invalid-phone-number':
        message = 'Le format du numéro de téléphone n\'est pas valide.';
        break;
      case 'too-many-requests':
        message = 'Trop de tentatives ! Veuillez patienter un moment avant de réessayer.';
        break;
      case 'network-request-failed':
        message = 'Problème de connexion internet. Vérifiez votre réseau.';
        break;
      default:
        message = 'Impossible d\'envoyer le code de vérification. Réessayez.';
    }
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blueGrey[900],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connexion"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(Icons.lock_person_rounded, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text('Bon retour !', 
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Connectez-vous pour accéder à vos propriétés.', textAlign: TextAlign.center),
              const SizedBox(height: 40),
              
              TextFormField(
                controller: _telCtrl,
                focusNode: _loginFocusNode,
                decoration: InputDecoration(
                  labelText: 'Téléphone',
                  hintText: '980 361 265',
                  prefixIcon: const Icon(Icons.phone_rounded),
                  prefixText: '+243 ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                keyboardType: TextInputType.phone,
                validator: validatePhoneNumber,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, 
                  LengthLimitingTextInputFormatter(9)
                ],
              ),
              
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (val) => setState(() => _rememberMe = val ?? false),
                    activeColor: theme.colorScheme.primary,
                  ),
                  const Text("Se souvenir de moi"),
                ],
              ),
              
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _seConnecter,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("Pas encore de compte ?", style: theme.textTheme.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _showRegistrationDialog(context),
                child: const Text("Créer un compte maintenant", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRegistrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Inscription'),
        content: const Text('Quel type de compte souhaitez-vous créer ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () { 
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InscriptionLocatairePage())); 
            }, 
            child: const Text('Locataire')
          ),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InscriptionBailleurPage())); 
            }, 
            child: const Text('Bailleur')
          ),
        ],
      ),
    );
  }
}