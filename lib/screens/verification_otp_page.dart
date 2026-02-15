import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:provider/provider.dart'; // IMPORTANT
import 'package:easylocation_mvp/services/auth_service.dart';
import 'package:easylocation_mvp/services/user_service.dart'; 
import 'package:easylocation_mvp/models/user_model.dart';    
import 'package:easylocation_mvp/providers/user_profile_provider.dart'; // À vérifier selon ton chemin
import 'package:sentry_flutter/sentry_flutter.dart';

class VerificationOtpPage extends StatefulWidget {
  final String verificationId;
  final bool estInscription;
  final bool? estLocataire;
  final String? telephone;
  final UserModel? userData;

  // Données pour l'inscription
  final String? nom;
  final String? postnom;
  final String? prenom;
  final String? genre;
  final String? email;
  final String? numeroMaison;
  final String? avenue;
  final String? quartier;
  final String? commune;

  final PhoneAuthCredential? autoCredential;

  const VerificationOtpPage({
    super.key,
    required this.verificationId,
    required this.estInscription,
    this.estLocataire,
    this.telephone,
    this.userData,
    this.nom,
    this.postnom,
    this.prenom,
    this.genre,
    this.email,
    this.numeroMaison,
    this.avenue,
    this.quartier,
    this.commune,
    this.autoCredential,
  });

  @override
  State<VerificationOtpPage> createState() => _VerificationOtpPageState();
}

class _VerificationOtpPageState extends State<VerificationOtpPage> {
  final _otpCtrl = TextEditingController();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool _isLoading = false;
  bool _isProcessing = false;
  late String _currentVerificationId;
  int _resendCountdown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    
    if (widget.autoCredential != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleVerification(credential: widget.autoCredential);
      });
    } else {
      _startResendTimer();
    }
  }

  Future<void> _processCredentialAndSync(PhoneAuthCredential credential) async {
    try {
      final authResult = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = authResult.user;
      if (user == null) throw Exception("Échec de l'authentification.");

      final String roleCible = widget.estLocataire == true ? 'locataire' : 'bailleur';
      UserModel finalUser;

      if (widget.estInscription) {
        final Map<String, dynamic> rawData = {
          'nom': widget.nom ?? '',
          'postnom': widget.postnom ?? '',
          'prenom': widget.prenom ?? '',
          'genre': widget.genre ?? 'M',
          'email': widget.email,
          'numeroMaison': widget.numeroMaison ?? '',
          'avenue': widget.avenue ?? '',
          'quartier': widget.quartier ?? '',
          'commune': widget.commune ?? '',
          'telephone': widget.telephone ?? '',
        };

        final existingProfile = await _userService.getUserByPhoneNumber(widget.telephone!);

        if (existingProfile != null) {
          final List<String> updatedRoles = List.from(existingProfile.roles);
          if (!updatedRoles.contains(roleCible)) {
            updatedRoles.add(roleCible);
          }
          finalUser = existingProfile.copyWith(
            roles: updatedRoles,
            activeRole: roleCible,
          );
        } else {
          finalUser = UserModel(
            uid: user.uid,
            nom: widget.nom ?? '',
            postnom: widget.postnom ?? '',
            prenom: widget.prenom ?? '',
            genre: widget.genre ?? 'M',
            telephone: widget.telephone ?? '',
            email: widget.email,
            numeroMaison: widget.numeroMaison ?? '',
            avenue: widget.avenue ?? '',
            quartier: widget.quartier ?? '',
            commune: widget.commune ?? '',
            roles: [roleCible],
            activeRole: roleCible,
            isVerified: true,
          );
        }

        // ✅ SYNC UNIQUE (Gère profil + index automatiquement)
        await _userService.syncUser(finalUser, roleCible, rawData);

      } else {
        // Mode Connexion simple
        finalUser = widget.userData!.copyWith(
          activeRole: widget.userData!.activeRole.isEmpty 
              ? roleCible 
              : widget.userData!.activeRole
        );
        await _userService.syncUser(finalUser, finalUser.activeRole);
      }

      // Force le rafraîchissement du token pour les claims
      await user.getIdToken(true);

      if (mounted) {
        // 🚀 INJECTION DANS LE PROVIDER (Crucial pour éviter l'écran blanc)
        // On utilise listen: false car on est dans une fonction asynchrone
        final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
        userProvider.setUser(finalUser);

        // Navigation finale
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(e);
      rethrow;
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      _showError("Oups ! Un problème de synchronisation est survenu.");
      await _authService.signOut();
      rethrow;
    }
  }

  // ... (Reste de tes méthodes : _handleFirebaseError, _handleVerification, etc.)
  
  void _handleFirebaseError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'invalid-verification-code':
        message = "Le code saisi est incorrect. Vérifiez-le et réessayez.";
        break;
      case 'session-expired':
        message = "Le code a expiré. Veuillez demander un nouveau code.";
        break;
      case 'invalid-verification-id':
        message = "Une erreur s'est produite. Veuillez recommencer la connexion.";
        break;
      case 'too-many-requests':
        message = "Trop de tentatives ! Patientez un instant avant de réessayer.";
        break;
      default:
        message = "Une erreur est survenue (${e.code}). Réessayez.";
    }
    _showError(message);
  }

  Future<void> _handleVerification({PhoneAuthCredential? credential}) async {
    if (_isProcessing) return;
    
    if (credential == null) {
      final otp = _otpCtrl.text.trim();
      if (otp.length != 6) {
        _showError("Veuillez entrer le code à 6 chiffres.");
        return;
      }
      credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: otp,
      );
    }

    setState(() { _isLoading = true; _isProcessing = true; });

    try {
      await _processCredentialAndSync(credential).timeout(const Duration(seconds: 45));
    } on TimeoutException {
      _showError("Délai d'attente dépassé. Vérifiez votre connexion.");
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
      _showError("Code incorrect ou expiré.");
    } finally {
      if (mounted) setState(() { _isLoading = false; _isProcessing = false; });
    }
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendCountdown == 0) {
        setState(() => timer.cancel());
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _resendCode() async {
    if (widget.telephone == null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _authService.verifyNewPhoneNumber(
        phoneNumber: widget.telephone!,
        onVerificationCompleted: (cred) => _handleVerification(credential: cred),
        onVerificationFailed: (e) => _handleFirebaseError(e),
        codeSent: (id, _) {
          setState(() { _currentVerificationId = id; _isLoading = false; });
          _startResendTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Un nouveau code a été envoyé."))
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Échec du renvoi du code.");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent)
    );
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text("Saisissez le code", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Code envoyé au ${widget.telephone}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            TextField(
              controller: _otpCtrl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "000000",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            ),
            const SizedBox(height: 24),
            _resendCountdown > 0 
                ? Text("Renvoyer dans $_resendCountdown s") 
                : TextButton(onPressed: _resendCode, child: const Text("Renvoyer le code")),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _handleVerification(),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Confirmer"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
