// lib/utils/validations.dart

/// Mixin pour des fonctions de validation courantes dans les formulaires.
mixin Validations {
  /// Valide si un champ est non-nul et non-vide.
  String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Le champ $fieldName est obligatoire.';
    }
    return null;
  }

  /// Valide le format du numéro de téléphone (9 chiffres).
  String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre numéro de téléphone.';
    }
    final RegExp phoneRegex = RegExp(r'^[0-9]{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Le numéro doit contenir exactement 9 chiffres.';
    }
    return null;
  }

  /// Valide si l'email (champ optionnel) est au bon format s'il est renseigné.
  String? emailOptional(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Veuillez entrer une adresse email valide.';
    }
    return null;
  }

  /// Valide si une valeur est un nombre positif.
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
}
