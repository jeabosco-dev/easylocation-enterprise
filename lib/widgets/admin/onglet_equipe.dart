import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OngletEquipe extends StatefulWidget {
  const OngletEquipe({super.key});

  @override
  State<OngletEquipe> createState() => _OngletEquipeState();
}

class _OngletEquipeState extends State<OngletEquipe> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final List<String> _roles = [
    'super_admin', 'comptable', 'rh', 'tech_support', 
    'marketing', 'operations', 'certificateur', 'logistique'
  ];

  final List<String> _statuts = ['actif', 'suspendu', 'licencié'];
  final List<String> _villes = ['Bukavu', 'Goma'];

  // --- LOGIQUE DE MODIFICATION ET CONFIGURATION DES ACCÈS WEB ---
  void _modifierMembre(String uid, String currentRole, String currentStatus, String currentVille, String name, String? currentEmail) {
    String selectedRole = currentRole;
    String selectedStatus = currentStatus;
    String selectedVille = _villes.contains(currentVille) ? currentVille : 'Bukavu';
    
    _emailController.text = currentEmail ?? '';
    _passwordController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Gestion de $name"),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Rôle (Direction) :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _roles.contains(selectedRole) ? selectedRole : 'operations',
                  isExpanded: true,
                  items: _roles.map((r) => DropdownMenuItem(
                    value: r, 
                    child: Text(r.toUpperCase().replaceAll('_', ' '))
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
                const SizedBox(height: 15),
                const Text("Statut du compte :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _statuts.contains(selectedStatus) ? selectedStatus : 'actif',
                  isExpanded: true,
                  items: _statuts.map((s) => DropdownMenuItem(
                    value: s, 
                    child: Text(s.toUpperCase(), style: TextStyle(
                      color: s == 'actif' ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold
                    ))
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedStatus = val!),
                ),
                const SizedBox(height: 15),
                const Text("Ville d'affectation :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: selectedVille,
                  isExpanded: true,
                  items: _villes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (val) => setDialogState(() => selectedVille = val!),
                ),
                const SizedBox(height: 15),
                const Divider(),
                const Text("Accès Backoffice (Optionnel)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email Professionnel", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Nouveau mot de passe (si modification)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            onPressed: () async {
              String staffMobileStatus = selectedStatus == 'actif' ? 'validated' : 'revoked';
              
              Map<String, dynamic> updateData = {
                'role': selectedRole,
                'statut': selectedStatus,
                'staffStatus': staffMobileStatus,
                'ville': selectedVille,
              };

              if (_emailController.text.trim().isNotEmpty) {
                updateData['email_professionnel'] = _emailController.text.trim();
              }
              if (_passwordController.text.trim().isNotEmpty) {
                updateData['password_backoffice'] = _passwordController.text.trim();
              }

              await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update(updateData);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil et accès mis à jour")));
            },
            child: const Text("ENREGISTRER"),
          ),
        ],
      ),
    );
  }

  void _ajouterMembre() {
    _phoneController.clear();
    _emailController.clear();
    _passwordController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nouveau Collaborateur"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("L'employé doit avoir un compte EasyLocation actif sur son téléphone.", 
                style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Numéro de téléphone", hintText: "+243...", prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 10),
              const Text("Créer ses accès de connexion Web", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email Professionnel", hintText: "nom@easylocation.cd", prefixIcon: Icon(Icons.alternate_email), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Mot de passe initial", prefixIcon: Icon(Icons.key), border: OutlineInputBorder()),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            onPressed: () async {
              final phone = _phoneController.text.trim();
              final email = _emailController.text.trim();
              final password = _passwordController.text.trim();

              if (phone.isEmpty || email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez remplir tous les champs"), backgroundColor: Colors.orange));
                return;
              }

              final indexDoc = await FirebaseFirestore.instance.collection('phone_index').doc(phone).get();

              if (indexDoc.exists) {
                final uid = indexDoc.data()?['uid'];
                await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({
                  'role': 'operations',
                  'statut': 'actif', 
                  'staffStatus': 'validated',
                  'ville': 'Bukavu',
                  'email_professionnel': email,
                  'password_backoffice': password, // Permet la validation croisée lors du login web
                });

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Membre ajouté avec succès !")));
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Numéro de téléphone introuvable sur la plateforme."), backgroundColor: Colors.red));
              }
            },
            child: const Text("AJOUTER"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Management Équipe", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  Text("Gérez les accès, les affectations et les statuts", style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _ajouterMembre,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text("Nouveau Membre"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B), 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('utilisateurs')
                .where('role', whereIn: _roles)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Aucun membre d'équipe."));

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final uid = docs[index].id;
                  final role = data['role'] ?? 'operations';
                  final statut = data['statut'] ?? 'actif';
                  final ville = data['ville'] ?? 'Bukavu';
                  final emailProf = data['email_professionnel'];
                  final name = "${data['prenom'] ?? ''} ${data['nom'] ?? ''}";
                  
                  bool isRestricted = statut != 'actif';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), 
                      side: BorderSide(color: isRestricted ? Colors.red.shade100 : Colors.grey.shade200)
                    ),
                    child: ListTile(
                      enabled: !isRestricted || statut == 'suspendu', 
                      leading: CircleAvatar(
                        backgroundColor: isRestricted ? Colors.grey.shade200 : _getRoleColor(role).withOpacity(0.1),
                        child: Icon(
                          isRestricted ? Icons.lock_outline : _getRoleIcon(role), 
                          color: isRestricted ? Colors.grey : _getRoleColor(role)
                        ),
                      ),
                      title: Text(name, style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRestricted ? Colors.grey : Colors.black,
                        decoration: statut == 'licencié' ? TextDecoration.lineThrough : null
                      )),
                      subtitle: Row(
                        children: [
                          Text(role.toUpperCase().replaceAll('_', ' '), 
                            style: TextStyle(color: isRestricted ? Colors.grey : _getRoleColor(role), fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text(ville.toUpperCase(), style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: isRestricted ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text(statut.toUpperCase(), style: TextStyle(color: isRestricted ? Colors.red : Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.settings_suggest_outlined),
                        onPressed: () => _modifierMembre(uid, role, statut, ville, name, emailProf),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin': return Colors.red.shade900;
      case 'comptable': return Colors.green.shade700;
      case 'rh': return Colors.blue.shade700;
      case 'tech_support': return Colors.orange.shade800;
      case 'marketing': return Colors.purple.shade700;
      case 'certificateur': return Colors.teal.shade700;
      default: return Colors.blueGrey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'super_admin': return Icons.admin_panel_settings;
      case 'comptable': return Icons.account_balance_wallet;
      case 'rh': return Icons.badge;
      case 'tech_support': return Icons.biotech;
      case 'marketing': return Icons.campaign;
      case 'certificateur': return Icons.verified_user;
      default: return Icons.person;
    }
  }
}