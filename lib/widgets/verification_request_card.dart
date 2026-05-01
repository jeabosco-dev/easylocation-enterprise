// lib/widgets/verification_request_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/property_service.dart';
import '../providers/user_profile_provider.dart';
import '../utils/ui_utils.dart';

class VerificationRequestCard extends StatefulWidget {
  final String propertyId;
  final String reference;
  final bool alreadyRequested; // 👈 Ajout : pour savoir si une demande existe déjà

  const VerificationRequestCard({
    super.key,
    required this.propertyId,
    required this.reference,
    this.alreadyRequested = false, // Par défaut false
  });

  @override
  State<VerificationRequestCard> createState() => _VerificationRequestCardState();
}

class _VerificationRequestCardState extends State<VerificationRequestCard> {
  bool _isSending = false;
  late bool _isSent; // 👈 On initialise selon l'état existant

  @override
  void initState() {
    super.initState();
    _isSent = widget.alreadyRequested; // Si déjà demandé, on affiche direct l'état vert
  }

  Future<void> _handleRequest(BuildContext context) async {
    final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
    final propertyService = PropertyService();

    if (userProvider.userData == null) {
      UIUtils.showSnackBar(context, "Connectez-vous pour sécuriser votre recherche", isError: true);
      return;
    }

    final user = userProvider.userData!;
    setState(() => _isSending = true);

    try {
      // ✅ Utilise exactement les paramètres attendus par ton nouveau PropertyService
      await propertyService.demanderVerification(
        propertyId: widget.propertyId,
        reference: widget.reference,
        clientName: userProvider.agentFullName, 
        clientPhone: user.telephone, 
        clientId: user.uid, 
      );

      if (mounted) {
        setState(() => _isSent = true);
        UIUtils.showSuccessDialog(
          context,
          title: "Mission acceptée !",
          message: "Nos experts vont vérifier ce bien en priorité pour vous rassurer sur sa conformité. Vous recevrez une notification très bientôt.",
        );
      }
    } catch (e) {
      if (mounted) {
        UIUtils.showSnackBar(context, "Échec de l'envoi. Vérifiez votre connexion.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isSent ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isSent ? Colors.green.shade200 : Colors.blue.shade100, 
          width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Icon(
                _isSent ? Icons.verified : Icons.shield_outlined, 
                color: _isSent ? Colors.green : Colors.blue.shade800, 
                size: 28
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isSent ? "Vérification lancée !" : "Un doute sur l’authenticité ?",
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 15, 
                    color: _isSent ? Colors.green.shade800 : Colors.blue.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!_isSent)
                _buildBadgeGratuit(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isSent 
              ? "Nous vérifions en priorité la conformité du bien ${widget.reference}. Restez serein, nous revenons vers vous dès que possible."
              : "Assurez-vous que tout est conforme avant de réserver. Demandez une certification gratuite : nos experts vérifient l’exactitude des informations en priorité.",
            style: TextStyle(
              fontSize: 13, 
              color: Colors.blueGrey.shade700, 
              height: 1.5,
              fontWeight: FontWeight.w500
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildBadgeGratuit() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        "OFFERT",
        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_isSending || _isSent) ? null : () => _handleRequest(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSent ? Colors.green : Colors.blue.shade800,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _isSent ? Colors.green.shade400 : Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isSending 
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isSent ? Icons.done_all : Icons.fact_check_rounded, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _isSent ? "DEMANDE EN COURS" : "CERTIFIER CE BIEN POUR MOI",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 0.5, 
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}