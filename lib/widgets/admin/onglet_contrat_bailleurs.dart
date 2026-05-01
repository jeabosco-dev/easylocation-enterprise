import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/contract_provider.dart';
import '../../models/contract_model.dart';
import '../../services/export_service.dart';

class OngletContratBailleurs extends StatelessWidget {
  const OngletContratBailleurs({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResumeMetriques(),
          const SizedBox(height: 30),
          _buildHeaderActions(context),
          const SizedBox(height: 15),
          const Expanded(child: _TableauContrats()),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Performance & Échéances Bailleurs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A5276)),
            ),
            Text(
              "Suivi de l'adoption et de la santé financière du parc (Bukavu)",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _handleExport(context),
              icon: const Icon(Icons.description, size: 18),
              label: const Text("Export Audit Excel"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Actualiser les données",
              onPressed: () => context.read<ContractProvider>().loadAllActiveContractsForAdmin(),
            ),
          ],
        )
      ],
    );
  }

  void _handleExport(BuildContext context) {
    final contrats = context.read<ContractProvider>().allContracts;
    if (contrats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune donnée à exporter"), backgroundColor: Colors.orange)
      );
      return;
    }

    final List<String> headers = ['BAILLEUR', 'TEL', 'PROPRIÉTÉ', 'LOCATAIRE', 'TYPE', 'LOYER', 'ÉCHÉANCE'];
    final data = contrats.map((c) => {
      'BAILLEUR': c.nomBailleur ?? "N/A",
      'TEL': c.bailleurTel ?? "N/A",
      'PROPRIÉTÉ': c.refMaison,
      'LOCATAIRE': c.locataireNom,
      'TYPE': (c.locataireId == null || c.locataireId!.isEmpty) ? "IMPORTÉ" : "OFFICIEL",
      'LOYER': "${c.loyerMensuel}\$",
      'ÉCHÉANCE': DateFormat('dd/MM/yyyy').format(c.endDate),
    }).toList();

    ExportService.exportCustomDataToExcel(
      data: data, 
      fileName: "Audit_Bailleurs_EasyLocation_${DateFormat('dd_MM_yyyy').format(DateTime.now())}", 
      headers: headers
    );
  }

  Widget _buildResumeMetriques() {
    return Consumer<ContractProvider>(
      builder: (context, provider, _) {
        final contrats = provider.allContracts;
        final nbImports = contrats.where((c) => c.locataireId == null || c.locataireId!.isEmpty).length;
        final totalLoyer = contrats.fold(0.0, (sum, item) => sum + (double.tryParse(item.loyerMensuel.toString()) ?? 0.0));

        return Row(
          children: [
            _MetricTile("Baux Actifs", "${contrats.length}", Colors.blueGrey),
            const SizedBox(width: 20),
            _MetricTile("Contrats Importés", "$nbImports", Colors.orange),
            const SizedBox(width: 20),
            _MetricTile("CA Sous Gestion", "${totalLoyer.toStringAsFixed(0)} \$", Colors.green),
            const SizedBox(width: 20),
            _MetricTile("Alertes (60j)", "${provider.totalAlertes}", Colors.redAccent),
          ],
        );
      }
    );
  }
}

class _TableauContrats extends StatelessWidget {
  const _TableauContrats();

  @override
  Widget build(BuildContext context) {
    return Consumer<ContractProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());
        if (provider.allContracts.isEmpty) {
           return const Center(child: Text("Aucune activité bailleur détectée.", style: TextStyle(color: Colors.grey)));
        }
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F6F7)),
                horizontalMargin: 20,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('BAILLEUR', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('PROPRIÉTÉ', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('LOCATAIRE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('LOYER', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ÉCHÉANCE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: provider.allContracts.map((contrat) {
                  final isImported = (contrat.locataireId == null || contrat.locataireId!.isEmpty);
                  return DataRow(cells: [
                    DataCell(Text(contrat.nomBailleur ?? "-", style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(contrat.refMaison)),
                    DataCell(Text(contrat.locataireNom)),
                    DataCell(_buildTypeBadge(isImported)),
                    DataCell(Text("${contrat.loyerMensuel}\$")),
                    DataCell(_AlerteChip(contrat.joursRestants)),
                    DataCell(Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_calendar, color: Colors.blue, size: 18),
                          tooltip: "Rectifier dates",
                          onPressed: () => _editDate(context, contrat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.exit_to_app, color: Colors.red, size: 18),
                          tooltip: "Forcer clôture",
                          onPressed: () => _confirmCloture(context, contrat),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeBadge(bool isImported) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isImported ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isImported ? "IMPORTÉ" : "OFFICIEL",
        style: TextStyle(
          color: isImported ? Colors.orange[800] : Colors.blue[800],
          fontSize: 10,
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  void _editDate(BuildContext context, ContractModel contrat) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: contrat.startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: "MODIFIER LA DATE D'ENTRÉE EFFECTIVE",
    );
    if (picked != null && context.mounted) {
      await context.read<ContractProvider>().updateContractStartDate(contrat.id, picked);
    }
  }

  void _confirmCloture(BuildContext context, ContractModel contrat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clôturer ce bail ?"),
        content: Text("Le bien ${contrat.refMaison} redeviendra 'Disponible' dans l'inventaire."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // CORRECTION ICI : Utilisation du nom correct de la méthode 'cloturerBail'
              await context.read<ContractProvider>().cloturerBail(contrat.id, contrat.propertyId ?? '');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Confirmer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title, value; final Color color;
  const _MetricTile(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );
}

class _AlerteChip extends StatelessWidget {
  final int jours;
  const _AlerteChip(this.jours);

  @override
  Widget build(BuildContext context) {
    Color c;
    String txt = "J-$jours";
    if (jours <= 0) { c = Colors.black; txt = "EXPIRÉ"; }
    else if (jours < 30) { c = Colors.red; }
    else if (jours < 60) { c = Colors.orange; }
    else { c = Colors.green; }

    return Chip(
      label: Text(txt, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)), 
      backgroundColor: c,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}