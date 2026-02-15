import 'package:easylocation_mvp/screens/verification_otp_update_phone_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // ✅ AJOUTÉ POUR LE NETTOYAGE

import 'package:easylocation_mvp/utils/validations.dart';
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModificationProfilPage extends StatefulWidget {
  final String role; 

  const ModificationProfilPage({super.key, required this.role});

  @override
  State<ModificationProfilPage> createState() => _ModificationProfilPageState();
}

class _ModificationProfilPageState extends State<ModificationProfilPage> with Validations {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  late TextEditingController _nomCtrl, _postnomCtrl, _prenomCtrl, _emailCtrl, 
                               _telephoneCtrl, _numeroCtrl, _avenueCtrl, 
                               _quartierCtrl, _communeCtrl;

  bool _isSaving = false;
  String? _imageUrl;
  String? _initialPhone;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProfileProvider>(context, listen: false).userData;
    
    _nomCtrl = TextEditingController(text: user?.nom);
    _postnomCtrl = TextEditingController(text: user?.postnom);
    _prenomCtrl = TextEditingController(text: user?.prenom);
    _emailCtrl = TextEditingController(text: user?.email);
    _numeroCtrl = TextEditingController(text: user?.numeroMaison);
    _avenueCtrl = TextEditingController(text: user?.avenue);
    _quartierCtrl = TextEditingController(text: user?.quartier);
    _communeCtrl = TextEditingController(text: user?.commune);
    
    _imageUrl = user?.imageUrl;
    _initialPhone = user?.telephone.replaceAll('+243', '').trim();
    _telephoneCtrl = TextEditingController(text: _initialPhone);
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _postnomCtrl.dispose(); _prenomCtrl.dispose();
    _emailCtrl.dispose(); _telephoneCtrl.dispose(); _numeroCtrl.dispose();
    _avenueCtrl.dispose(); _quartierCtrl.dispose(); _communeCtrl.dispose();
    super.dispose();
  }

  // --- LOGIQUE PHOTO ---
  Future<void> _showPhotoOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Prendre une photo"),
              onTap: () { Navigator.pop(context); _pickAndUploadImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text("Choisir depuis la galerie"),
              onTap: () { Navigator.pop(context); _pickAndUploadImage(ImageSource.gallery); },
            ),
            if (_imageUrl != null && _imageUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Supprimer la photo", style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); setState(() => _imageUrl = null); },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      XFile fileToUpload = pickedFile;

      if (!kIsWeb) {
        final targetPath = '${pickedFile.path.substring(0, pickedFile.path.lastIndexOf('.'))}_compressed.jpg';
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          pickedFile.path, targetPath, quality: 60, minWidth: 600, minHeight: 600,
        );
        if (compressedFile != null) fileToUpload = XFile(compressedFile.path);
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child('profils').child('${uid}_$timestamp.jpg');
      
      await ref.putFile(File(fileToUpload.path));
      final url = await ref.getDownloadURL();

      // ✅ NETTOYAGE DU CACHE : On supprime l'ancienne URL du cache pour forcer la mise à jour
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        await DefaultCacheManager().removeFile(_imageUrl!);
      }

      setState(() => _imageUrl = url);
    } catch (e) {
      _showSnackBar("Erreur lors de l'upload.", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- SAUVEGARDE & VÉRIFICATION TÉLÉPHONE ---
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPhone = _telephoneCtrl.text.trim();
    if (currentPhone != _initialPhone) {
      _showVerificationDialog("+243$currentPhone");
    } else {
      _performUpdate();
    }
  }

  void _showVerificationDialog(String fullPhone) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text("Changement de numéro"),
        content: Text("Nous devons vérifier le numéro $fullPhone. Envoyer un SMS ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendSmsAndNavigate(fullPhone);
            }, 
            child: const Text("Vérifier")
          ),
        ],
      )
    );
  }

  Future<void> _sendSmsAndNavigate(String fullPhone) async {
    setState(() => _isSaving = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        verificationCompleted: (PhoneAuthCredential credential) {
          if (mounted) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => VerificationOtpUpdatePhonePage(
              verificationId: '', 
              telephone: fullPhone,
              autoCredential: credential,
              onVerificationComplete: _performUpdate,
            )));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _showSnackBar("Échec de l'envoi : ${e.message}", Colors.red);
          setState(() => _isSaving = false);
        },
        codeSent: (String vid, int? resendToken) {
          setState(() => _isSaving = false);
          Navigator.push(context, MaterialPageRoute(builder: (_) => VerificationOtpUpdatePhonePage(
            verificationId: vid,
            telephone: fullPhone,
            onVerificationComplete: _performUpdate,
          )));
        },
        codeAutoRetrievalTimeout: (String vid) {},
      );
    } catch (e) {
      _showSnackBar("Erreur : $e", Colors.red);
      setState(() => _isSaving = false);
    }
  }

  Future<void> _performUpdate() async {
    setState(() => _isSaving = true);
    final provider = Provider.of<UserProfileProvider>(context, listen: false);

    try {
      final uid = provider.userData!.uid;
      
      final Map<String, dynamic> updates = {
        'nom': _nomCtrl.text.trim().toUpperCase(),
        'postnom': _postnomCtrl.text.trim(),
        'prenom': _prenomCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'telephone': "+243${_telephoneCtrl.text.trim()}",
        'imageUrl': _imageUrl ?? '',
        'numeroMaison': _numeroCtrl.text.trim(),
        'avenue': _avenueCtrl.text.trim(),
        'quartier': _quartierCtrl.text.trim(),
        'commune': _communeCtrl.text.trim(),
      };

      await _userService.updateProfile(uid, updates);
      await provider.refreshUser();

      _showSnackBar("Profil mis à jour ! ✅", Colors.green);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Erreur : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier mon Profil"), elevation: 0),
      body: _isSaving 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildPhotoHeader(),
                    const SizedBox(height: 25),
                    _buildTextField(_nomCtrl, "Nom", Icons.person, validator: (v) => requiredField(v, "Nom")),
                    _buildTextField(_postnomCtrl, "Postnom", Icons.person_outline, validator: (v) => requiredField(v, "Postnom")),
                    _buildTextField(_prenomCtrl, "Prénom", Icons.person_outline, validator: (v) => requiredField(v, "Prénom")),
                    _buildTextField(_emailCtrl, "E-mail (Facultatif)", Icons.email, type: TextInputType.emailAddress),
                    _buildTextField(
                      _telephoneCtrl, "Téléphone", Icons.phone, 
                      type: TextInputType.phone, prefix: "+243 ", isPhone: true,
                      validator: validatePhoneNumber
                    ),
                    const Divider(height: 40),
                    const Text("Adresse", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_numeroCtrl, "N°", Icons.home)),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: _buildTextField(_avenueCtrl, "Avenue", Icons.map)),
                      ],
                    ),
                    _buildTextField(_quartierCtrl, "Quartier", Icons.location_city),
                    _buildTextField(_communeCtrl, "Commune", Icons.location_on),
                    const SizedBox(height: 30),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPhotoHeader() {
    return Center(
      child: Stack(
        children: [
          (_imageUrl != null && _imageUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: _imageUrl!,
                  imageBuilder: (context, imageProvider) => CircleAvatar(
                    radius: 65,
                    backgroundImage: imageProvider,
                    backgroundColor: Colors.grey.shade200,
                  ),
                  placeholder: (context, url) => const CircleAvatar(
                    radius: 65,
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const CircleAvatar(
                    radius: 65,
                    child: Icon(Icons.error, color: Colors.red),
                  ),
                )
              : CircleAvatar(
                  radius: 65,
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.person, size: 60, color: Colors.grey),
                ),
          Positioned(
            bottom: 0, 
            right: 0, 
            child: FloatingActionButton.small(
              onPressed: _showPhotoOptions, 
              child: const Icon(Icons.camera_alt, size: 20)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, String? prefix, String? Function(String?)? validator, bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label, 
          prefixIcon: Icon(icon), 
          prefixText: prefix, 
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
        ),
        validator: validator,
        inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)] : null,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        onPressed: _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700, 
          foregroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
        ),
        child: const Text("ENREGISTRER LES MODIFICATIONS", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }
}
