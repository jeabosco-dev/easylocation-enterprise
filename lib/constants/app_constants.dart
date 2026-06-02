/// ✅ CONFIGURATION GÉNÉRALE ET TECHNIQUE DE L'APPLICATION
class AppConfig {
  static const int bookingLockDurationMinutes = 10;
  static int get bookingLockDurationMillis => bookingLockDurationMinutes * 60 * 1000;
  
  /// Support technique centralisé pour toute l'app
  static const String supportWhatsApp = "+243XXXXXXXXX"; 
}

/// ✅ RÉGLAGES DE PERFORMANCE ET TIMEOUTS TECHNIQUES
class FirestoreConstants {
  static const Duration readWriteTimeout = Duration(seconds: 15);
  static const Duration getIndexTimeout = Duration(seconds: 8);
  static const Duration getUserTimeout = Duration(seconds: 10);
}

/// ✅ GESTION DES CHEMINS DE STOCKAGE (Firebase Storage)
class StoragePaths {
  static const String propertiesRoot = 'proprietes';

  static String getPropertyImagePath(String bId, String pId, String f) {
    return '$propertiesRoot/$bId/$pId/$f.jpg';
  }

  static String getChambreImagePath(String bId, String pId, String fol, String f) {
    return '$propertiesRoot/$bId/$pId/$fol/$f';
  }
}