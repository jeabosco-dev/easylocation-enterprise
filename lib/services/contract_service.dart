// lib/services/contract_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ContractService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Récupérer le contrat actif d'un locataire
  Stream<DocumentSnapshot?> getActiveContract(String locataireId) {
    return _db
        .collection('contracts')
        .where('locataireId', isEqualTo: locataireId)
        .where('status', isEqualTo: 'active') // 'status' et 'active' correspondent à ton modèle
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null);
  }
}