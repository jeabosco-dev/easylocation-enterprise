// lib/widgets/logout_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/wallet_provider.dart';
import 'package:easylocation_mvp/screens/onboarding_page.dart';

class LogoutConfirmationDialog extends StatefulWidget {
  const LogoutConfirmationDialog({super.key});

  @override
  State<LogoutConfirmationDialog> createState() =>
      _LogoutConfirmationDialogState();
}

class _LogoutConfirmationDialogState
    extends State<LogoutConfirmationDialog> {
  bool isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Confirmation"),
      content: const Text("Voulez-vous vraiment vous déconnecter ?"),
      actions: [
        TextButton(
          onPressed: isLoggingOut
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text("Annuler"),
        ),
        TextButton(
          onPressed: isLoggingOut
              ? null
              : () async {
                  setState(() => isLoggingOut = true);

                  try {
                    final walletProvider =
                        Provider.of<WalletProvider>(
                      context,
                      listen: false,
                    );

                    final userProvider =
                        Provider.of<UserProfileProvider>(
                      context,
                      listen: false,
                    );

                    // Arrête immédiatement tous les streams Wallet.
                    walletProvider.clearWallet();

                    // Déconnecte ensuite Firebase et nettoie le profil.
                    await userProvider.signOut();

                    if (!context.mounted) return;

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingPage(),
                      ),
                      (route) => false,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  }
                },
          child: isLoggingOut
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  "Se déconnecter",
                  style: TextStyle(color: Colors.red),
                ),
        ),
      ],
    );
  }
}