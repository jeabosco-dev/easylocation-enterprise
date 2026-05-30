// lib/services/espace_staff_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/user_model.dart'; // Étape cruciale : import direct du modèle aligné
import 'agent_dashboard_page.dart'; 

class EspaceStaffPage extends StatefulWidget {
  const EspaceStaffPage({super.key});

  @override
  State<EspaceStaffPage> createState() => _EspaceStaffPageState();
}

class _EspaceStaffPageState extends State<EspaceStaffPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isFormVisible = false; 
  String _selectedRole = 'operations'; 

  final List<Map<String, String>> _roles = [
    {'id': 'comptable', 'label': 'Direction Financière / Comptabilité'},
    {'id': 'rh', 'label': 'Ressources Humaines'},
    {'id': 'operations', 'label': 'Opérations & Terrain'},
    {'id': 'marketing', 'label': 'Marketing & Communication'},
    {'id': 'logistique', 'label': 'Logistique'},
    {'id': 'certificateur', 'label': 'Agent Certificateur (CCV)'},
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _lierCompteStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final userProfile = context.read<UserProfileProvider>();
    final user = FirebaseAuth.instance.currentUser;

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await user?.linkWithCredential(credential);

      await FirebaseFirestore.instance.collection('utilisateurs').doc(user?.uid).update({
        'email': _emailController.text.trim(),
        'requestedRole': _selectedRole,
        'staffStatus': 'pending', 
        'dateDemandeStaff': FieldValue.serverTimestamp(),
      });

      await userProfile.loadUser(user!.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Demande envoyée avec succès !"), backgroundColor: Colors.green),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Une erreur est survenue";
      if (e.code == 'provider-already-linked') message = "Cet email est déjà lié à un compte.";
      if (e.code == 'email-already-in-use') message = "Cet email est déjà utilisé par un autre utilisateur.";
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, userProvider, child) {
        // Interception sécurisée de l'objet utilisateur typé
        final UserModel? userModel = userProvider.userData;
        
        String staffStatus = '';
        String userRole = '';
        
        // ✅ PASSERELLE D'HARMONISATION FLUIDE SANS CAST RISK
        try {
          if (userModel != null) {
            final String statutMobile = userModel.staffStatus; // Propriété native du UserModel
            final String roleGlobal = userModel.role;               // Grade de sécurité natif
            final String roleActif = userModel.activeRole;           // Rôle actuellement exécuté

            // Vérification de l'admissibilité au statut validé
            // Si le compte possède un rôle d'exploitation ou si l'admin a passé le flag mobile à validated/approved
            if (statutMobile == 'validated' || 
                statutMobile == 'approved' || 
                roleGlobal == 'operations' || 
                roleGlobal == 'certificateur' || 
                roleGlobal == 'staff' ||
                roleGlobal == 'super_admin') {
              staffStatus = 'validated';
            } else if (statutMobile == 'pending') {
              staffStatus = 'pending';
            } else {
              staffStatus = '';
            }

            // Détermination du rôle cible
            userRole = roleGlobal.isNotEmpty ? roleGlobal : (userModel.requestedRole.isNotEmpty ? userModel.requestedRole : 'operations');

            // ✅ RENTRÉE EN ACCÈS EN TÂCHE DE FOND (Aiguillage du State du Provider)
            if (staffStatus == 'validated' && roleActif != userRole) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                userProvider.setActiveRole(userRole);
              });
            }
          }
        } catch (e) {
          debugPrint("Erreur critique d'alignement de type dans la passerelle : $e");
          staffStatus = ''; 
          userRole = 'operations';
        }

        // 🛡️ ACCÈS COURT-CIRCUIT : Empêche l'affichage du SingleChildScrollView si le profil est validé
        if (staffStatus == 'validated') {
          return _getCorrectView(staffStatus, userRole);
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text("Espace Collaborateur"),
            backgroundColor: Colors.blueGrey.shade900,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _getCorrectView(staffStatus, userRole),
          ),
        );
      },
    );
  }

  // ✅ ROUTAGE INTERNE ET INJECTION DE LA VUE MÉTIER ISOLLÉE
  Widget _getCorrectView(String status, String role) {
    if (status == 'validated') {
      switch (role) {
        case 'super_admin':
        case 'tech_support':
          return Scaffold(
            appBar: AppBar(title: const Text("Administration Globale"), backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
            body: _buildPlaceholderDashboard("Administration Globale"),
          );
        case 'operations':
        case 'certificateur':
          return const Scaffold(
            body: AgentDashboardPage(),
          ); 
        case 'comptable':
          return Scaffold(
            appBar: AppBar(title: const Text("Direction Financière"), backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
            body: _buildPlaceholderDashboard("Direction Financière"),
          );
        case 'logistique':
          return Scaffold(
            appBar: AppBar(title: const Text("Logistique & Circuits Courts"), backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
            body: _buildPlaceholderDashboard("Logistique & Circuits Courts"),
          );
        case 'rh':
          return Scaffold(
            appBar: AppBar(title: const Text("Ressources Humaines"), backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
            body: _buildPlaceholderDashboard("Ressources Humaines"),
          );
        default:
          return const Scaffold(
            body: AgentDashboardPage(),
          );
      }
    } else if (status == 'pending') {
      return _buildSuccessState();
    } else if (_isFormVisible) {
      return _buildLinkForm();
    } else {
      return _buildIntroState();
    }
  }

  Widget _buildIntroState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.business_center_rounded, size: 90, color: Colors.blueGrey),
        const SizedBox(height: 20),
        const Text(
          "Espace Collaborateur",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87), 
        ),
        const SizedBox(height: 15),
        const Text(
          "Cet espace interne est strictement réservé aux agents certifiés et au personnel administratif d'EasyLocation Enterprise. Si vous êtes un collaborateur, veuillez activer vos accès d'authentification.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, height: 1.6, fontSize: 14),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () => setState(() => _isFormVisible = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("JE SUIS UN EMPLOYÉ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Identification Staff", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Associez vos identifiants réseau d'entreprise pour synchroniser votre terminal.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Email Professionnel", 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) => (v != null && v.contains('@')) ? null : "Veuillez entrer un email valide",
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Mot de passe d'accès", 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) => (v != null && v.length >= 8) ? null : "Le mot de passe doit contenir au moins 8 caractères",
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: "Département / Affectation", 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.layers_outlined),
            ),
            items: _roles.map((r) => DropdownMenuItem(
              value: r['id'], 
              child: Text(
                r['label']!,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            )).toList(),
            onChanged: (val) => setState(() => _selectedRole = val!),
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _lierCompteStaff,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("DEMANDER L'ACTIVATION DE MON ACCÈS", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _isFormVisible = false),
            child: const Center(child: Text("Retour", style: TextStyle(color: Colors.grey))),
          )
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Icon(Icons.hourglass_top_rounded, size: 80, color: Colors.amber),
          const SizedBox(height: 20),
          const Text("Demande en cours d'examen", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          const Text(
            "Vos identifiants ont été liés avec succès. Votre demande d'intégration est actuellement en cours de vérification par la direction de EasyLocation Enterprise.\n\nVous serez automatiquement redirigé dès validation.",
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.6, color: Colors.black87), 
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context), 
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              child: const Text("RETOUR AU PROFIL"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderDashboard(String departementName) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 70, color: Colors.blueGrey),
            const SizedBox(height: 20),
            Text(
              "Espace $departementName",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Ce module métier est optimisé pour l'affichage console Web et grand écran. Les fonctionnalités mobiles d'appoint seront disponibles dans la prochaine mise à jour.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}