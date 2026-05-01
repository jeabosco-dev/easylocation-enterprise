// lib/widgets/admin/property_details_panel.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../models/property_model.dart';
import '../../screens/formulaire_de_mise_en_publication_page.dart';
// ✅ Import du service
import '../../services/property_service.dart';

class PropertyDetailsPanel extends StatefulWidget {
  final Property property;
  final VoidCallback onClose;

  const PropertyDetailsPanel({
    super.key,
    required this.property,
    required this.onClose,
  });

  @override
  State<PropertyDetailsPanel> createState() => _PropertyDetailsPanelState();
}

class _PropertyDetailsPanelState extends State<PropertyDetailsPanel> {
  bool _isEditingPrice = false;
  bool _isFullEditing = false; 
  late TextEditingController _priceController;
  
  // ✅ Instance unique du service pour tout le panel
  final PropertyService _propertyService = PropertyService();

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.property.price.toString());
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  // --- LOGIQUE MÉTIER (VIA SERVICE) ---

  // ✅ Sélection, Compression et Upload via Service
  Future<void> _pickAndUploadPhoto() async {
    final picker.ImagePicker imagePicker = picker.ImagePicker();
    
    final picker.ImageSource? source = await showDialog<picker.ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ajouter une photo"),
        content: const Text("Choisir la source de l'image :"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, picker.ImageSource.camera), child: const Text('Caméra')),
          TextButton(onPressed: () => Navigator.pop(context, picker.ImageSource.gallery), child: const Text('Galerie')),
        ],
      ),
    );

    if (source == null) return;

    final picker.XFile? pickedFile = await imagePicker.pickImage(source: source);
    if (pickedFile == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final String targetPath = '${pickedFile.path.substring(0, pickedFile.path.lastIndexOf('.'))}_admin.jpg';
      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        targetPath,
        minWidth: 1080,
        minHeight: 1080,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      final File fileToUpload = File(compressedFile?.path ?? pickedFile.path);
      final String fileName = "img_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      // Référence pour l'upload Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('proprietes')
          .child(widget.property.id)
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(fileToUpload);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // ✅ APPEL SERVICE : Ajout de l'URL dans Firestore
      await _propertyService.addPhoto(widget.property.id, downloadUrl);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo ajoutée !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Erreur upload: $e");
    }
  }

  // ✅ Mise à jour du prix via Service
  Future<void> _updatePrice() async {
    final double? newPrice = double.tryParse(_priceController.text);
    if (newPrice == null) return;

    try {
      // ✅ APPEL SERVICE
      await _propertyService.updatePrice(widget.property.id, newPrice);

      setState(() => _isEditingPrice = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Prix mis à jour !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erreur prix: $e");
    }
  }

  // ✅ Suppression d'une photo via Service
  Future<void> _removePhoto(String url) async {
    try {
      // ✅ APPEL SERVICE (Gère Firestore + Storage)
      await _propertyService.removePhoto(widget.property.id, url);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo supprimée"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Erreur suppression photo: $e");
    }
  }

  // ✅ Certification via Service
  Future<void> _updateVerification(BuildContext context, String id, bool status) async {
    try {
      // ✅ APPEL SERVICE
      await _propertyService.certifierPropriete(id, status);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status ? "Bien certifié et urgence traitée !" : "Certification retirée"),
            backgroundColor: status ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur verification: $e");
    }
  }

  // --- INTERFACE (UI) ---

  @override
  Widget build(BuildContext context) {
    // ✅ Suppression de width: 500 pour laisser le parent gérer la flexibilité
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isFullEditing 
              ? FormulaireDeMiseEnPublicationPage(propertyToEdit: widget.property)
              : _buildStaticDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isFullEditing ? Icons.arrow_back : Icons.close), 
            onPressed: _isFullEditing ? () => setState(() => _isFullEditing = false) : widget.onClose
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isFullEditing ? "Modifier tout le bien" : "Réf: ${widget.property.referenceCourte}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_isFullEditing)
            TextButton.icon(
              onPressed: () => setState(() => _isFullEditing = true),
              icon: const Icon(Icons.edit_note, color: Colors.orange),
              label: const Text("Modifier", style: TextStyle(color: Colors.orange)),
            ),
          if (widget.property.isVerified && !_isFullEditing)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.verified, color: Colors.blue, size: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildStaticDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhotoGallery(),
          const SizedBox(height: 25),
          _buildPriceSection(),
          const Divider(height: 40),
          _buildPerformanceStats(),
          const Divider(height: 40),
          _buildAdminActions(context),
          const Divider(height: 40),
          _buildOwnerSection(),
          const SizedBox(height: 20),
          _buildSectionTitle("Description"),
          Text(widget.property.description, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery() {
    final images = widget.property.imageUrls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Gestion des Photos"),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == images.length) {
                return _buildAddPhotoButton();
              }
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(images[index], width: 120, height: 120, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: InkWell(
                      onTap: () => _removePhoto(images[index]),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return InkWell(
      onTap: _pickAndUploadPhoto,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: Colors.blue),
            SizedBox(height: 4),
            Text("Ajouter", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Prix du loyer"),
        const SizedBox(height: 8),
        _isEditingPrice
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        suffixText: "\$",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  IconButton(onPressed: _updatePrice, icon: const Icon(Icons.check, color: Colors.green)),
                  IconButton(onPressed: () => setState(() => _isEditingPrice = false), icon: const Icon(Icons.close, color: Colors.red)),
                ],
              )
            : Row(
                children: [
                  Text("${widget.property.price}\$", 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(width: 15),
                  TextButton.icon(
                    onPressed: () => setState(() => _isEditingPrice = true),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text("Modifier le prix"),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return Column(
      children: [
        _buildSectionTitle("Actions de Modération"),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.property.isVerified ? Colors.orange : Colors.blue[700],
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: Icon(widget.property.isVerified ? Icons.remove_moderator : Icons.verified_user),
          label: Text(widget.property.isVerified ? "Retirer la certification" : "Certifier ce bien"),
          onPressed: () => _updateVerification(context, widget.property.id, !widget.property.isVerified),
        ),
      ],
    );
  }

  Widget _buildPerformanceStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem("Vues", widget.property.views.toString(), Icons.visibility, Colors.blue),
        _statItem("Favoris", widget.property.favoriteCount.toString(), Icons.favorite, Colors.red),
        _statItem("Partages", widget.property.shares.toString(), Icons.share, Colors.green),
      ],
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildOwnerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Propriétaire"),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(widget.property.nomProprietaire.isNotEmpty ? widget.property.nomProprietaire[0] : "?")),
          title: Text("${widget.property.prenomProprietaire} ${widget.property.nomProprietaire}",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(widget.property.telephoneProprietaire),
          trailing: IconButton(
            icon: const Icon(Icons.phone_in_talk, color: Colors.green),
            onPressed: () { /* Logique appel */ },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 5),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Colors.blueGrey.shade700,
              letterSpacing: 1.1)),
    );
  }
}