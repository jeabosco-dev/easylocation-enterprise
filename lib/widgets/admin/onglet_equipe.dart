// lib/widgets/admin/onglet_equipe.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

// ✅ ALIGNEMENT : Importation de la classe de gouvernance et des constantes
import 'package:easylocation_mvp/constants/all_constants.dart';

class OngletEquipe extends StatefulWidget {
  const OngletEquipe({super.key});

  @override
  State<OngletEquipe> createState() => _OngletEquipeState();
}

class _OngletEquipeState extends State<OngletEquipe> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isActionLoading = false;

  // Rôles de haut niveau alignés
  final List<String> _rolesGouvernance = ['AGENT', 'SUPER_ADMIN'];
  final List<String> _statuts = ['actif', 'suspendu', 'licencié'];
  final List<String> _villes = ['Bukavu', 'Goma'];

  // --- LOGIQUE DE MODIFICATION ET CONFIGURATION DES ACCÈS ---
  void _modifierMembre(
    String uid, 
    String currentRole, 
    String currentDirection, 
    String currentStatus, 
    String currentVille, 
    String name, 
    String? currentEmail
  ) {
    String selectedRole = _rolesGouvernance.contains(currentRole.toUpperCase()) ? currentRole.toUpperCase() : 'AGENT';
    String selectedDirection = AppDepartments.allDirections.contains(currentDirection.toUpperCase()) 
        ? currentDirection.toUpperCase() 
        : AppDepartments.operations;
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
                const Text("Type de Profil (Rôle) :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: selectedRole,
                  isExpanded: true,
                  items: _rolesGouvernance.map((r) => DropdownMenuItem(
                    value: r, 
                    child: Text(r)
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
                const SizedBox(height: 15),

                const Text("Direction Administrative (Affectation) :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: selectedDirection,
                  isExpanded: true,
                  items: AppDepartments.allDirections.map((d) => DropdownMenuItem(
                    value: d, 
                    child: Text(d)
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedDirection = val!),
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
                  decoration: const InputDecoration(labelText: "Nouveau mot de passe", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
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
              
              // ✅ MODIFICATION CLÉ : Préservation du rôle mobile existant. 
              // On utilise une mise à jour destructive uniquement pour activeRole et les accès spécifiques au backoffice web.
              Map<String, dynamic> updateData = {
                'activeRole': selectedRole,
                'statut_web': selectedStatus == 'actif' ? 'active' : 'inactive',
                UserFields.direction: selectedRole == 'SUPER_ADMIN' ? AppDepartments.superAdmin : selectedDirection,
                'statut': selectedStatus,
                'staffStatus': staffMobileStatus,
                'ville': selectedVille,
                // On pousse dynamiquement les rôles de gouvernance dans le tableau sans toucher aux rôles "locataire/bailleur"
                'roles': FieldValue.arrayUnion([selectedRole, selectedRole == 'SUPER_ADMIN' ? 'super_admin' : 'operations'])
              };

              // Si le rôle choisi est SUPER_ADMIN, on l'aligne en minuscules sur la racine pour éviter de bloquer l'app mobile
              if (selectedRole == 'SUPER_ADMIN') {
                updateData[UserFields.role] = 'super_admin';
              }

              if (_emailController.text.trim().isNotEmpty) {
                updateData['email_professionnel'] = _emailController.text.trim();
              }
              if (_passwordController.text.trim().isNotEmpty) {
                updateData[UserFields.passwordBackoffice] = _passwordController.text.trim();
              }

              await FirebaseFirestore.instance.collection(FirestoreCollections.utilisateurs).doc(uid).update(updateData);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil, rôle et direction mis à jour.")));
            },
            child: const Text("ENREGISTRER"),
          ),
        ],
      ),
    );
  }

  // --- AJOUT AUTOMATIQUE AVEC SELECTION DU ROLE ET DE LA DIRECTION ---
  void _ajouterMembre() {
    _phoneController.clear();
    _emailController.clear();
    _passwordController.clear();

    // Configuration des états locaux par défaut du nouvel utilisateur
    String chosenRole = 'AGENT';
    String chosenDirection = AppDepartments.operations;
    String chosenVille = 'Bukavu';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Nouveau Collaborateur"),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("L'inscription synchronise automatiquement Firebase Auth et Firestore.", 
                  style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: "Numéro de téléphone de l'agent", hintText: "+243...", prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),

                // ✅ AJOUT : Sélection du Type de Profil (Rôle)
                const Text("Type de Profil (Rôle global) :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: chosenRole,
                  isExpanded: true,
                  items: _rolesGouvernance.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setDialogState(() => chosenRole = val!),
                ),
                const SizedBox(height: 15),

                // ✅ AJOUT : Sélection du Département (Direction Administrative)
                const Text("Département d'affectation :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: chosenDirection,
                  isExpanded: true,
                  items: AppDepartments.allDirections.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) => setDialogState(() => chosenDirection = val!),
                ),
                const SizedBox(height: 15),

                // ✅ AJOUT : Sélection de la Ville d'affectation
                const Text("Ville d'établissement :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: chosenVille,
                  isExpanded: true,
                  items: _villes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (val) => setDialogState(() => chosenVille = val!),
                ),

                const SizedBox(height: 15),
                const Divider(),
                const SizedBox(height: 10),
                const Text("Créer ses accès de connexion Web", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email Professionnel", hintText: "nom@easylocationrdc.com", prefixIcon: Icon(Icons.alternate_email), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Mot de passe initial Backoffice", prefixIcon: Icon(Icons.key), border: OutlineInputBorder()),
                  obscureText: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isActionLoading ? null : () => Navigator.pop(context), 
            child: const Text("ANNULER")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            onPressed: _isActionLoading ? null : () async {
              final phone = _phoneController.text.trim();
              final email = _emailController.text.trim();
              final password = _passwordController.text.trim();

              if (phone.isEmpty || email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez remplir tous les champs"), backgroundColor: Colors.orange));
                return;
              }

              setState(() => _isActionLoading = true);

              try {
                final indexDoc = await FirebaseFirestore.instance.collection('phone_index').doc(phone).get();
                
                String agentNom = "Collaborateur";
                String agentPrenom = "EasyLocation";

                if (indexDoc.exists) {
                  final linkedUid = indexDoc.data()?['uid'];
                  final currentProfileDoc = await FirebaseFirestore.instance.collection(FirestoreCollections.utilisateurs).doc(linkedUid).get();
                  if (currentProfileDoc.exists) {
                    final profileData = currentProfileDoc.data() as Map<String, dynamic>;
                    agentNom = profileData['nom'] ?? "Collaborateur";
                    agentPrenom = profileData['prenom'] ?? "EasyLocation";
                  }
                }

                HttpsCallable callable = FirebaseFunctions.instanceFor(region: "europe-west1")
                    .httpsCallable('creerAgentEquipe');
                
                // ✅ ENVOI DYNAMIQUE : Les valeurs choisies sont injectées à la Cloud Function
                final response = await callable.call(<String, dynamic>{
                  'emailProfessionnel': email,
                  'passwordBackoffice': password,
                  'nom': agentNom,
                  'prenom': agentPrenom,
                  'postnom': '',
                  'genre': 'Homme',
                  'telephone': phone,
                  'ville': chosenVille,
                  'roleEquipe': chosenRole, 
                  'direction': chosenRole == 'SUPER_ADMIN' ? AppDepartments.superAdmin : chosenDirection,
                });

                if (response.data['success'] == true) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response.data['message'] ?? "Membre de l'équipe synchronisé !"), backgroundColor: Colors.green)
                  );
                }
              } on FirebaseFunctionsException catch (fe) {
                debugPrint("❌ Erreur Cloud Function : ${fe.message}");
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Échec Serveur : ${fe.message}"), backgroundColor: Colors.red)
                );
              } catch (e) {
                debugPrint("❌ Erreur inattendue : $e");
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Une erreur de communication est survenue."), backgroundColor: Colors.red)
                );
              } finally {
                if (mounted) setState(() => _isActionLoading = false);
              }
            },
            child: _isActionLoading 
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("AJOUTER"),
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
                  Text("Gérez les directions, affectations de pôles et habilitations", style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                .collection(FirestoreCollections.utilisateurs)
                .where(UserFields.direction, whereIn: AppDepartments.allDirections)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Aucun membre d'équipe configuré."));

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final uid = docs[index].id;
                  
                  final role = data['activeRole'] ?? data[UserFields.role] ?? 'AGENT';
                  final direction = data[UserFields.direction] ?? AppDepartments.operations;
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
                        backgroundColor: isRestricted ? Colors.grey.shade200 : _getDirectionColor(direction).withOpacity(0.1),
                        child: Icon(
                          isRestricted ? Icons.lock_outline : _getDirectionIcon(direction), 
                          color: isRestricted ? Colors.grey : _getDirectionColor(direction)
                        ),
                      ),
                      title: Text(name, style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRestricted ? Colors.grey : Colors.black,
                        decoration: statut == 'licencié' ? TextDecoration.lineThrough : null
                      )),
                      subtitle: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(direction, 
                              style: TextStyle(color: isRestricted ? Colors.grey : _getDirectionColor(direction), fontSize: 10, fontWeight: FontWeight.bold)),
                            if (role == 'SUPER_ADMIN') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(4))),
                                child: const Text("ROOT", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              )
                            ],
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
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.settings_suggest_outlined),
                        onPressed: () => _modifierMembre(uid, role, direction, statut, ville, name, emailProf),
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

  Color _getDirectionColor(String direction) {
    switch (direction) {
      case AppDepartments.superAdmin: return Colors.red.shade900;
      case AppDepartments.directionGenerale: return Colors.indigo.shade900;
      case AppDepartments.finance: return Colors.green.shade700;
      case AppDepartments.rh: return Colors.blue.shade700;
      case AppDepartments.produitTech: return Colors.orange.shade800;
      case AppDepartments.marketing: return Colors.purple.shade700;
      case AppDepartments.logistique: return Colors.teal.shade700;
      default: return Colors.blueGrey;
    }
  }

  IconData _getDirectionIcon(String direction) {
    switch (direction) {
      case AppDepartments.superAdmin: return Icons.gavel;
      case AppDepartments.directionGenerale: return Icons.business; 
      case AppDepartments.finance: return Icons.account_balance_wallet;
      case AppDepartments.rh: return Icons.badge;
      case AppDepartments.produitTech: return Icons.biotech;
      case AppDepartments.marketing: return Icons.campaign;
      case AppDepartments.logistique: return Icons.local_shipping;
      default: return Icons.corporate_fare;
    }
  }
}