import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easylocation_mvp/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';

class OperationsModule extends StatefulWidget {
  const OperationsModule({super.key});

  @override
  State<OperationsModule> createState() => _OperationsModuleState();
}

class _OperationsModuleState extends State<OperationsModule> {
  
  // --- FONCTION CŒUR : LOGS D'AUDIT ---
  Future<void> _createAuditLog({
    required BuildContext context,
    required String actionType,
    required String propertyId,
    required String propertyName,
    String? clientName,
    double? amount,
    required String details,
  }) async {
    final profileProvider = context.read<UserProfileProvider>();
    final adminName = "${profileProvider.userData?.prenom} ${profileProvider.userData?.nom}";
    final adminRole = profileProvider.userData?.activeRole ?? "Admin";

    await FirebaseFirestore.instance.collection('admin_logs').add({
      'actionType': actionType,
      'adminName': adminName, 
      'adminRole': adminRole,
      'propertyId': propertyId,
      'propertyName': propertyName,
      'clientName': clientName ?? "N/A",
      'amount': amount ?? 0.0,
      'timestamp': FieldValue.serverTimestamp(),
      'details': details,
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF1E293B),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              indicatorWeight: 3,
              tabs: [
                Tab(icon: Icon(Icons.verified_user), text: "CERTIFICATIONS"),
                Tab(icon: Icon(Icons.handshake), text: "REMISE DES CLÉS"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCertificationList(),
                _buildConfirmationList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. LISTE DES CERTIFICATIONS ---
  Widget _buildCertificationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.properties)
          .where(FirestoreFields.isVerified, isEqualTo: false) 
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Aucune propriété en attente de vérification.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String titreBien = data['typeMaison'] ?? "Bien immobilier";

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.home, color: Colors.white)),
                title: Text(titreBien, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${data['commune']} - ${data['quartier']}"),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _rejeterPropriete(context, doc.id, data),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text("REJETER", style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _validerCertification(context, doc.id, data),
                          icon: const Icon(Icons.check_circle),
                          label: const Text("CERTIFIER & GARANTIR"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- 2. LISTE DES CONFIRMATIONS ---
  Widget _buildConfirmationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.properties)
          .where(FirestoreFields.status, isEqualTo: PropertyStatus.reserved)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Aucune remise de clés programmée.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return Card(
              elevation: 2,
              color: Colors.blue.shade50,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: const Icon(Icons.vpn_key, color: Colors.blue, size: 30),
                title: Text("Clés : ${data['typeMaison']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Propriétaire : ${data['prenomProprietaire']} | Prix : ${data['price']}\$"),
                trailing: ElevatedButton(
                  onPressed: () => _confirmerRemiseCles(context, doc.id, data),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text("CONFIRMER LA REMISE", style: TextStyle(color: Colors.white)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- LOGIQUE METIER (Actions) ---

  void _validerCertification(BuildContext context, String id, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(id).update({
        FirestoreFields.isVerified: true,
        FirestoreFields.verificationDate: FieldValue.serverTimestamp(),
      });
      await _createAuditLog(context: context, actionType: "CERTIFICATION", propertyId: id, propertyName: data['typeMaison'] ?? "N/A", details: "Validation terrain effectuée.");
      if (mounted) _showSuccessSnackBar("Le bien est désormais certifié.");
    } catch (e) { _showErrorSnackBar("Erreur technique lors de la validation."); }
  }

  void _rejeterPropriete(BuildContext context, String id, Map<String, dynamic> data) async {
    final bool confirm = await _showConfirmDialog(data['typeMaison'] ?? "ce bien");
    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(id).delete();
        await _createAuditLog(context: context, actionType: "REJET_ANNONCE", propertyId: id, propertyName: data['typeMaison'] ?? "N/A", details: "Suppression pour non-conformité.");
        if (mounted) _showSuccessSnackBar("Annonce retirée.");
      } catch (e) { _showErrorSnackBar("Erreur lors de la suppression."); }
    }
  }

  void _confirmerRemiseCles(BuildContext context, String id, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection(FirestoreCollections.properties).doc(id).update({
        FirestoreFields.status: PropertyStatus.rented,
        'isVisible': false,
        'dateCloture': FieldValue.serverTimestamp(),
      });
      await _createAuditLog(context: context, actionType: "CLOTURE_VENTE", propertyId: id, propertyName: data['typeMaison'] ?? "N/A", amount: (data['price'] as num?)?.toDouble(), details: "Transaction terminée avec succès.");
      if (mounted) _showSuccessSnackBar("Vente clôturée.");
    } catch (e) { _showErrorSnackBar("Erreur lors de la clôture."); }
  }

  // --- UI HELPERS ---
  Widget _buildEmptyState(String message) {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.inbox, size: 60, color: Colors.grey),
        const SizedBox(height: 10),
        Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16)),
      ],
    ));
  }

  Future<bool> _showConfirmDialog(String titre) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Action irréversible"),
        content: Text("Voulez-vous vraiment supprimer définitivement '$titre' ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULER")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("SUPPRIMER", style: TextStyle(color: Colors.white))),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  void _showErrorSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
}
