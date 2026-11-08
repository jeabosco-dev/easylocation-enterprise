
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Service responsable de la création des images QR de parrainage EasyLocation.
///
/// Fonctionnalités :
/// - Génération d'un QR Code à partir du lien officiel de parrainage.
/// - Création d'une carte graphique EasyLocation.
/// - Export en PNG haute résolution.
/// - Fourniture des octets PNG pour partage et enregistrement.
///
/// IMPORTANT :
/// Ce service ne génère pas lui-même les liens de parrainage.
/// Le lien doit être fourni par ReferralService afin de conserver
/// une seule source de vérité pour les liens partenaires et utilisateurs.
class ReferralQrImageService {
  ReferralQrImageService._();

  // Identité visuelle EasyLocation.
  static const Color _blue = Color(0xFF1E5D8F);
  static const Color _orange = Color(0xFFF28C28);
  static const Color _dark = Color(0xFF263238);
  static const Color _grey = Color(0xFF667085);
  static const Color _white = Colors.white;

  /// Génère une image PNG haute résolution du QR Code.
  ///
  /// [link] : lien officiel généré par ReferralService.
  /// [partnerName] : prénom ou nom d'affichage facultatif.
  ///
  /// Retourne les octets PNG prêts à être partagés ou enregistrés.
  static Future<Uint8List> genererPng({
    required String link,
    String? partnerName,
  }) async {
    if (link.trim().isEmpty) {
      throw ArgumentError('Le lien de parrainage ne peut pas être vide.');
    }

    const double width = 1080;
    const double height = 1350;
    const double qrSize = 660;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, width, height),
    );

    // 1. Fond blanc.
    final backgroundPaint = Paint()..color = _white;

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      backgroundPaint,
    );

    // 2. En-tête EasyLocation.
    _drawHeader(canvas, width, partnerName);

    // 3. Texte introductif.
    _drawCenteredText(
      canvas,
      text: 'INVITEZ VOTRE RESEAU',
      centerX: width / 2,
      y: 280,
      fontSize: 37,
      color: _blue,
      fontWeight: FontWeight.bold,
    );

    _drawCenteredText(
      canvas,
      text: 'Scannez ce code pour rejoindre EasyLocation',
      centerX: width / 2,
      y: 340,
      fontSize: 27,
      color: _grey,
    );

    // 4. Cadre blanc du QR Code.
    const double qrLeft = (width - qrSize) / 2;
    const double qrTop = 405;

    final qrRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(qrLeft, qrTop, qrSize, qrSize),
      const Radius.circular(28),
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        16,
      );

    canvas.drawRRect(
      qrRect.shift(const Offset(0, 10)),
      shadowPaint,
    );

    canvas.drawRRect(
      qrRect,
      Paint()..color = _white,
    );

    // 5. Génération QR haute résolution.
    //
    // Quiet zone : 40 pixels de chaque côté.
    // Les modules sont noirs pour garantir un contraste maximal.
    const double qrPadding = 40;
    const double actualQrSize = qrSize - (qrPadding * 2);

    final qrPainter = QrPainter(
      data: link,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );

    canvas.save();

canvas.translate(
  qrLeft + qrPadding,
  qrTop + qrPadding,
);

qrPainter.paint(
  canvas,
  const Size(actualQrSize, actualQrSize),
);

canvas.restore();

    // 6. Texte sous le QR Code.
    _drawCenteredText(
      canvas,
      text: 'VOTRE CODE PERSONNEL DE PARRAINAGE',
      centerX: width / 2,
      y: 1115,
      fontSize: 25,
      color: _blue,
      fontWeight: FontWeight.bold,
    );

    _drawCenteredText(
      canvas,
      text: 'EasyLocation • Réseau officiel',
      centerX: width / 2,
      y: 1180,
      fontSize: 26,
      color: _dark,
      fontWeight: FontWeight.bold,
    );

    _drawCenteredText(
      canvas,
      text: 'L’immobilier réinventé en RDC',
      centerX: width / 2,
      y: 1230,
      fontSize: 23,
      color: _grey,
    );

    // 7. Conversion du dessin en PNG.
    final picture = recorder.endRecording();

    try {
      final image = await picture.toImage(
        width.toInt(),
        height.toInt(),
      );

      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData == null) {
          throw Exception(
            'Impossible de convertir le QR Code en PNG.',
          );
        }

        return byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
  picture.dispose();
}
  }

  /// Dessine l'en-tête graphique.
  static void _drawHeader(
    Canvas canvas,
    double width,
    String? partnerName,
  ) {
    // Petit accent orange.
    final orangePaint = Paint()..color = _orange;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(80, 65, 12, 100),
        const Radius.circular(6),
      ),
      orangePaint,
    );

    _drawCenteredText(
      canvas,
      text: 'EasyLocation',
      centerX: width / 2,
      y: 75,
      fontSize: 68,
      color: _blue,
      fontWeight: FontWeight.bold,
    );

    _drawCenteredText(
      canvas,
      text: 'VOTRE PARTENAIRE IMMOBILIER DE CONFIANCE',
      centerX: width / 2,
      y: 165,
      fontSize: 20,
      color: _grey,
      fontWeight: FontWeight.w600,
    );

    if (partnerName != null && partnerName.trim().isNotEmpty) {
      _drawCenteredText(
        canvas,
        text: 'Invitation de ${partnerName.trim()}',
        centerX: width / 2,
        y: 225,
        fontSize: 27,
        color: _dark,
        fontWeight: FontWeight.w600,
      );
    }
  }

  /// Dessine un texte centré sur le canvas.
  static void _drawCenteredText(
    Canvas canvas, {
    required String text,
    required double centerX,
    required double y,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    );

    textPainter.layout(maxWidth: 920);

    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        y,
      ),
    );
  }
}
