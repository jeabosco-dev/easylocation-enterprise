import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

class UniversalScannerWidget extends StatefulWidget {
  const UniversalScannerWidget({super.key});

  @override
  State<UniversalScannerWidget> createState() => _UniversalScannerWidgetState();
}

class _UniversalScannerWidgetState extends State<UniversalScannerWidget> {
  final MobileScannerController _controller = MobileScannerController();

  Future<void> _scannerDepuisGalerie(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
      
      if (capture == null || capture.barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun QR code valide trouvé sur cette image.")),
        );
      } else {
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
          ],
        ),
      ),
    );
  }

  void _traiterCodeScanner(BuildContext context, String code) {
    // Analyse robuste via Uri
    final Uri uri = Uri.parse(code);

    // --- LOGIQUE 1 : VÉRIFICATION RÉSERVATION / FACTURE ---
    if (uri.path.contains('verify')) {
      final ref = uri.queryParameters['ref'] ?? '';
      final clientId = uri.queryParameters['client'] ?? '';
      final type = uri.queryParameters['type'] ?? '';

      Navigator.pop(context); // Ferme le scanner

      // Exemple d'évolutivité : on peut différencier les types
      if (type == 'invoice') {
        // Gérer le cas spécifique facture si nécessaire
      }

      Navigator.pushNamed(
        context,
        '/verification-reservation',
        arguments: {
          'refMaison': ref,
          'clientId': clientId,
        },
      );
    } 
    
    // --- LOGIQUE 2 : PARRAINAGE ---
    else if (uri.path.contains('partner')) {
      final partnerId = uri.queryParameters['id'] ?? '';
      Navigator.pop(context); // Ferme le scanner
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