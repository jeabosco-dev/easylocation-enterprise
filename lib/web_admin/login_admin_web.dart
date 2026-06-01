// lib/web_admin/login_admin_web.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart'; // ✅ AJOUTÉ pour la gestion du Provider
import 'package:shared_preferences/shared_preferences.dart';

// ✅ ALIGNEMENT : Importation des constantes officielles pour la validation RBAC
import '../constants/constants.dart';
import '../providers/user_profile_provider.dart'; 

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

  // 🔐 VALIDATION STRICTE DE L'ACCÈS ADMINISTRATIF
  bool _hasAdministrativeAccess(String role, String direction) {
    final String formattedRole = role.trim().toUpperCase();
    final String formattedDirection = direction.trim().toUpperCase();

    if (formattedRole == 'SUPER_ADMIN') return true;
    return AppDepartments.allDirections.contains(formattedDirection);
  }

  Future<void> _connexionAdmin() async {
    if (_isLoading) return;
    
    final emailProInput = _emailController.text.trim();
    final passwordInput = _passwordController.text.trim();

    if (emailProInput.isEmpty || passwordInput.isEmpty) {
      _showSnackBar("Veuillez remplir tous les champs", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("🔍 [LOGIN] Étape 1 : Vérification des droits d'accès dans Firestore...");
      
      // 1. RECHERCHE DE L'AGENT PAR SON EMAIL PROFESSIONNEL DANS FIRESTORE
      final userQuery = await FirebaseFirestore.instance
          .collection(FirestoreCollections.utilisateurs)
          .where('email_professionnel', isEqualTo: emailProInput)
          .limit(1)
          .get();

      if (!mounted) return;

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        final data = userDoc.data();
        
        final String savedPassword = data[UserFields.passwordBackoffice] ?? '';
        final String statut = data['statut'] ?? 'actif'; 
        final String role = data[UserFields.role] ?? 'locataire';
        final String direction = data[UserFields.direction] ?? 'AUCUNE';
        final String prenom = data['prenom'] ?? 'Admin';

        // Vérification du mot de passe stocké dans Firestore
        if (savedPassword != passwordInput) {
          _showSnackBar("Mot de passe incorrect.", Colors.red);
          setState(() => _isLoading = false);
          return;
        }

        // Vérification du statut de sécurité
        if (statut != 'actif') {
          _showSnackBar("ACCÈS REFUSÉ : Votre compte est actuellement $statut.", Colors.red.shade900);
          setState(() => _isLoading = false);
          return;
        }

        // Vérification des habilitations managériales et administratives strictes
        if (_hasAdministrativeAccess(role, direction)) {
          debugPrint("🔑 [LOGIN] Étape 2 : Structure validée ($direction | $role). Connexion Firebase Auth...");
          
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: emailProInput,
              password: passwordInput,
            );
            debugPrint("✅ [LOGIN] Session Firebase Auth ouverte avec succès.");
          } catch (authError) {
            debugPrint("❌ [LOGIN] Erreur Firebase Auth : $authError");
            _showSnackBar("Erreur d'authentification système. Contactez la Direction Technique.", Colors.red);
            setState(() => _isLoading = false);
            return;
          }

          // Sauvegarde locale de l'e-mail si "Se souvenir de moi" est coché
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setString('remembered_admin_email', emailProInput);
          } else {
            await prefs.remove('remembered_admin_email');
          }

          // 🚨 MODIFICATION ICI : Chargement du profil dans le Provider avant la navigation
          if (mounted) {
            final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
            // On récupère le UID que Firebase vient d'authentifier
            final String uid = FirebaseAuth.instance.currentUser!.uid;
            // On force le chargement des données depuis Firestore vers le Provider
            await userProvider.loadUser(uid); 

            _showSnackBar("Accès autorisé. Bienvenue au Hub, $prenom.", Colors.green);
            context.go('/dashboard'); 
          }
        } else {
          _showSnackBar("Accès refusé : Droits administratifs et direction de pôle insuffisants.", Colors.red);
        }
      } else {
        // Option de repli historique : Tentative de connexion directe si configuration via e-mail racine
        debugPrint("⚠️ [LOGIN] Aucun email professionnel trouvé. Tentative via authentification directe.");
        try {
          UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: emailProInput,
            password: passwordInput,
          );
          
          DocumentSnapshot adminDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.utilisateurs) 
              .doc(userCredential.user!.uid)
              .get();

          if (adminDoc.exists) {
            final adminData = adminDoc.data() as Map<String, dynamic>;
            final String role = adminData[UserFields.role] ?? 'locataire';
            final String direction = adminData[UserFields.direction] ?? 'AUCUNE';
            final String prenom = adminData['prenom'] ?? 'Admin';

            if (_hasAdministrativeAccess(role, direction)) {
              // 🚨 MODIFICATION ICI : Chargement du profil également dans le flux alternatif
              if (mounted) {
                final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
                await userProvider.loadUser(userCredential.user!.uid);
                
                _showSnackBar("Accès autorisé. Bienvenue au Hub, $prenom.", Colors.green);
                context.go('/dashboard');
              }
            } else {
              await FirebaseAuth.instance.signOut();
              _showSnackBar("Accès refusé : Profil non répertorié dans les directions exécutives.", Colors.red);
            }
          } else {
            await FirebaseAuth.instance.signOut();
            _showSnackBar("Accès refusé : Fiche utilisateur introuvable.", Colors.red);
          }
        } catch (_) {
          _showSnackBar("Identifiants professionnels ou profil introuvable.", Colors.red);
        }
      }
    } catch (e) {
      debugPrint("❌ [LOGIN] Erreur critique : $e");
      if (mounted) _showSnackBar("Une erreur inattendue est survenue au niveau de la passerelle.", Colors.red);
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
        duration: const Duration(seconds: 5),
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
                                const Expanded(
                                  child: Text(
                                    "Se souvenir de l'adresse email", 
                                    style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
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