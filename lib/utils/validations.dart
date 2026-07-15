// lib/utils/validations.dart

import 'package:flutter/services.dart';

/// Mixin regroupant toutes les validations réutilisables
/// dans les formulaires de l'application.
mixin Validations {
  /// ============================
  /// CONSTANTES
  /// ============================

  static const int maxNameLength = 50;

  static final RegExp _nameRegex =
      RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ'. -]+$");

  static final RegExp _hasLetterRegex =
      RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]');

  /// ============================
  /// INPUT FORMATTERS
  /// ============================

  List<TextInputFormatter> get nameInputFormatters => [
        FilteringTextInputFormatter.allow(
          RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ'. -]"),
        ),
        LengthLimitingTextInputFormatter(maxNameLength),
      ];

  /// ============================
  /// NORMALISATION
  /// ============================

  /// Supprime les espaces inutiles
  /// Jean     Bosco  -> Jean Bosco
  String normalizeInput(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// ============================
  /// VALIDATION DES NOMS
  /// ============================

  /// Nom/Postnom obligatoires
  String? validatePersonName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Le champ $fieldName est obligatoire.';
    }

    final text = normalizeInput(value);

    if (!_nameRegex.hasMatch(text)) {
      return '$fieldName ne peut contenir que des lettres, des espaces, des apostrophes, des tirets et des points.';
    }

    if (!_hasLetterRegex.hasMatch(text)) {
      return '$fieldName doit contenir au moins une lettre.';
    }

    if (text.length < 2) {
      return '$fieldName est trop court.';
    }

    if (text.length > maxNameLength) {
      return '$fieldName est trop long.';
    }

    return null;
  }

  /// Prénom optionnel
  String? validateOptionalPersonName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final text = normalizeInput(value);

    if (!_nameRegex.hasMatch(text)) {
      return 'Le prénom ne peut contenir que des lettres, des espaces, des apostrophes, des tirets et des points.';
    }

    if (!_hasLetterRegex.hasMatch(text)) {
      return 'Le prénom doit contenir au moins une lettre.';
    }

    if (text.length > maxNameLength) {
      return 'Le prénom est trop long.';
    }

    return null;
  }

  /// ============================
  /// VALIDATION TÉLÉPHONE
  /// ============================

  String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre numéro de téléphone.';
    }

    final phoneRegex = RegExp(r'^[0-9]{9}$');

    if (!phoneRegex.hasMatch(value)) {
      return 'Le numéro doit contenir exactement 9 chiffres.';
    }

    return null;
  }

  /// ============================
  /// VALIDATION EMAIL
  /// ============================

  String? emailOptional(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Veuillez entrer une adresse email valide.';
    }

    return null;
  }

  /// ============================
  /// VALIDATION NOMBRE
  /// ============================

  String? validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Le champ $fieldName est obligatoire.';
    }

    final number = double.tryParse(value);

    if (number == null || number <= 0) {
      return '$fieldName doit être un nombre positif.';
    }

    return null;
  }

  /// ============================
  /// VALIDATION GÉNÉRIQUE
  /// ============================

  String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Le champ $fieldName est obligatoire.';
    }

    return null;
  }
}