
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:sentry_flutter/sentry_flutter.dart';

// Fichier : lib/screens/verification_otp_update_phone_page.dart

class VerificationOtpUpdatePhonePage extends StatefulWidget {
  final String verificationId;
  final String telephone;
  final VoidCallback onVerificationComplete;
  final PhoneAuthCredential? autoCredential;

  const VerificationOtpUpdatePhonePage({
    super.key,
    required this.verificationId,
    required this.telephone,
    required this.onVerificationComplete,
    this.autoCredential,
  });

  @override
  State<VerificationOtpUpdatePhonePage> createState() =>
      _VerificationOtpUpdatePhonePageState();
}

class _VerificationOtpUpdatePhonePageState
    extends State<VerificationOtpUpdatePhonePage> {
  final _otpCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isOtpVisible = false;
  int _resendCountdown = 60;
  Timer? _resendTimer;
  late String _currentVerificationId;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startResendTimer();

    if (widget.autoCredential != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyAutoCredential(widget.autoCredential!);
      });
    }
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();

    _resendTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_resendCountdown == 0) {
          timer.cancel();
          setState(() {});
        } else {
          setState(() => _resendCountdown--);
        }
      },
    );
  }

  Future<void> _applyAutoCredential(
    PhoneAuthCredential credential,
  ) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _otpCtrl.text = credential.smsCode ?? '';
    });

    await _processPhoneUpdate(credential);
  }

  Future<void> _verifyAndChangePhone() async {
    if (_isLoading) return;

    final otp = _otpCtrl.text.trim();

    if (otp.length != 6) return;

    final credential = PhoneAuthProvider.credential(
      verificationId: _currentVerificationId,
      smsCode: otp,
    );

    await _processPhoneUpdate(credential);
  }

  Future<void> _processPhoneUpdate(
    PhoneAuthCredential credential,
  ) async {
    if (_isLoading && _otpCtrl.text.length < 6) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Aucun utilisateur connecté.',
        );
      }

      // 1. Mettre à jour Firebase Auth.
      await user.updatePhoneNumber(credential);

      // 2. Exécuter le callback pour mettre à jour Firestore.
      widget.onVerificationComplete();

      // 3. Revenir à la page précédente.
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erreur de validation.';

      if (e.code == 'invalid-verification-code') {
        message = 'Code incorrect ❌';
      } else if (e.code == 'session-expired') {
        message = 'Code expiré, renvoyez-en un nouveau.';
      } else if (e.code == 'user-not-found') {
        message = 'Aucun utilisateur connecté.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      await Sentry.captureException(
        e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Une erreur est survenue lors de la mise à jour.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification'),
        automaticallyImplyLeading: !_isLoading,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(
              Icons.phonelink_setup,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),

            Text(
              'Saisissez le code envoyé au\n${widget.telephone}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 32),

            TextField(
              controller: _otpCtrl,
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,

              // Masquer ou afficher le code OTP.
              obscureText: !_isOtpVisible,
              obscuringCharacter: '•',

              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),

              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: const TextStyle(
                  color: Colors.grey,
                  letterSpacing: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.blue,
                    width: 2,
                  ),
                ),

                // Bouton œil.
                suffixIcon: IconButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isOtpVisible = !_isOtpVisible;
                          });
                        },
                  icon: Icon(
                    _isOtpVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  tooltip: _isOtpVisible
                      ? 'Masquer le code'
                      : 'Afficher le code',
                ),
              ),

              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],

              onChanged: (value) {
                if (value.length == 6 && !_isLoading) {
                  _verifyAndChangePhone();
                }
              },
            ),

            const SizedBox(height: 25),

            if (_resendCountdown > 0)
              Text(
                'Renvoyer le code dans $_resendCountdown s',
                style: const TextStyle(color: Colors.grey),
              )
            else
              TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Veuillez revenir en arrière pour renvoyer le code.',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Renvoyer un SMS'),
              ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : _verifyAndChangePhone,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        'CONFIRMER LE CHANGEMENT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}