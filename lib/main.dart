
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

// Initialisation Firebase selon le flavor
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

// Séparation de l'authentification
import 'package:easylocation_mvp/widgets/auth_wrapper.dart';

// Localisation des dates
import 'package:intl/date_symbol_data_local.dart';

import 'package:app_links/app_links.dart';
import 'package:easylocation_mvp/services/property_service.dart';
import 'package:easylocation_mvp/services/config_service.dart';
import 'package:easylocation_mvp/services/notification_service.dart';
import 'package:easylocation_mvp/services/referral_service.dart';
import 'package:easylocation_mvp/utils/global_data.dart';

// Widgets
import 'package:easylocation_mvp/widgets/verrou_code_conduite.dart';

// Screens mobiles
import 'package:easylocation_mvp/screens/onboarding_page.dart';
import 'package:easylocation_mvp/screens/accueil_page.dart';
import 'package:easylocation_mvp/screens/inscription_locataire_page.dart';
import 'package:easylocation_mvp/screens/inscription_bailleur_page.dart';
import 'package:easylocation_mvp/screens/formulaire_de_mise_en_publication_page.dart';
import 'package:easylocation_mvp/screens/maisons_publiees_page.dart';
import 'package:easylocation_mvp/screens/profil_bailleur_page.dart';
import 'package:easylocation_mvp/screens/profil_locataire_page.dart';
import 'package:easylocation_mvp/screens/historique_locataire_page.dart';
import 'package:easylocation_mvp/screens/connexion_page.dart';
import 'package:easylocation_mvp/screens/selection_role_page.dart';
import 'package:easylocation_mvp/screens/verification_otp_update_phone_page.dart';
import 'package:easylocation_mvp/screens/verification_reservation_page.dart';
import 'package:easylocation_mvp/screens/paiement_succes_page.dart';
import 'package:easylocation_mvp/screens/details_propriete_page.dart';
import 'package:easylocation_mvp/screens/ma_location_page.dart';
import 'package:easylocation_mvp/screens/validations_paiements_page.dart';
import 'package:easylocation_mvp/screens/mes_factures_page.dart';
import 'package:easylocation_mvp/screens/suivi_locations_bailleur_page.dart';
import 'package:easylocation_mvp/screens/upsell_selection_page.dart';

// Web admin
import 'package:easylocation_mvp/web_admin/login_admin_web.dart';
import 'package:easylocation_mvp/web_admin/admin_main_shell.dart';

// Web public
import 'package:easylocation_mvp/web_public/property_share_page.dart';
import 'package:easylocation_mvp/web_public/referral_share_page.dart';

// Providers
import 'package:easylocation_mvp/providers/user_profile_provider.dart';
import 'package:easylocation_mvp/providers/booking_timer_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart';
import 'package:easylocation_mvp/providers/contract_provider.dart';
import 'package:easylocation_mvp/providers/wallet_provider.dart';
import 'package:easylocation_mvp/providers/service_provider.dart';

const String dsnSentry =
    'https://edbd5678b932b7db3b01dda47c292619@o4510176724123648.ingest.de.sentry.io/4510176832323664';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  await Firebase.initializeApp(
    options: flavor == 'prod'
        ? prod.DefaultFirebaseOptionsProd.currentPlatform
        : dev.DefaultFirebaseOptionsDev.currentPlatform,
  );

  debugPrint(
    'Handling a background message: ${message.messageId}',
  );
}

// ============================================================
// ROUTEUR WEB
// ============================================================

final GoRouter _webRouter = GoRouter(
  initialLocation: '/',
  observers: [
    SentryNavigatorObserver(),
    FirebaseAnalyticsObserver(
      analytics: FirebaseAnalytics.instance,
    ),
  ],
  redirect: (context, state) {
    // Les routes publiques restent accessibles sans authentification admin
    if (state.matchedLocation.startsWith('/propriete') ||
        state.matchedLocation.startsWith('/referral')) {
      return null;
    }

    final bool loggedIn =
        FirebaseAuth.instance.currentUser != null;

    final bool isLoggingIn =
        state.matchedLocation == '/';

    if (!loggedIn && !isLoggingIn) {
      return '/';
    }

    if (loggedIn && isLoggingIn) {
      return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginAdminWeb(),
    ),

    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const AdminMainShell(),
    ),

    GoRoute(
      path: '/propriete',
      builder: (context, state) {
        final String propertyId =
            state.uri.queryParameters['id'] ?? '';

        return WebPublicPropertyPage(
          propertyId: propertyId,
        );
      },
    ),

    GoRoute(
      path: '/referral',
      builder: (context, state) {
        final String? userId =
            state.uri.queryParameters['user'];

        final String? partnerId =
            state.uri.queryParameters['partner'];

        return WebPublicReferralPage(
          userId: userId,
          partnerId: partnerId,
        );
      },
    ),
  ],
);

// ============================================================
// INITIALISATION PRINCIPALE
// ============================================================

Future<void> main() async {
  BindingBase.debugZoneErrorsAreFatal = true;

  await runZonedGuarded(
    () async {
      await SentryFlutter.init(
        (options) {
          options.dsn = dsnSentry;
          options.tracesSampleRate = 1.0;
        },
        appRunner: () async {
          WidgetsFlutterBinding.ensureInitialized();

          const String flavor = String.fromEnvironment(
            'FLAVOR',
            defaultValue: 'dev',
          );

          await initializeDateFormatting(
            'fr_FR',
            null,
          );

          try {
            await dotenv.load(
              fileName: '.env',
            );
          } catch (e) {
            debugPrint(
              '⚠️ Attention : fichier .env introuvable : $e',
            );
          }

          await Firebase.initializeApp(
            options: flavor == 'prod'
                ? prod.DefaultFirebaseOptionsProd.currentPlatform
                : dev.DefaultFirebaseOptionsDev.currentPlatform,
          );

          // Utilisation des émulateurs uniquement en mode debug/dev
          if (kDebugMode && flavor != 'prod') {
            try {
              const String host = 'localhost';

              FirebaseFirestore.instance
                  .useFirestoreEmulator(
                host,
                8080,
              );

              await FirebaseAuth.instance
                  .useAuthEmulator(
                host,
                9099,
              );

              await FirebaseStorage.instance
                  .useStorageEmulator(
                host,
                9199,
              );
            } catch (e) {
              debugPrint(
                '⚠️ Erreur émulateurs Firebase : $e',
              );
            }
          }

          if (!kIsWeb) {
            FirebaseMessaging.onBackgroundMessage(
              firebaseMessagingBackgroundHandler,
            );

            await NotificationService.initialize();
          }

          FirebaseFirestore.instance.settings =
              const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );

          final ConfigService configService =
              ConfigService();

          await configService.init();

          if (!kIsWeb) {
            await FirebaseAppCheck.instance.activate(
              androidProvider: kDebugMode
                  ? AndroidProvider.debug
                  : AndroidProvider.playIntegrity,
              appleProvider: kDebugMode
                  ? AppleProvider.debug
                  : AppleProvider.appAttest,
            );
          }

          unawaited(
            _runInitialCleanup(),
          );

          runApp(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (context) =>
                      UserProfileProvider(),
                ),
                ChangeNotifierProvider(
                  create: (context) =>
                      WalletProvider(),
                ),
                ChangeNotifierProvider(
                  create: (context) =>
                      BookingTimerProvider(),
                ),
                ChangeNotifierProvider(
                  create: (context) =>
                      AdminCountsProvider(),
                ),
                ChangeNotifierProvider(
                  create: (context) =>
                      ContractProvider(),
                ),
                ChangeNotifierProvider(
                  create: (context) =>
                      ServiceProvider(),
                ),
                ChangeNotifierProvider.value(
                  value: configService,
                ),
              ],
              child: const EasyLocationApp(),
            ),
          );
        },
      );
    },
    (error, stackTrace) async {
      debugPrint(
        '❌ ERREUR FATALE INITIALISATION : $error',
      );

      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
      );
    },
  );
}

// ============================================================
// NETTOYAGE INITIAL
// ============================================================

Future<void> _runInitialCleanup() async {
  try {
    final PropertyService propertyService =
        PropertyService();

    await propertyService.cleanExpiredReservations();
    await propertyService.cleanOldRentedProperties();
  } catch (e) {
    debugPrint(
      '⚠️ Erreur pendant le nettoyage : $e',
    );
  }
}

// ============================================================
// APPLICATION PRINCIPALE
// ============================================================

class EasyLocationApp extends StatelessWidget {
  const EasyLocationApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return MaterialApp.router(
        title: 'EasyLocation',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF1E5D8F),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', ''),
        ],
        locale: const Locale('fr', ''),
        routerConfig: _webRouter,
      );
    }

    return MaterialApp(
      title: 'EasyLocation',
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E5D8F),
        ),
        useMaterial3: true,
      ),
      navigatorObservers: [
        SentryNavigatorObserver(),
        FirebaseAnalyticsObserver(
          analytics: FirebaseAnalytics.instance,
        ),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', ''),
      ],
      home: const AuthWrapper(),
      builder: (context, child) {
        return DeepLinkWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
      routes: {
        '/onboarding': (context) =>
            const OnboardingPage(),

        '/accueil': (context) =>
            const AccueilPage(),

        '/inscription-locataire': (context) =>
            const InscriptionLocatairePage(),

        '/inscription-bailleur': (context) =>
            const InscriptionBailleurPage(),

        '/maisons-publiees': (context) =>
            const MaisonsPublieesPage(),

        '/formulaire-publication': (context) =>
            const FormulaireDeMiseEnPublicationPage(),

        '/profil-locataire': (context) =>
            const ProfilLocatairePage(),

        '/profil-bailleur': (context) =>
            const ProfilBailleurPage(),

        '/historique-locataire': (context) =>
            const HistoriqueLocatairePage(),

        '/connexion': (context) =>
            const ConnexionPage(),

        '/selection-role': (context) =>
            const SelectionRolePage(),

        '/paiement-succes': (context) =>
            const PaiementSuccesPage(),

        '/ma-location': (context) =>
            const MaLocationPage(),

        UpsellSelectionPage.routeName: (context) =>
            const UpsellSelectionPage(),

        '/mes-factures': (context) {
          final Object? args =
              ModalRoute.of(context)?.settings.arguments;

          final String? contractId =
              args is String ? args : null;

          return MesFacturesPage(
            contractId: contractId,
          );
        },

        '/suivi-locations-bailleur': (context) {
          final Object? args =
              ModalRoute.of(context)?.settings.arguments;

          final String? contractId =
              args is String ? args : null;

          return SuiviLocationsBailleurPage(
            contractId: contractId,
          );
        },

        '/validations-paiements': (context) {
          final Object? args =
              ModalRoute.of(context)?.settings.arguments;

          final String? contratId =
              args is String ? args : null;

          return ValidationsPaiementsPage(
            contratId: contratId,
          );
        },

        '/details-maison': (context) {
          final Object? args =
              ModalRoute.of(context)?.settings.arguments;

          final String propertyId =
              args is String ? args : '';

          return DetailsProprietePage(
            propertiesIds: [
              propertyId,
            ],
            initialIndex: 0,
          );
        },

        '/verification-otp-update': (context) {
          final Object? rawArguments =
              ModalRoute.of(context)?.settings.arguments;

          final Map<dynamic, dynamic> args =
              rawArguments is Map
                  ? rawArguments
                  : <dynamic, dynamic>{};

          return VerificationOtpUpdatePhonePage(
            verificationId: args['verificationId'],
            telephone: args['telephone'],
            onVerificationComplete:
                args['onVerificationComplete'],
          );
        },

        '/verification-reservation': (context) {
          final Object? rawArguments =
              ModalRoute.of(context)?.settings.arguments;

          final Map<dynamic, dynamic> args =
              rawArguments is Map
                  ? rawArguments
                  : <dynamic, dynamic>{};

          return VerificationReservationPage(
            refMaison: args['refMaison'],
            clientId: args['clientId'],
          );
        },
      },
    );
  }
}

// ============================================================
// GESTION DES DEEP LINKS
// ============================================================

class DeepLinkWrapper extends StatefulWidget {
  final Widget child;

  const DeepLinkWrapper({
    super.key,
    required this.child,
  });

  @override
  State<DeepLinkWrapper> createState() =>
      _DeepLinkWrapperState();
}

class _DeepLinkWrapperState
    extends State<DeepLinkWrapper> {
  late AppLinks _appLinks;

  StreamSubscription<Uri>? _linkSubscription;

  // Évite d'ouvrir plusieurs fois le même lien
  String? _lastPropertyId;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _initDeepLinks();
    }
  }

  // ==========================================================
  // INITIALISATION DES DEEP LINKS
  // ==========================================================

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      // --------------------------------------------------------
      // Lien reçu lorsque l'application était complètement fermée
      // --------------------------------------------------------
      final Uri? initialUri =
          await _appLinks.getInitialLink();

      if (initialUri != null) {
        debugPrint(
          '🔗 Lien initial détecté : $initialUri',
        );

        await _handleLink(initialUri);
      }

      // --------------------------------------------------------
      // Liens reçus lorsque l'application est déjà ouverte
      // --------------------------------------------------------
      _linkSubscription =
          _appLinks.uriLinkStream.listen(
        (Uri uri) async {
          debugPrint(
            '🔗 Nouveau lien détecté : $uri',
          );

          await _handleLink(uri);
        },
        onError: (Object error) {
          debugPrint(
            '❌ Erreur Deep Link : $error',
          );
        },
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ Erreur initialisation Deep Link : $e',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ==========================================================
  // ATTENDRE QUE L'APPLICATION SOIT PRÊTE
  // ==========================================================

  Future<void> _waitForAppReady() async {
    debugPrint(
      '⏳ Attente de la stabilisation de l’application...',
    );

    // Attendre au moins le premier cycle de rendu
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    // ----------------------------------------------------------
    // Aucun utilisateur connecté
    // ----------------------------------------------------------
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      debugPrint(
        'ℹ️ Aucun utilisateur connecté.',
      );

      // Un cycle supplémentaire permet à AuthWrapper
      // de terminer son affichage initial.
      await WidgetsBinding.instance.endOfFrame;

      return;
    }

    // ----------------------------------------------------------
    // Utilisateur connecté :
    // attendre le chargement du profil
    // ----------------------------------------------------------
    final UserProfileProvider profileProvider =
        context.read<UserProfileProvider>();

    const int maxAttempts = 50;

    for (int i = 0; i < maxAttempts; i++) {
      if (!mounted) return;

      final bool profileLoaded =
          profileProvider.userData != null &&
          !profileProvider.isLoading;

      if (profileLoaded) {
        debugPrint(
          '✅ Profil utilisateur chargé.',
        );

        return;
      }

      debugPrint(
        '⏳ Profil encore en chargement... '
        '(${i + 1}/$maxAttempts)',
      );

      // Attendre 100 ms avant de vérifier à nouveau
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      );
    }

    // ----------------------------------------------------------
    // Sécurité :
    // ne jamais bloquer définitivement le Deep Link
    // ----------------------------------------------------------
    debugPrint(
      '⚠️ Délai maximum atteint. '
      'Poursuite de la navigation Deep Link.',
    );
  }

  // ==========================================================
  // TRAITEMENT DU LIEN
  // ==========================================================

  Future<void> _handleLink(Uri uri) async {
    if (!mounted) return;

    debugPrint(
      '🔗 Lien intercepté : $uri',
    );

    // ========================================================
    // 1. PARRAINAGE
    // ========================================================

    final referral =
        ReferralService.capturerReferral(uri);

    if (referral != null) {
      await ReferralService.savePendingReferral(
        referral,
      );

      GlobalData.capturedCode = referral.id;

      debugPrint(
        '✅ Parrainage capturé : '
        '${referral.type} (${referral.id})',
      );
    }

    // ========================================================
    // 2. PAIEMENT
    // ========================================================

    if (uri.scheme == 'easylocation' &&
        uri.host == 'success') {
      await _waitForAppReady();

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          NotificationService
              .navigatorKey
              .currentState
              ?.pushNamedAndRemoveUntil(
            '/paiement-succes',
            (route) => false,
          );
        },
      );

      return;
    }

    // ========================================================
    // 3. LIEN PROPRIÉTÉ
    // ========================================================

    final bool isPropertyLink =
        uri.path == '/propriete' ||
        (uri.scheme == 'easylocation' &&
            uri.host == 'propriete');

    if (!isPropertyLink) {
      debugPrint(
        'ℹ️ Ce lien n’est pas un lien propriété.',
      );

      return;
    }

    // Récupération de l’identifiant du bien
    final String? propertyId =
        uri.queryParameters['id'];

    if (propertyId == null || propertyId.isEmpty) {
      debugPrint(
        '❌ Lien propriété sans propertyId.',
      );

      return;
    }

    // Éviter les doublons
    if (_lastPropertyId == propertyId) {
      debugPrint(
        'ℹ️ Propriété déjà ouverte : $propertyId',
      );

      return;
    }

    _lastPropertyId = propertyId;

    debugPrint(
      '🏠 Propriété demandée : $propertyId',
    );

    // ========================================================
    // 4. ATTENDRE L’APPLICATION
    // ========================================================

    await _waitForAppReady();

    if (!mounted) return;

    // ========================================================
    // 5. OUVRIR LA PROPRIÉTÉ
    // ========================================================

    debugPrint(
      '🚀 Ouverture de /details-maison avec ID : $propertyId',
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        NotificationService
            .navigatorKey
            .currentState
            ?.pushNamed(
          '/details-maison',
          arguments: propertyId,
        );
      },
    );
  }

  // ==========================================================
  // NETTOYAGE
  // ==========================================================

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}