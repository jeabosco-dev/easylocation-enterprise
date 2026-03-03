import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async'; 

import 'package:app_links/app_links.dart';
import 'package:easylocation_mvp/services/property_service.dart';
import 'package:easylocation_mvp/services/config_service.dart';

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

// --- WEB ADMIN ---
import 'package:easylocation_mvp/web_admin/login_admin_web.dart';
import 'package:easylocation_mvp/web_admin/admin_main_shell.dart'; 

// --- PROVIDERS ---
import 'package:easylocation_mvp/providers/user_profile_provider.dart'; 
import 'package:easylocation_mvp/providers/booking_timer_provider.dart';
import 'firebase_options.dart';

const String dsnSentry = 'https://edbd5678b932b7db3b01dda47c292619@o4510176724123648.ingest.de.sentry.io/4510176832323664';

// Configuration GoRouter pour le Web
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

// --- FONCTION MAIN OPTIMISÉE ---
Future<void> main() async {
  // 1. Initialisation du moteur Flutter avant tout (Crucial)
  WidgetsFlutterBinding.ensureInitialized(); 

  // 2. Initialisation de Sentry qui englobe l'exécution de l'app
  await SentryFlutter.init(
    (options) {
      options.dsn = dsnSentry;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () async {
      try {
        // 3. Chargement des variables d'environnement
        try {
          await dotenv.load(fileName: ".env");
        } catch (e) {
          debugPrint("⚠️ Attention: Fichier .env introuvable : $e");
        }

        // 4. Initialisation Firebase
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // 5. Configuration Firestore (Cache & Persistance)
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true, 
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );

        // 6. Initialisation du Service de Configuration Dynamique
        final configService = ConfigService();
        await configService.init();

        // 7. Firebase App Check (Optimisé pour ne pas bloquer en Debug)
        if (!kIsWeb) {
          await FirebaseAppCheck.instance.activate(
            androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
            appleProvider: AppleProvider.appAttest,
          );
        }

        // 8. Tâches de nettoyage en arrière-plan (non bloquante)
        unawaited(PropertyService().cleanExpiredReservations().catchError((e) => debugPrint(e.toString())));

        // 9. Lancement définitif de l'interface
        runApp(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (context) => UserProfileProvider()),
              ChangeNotifierProvider(create: (context) => BookingTimerProvider()),
              // ✅ CORRECTION ICI : Utilisation de ChangeNotifierProvider.value pour ConfigService
              ChangeNotifierProvider<ConfigService>.value(value: configService),
            ],
            child: const EasyLocationApp(),
          ),
        );
      } catch (e, stackTrace) {
        debugPrint("❌ ERREUR FATALE INITIALISATION : $e");
        await Sentry.captureException(e, stackTrace: stackTrace);
        
        // Affichage d'une interface de secours en cas de crash complet
        runApp(MaterialApp(
          home: Scaffold(body: Center(child: Text("Erreur au démarrage : $e"))),
        ));
      }
    },
  );
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
        
        '/details-maison': (context) {
          final propertyId = ModalRoute.of(context)!.settings.arguments as String;
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

// --- GESTION DES DEEP LINKS ---
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
    if (!kIsWeb) _initDeepLinks();
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _handleLink(initialUri);
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) => _handleLink(uri));
  }

  void _handleLink(Uri uri) {
    debugPrint("🔗 Lien intercepté : $uri");
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

// --- AUTH WRAPPER (LOGIQUE DE DIRECTION) ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _checkIfFormWasInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('form_in_progress') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!authSnapshot.hasData) return const OnboardingPage();

        return Selector<UserProfileProvider, String>(
          selector: (_, provider) => "${provider.userData?.uid ?? ''}-${provider.userData?.activeRole ?? ''}",
          builder: (context, combinedKey, child) {
            final profileProvider = context.read<UserProfileProvider>();
            
            if (profileProvider.userData == null) {
              if (!profileProvider.isLoading) {
                Future.microtask(() => profileProvider.loadUser(authSnapshot.data!.uid));
              }
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            final user = profileProvider.userData!;

            List<String> rolesStaff = ['operations', 'tech_support', 'certificateur', 'logistique', 'admin'];
            if (rolesStaff.contains(user.activeRole.toLowerCase())) {
              if (user.certification_conduite != true) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  VerrouCodeConduite.afficherEngagement(context, user.uid);
                });
              }
            }

            if (user.activeRole.isEmpty) return const SelectionRolePage();

            return FutureBuilder<bool>(
              future: _checkIfFormWasInProgress(),
              builder: (context, snapshot) {
                final formInProgress = snapshot.data ?? false;
                final role = user.activeRole.toLowerCase();
                if (formInProgress && role == 'bailleur') return const FormulaireDeMiseEnPublicationPage();
                return (role == 'bailleur') ? const ProfilBailleurPage() : const ProfilLocatairePage();
              },
            );
          },
        );
      },
    );
  }
}