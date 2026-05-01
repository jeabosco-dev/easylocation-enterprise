import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/contract_provider.dart';
import '../../models/contract_model.dart';
import '../../services/export_service.dart';

class OngletContratLocataires extends StatelessWidget {
  const OngletContratLocataires({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResumeAudit(),
          const SizedBox(height: 30),
          _buildHeaderActions(context),
          const SizedBox(height: 15),
          // Correction : suppression du const ici pour garantir la réactivité du Consumer
          const Expanded(child: _TableauAuditLocataires()),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Audit & Suivi des Locataires",
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A5276)),
        ),
        ElevatedButton.icon(
          onPressed: () => _handleExport(context),
          icon: const Icon(Icons.file_download, size: 18),
          label: const Text("Exporter l'Audit (Excel)"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A5276),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _handleExport(BuildContext context) {
    final contrats = context.read<ContractProvider>().allContracts;
    final List<String> headers = [
      'TYPE',
      'LOCATAIRE',
      'TEL',
      'MAISON',
      'LOYER',
      'PROCHAIN RDV',
      'STATUT'
    ];

    final data = contrats.map((c) => {
          'TYPE': c.bailleurId == null ? "JOURNAL PERSO" : "OFFICIEL",
          'LOCATAIRE': c.locataireNom ?? "N/A",
          'TEL': c.locataireTel ?? "N/A",
          'MAISON': c.refMaison,
          'LOYER': "${c.loyerMensuel} \$",
          'PROCHAIN RDV': DateFormat('dd/MM/yyyy').format(c.prochainPaiement),
          'STATUT': c.joursRestants < 0 ? "RETARD" : "A JOUR",
        }).toList();

    ExportService.exportCustomDataToExcel(
        data: data,
        fileName: "Audit_Locataires_EasyLocation_${DateFormat('yyyyMMdd').format(DateTime.now())}",
        headers: headers);
  }

  Widget _buildResumeAudit() {
    return Consumer<ContractProvider>(
      builder: (context, provider, _) {
        final contrats = provider.allContracts;
        int retards = contrats.where((c) => c.joursRestants < 0).length;
        
        final officiels = contrats.where((c) => c.bailleurId != null).toList();
        double taux = 0;
        if (officiels.isNotEmpty) {
          int aJour = officiels.where((c) => c.joursRestants >= 0).length;
          taux = (aJour / officiels.length) * 100;
        }

        return Row(
          children: [
            _AuditStatCard("Locataires Actifs", "${contrats.length}", Colors.blueGrey),
            const SizedBox(width: 20),
            _AuditStatCard("En Retard", "$retards", Colors.red),
            const SizedBox(width: 20),
            _AuditStatCard(
              "Taux Recouvrement", 
              officiels.isEmpty ? "N/A" : "${taux.toStringAsFixed(1)}%", 
              Colors.green
            ),
          ],
        );
      },
    );
  }
}

class _TableauAuditLocataires extends StatelessWidget {
  const _TableauAuditLocataires();

  @override
  Widget build(BuildContext context) {
    return Consumer<ContractProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.allContracts.isEmpty) {
          return const Center(child: Text("Aucun contrat à auditer."));
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('LOCATAIRE', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('MAISON', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('PROCHAINE ÉCHÉANCE', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('STATUT', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('CONTACT', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: provider.allContracts.map((contrat) {
                    final bool estEnRetard = contrat.joursRestants < 0;
                    final bool isJournal = contrat.bailleurId == null;

                    return DataRow(cells: [
                      DataCell(_buildTypeBadge(isJournal)),
                      DataCell(Text(contrat.locataireNom ?? "Inconnu",
                          style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(contrat.refMaison)),
                      DataCell(Text(DateFormat('dd/MM/yyyy')
                          .format(contrat.prochainPaiement))),
                      DataCell(_StatusBadge(estEnRetard, isJournal)),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.chat, color: Colors.green),
                          onPressed: () => _relancerLocataire(contrat),
                          tooltip: "Relancer via WhatsApp",
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeBadge(bool isJournal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isJournal ? Colors.amber.shade100 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isJournal ? Colors.amber.shade300 : Colors.blue.shade300),
      ),
      child: Text(
        isJournal ? "JOURNAL" : "OFFICIEL",
        style: TextStyle(
          color: isJournal ? Colors.orange.shade900 : Colors.blue.shade900,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _relancerLocataire(ContractModel contrat) async {
    if (contrat.locataireTel == null || contrat.locataireTel!.isEmpty) return;
    
    final msg = "Bonjour ${contrat.locataireNom}, rappel EasyLocation concernant votre loyer pour la maison ${contrat.refMaison}.";
    final url = "https://wa.me/${contrat.locataireTel}?text=${Uri.encodeComponent(msg)}";
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _AuditStatCard extends StatelessWidget {
  final String title, value;
  final Color color;
  const _AuditStatCard(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isLate;
  final bool isJournal;
  const _StatusBadge(this.isLate, this.isJournal);

  @override
  Widget build(BuildContext context) {
    Color bgColor = isLate ? Colors.red.shade100 : Colors.green.shade100;
    Color textColor = isLate ? Colors.red.shade800 : Colors.green.shade800;
    String label = isLate ? "RETARD" : "À JOUR";

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        if (isJournal)
          const Padding(
            padding: EdgeInsets.only(top: 2, left: 4),
            child: Text("(Auto-déclaré)", 
                style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}