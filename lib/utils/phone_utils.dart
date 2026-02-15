// lib/utils/phone_utils.dart

/// Normalise un numéro de téléphone au format E.164 (+243XXXXXXXXX)
/// Idéal pour la RDC et compatible avec les recherches Firestore strictes.
String normalizePhoneNumber(String input) {
  // 1. Nettoyage total : on ne garde que les chiffres
  String digits = input.replaceAll(RegExp(r'[^0-9]'), '');

  // 2. Gestion du préfixe international '00'
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }

  // 3. Cas déjà au format RDC avec 243 (ex: 243972...)
  // Si le numéro commence par 243, on considère qu'il est complet.
  if (digits.startsWith('243')) {
    return '+$digits';
  }

  // 4. Cas local avec '0' (ex: 0972...)
  // On retire le 0 pour ne garder que les 9 chiffres utiles.
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  // 5. Cas local sans le '0' (9 chiffres restants)
  // On ajoute le préfixe pays +243.
  if (digits.length == 9) {
    return '+243$digits';
  }

  // 6. Fallback de sécurité (si format inconnu, on force le 243)
  return '+243$digits';
}
