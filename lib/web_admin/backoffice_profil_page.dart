import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:easylocation_mvp/utils/validations.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/services/user_service.dart';
import 'package:easylocation_mvp/constants/all_constants.dart';

// 🌟 Importation de ton widget de dialogue de mot de passe
import 'package:easylocation_mvp/widgets/admin/changement_password_dialog.dart';

class BackofficeProfilPage extends StatefulWidget {
  const BackofficeProfilPage({super.key});

  @override
  State<BackofficeProfilPage> createState() => _BackofficeProfilPageState();
}

class _BackofficeProfilPageState extends State<BackofficeProfilPage> with Validations {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  late TextEditingController _nomCtrl, _postnomCtrl, _prenomCtrl, _emailCtrl, 
                             _telephoneCtrl, _numeroCtrl, _avenueCtrl, 
                             _quartierCtrl, _communeCtrl;

  bool _isSaving = false;
  String? _imageUrl;
  // Suppression de la référence à UserRoles.ccv
  String _userRole = 'AGENT'; 
  String _userDirection = AppDepartments.operations; 

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProfileProvider>(context, listen: false).userData;
    
    _nomCtrl = TextEditingController(text: user?.nom);
    _postnomCtrl = TextEditingController(text: user?.postnom);
    _prenomCtrl = TextEditingController(text: user?.prenom);
    _emailCtrl = TextEditingController(text: user?.email_professionnel ?? user?.email);
    
    final adresse = user?.adresse_complete;
    _numeroCtrl = TextEditingController(text: adresse?['numero'] ?? user?.numeroMaison);
    _avenueCtrl = TextEditingController(text: adresse?['avenue'] ?? user?.avenue);
    _quartierCtrl = TextEditingController(text: adresse?['quartier'] ?? user?.quartier);
    _communeCtrl = TextEditingController(text: adresse?['commune'] ?? user?.commune);
    
    _imageUrl = user?.imageUrl;
    _telephoneCtrl = TextEditingController(text: user?.telephone);
    
    // Récupération directe sans dépendre d'une constante supprimée
    _userRole = user?.activeRole ?? 'AGENT';
    _userDirection = user?.direction ?? AppDepartments.operations;
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _postnomCtrl.dispose(); _prenomCtrl.dispose();
    _emailCtrl.dispose(); _telephoneCtrl.dispose(); _numeroCtrl.dispose();
    _avenueCtrl.dispose(); _quartierCtrl.dispose(); _communeCtrl.dispose();
    super.dispose();
  }

  // --- OUVERTURE DE LA BOÎTE DE DIALOGUE ---
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const ChangementPasswordDialog();
      },
    );
  }

  // --- LOGIQUE PHOTO COMPATIBLE WEB ---
  Future<void> _pickAndUploadImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<UserProfileProvider>(context, listen: false);
      final uid = provider.userData!.uid;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child('profils').child('${uid}_$timestamp.jpg');
      
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(pickedFile.path));
      }
      
      final url = await ref.getDownloadURL();
      setState(() => _imageUrl = url);
      _showSnackBar("Image chargée. N'oubliez pas de sauvegarder les modifications.", Colors.blue);
    } catch (e) {
      _showSnackBar("Erreur lors du téléversement de l'image.", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- LOGIQUE DE SAUVEGARDE DIRECTE ---
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = Provider.of<UserProfileProvider>(context, listen: false);

    try {
      final uid = provider.userData!.uid;
      
      final Map<String, dynamic> updates = {
        'nom': _nomCtrl.text.trim().toUpperCase(),
        'postnom': _postnomCtrl.text.trim(),
        'prenom': _prenomCtrl.text.trim(),
        'email_professionnel': _emailCtrl.text.trim(),
        'telephone': _telephoneCtrl.text.trim(),
        'imageUrl': _imageUrl ?? '',
        
        'adresse_complete': {
          'numero': _numeroCtrl.text.trim(),
          'avenue': _avenueCtrl.text.trim(),
          'quartier': _quartierCtrl.text.trim(),
          'commune': _communeCtrl.text.trim(),
          'ville': AppLocations.defaultCity.toLowerCase(),    
          'province': 'Sud-Kivu', 
          'pays': 'RDC',         
        },

        'numeroMaison': _numeroCtrl.text.trim(),
        'avenue': _avenueCtrl.text.trim(),
        'quartier': _quartierCtrl.text.trim(),
        'commune': _communeCtrl.text.trim(),
      };

      await _userService.updateProfile(uid, updates);
      await provider.refreshUser();

      _showSnackBar("Profil mis à jour avec succès ! ✅", Colors.green);
    } catch (e) {
      _showSnackBar("Erreur lors de la mise à jour : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isSaving 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mon Profil Professionnel",
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const Text("Visualisez vos privilèges d'accès et gérez vos informations professionnelles."),
                    const SizedBox(height: 30),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- CONFIGURATION ADMIN ET AVATAR (GAUCHE) ---
                        Expanded(
                          flex: 1,
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  _buildPhotoComponent(),
                                  const SizedBox(height: 20),
                                  Text(
                                    "${_prenomCtrl.text} ${_nomCtrl.text}".toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const Divider(height: 30),
                                  _buildBadgeAdministrative("RÔLE SYSTEME", _userRole.toUpperCase(), Colors.blue),
                                  const SizedBox(height: 12),
                                  _buildBadgeAdministrative("DÉPARTEMENT / POLE", AppDepartments.getLabel(_userDirection), Colors.orange),
                                  
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _showChangePasswordDialog,
                                    icon: const Icon(Icons.lock_open, size: 18),
                                    label: const Text(
                                      "MODIFIER LE MOT DE PASSE",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1E293B),
                                      side: const BorderSide(color: Color(0xFF1E293B)),
                                      minimumSize: const Size(double.infinity, 45),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        
                        // --- FORMULAIRE DES DONNÉES DE PROFIL (DROITE) ---
                        Expanded(
                          flex: 2,
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Informations Générales", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(child: _buildInputField(_nomCtrl, "Nom", Icons.person, isRequired: true)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildInputField(_postnomCtrl, "Postnom", Icons.person_outline, isRequired: true)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(child: _buildInputField(_prenomCtrl, "Prénom", Icons.person_outline, isRequired: true)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildInputField(_telephoneCtrl, "Téléphone Pro", Icons.phone, isRequired: true)),
                                    ],
                                  ),
                                  _buildInputField(_emailCtrl, "E-mail Professionnel", Icons.email, isRequired: true),
                                  
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Divider(),
                                  ),
                                  const Text("Adresse de Résidence (Affectation Terrain)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(flex: 1, child: _buildInputField(_numeroCtrl, "N° Maison", Icons.home)),
                                      const SizedBox(width: 16),
                                      Expanded(flex: 3, child: _buildInputField(_avenueCtrl, "Avenue", Icons.add_road)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(child: _buildInputField(_quartierCtrl, "Quartier", Icons.location_city)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildInputField(_communeCtrl, "Commune", Icons.explore)),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                  _buildSaveButton(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPhotoComponent() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 70,
          backgroundColor: Colors.grey.shade200,
          child: _imageUrl != null && _imageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(70),
                  child: CachedNetworkImage(
                    imageUrl: _imageUrl!,
                    fit: BoxFit.cover,
                    width: 140,
                    height: 140,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
                  ),
                )
              : Icon(Icons.business_center, size: 65, color: Colors.grey.shade400),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: FloatingActionButton.small(
            onPressed: _pickAndUploadImage,
            tooltip: "Modifier la photo",
            child: const Icon(Icons.camera_alt, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeAdministrative(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color.withOpacity(0.9))),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: isRequired ? (v) => (v == null || v.trim().isEmpty) ? "Ce champ est requis" : null : null,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _handleSave,
        icon: const Icon(Icons.save),
        label: const Text("ENREGISTRER MES INFORMATIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: color, 
        behavior: SnackBarBehavior.floating, 
        width: 420
      )
    );
  }
}