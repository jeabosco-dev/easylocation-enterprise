import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginAdminWeb extends StatefulWidget {
  const LoginAdminWeb({super.key});

  @override
  State<LoginAdminWeb> createState() => _LoginAdminWebState();
}

class _LoginAdminWebState extends State<LoginAdminWeb> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedEmail = prefs.getString('remembered_admin_email');
    if (savedEmail != null && mounted) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  // --- LOGIQUE DE CONNEXION AVEC VÉRIFICATION DE STATUT ---
  Future<void> _connexionAdmin() async {
    if (_isLoading) return;
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Veuillez remplir tous les champs", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Authentification Firebase
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Récupération du profil utilisateur
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs') 
          .doc(userCredential.user!.uid)
          .get();

      if (!mounted) return;

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        
        // --- ÉTAPE A : VÉRIFICATION DU STATUT (LA BARRIÈRE) ---
        final String statut = data['statut'] ?? 'actif'; 

        if (statut != 'actif') {
          // Bloquer l'accès immédiatement si suspendu ou licencié
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            _showSnackBar(
              "ACCÈS REFUSÉ : Votre compte est actuellement $statut. Veuillez contacter la Direction.", 
              Colors.red.shade900
            );
          }
          setState(() => _isLoading = false);
          return; // On arrête l'exécution ici
        }

        // --- ÉTAPE B : VÉRIFICATION DU RÔLE ---
        final String role = data['role'] ?? 'locataire';
        final String prenom = data['prenom'] ?? 'Admin';

        List<String> equipeRoles = [
          'super_admin', 'comptable', 'rh', 'tech_support', 
          'marketing', 'operations', 'certificateur', 'logistique'
        ];

        if (equipeRoles.contains(role)) {
          // SAUVEGARDE PRÉFÉRENCES EMAIL
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setString('remembered_admin_email', email);
          } else {
            await prefs.remove('remembered_admin_email');
          }

          if (mounted) {
            _showSnackBar("Accès autorisé. Bienvenue, $prenom.", Colors.green);
            context.go('/dashboard'); 
          }
        } else {
          // Rôle non autorisé
          await FirebaseAuth.instance.signOut();
          if (mounted) _showSnackBar("Accès refusé : Permissions administratives requises.", Colors.red);
        }
      } else {
        // Profil inexistant
        await FirebaseAuth.instance.signOut();
        if (mounted) _showSnackBar("Erreur : Profil introuvable.", Colors.red);
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = "Erreur d'authentification";
      if (e.code == 'user-not-found') errorMsg = "Utilisateur inconnu.";
      if (e.code == 'wrong-password') errorMsg = "Mot de passe incorrect.";
      if (e.code == 'invalid-email') errorMsg = "Format d'email invalide.";
      _showSnackBar(errorMsg, Colors.red);
    } catch (e) {
      if (mounted) _showSnackBar("Une erreur inattendue est survenue.", Colors.red);
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
        margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        duration: const Duration(seconds: 5), // Plus long pour que l'agent lise le motif
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () => _connexionAdmin(),
        },
        child: FocusScope(
          autofocus: true,
          child: Row(
            children: [
              // --- CÔTÉ GAUCHE : IDENTITÉ VISUELLE ---
              Container(
                width: 350,
                color: const Color(0xFF1E293B), 
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 80, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      "EASYLOCATION HQ",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "ADMIN SECURE ACCESS",
                        style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
              
              // --- CÔTÉ DROIT : FORMULAIRE ---
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40.0),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Identification",
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Veuillez vous identifier pour accéder au tableau de bord.",
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 40),
                            
                            _buildTextField(
                              controller: _emailController,
                              label: "Email Professionnel",
                              icon: Icons.alternate_email,
                            ),
                            const SizedBox(height: 25),
                            
                            _buildTextField(
                              controller: _passwordController,
                              label: "Mot de passe",
                              icon: Icons.key_outlined,
                              isPassword: true,
                            ),

                            const SizedBox(height: 15),

                            Row(
                              children: [
                                SizedBox(
                                  height: 24, width: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: const Color(0xFF1E293B),
                                    onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Se souvenir de l'adresse email", 
                                  style: TextStyle(color: Colors.blueGrey, fontSize: 13)
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 35),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _connexionAdmin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20, 
                                        width: 20, 
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                      )
                                    : const Text("SE CONNECTER", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          onSubmitted: (_) => _connexionAdmin(), 
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF1E293B), size: 20),
            suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E293B), width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
