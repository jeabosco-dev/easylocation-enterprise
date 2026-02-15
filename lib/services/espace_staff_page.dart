import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';

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

  Future<void> _lierCompteStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final userProfile = context.read<UserProfileProvider>();
    final user = FirebaseAuth.instance.currentUser;

    try {
      // ✅ CORRECTION ICI : .credential au lieu de .getCredential
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, userProvider, child) {
        final userData = userProvider.userData;
        
        // ✅ CORRECTION ICI : Lecture sécurisée pour éviter l'erreur de Getter
        String staffStatus = '';
        try {
          // On tente de lire via une conversion dynamique si le modèle n'est pas encore à jour
          staffStatus = (userData as dynamic).staffStatus ?? '';
        } catch (e) {
          staffStatus = ''; 
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Espace Collaborateur")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                if (staffStatus == 'pending')
                  _buildSuccessState()
                else if (_isFormVisible)
                  _buildLinkForm()
                else
                  _buildIntroState(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntroState() {
    return Column(
      children: [
        const Icon(Icons.business_center_rounded, size: 80, color: Colors.blueGrey),
        const SizedBox(height: 20),
        const Text(
          "Travailler avec EasyLocation",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        const Text(
          "Cet espace est réservé aux agents certifiés et au personnel administratif de EasyLocation RDC. Si vous êtes un professionnel souhaitant nous rejoindre, contactez notre service RH.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () => setState(() => _isFormVisible = true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            child: const Text("JE SUIS DÉJÀ EMPLOYÉ", style: TextStyle(color: Colors.white)),
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
          const Text("Identification Staff", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Liez votre email professionnel pour accéder au tableau de bord Web."),
          const SizedBox(height: 30),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: "Email Professionnel", border: OutlineInputBorder()),
            validator: (v) => v!.contains('@') ? null : "Email invalide",
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Mot de passe Web", border: OutlineInputBorder()),
            validator: (v) => v!.length >= 8 ? null : "Minimum 8 caractères",
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(labelText: "Votre Département", border: OutlineInputBorder()),
            items: _roles.map((r) => DropdownMenuItem(value: r['id'], child: Text(r['label']!))).toList(),
            onChanged: (val) => setState(() => _selectedRole = val!),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _lierCompteStaff,
              child: _isLoading ? const CircularProgressIndicator() : const Text("ACTIVER MON ACCÈS STAFF"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.verified_user_outlined, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text("Demande en cours", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          const Text(
            "Votre demande d'accès au Back-office Web a été transmise à la direction.\n\nVous recevrez une notification dès que votre accès sera validé.",
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 30),
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text("Retour au profil")),
        ],
      ),
    );
  }
}
