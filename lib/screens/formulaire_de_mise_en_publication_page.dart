// lib/screens/formulaire_publication_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'dart:io';

// Import des contrôleurs et modèles
import '../controllers/formulaire_publication_controller.dart'; 
import '../models/formulaire_publication_model.dart';
import '../providers/user_profile_provider.dart';
import '../services/submission_service.dart';
import '../services/service_journal.dart';

// Import des widgets enfants 
import '../widgets/informations_generales_widget.dart';
import '../widgets/description_physique_widget.dart';
import '../widgets/services_infrastructures_widget.dart';
import '../widgets/informations_proprietaire_widget.dart';
import '../widgets/confirmation_publication_dialog.dart'; 
import '../widgets/upload_progress_dialog.dart'; 

class FormulaireDeMiseEnPublicationPage extends StatefulWidget {
  final dynamic propertyToEdit; 
  
  const FormulaireDeMiseEnPublicationPage({super.key, this.propertyToEdit});

  @override
  _FormulaireDeMiseEnPublicationPageState createState() =>
      _FormulaireDeMiseEnPublicationPageState();
}

class _FormulaireDeMiseEnPublicationPageState
    extends State<FormulaireDeMiseEnPublicationPage> {
  int _currentStep = 0;
  late final FormulairePublicationController _controller;
  
  final ScrollController _mainScrollController = ScrollController();
  final _stepKeys = List.generate(4, (index) => GlobalKey<FormState>());
  SubmissionService? _submissionService;

  bool _isNavigating = false;
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    
    final userProvider = context.read<UserProfileProvider>();
    final String currentUserId = userProvider.userData?.uid ?? '';

    FormulairePublicationModel initialData;
    
    if (widget.propertyToEdit != null) {
      initialData = FormulairePublicationModel.fromProperty(widget.propertyToEdit!);
    } else {
      initialData = FormulairePublicationModel();
    }

    _controller = FormulairePublicationController(
      initialData: initialData,
      currentUserId: currentUserId,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.propertyToEdit == null) {
        _controller.checkLostData(); 
      }
      _initializeFormWithUserData(context);
    });
  }

  void _initializeFormWithUserData(BuildContext context) {
    final userProvider = context.read<UserProfileProvider>();
    _submissionService = SubmissionService();
    final currentUser = userProvider.userData; 

    if (currentUser != null) {
      _controller.updateData(
        nomProprietaire: currentUser.nom,
        postnomProprietaire: currentUser.postnom, 
        prenomProprietaire: (currentUser.prenom.isNotEmpty) ? currentUser.prenom : "",
        telephoneProprietaire: currentUser.telephone,
        emailProprietaire: currentUser.email,
      );
    }
  }

  void _safePop({BuildContext? targetContext}) {
    final ctx = targetContext ?? context;
    if (mounted && Navigator.canPop(ctx)) {
      Navigator.pop(ctx);
    }
  }

  void _animateToTop() {
    if (_mainScrollController.hasClients) {
      _mainScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _showCoverSelectionDialog() {
    final controller = _controller;
    final data = controller.data;
    bool isDialogProcessing = false;

    List<ImageSource> allImages = [
      if (data.salonImage != null) data.salonImage!,
      if (data.cuisineImage != null) data.cuisineImage!,
      if (data.garageImage != null) data.garageImage!,
      if (data.courRecreationImage != null) data.courRecreationImage!,
      if (data.toiletteParentaleImage != null) data.toiletteParentaleImage!,
      if (data.depotImage != null) data.depotImage!,
      ...data.chambresImages.where((img) => img.file != null || img.url != null),
    ];

    if (allImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez ajouter au moins une photo pour continuer.")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Photo de couverture"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Laquelle de ces photos voulez-vous utiliser comme couverture ?"),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: allImages.length,
                      itemBuilder: (context, index) {
                        final img = allImages[index];
                        bool isSelected = controller.data.mainImage == img;
                        return GestureDetector(
                          onTap: () {
                            controller.updateData(mainImage: img);
                            setDialogState(() {}); 
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey[300]!,
                                width: isSelected ? 4 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: img.file != null
                                  ? Image.file(File(img.file!.path), fit: BoxFit.cover)
                                  : (img.url != null ? Image.network(img.url!, fit: BoxFit.cover) : const Icon(Icons.image)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: isDialogProcessing ? null : () {
                    if (controller.data.mainImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sélectionnez une image.")));
                    } else {
                      setDialogState(() => isDialogProcessing = true);
                      _safePop(targetContext: dialogContext); 
                      setState(() => _currentStep++);
                      _animateToTop();
                    }
                  },
                  child: const Text("Valider"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCancelConfirmation() async {
    if (_isNavigating) return;
    _isNavigating = true;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la publication ?'),
        content: const Text('Toutes les informations saisies seront perdues.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    _isNavigating = false;
    if (confirm == true) {
      await _controller.clearFormProgress();
      if (mounted) {
        await context.read<UserProfileProvider>().clearFormPersistence();
        _safePop();
      }
    }
  }

  void _nextStep() {
    if (_isNavigating) return;
    if (_stepKeys[_currentStep].currentState?.validate() ?? false) {
      if (_currentStep == 1) {
        _showCoverSelectionDialog();
      } else if (_currentStep < 3) {
        setState(() => _currentStep++);
        _animateToTop();
      } else {
        _showConfirmationDialog();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _animateToTop();
    }
  }

  void _showConfirmationDialog() {
    final data = _controller.data;
    if (data.price == null || data.garantieMinimale == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (confirmContext) => ConfirmationPublicationDialog(
        data: data,
        onConfirm: () => _submitForm(confirmContext),
      ),
    );
  }

  // ✅ LOGIQUE DE SOUMISSION CORRIGÉE ET HARMONISÉE
  Future<void> _submitForm(BuildContext confirmContext) async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    // 1. Fermer le dialogue de prix
    _safePop(targetContext: confirmContext); 

    // 2. Notificateur de progression
    final progressNotifier = ValueNotifier<double>(0.0);

    // 3. Dialogue d'upload
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, value, child) => UploadProgressDialog(progress: value),
      ),
    );
    
    final transaction = Sentry.startTransaction('submitPropertyForm', 'publication', bindToScope: true);

    try {
      final currentData = _controller.data;
      
      // ✅ APPEL CRUCIAL : On passe le controller pour bénéficier de prepareDataForFirebase()
      await _submissionService!.submitProperty(
        controller: _controller, // On envoie le controller complet
        bailleurId: currentData.bailleurId!,
        propertyId: widget.propertyToEdit?.id,
        onProgress: (p) {
          progressNotifier.value = p; 
        },
      );
      
      String typeActivite = widget.propertyToEdit != null ? "modification" : "creation";
      await ServiceJournal.enregistrerActivite(
        activite: "${typeActivite == "creation" ? "Nouvelle propriété" : "Mise à jour"} : ${currentData.typeBien}",
        type: typeActivite,
      );

      transaction.status = const SpanStatus.ok();
      await _controller.clearFormProgress(); 
      
      if (mounted) {
        await context.read<UserProfileProvider>().clearFormPersistence();
        
        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted) {
          _safePop(); // Ferme le UploadProgressDialog
          _safePop(); // Quitte la page formulaire
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Votre annonce a été publiée avec succès !'),
              backgroundColor: Colors.green,
            )
          );
        }
      }
    } catch (e, stackTrace) {
      if (mounted) _safePop(); // Ferme le dialogue progress
      Sentry.captureException(e, stackTrace: stackTrace);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la publication : $e'),
            backgroundColor: Colors.red,
          )
        );
      }
    } finally {
      transaction.finish();
      _isSubmitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Étape ${_currentStep + 1} sur 4'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _showCancelConfirmation),
      ),
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          await _showCancelConfirmation();
        },
        child: ChangeNotifierProvider<FormulairePublicationController>.value(
          value: _controller,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LinearProgressIndicator(value: (_currentStep + 1) / 4),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _mainScrollController,
                    child: SingleChildScrollView(
                      controller: _mainScrollController,
                      padding: const EdgeInsets.all(16.0),
                      child: _getStepContent(),
                    ),
                  ),
                ),
                _buildBottomNavigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getStepContent() {
    switch (_currentStep) {
      case 0: return InformationsGeneralesWidget(formKey: _stepKeys[0]);
      case 1: return DescriptionPhysiqueWidget(formKey: _stepKeys[1]);
      case 2: return ServicesInfrastructuresWidget(formKey: _stepKeys[2]);
      case 3: return InformationsProprietaireWidget(formKey: _stepKeys[3]);
      default: return Container();
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12))),
      child: Row(
        children: <Widget>[
          if (_currentStep > 0) Expanded(child: TextButton(onPressed: _previousStep, child: const Text('Précédent'))),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(child: ElevatedButton(onPressed: _nextStep, child: Text(_currentStep == 3 ? 'Confirmer' : 'Suivant'))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
