// lib/widgets/bailleur/migration_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/contract_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../models/contract_model.dart';
import '../../utils/phone_utils.dart';

class MigrationBottomSheet extends StatefulWidget {
  final ContractModel? contractToEdit;
  const MigrationBottomSheet({super.key, this.contractToEdit});

  @override
  State<MigrationBottomSheet> createState() => _MigrationBottomSheetState();
}

class _MigrationBottomSheetState extends State<MigrationBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late DateTime _selectedDate; 
  
  final TextEditingController _villeController = TextEditingController(text: "Bukavu");
  final TextEditingController _communeController = TextEditingController();
  final TextEditingController _quartierController = TextEditingController();
  final TextEditingController _avenueController = TextEditingController();
  final TextEditingController _numMaisonController = TextEditingController();
  final TextEditingController _telLocataireController = TextEditingController();
  final TextEditingController _loyerController = TextEditingController();
  final TextEditingController _nomLocataireController = TextEditingController();
  final TextEditingController _dureeInitialeController = TextEditingController(text: "1");

  @override
  void initState() {
    super.initState();
    
    _selectedDate = widget.contractToEdit?.startDate ?? DateTime.now();

    if (widget.contractToEdit != null) {
      final c = widget.contractToEdit!;
      _villeController.text = c.ville ?? "Bukavu";
      _communeController.text = c.commune ?? "";
      _quartierController.text = c.quartier ?? "";
      _avenueController.text = c.avenue ?? "";
      _numMaisonController.text = c.numeroMaison ?? "";
      _nomLocataireController.text = c.locataireNom; 
      _telLocataireController.text = c.locataireTel ?? ""; 
      _loyerController.text = c.loyerMensuel.toString();
      // On récupère la durée totale si possible, sinon 12 mois par défaut en édition
      _dureeInitialeController.text = c.dureeTotaleMois > 0 ? c.dureeTotaleMois.toString() : "12";
    }
  }

  @override
  void dispose() {
    _villeController.dispose();
    _communeController.dispose();
    _quartierController.dispose();
    _avenueController.dispose();
    _numMaisonController.dispose();
    _telLocataireController.dispose();
    _loyerController.dispose();
    _nomLocataireController.dispose();
    _dureeInitialeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)), 
      lastDate: DateTime.now().add(const Duration(days: 31)),
      helpText: "DATE DE PRISE D'EFFET DU BAIL",
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final userProfile = context.read<UserProfileProvider>().userData;
      if (userProfile == null) {
        setState(() => _isLoading = false);
        return;
      }

      double montantLoyer = double.parse(_loyerController.text.replaceAll(',', '.'));
      int dureeMois = int.parse(_dureeInitialeController.text);
      
      // ✅ Calcul de la date de fin basée sur la durée
      final DateTime dateFin = DateTime(
        _selectedDate.year, 
        _selectedDate.month + dureeMois, 
        _selectedDate.day
      );

      final provider = context.read<ContractProvider>();
      bool success = false;

      if (widget.contractToEdit != null) {
        // ✅ Ajout des paramètres obligatoires startDate et endDate
        success = await provider.updateJournalDetails(
          contractId: widget.contractToEdit!.id,
          ville: _villeController.text,
          commune: _communeController.text,
          quartier: _quartierController.text,
          avenue: _avenueController.text,
          numeroMaison: _numMaisonController.text,
          nomLocataire: _nomLocataireController.text,
          telLocataire: normalizePhoneNumber(_telLocataireController.text),
          loyer: montantLoyer,
          startDate: _selectedDate,
          endDate: dateFin, 
        );
      } else {
        success = await provider.importerContratExistant(
          bailleurId: userProfile.uid,
          data: {
            'ville': _villeController.text,
            'commune': _communeController.text,
            'quartier': _quartierController.text,
            'avenue': _avenueController.text,
            'numMaison': _numMaisonController.text,
            'locataireNom': _nomLocataireController.text,
            'locataireTel': normalizePhoneNumber(_telLocataireController.text),
            'loyer': montantLoyer,
            'startDate': _selectedDate, 
            'endDate': dateFin,
            'dureeBail': dureeMois,
          },
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.contractToEdit != null 
                  ? "Modifications enregistrées." 
                  : "Le contrat a été importé avec succès."),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Une erreur est survenue"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdition = widget.contractToEdit != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, 
        left: 20, 
        right: 20, 
        top: 20
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdition ? "Modifier le bail" : "Importer un bail existant", 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(isEdition 
                  ? "Ajustez les détails contractuels."
                  : "Saisissez les infos actuelles pour que l'app prenne le relais.", 
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              
              const Text("LOCALISATION DU BIEN", 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildField(_villeController, "Ville", Icons.location_city, true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(_communeController, "Commune", Icons.map, true)),
                ],
              ),
              _buildField(_quartierController, "Quartier", Icons.explore, true),
              Row(
                children: [
                  Expanded(child: _buildField(_avenueController, "Avenue", Icons.add_location_alt, true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(_numMaisonController, "N° Maison", Icons.home, false)),
                ],
              ),

              const Divider(height: 30),
              const Text("INFOS LOCATAIRE & LOYER", 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              _buildField(_nomLocataireController, "Nom complet du locataire", Icons.person, true),
              _buildField(_telLocataireController, "Téléphone (WhatsApp)", Icons.phone, true, isNumber: true),
              _buildField(_loyerController, "Loyer mensuel (\$)", Icons.attach_money, true, isNumber: true, isPrice: true),

              const Divider(height: 30),
              const Text("CHRONOLOGIE DU BAIL", 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Colors.blueGrey),
                  title: const Text("Date de prise d'effet (Signature)", style: TextStyle(fontSize: 13)),
                  subtitle: Text(DateFormat('dd MMMM yyyy').format(_selectedDate), 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  trailing: TextButton(onPressed: _pickDate, child: const Text("MODIFIER")),
                ),
              ),

              _buildField(
                _dureeInitialeController, 
                isEdition ? "Durée totale du contrat (mois)" : "Nombre de mois déjà payés (à l'entrée)", 
                Icons.timelapse, 
                true, 
                isNumber: true,
                hint: "Ex: 3, 6 ou 12 mois"
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEdition ? Colors.blue[900] : Colors.black, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEdition ? "METTRE À JOUR LE BAIL" : "ACTIVER LE SUIVI DIGITAL", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, bool required, {bool isNumber = false, bool isPrice = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) return "Ce champ est requis";
          if (isPrice && value != null) {
            final n = double.tryParse(value.replaceAll(',', '.'));
            if (n == null || n <= 0) return "Entrez un montant valide";
          }
          if (isNumber && value != null && controller == _dureeInitialeController) {
            final n = int.tryParse(value);
            if (n == null || n < 1) return "Min. 1 mois";
          }
          return null;
        },
      ),
    );
  }
}