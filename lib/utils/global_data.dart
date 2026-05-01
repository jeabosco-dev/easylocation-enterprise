class GlobalData {
  /// Stocke le code de parrainage intercepté par app_links au démarrage.
  /// Il est statique pour être accessible partout sans créer d'instance.
  static String? capturedCode;

  /// Permet de vider le code après utilisation (optionnel)
  static void clearCapturedCode() {
    capturedCode = null;
  }
}