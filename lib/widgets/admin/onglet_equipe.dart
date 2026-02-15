import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OngletEquipe extends StatefulWidget {
  const OngletEquipe({super.key});

  @override
  State<OngletEquipe> createState() => _OngletEquipeState();
}

class _OngletEquipeState extends State<OngletEquipe> {
  final TextEditingController _phoneController = TextEditingController();

  // --- LISTES OFFICIELLES ---
  final List<String> _roles = [
    'super_admin', 'comptable', 'rh', 'tech_support', 
    'marketing', 'operations', 'certificateur', 'logistique'
  ];

  final List<String> _statuts = ['actif', 'suspendu', 'licencié'];

  // --- LOGIQUE DE MODIFICATION ---
  void _modifierMembre(String uid, String currentRole, String currentStatus, String name) {
    String selectedRole = currentRole;
    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Gestion de $name"),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
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
              const SizedBox(height: 20),
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
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({
                'role': selectedRole,
                'statut': selectedStatus,
              });
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour avec succès")));
            },
            child: const Text("ENREGISTRER"),
          ),
        ],
      ),
    );
  }

  void _ajouterMembre() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nouveau Collaborateur"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("L'employé doit avoir un compte EasyLocation actif.", 
              style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "Numéro de téléphone",
                hintText: "+243...",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            onPressed: () async {
              final phone = _phoneController.text.trim();
              if (phone.isEmpty) return;

              final indexDoc = await FirebaseFirestore.instance.collection('phone_index').doc(phone).get();

              if (indexDoc.exists) {
                final uid = indexDoc.data()?['uid'];
                await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({
                  'role': 'operations',
                  'statut': 'actif', // Par défaut actif à l'ajout
                });

                if (!mounted) return;
                Navigator.pop(context);
                _phoneController.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Membre ajouté à l'équipe !")));
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Numéro introuvable."), backgroundColor: Colors.red));
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
                  Text("Gérez les accès et les statuts des agents", style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                      enabled: !isRestricted || statut == 'suspendu', // Permet de cliquer même si suspendu pour réactiver
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
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRestricted ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(statut.toUpperCase(), 
                              style: TextStyle(color: isRestricted ? Colors.red : Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.settings_suggest_outlined),
                        onPressed: () => _modifierMembre(uid, role, statut, name),
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

  // --- COULEURS ET ICÔNES ---
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
