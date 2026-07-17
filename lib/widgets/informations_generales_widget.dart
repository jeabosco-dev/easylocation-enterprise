import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/formulaire_publication_controller.dart';
import 'package:easylocation_mvp/services/config_service.dart';
import 'package:easylocation_mvp/services/location_service.dart';
import 'selecteur_localisation.dart';

class InformationsGeneralesWidget extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  const InformationsGeneralesWidget({super.key, required this.formKey});

  @override
  State<InformationsGeneralesWidget> createState() => _InformationsGeneralesWidgetState();
}

class _InformationsGeneralesWidgetState extends State<InformationsGeneralesWidget> {
  final LocationService _locService = LocationService();
  
  late Future<List<String>> _provincesFuture;

  List<String> _villes = [];
  List<String> _communes = [];
  List<String> _quartiers = [];
  List<String> _avenues = [];

  @override
  void initState() {
    super.initState();
    _provincesFuture = _locService.getProvinces();
    _initLocalisationData();
  }

  Future<void> _initLocalisationData() async {
    final controller = Provider.of<FormulairePublicationController>(context, listen: false);
    final data = controller.data;
    if (data.province != null) await _loadVilles(data.province!);
    if (data.ville != null) await _loadCommunes(data.province!, data.ville!);
    if (data.commune != null) await _loadQuartiers(data.province!, data.ville!, data.commune!);
    if (data.quartier != null) await _loadAvenues(data.province!, data.ville!, data.commune!, data.quartier!);
  }

  Future<void> _loadVilles(String p) async {
    final list = await _locService.getVilles(p);
    if (mounted) setState(() => _villes = [...list, "Autre"]);
  }

  Future<void> _loadCommunes(String p, String v) async {
    final list = await _locService.getCommunes(p, v);
    if (mounted) setState(() => _communes = [...list, "Autre"]);
  }

  Future<void> _loadQuartiers(String p, String v, String c) async {
    final list = await _locService.getQuartiers(p, v, c);
    if (mounted) setState(() => _quartiers = [...list, "Autre"]);
  }

  Future<void> _loadAvenues(String p, String v, String c, String q) async {
    final list = await _locService.getAvenues(p, v, c, q);
    if (mounted) setState(() => _avenues = [...list, "Autre"]);
  }

  void _showComingSoonMessage(BuildContext context, String typeChoisi) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rocket_launch, size: 50, color: Colors.blue),
              const SizedBox(height: 16),
              const Text("Bientôt disponible !", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text("L'offre pour les '$typeChoisi' arrive bientôt. Pour l'instant, nous optimisons l'expérience pour les Maisons Résidentielles.",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              const Text("Besoin d'aide ou d'une offre sur mesure ?"),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final Uri launchUri = Uri(scheme: 'tel', path: '+243980361265');
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  }
                },
                icon: const Icon(Icons.phone),
                label: const Text("+243 980 361 265", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FormulairePublicationController>(context);
    final data = controller.data;
    
    final config = context.watch<ConfigService>();
    final List<String> categoriesDisponibles = config.categoriesImmo;

    return Form(
      key: widget.formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text("Type de Propriété", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: categoriesDisponibles.contains(data.typeBien) ? data.typeBien : (categoriesDisponibles.isNotEmpty ? categoriesDisponibles.first : null),
            decoration: InputDecoration(
              labelText: "Quel type de bien publiez-vous ? *",
              prefixIcon: const Icon(Icons.home_work_outlined, color: Colors.blue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: categoriesDisponibles.map((String type) {
              final bool isAvailable = type == "Maison Résidentielle";
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type, style: TextStyle(color: isAvailable ? Colors.black : Colors.grey, fontWeight: isAvailable ? FontWeight.w500 : FontWeight.normal)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue == "Maison Résidentielle") {
                controller.updateData(typeBien: newValue);
              } else if (newValue != null) {
                _showComingSoonMessage(context, newValue);
                controller.updateData(typeBien: "Maison Résidentielle");
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 24),
          const Text("Localisation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          FutureBuilder<List<String>>(
            future: _provincesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final provincesList = snapshot.data ?? [];

              return SelecteurLocalisation(
                provincesDispo: provincesList,
                provinceSaisie: data.province,
                villeSaisie: data.ville ?? "Toutes",
                communeSaisie: data.commune ?? "Toutes",
                quartierSaisi: data.quartier ?? "Toutes",
                avenueSaisie: data.avenue ?? "Toutes",
                villesDispo: _villes,
                communesDispo: _communes,
                quartiersDispo: _quartiers,
                avenuesDispo: _avenues,
                provinceSpecifiqueCtrl: controller.provinceSpecifiqueCtrl,
                villeSpecifiqueCtrl: controller.villeSpecifiqueCtrl,
                communeSpecifiqueCtrl: controller.communeSpecifiqueCtrl,
                quartierSpecifiqueCtrl: controller.quartierSpecifiqueCtrl,
                avenueSpecifiqueCtrl: controller.avenueSpecifiqueCtrl,
                onProvinceChange: (val) {
                  controller.updateData(
                    province: val, 
                    ville: null, commune: null, quartier: null, avenue: null,
                    provinceSpecifique: null, 
                    villeSpecifique: null, communeSpecifique: null, quartierSpecifique: null, avenueSpecifique: null
                  );
                  controller.provinceSpecifiqueCtrl.clear();
                  controller.villeSpecifiqueCtrl.clear();
                  controller.communeSpecifiqueCtrl.clear();
                  controller.quartierSpecifiqueCtrl.clear();
                  controller.avenueSpecifiqueCtrl.clear();
                  if (val != null && val != "Autre") _loadVilles(val);
                },
                onVilleChange: (val) {
                  controller.updateData(ville: val, commune: null, quartier: null, avenue: null, villeSpecifique: null, communeSpecifique: null, quartierSpecifique: null, avenueSpecifique: null);
                  if (val != "Autre") controller.villeSpecifiqueCtrl.clear();
                  controller.communeSpecifiqueCtrl.clear();
                  controller.quartierSpecifiqueCtrl.clear();
                  controller.avenueSpecifiqueCtrl.clear();
                  if (val != null && val != "Autre") _loadCommunes(data.province!, val);
                },
                onCommuneChange: (val) {
                  controller.updateData(commune: val, quartier: null, avenue: null, communeSpecifique: null, quartierSpecifique: null, avenueSpecifique: null);
                  if (val != "Autre") controller.communeSpecifiqueCtrl.clear();
                  controller.quartierSpecifiqueCtrl.clear();
                  controller.avenueSpecifiqueCtrl.clear();
                  if (val != null && val != "Autre") _loadQuartiers(data.province!, data.ville!, val);
                },
                onQuartierChange: (val) {
                  controller.updateData(quartier: val, avenue: null, quartierSpecifique: null, avenueSpecifique: null);
                  if (val != "Autre") controller.quartierSpecifiqueCtrl.clear();
                  controller.avenueSpecifiqueCtrl.clear();
                  if (val != null && val != "Autre") _loadAvenues(data.province!, data.ville!, data.commune!, val);
                },
                onAvenueChange: (val) {
                  controller.updateData(avenue: val, avenueSpecifique: null);
                  if (val != "Autre") controller.avenueSpecifiqueCtrl.clear();
                },
              );
            },
          ),
          
          const SizedBox(height: 12),
          _buildTextField(label: 'Numéro de la maison (Optionnel)', hint: 'Ex: 12A', controller: controller.numeroMaisonCtrl, onChanged: (value) => controller.updateData(numeroMaison: value)),
          const Padding(padding: EdgeInsets.only(top: 4.0, left: 4.0), child: Text("Laissez vide si la maison n'a pas de numéro", style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontStyle: FontStyle.italic))),
          const SizedBox(height: 24),
          const Text("Conditions financières", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTextField(label: 'Prix de loyer mensuel (\$) *', hint: 'Ex: 150', keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], initialValue: data.price?.toString(), onChanged: (value) => controller.updateData(price: double.tryParse(value) ?? 0.0), validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0 ? 'Prix invalide' : null),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTextField(label: 'Garantie idéale *', hint: 'Mois', initialValue: data.garantieIdeale?.toString(), keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (value) => controller.updateData(garantieIdeale: int.tryParse(value)), validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0 ? 'Requis' : null)),
              const SizedBox(width: 10),
              Expanded(child: _buildTextField(label: 'Garantie min. *', hint: 'Mois', initialValue: data.garantieMinimale?.toString(), keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (value) => controller.updateData(garantieMinimale: int.tryParse(value)), validator: (value) { final min = int.tryParse(value ?? '') ?? 0; final ideal = data.garantieIdeale ?? 0; if (min <= 0) return 'Invalide'; if (min > ideal) return 'Max $ideal'; return null; })),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Disponibilité & Niveau", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildRadioSection<bool>(title: "Le bien est disponible : *", options: [RadioOption(label: "Immédiatement", value: true), RadioOption(label: "À une date précise", value: false)], groupValue: data.disponibiliteImmediate, validator: (val) => val == null ? "Veuillez faire un choix" : null, onChanged: (val) => controller.updateData(disponibiliteImmediate: val, dateDisponibilite: null)),
          if (data.disponibiliteImmediate == false) ...[
            FormField<DateTime>(
              initialValue: data.dateDisponibilite,
              validator: (val) => val == null ? "Obligatoire : Veuillez sélectionner une date précise" : null,
              builder: (state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    shape: RoundedRectangleBorder(side: BorderSide(color: state.hasError ? Colors.red : Colors.grey), borderRadius: BorderRadius.circular(4)), 
                    title: Text(data.dateDisponibilite != null ? 'Date: ${data.dateDisponibilite!.day}/${data.dateDisponibilite!.month}/${data.dateDisponibilite!.year}' : 'Cliquer pour choisir la date *'), 
                    trailing: const Icon(Icons.calendar_today), 
                    onTap: () async { 
                      final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 2))); 
                      if (picked != null) { 
                        state.didChange(picked); 
                        controller.updateData(dateDisponibilite: picked); 
                      } 
                    }
                  ),
                ),
                if (state.hasError) Padding(padding: const EdgeInsets.only(top: 8.0, left: 12.0), child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          _buildRadioSection<bool>(title: "Niveau de propriété : *", options: [RadioOption(label: "Maison non en étage", value: false), RadioOption(label: "Maison en étage", value: true)], groupValue: data.maisonEnEtage, validator: (val) => val == null ? "Veuillez préciser le niveau" : null, onChanged: (val) { controller.updateData(maisonEnEtage: val, niveauEtage: val == true ? null : 0); if (val == false) controller.niveauEtageCtrl.clear(); }),
          if (data.maisonEnEtage == true) ...[
            const SizedBox(height: 8),
            _buildTextField(label: 'Numéro de l\'étage *', hint: '0, 1, 2, 99...', controller: controller.niveauEtageCtrl, keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (value) => controller.updateData(niveauEtage: int.tryParse(value)), validator: (value) => (value == null || value.isEmpty) ? 'Ce champ est obligatoire' : null),
            const Padding(padding: EdgeInsets.only(top: 8.0, left: 4.0), child: Text("Note : Mettez 0 pour Rez-de-chaussée, 99 pour Grenier. Pour les autres, mettez le chiffre exact (ex: 1 pour 1er étage).", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint, TextEditingController? controller, String? initialValue, TextInputType keyboard = TextInputType.text, List<TextInputFormatter>? formatters, Function(String)? onChanged, String? Function(String?)? validator}) {
    return TextFormField(controller: controller, initialValue: controller == null ? initialValue : null, decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)), keyboardType: keyboard, inputFormatters: formatters, onChanged: onChanged, validator: validator);
  }

  Widget _buildRadioSection<T>({required String title, required List<RadioOption> options, required T? groupValue, required String? Function(T?)? validator, required Function(T) onChanged}) {
    return FormField<T>(
      initialValue: groupValue, 
      validator: validator, 
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0), 
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))
          ),
          ...options.map((opt) => Material(
            color: Colors.transparent,
            child: RadioListTile<T>(
              title: Text(opt.label), 
              value: opt.value, 
              groupValue: groupValue, 
              onChanged: (val) { 
                if (val != null) { 
                  state.didChange(val); 
                  onChanged(val); 
                } 
              }, 
              contentPadding: EdgeInsets.zero, 
              dense: true
            ),
          )),
          if (state.hasError) 
            Padding(
              padding: const EdgeInsets.only(left: 12.0), 
              child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12))
            ),
        ]
      )
    );
  }
}

class RadioOption {
  final String label;
  final dynamic value;
  RadioOption({required this.label, required this.value});
}