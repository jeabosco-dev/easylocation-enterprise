import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../providers/contract_provider.dart';
import '../../models/contract_model.dart';
import '../../utils/date_helper.dart';

class MigrationFormBottomSheet extends StatefulWidget {
  final ContractModel? contractToEdit;
  const MigrationFormBottomSheet({super.key, this.contractToEdit});

  @override
  State<MigrationFormBottomSheet> createState() => _MigrationFormBottomSheetState();
}

class _MigrationFormBottomSheetState extends State<MigrationFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Dates clés harmonisées
  late DateTime _selectedStartDate; // Prise d'effet
  late DateTime _selectedEndDate;   // Fin de bail

  // Contrôleurs d'adresse
  final TextEditingController _villeController = TextEditingController(text: "Bukavu");
  final TextEditingController _communeController = TextEditingController();
  final TextEditingController _quartierController = TextEditingController();
  final TextEditingController _avenueController = TextEditingController();
  final TextEditingController _numMaisonController = TextEditingController();

  // Contrôleurs Bailleur & Loyer
  final TextEditingController _nomBailleurController = TextEditingController();
  final TextEditingController _telBailleurController = TextEditingController();
  final TextEditingController _loyerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Initialisation des dates (Miroir de la logique bailleur)
    _selectedStartDate = widget.contractToEdit?.startDate ?? DateTime.now();
    _selectedEndDate = widget.contractToEdit?.endDate ?? DateTime.now().add(const Duration(days: 365));

    if (widget.contractToEdit != null) {
      final c = widget.contractToEdit!;
      _villeController.text = c.ville ?? "Bukavu";
      _communeController.text = c.commune ?? "";
      _quartierController.text = c.quartier ?? "";
      _avenueController.text = c.avenue ?? "";
      _numMaisonController.text = c.numeroMaison ?? "";
      _nomBailleurController.text = c.nomBailleur ?? "";
      // ✅ CORRIGÉ : Utilisation de telBailleur
      _telBailleurController.text = c.telBailleur ?? "";
      _loyerController.text = c.loyerMensuel.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _villeController.dispose();
    _communeController.dispose();
    _quartierController.dispose();
    _avenueController.dispose();
    _numMaisonController.dispose();
    _nomBailleurController.dispose();
    _telBailleurController.dispose();
    _loyerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdition = widget.contractToEdit != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdition ? "Mise à jour du bail" : "Activer mon bail numérique",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              const Text(
                "Harmonisez vos dates avec celles de votre contrat physique pour un suivi précis.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 25),

              // SECTION 1 : ADRESSE
              _sectionTitle("LOCALISATION DU LOGEMENT"),
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
                  Expanded(child: _buildField(_avenueController, "Avenue / Rue", Icons.add_location_alt, true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(_numMaisonController, "N°", Icons.home, false)),
                ],
              ),

              const Divider(height: 40),

              // SECTION 2 : INFOS BAILLEUR & LOYER
              _sectionTitle("CONTRACTANT & LOYER"),
              _buildField(_nomBailleurController, "Identité du Bailleur (Propriétaire)", Icons.person, true),
              _buildField(_telBailleurController, "Contact Téléphonique", Icons.phone, true, isTel: true),
              _buildField(_loyerController, "Prix du loyer mensuel (\$)", Icons.monetization_on, true, isPrice: true),

              const Divider(height: 40),

              // SECTION 3 : DATES DU BAIL (CRUCIAL)
              _sectionTitle("CHRONOLOGIE DU CONTRAT"),
              
              // DATE DE DÉBUT
              _dateTile(
                label: "Date de prise d'effet (Entrée)",
                date: _selectedStartDate,
                onTap: () => _pickDate(isStartDate: true),
                icon: Icons.calendar_today,
              ),
              
              const SizedBox(height: 10),

              // DATE DE FIN
              _dateTile(
                label: "Date d'expiration du bail",
                date: _selectedEndDate,
                onTap: () => _pickDate(isStartDate: false),
                icon: Icons.event_busy,
              ),

              const SizedBox(height: 30),
              _buildSubmitButton(isEdition),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1.1)),
    );
  }

  Widget _dateTile({required String label, required DateTime date, required VoidCallback onTap, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(DateFormat('dd MMMM yyyy').format(date), 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        trailing: const Icon(Icons.edit_calendar, size: 20, color: Colors.blue),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, bool required, {bool isTel = false, bool isPrice = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: (isTel || isPrice) ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) return "Obligatoire";
          if (isPrice && value != null) {
            final n = double.tryParse(value.replaceAll(',', '.'));
            if (n == null || n <= 0) return "Prix invalide";
          }
          return null;
        },
      ),
    );
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _selectedStartDate : _selectedEndDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)), 
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
          if (_selectedEndDate.isBefore(_selectedStartDate)) {
             _selectedEndDate = _selectedStartDate.add(const Duration(days: 365));
          }
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  Widget _buildSubmitButton(bool isEdition) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
        ),
        onPressed: _isLoading ? null : _submit,
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(isEdition ? "METTRE À JOUR LE BAIL" : "ACTIVER MON JOURNAL", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw "Utilisateur non connecté";

        final provider = context.read<ContractProvider>();
        
        final double loyerDouble = double.parse(_loyerController.text.replaceAll(',', '.'));
        
        final String adresseComplete = "${_numMaisonController.text}, Av. ${_avenueController.text}, Q. ${_quartierController.text}, ${_communeController.text}, ${_villeController.text}";

        if (widget.contractToEdit != null) {
          await provider.updateJournalDetails(
            contractId: widget.contractToEdit!.id,
            ville: _villeController.text,
            commune: _communeController.text,
            quartier: _quartierController.text,
            avenue: _avenueController.text,
            numeroMaison: _numMaisonController.text,
            nomBailleur: _nomBailleurController.text,
            telBailleur: _telBailleurController.text, // ✅ CORRIGÉ
            loyer: loyerDouble,
            startDate: _selectedStartDate,
            endDate: _selectedEndDate,
            adresseComplete: adresseComplete,
          );
        } else {
          await provider.activerJournalLocation(
            adresse: adresseComplete,
            nomBailleur: _nomBailleurController.text,
            telBailleur: _telBailleurController.text, // ✅ CORRIGÉ
            loyer: loyerDouble,
            locataireId: user.phoneNumber ?? user.uid,
            startDate: _selectedStartDate,
            endDate: _selectedEndDate,
            ville: _villeController.text,
            commune: _communeController.text,
            quartier: _quartierController.text,
            avenue: _avenueController.text,
            numeroMaison: _numMaisonController.text,
          );
        }

        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}