import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async'; 

// Import nécessaire pour la séparation
import 'package:easylocation_mvp/widgets/auth_wrapper.dart';

// ✅ INITIALISATION DES DONNÉES DE LOCALISATION POUR LES DATES (intl)
import 'package:intl/date_symbol_data_local.dart';

import 'package:app_links/app_links.dart';
import 'package:easylocation_mvp/services/property_service.dart';
import 'package:easylocation_mvp/services/config_service.dart';
import 'package:easylocation_mvp/services/notification_service.dart'; 
import 'package:easylocation_mvp/utils/global_data.dart';

// --- WIDGETS ---
import 'package:easylocation_mvp/widgets/verrou_code_conduite.dart';

// --- SCREENS MOBILE ---
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

// --- WEB ADMIN ---
import 'package:easylocation_mvp/web_admin/login_admin_web.dart';
import 'package:easylocation_mvp/web_admin/admin_main_shell.dart'; 

// --- PROVIDERS ---
import 'package:easylocation_mvp/providers/user_profile_provider.dart'; 
import 'package:easylocation_mvp/providers/booking_timer_provider.dart';
import 'package:easylocation_mvp/providers/admin_counts_provider.dart'; 
import 'package:easylocation_mvp/providers/contract_provider.dart';
import 'package:easylocation_mvp/providers/wallet_provider.dart';
import 'package:easylocation_mvp/providers/service_provider.dart'; 
import 'firebase_options.dart';

const String dsnSentry = 'https://edbd5678b932b7db3b01dda47c292619@o4510176724123648.ingest.de.sentry.io/4510176832323664';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

final GoRouter _webRouter = GoRouter(
  initialLocation: '/',
  observers: [
    SentryNavigatorObserver(),
    FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
  ], 
  redirect: (context, state) {
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;
    final bool isLoggingIn = state.matchedLocation == '/';
    
    if (!loggedIn && !isLoggingIn) return '/';
    if (loggedIn && isLoggingIn) return '/dashboard';
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
  ],
);

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = dsnSentry;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized(); 

      await initializeDateFormatting('fr_FR', null);

      try {
        try {
          await dotenv.load(fileName: ".env");
        } catch (e) {
          debugPrint("⚠️ Attention: Fichier .env introuvable : $e");
        }

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        if (!kIsWeb) {
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
          await NotificationService.initialize();
        }

        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true, 
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );

        final configService = ConfigService();
        await configService.init();

        if (!kIsWeb) {
          await FirebaseAppCheck.instance.activate(
            androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
            appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
          );
        }

        unawaited(_runInitialCleanup());

        runApp(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (context) {
                  final provider = UserProfileProvider();
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    provider.loadUser(user.uid); 
                  }
                  return provider;
                },
              ),
              ChangeNotifierProvider(
                create: (context) {
                  final walletProvider = WalletProvider();
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    walletProvider.listenToWallet(user.uid);
                  }
                  return walletProvider;
                },
              ),
              ChangeNotifierProvider(create: (context) => BookingTimerProvider()),
              ChangeNotifierProvider(create: (context) => AdminCountsProvider()), 
              ChangeNotifierProvider(create: (context) => ContractProvider()),
              ChangeNotifierProvider(create: (context) => ServiceProvider()), 
              ChangeNotifierProvider<ConfigService>.value(value: configService),
            ],
            child: const EasyLocationApp(),
          ),
        );
      } catch (e, stackTrace) {
        debugPrint("❌ ERREUR FATALE INITIALISATION : $e");
        await Sentry.captureException(e, stackTrace: stackTrace);
        
        runApp(MaterialApp(
          home: Scaffold(body: Center(child: Text("Erreur au démarrage : $e"))),
        ));
      }
    },
  );
}

Future<void> _runInitialCleanup() async {
  try {
    final propertyService = PropertyService();
    await propertyService.cleanExpiredReservations();
    await propertyService.cleanOldRentedProperties();
    debugPrint("✅ Nettoyage automatique EasyLocation effectué.");
  } catch (e) {
    debugPrint("⚠️ Erreur lors du nettoyage : $e");
  }
}

class EasyLocationApp extends StatelessWidget {
  const EasyLocationApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return MaterialApp.router(
        title: 'EasyLocation Admin HQ',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF1E293B),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', '')],
        locale: const Locale('fr', ''), 
        routerConfig: _webRouter,
      );
    }

    return MaterialApp(
      title: 'EasyLocation',
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey, 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5D8F)),
        useMaterial3: true,
      ),
      navigatorObservers: [
        SentryNavigatorObserver(),
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', '')],
      home: const AuthWrapper(),
      builder: (context, child) => DeepLinkWrapper(child: child!),
      routes: {
        '/onboarding': (context) => const OnboardingPage(),
        '/accueil': (context) => const AccueilPage(),
        '/inscription-locataire': (context) => const InscriptionLocatairePage(),
        '/inscription-bailleur': (context) => const InscriptionBailleurPage(),
        '/maisons-publiees': (context) => const MaisonsPublieesPage(),
        '/formulaire-publication': (context) => const FormulaireDeMiseEnPublicationPage(),
        '/profil-locataire': (context) => const ProfilLocatairePage(),
        '/profil-bailleur': (context) => const ProfilBailleurPage(),
        '/historique-locataire': (context) => const HistoriqueLocatairePage(),
        '/connexion': (context) => const ConnexionPage(),
        '/selection-role': (context) => const SelectionRolePage(),
        '/paiement-succes': (context) => const PaiementSuccesPage(),
        '/ma-location': (context) => const MaLocationPage(), 
        '/mes-factures': (context) => const MesFacturesPage(),
        '/suivi-locations-bailleur': (context) => const SuiviLocationsBailleurPage(),
        '/validations-paiements': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final contratId = args is String ? args : null;
          return ValidationsPaiementsPage(contratId: contratId);
        },
        '/details-maison': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final propertyId = args is String ? args : "";
          return DetailsProprietePage(
            propertiesIds: [propertyId],
            initialIndex: 0,
          );
        },
        '/verification-otp-update': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return VerificationOtpUpdatePhonePage(
            verificationId: args['verificationId'],
            telephone: args['telephone'],
            onVerificationComplete: args['onVerificationComplete'],
          );
        },
        '/verification-reservation': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return VerificationReservationPage(
            refMaison: args['refMaison'],
            clientId: args['clientId'],
          );
        },
      },
    );
  }
}

class DeepLinkWrapper extends StatefulWidget {
  final Widget child;
  const DeepLinkWrapper({super.key, required this.child});
  @override
  State<DeepLinkWrapper> createState() => _DeepLinkWrapperState();
}

class _DeepLinkWrapperState extends State<DeepLinkWrapper> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initDeepLinks();
    }
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _handleLink(initialUri);
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) => _handleLink(uri));
  }

  void _handleLink(Uri uri) {
    debugPrint("🔗 Lien intercepté : $uri");

    if (uri.queryParameters.containsKey('code')) {
      final code = uri.queryParameters['code'];
      GlobalData.capturedCode = code; 
      debugPrint("🎁 Code de parrainage détecté et stocké : $code");
    }

    if (uri.scheme == 'easylocation' && uri.host == 'success') {
      Navigator.of(context).pushNamedAndRemoveUntil('/paiement-succes', (route) => false);
      return;
    }
    if (uri.path == '/propriete') { 
      final propertyId = uri.queryParameters['id'];
      if (propertyId != null) {
        Navigator.of(context).pushNamed('/details-maison', arguments: propertyId);
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}