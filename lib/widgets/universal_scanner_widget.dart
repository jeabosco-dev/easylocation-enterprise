import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

class UniversalScannerWidget extends StatefulWidget {
  const UniversalScannerWidget({super.key});

  @override
  State<UniversalScannerWidget> createState() => _UniversalScannerWidgetState();
}

class _UniversalScannerWidgetState extends State<UniversalScannerWidget> {
  // Contrôleur pour gérer les fonctions avancées comme l'analyse d'image
  final MobileScannerController _controller = MobileScannerController();

  /// Méthode pour choisir une image depuis la galerie et l'analyser
  Future<void> _scannerDepuisGalerie(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    // 1. Sélection de l'image
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // 2. Analyse de l'image sélectionnée
      // Dans mobile_scanner 7.x, analyzeImage renvoie BarcodeCapture? et non bool
      final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
      
      if (capture == null || capture.barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun QR code valide trouvé sur cette image.")),
        );
      } else {
        // Si un code est trouvé, on traite le premier trouvé
        final String? code = capture.barcodes.first.rawValue;
        if (code != null && mounted) {
          _traiterCodeScanner(context, code);
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Scanner un code QR"),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // ✅ BOUTON GALERIE
            IconButton(
              icon: const Icon(Icons.photo_library),
              tooltip: "Choisir une image",
              onPressed: () => _scannerDepuisGalerie(context),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null) {
                    _traiterCodeScanner(context, code);
                    break;
                  }
                }
              },
            ),
            // Overlay pour guider l'utilisateur
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Text(
                "Scannez un code ou importez une capture d'écran via l'icône en haut à droite",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white, 
                  backgroundColor: Colors.black45,
                  fontSize: 12
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _traiterCodeScanner(BuildContext context, String code) {
    final Uri uri = Uri.parse(code);

    // --- LOGIQUE 1 : VÉRIFICATION RÉSERVATION / FACTURE ---
    if (code.contains('verify?ref=')) {
      Navigator.pop(context); // Ferme le scanner
      String ref = uri.queryParameters['ref'] ?? '';
      String client = uri.queryParameters['client'] ?? '';

      Navigator.pushNamed(
        context,
        '/verification-reservation',
        arguments: {'refMaison': ref, 'clientId': client},
      );
    } 
    
    // --- LOGIQUE 2 : PARRAINAGE ---
    else if (code.contains('partner?id=')) {
      Navigator.pop(context); // Ferme le scanner
      String partnerId = uri.queryParameters['id'] ?? '';
      _validerParrainage(context, partnerId);
    } 
    
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Format de code QR non reconnu")),
      );
    }
  }

  void _validerParrainage(BuildContext context, String partnerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Parrainage détecté"),
        content: Text("Voulez-vous lier votre compte au partenaire ID: $partnerId ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Lien de parrainage enregistré !")),
              );
            }, 
            child: const Text("Confirmer")
          ),
        ],
      ),
    );
  }
}