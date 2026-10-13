import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importations des pages
import 'package:easylocation_mvp/widgets/auth_wrapper.dart';
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

// Web admin & public
import 'package:easylocation_mvp/web_admin/login_admin_web.dart';
import 'package:easylocation_mvp/web_admin/admin_main_shell.dart';
import 'package:easylocation_mvp/web_public/property_share_page.dart';
import 'package:easylocation_mvp/web_public/referral_share_page.dart';

class AppRoutes {
  static final GoRouter webRouter = GoRouter(
    initialLocation: '/',
    observers: [
      SentryNavigatorObserver(),
      FirebaseAnalyticsObserver(
        analytics: FirebaseAnalytics.instance,
      ),
    ],
    redirect: (context, state) {
      if (state.matchedLocation.startsWith('/propriete') ||
          state.matchedLocation.startsWith('/referral')) {
        return null;
      }

      final bool loggedIn = FirebaseAuth.instance.currentUser != null;
      final bool isLoggingIn = state.matchedLocation == '/';

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
          final String propertyId = state.uri.queryParameters['id'] ?? '';
          return WebPublicPropertyPage(propertyId: propertyId);
        },
      ),
      GoRoute(
        path: '/referral',
        builder: (context, state) {
          final String? userId = state.uri.queryParameters['user'];
          final String? partnerId = state.uri.queryParameters['partner'];
          return WebPublicReferralPage(userId: userId, partnerId: partnerId);
        },
      ),
    ],
  );

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name != null && settings.name!.startsWith('/referral')) {
      return MaterialPageRoute(
        builder: (context) => const AuthWrapper(),
        settings: settings,
      );
    }
    return null;
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => const AuthWrapper(),
    );
  }

  static Map<String, WidgetBuilder> get mobileRoutes => {
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
        UpsellSelectionPage.routeName: (context) => const UpsellSelectionPage(),
        '/mes-factures': (context) {
          final Object? args = ModalRoute.of(context)?.settings.arguments;
          final String? contractId = args is String ? args : null;
          return MesFacturesPage(contractId: contractId);
        },
        '/suivi-locations-bailleur': (context) {
          final Object? args = ModalRoute.of(context)?.settings.arguments;
          final String? contractId = args is String ? args : null;
          return SuiviLocationsBailleurPage(contractId: contractId);
        },
        '/validations-paiements': (context) {
          final Object? args = ModalRoute.of(context)?.settings.arguments;
          final String? contratId = args is String ? args : null;
          return ValidationsPaiementsPage(contratId: contratId);
        },
        '/details-maison': (context) {
          final Object? args = ModalRoute.of(context)?.settings.arguments;
          final String propertyId = args is String ? args : '';
          return DetailsProprietePage(propertiesIds: [propertyId], initialIndex: 0);
        },
        '/verification-otp-update': (context) {
          final Object? rawArguments = ModalRoute.of(context)?.settings.arguments;
          final Map<dynamic, dynamic> args = rawArguments is Map ? rawArguments : <dynamic, dynamic>{};
          return VerificationOtpUpdatePhonePage(
            verificationId: args['verificationId'],
            telephone: args['telephone'],
            onVerificationComplete: args['onVerificationComplete'],
          );
        },
        '/verification-reservation': (context) {
          final Object? rawArguments = ModalRoute.of(context)?.settings.arguments;
          final Map<dynamic, dynamic> args = rawArguments is Map ? rawArguments : <dynamic, dynamic>{};
          return VerificationReservationPage(
            refMaison: args['refMaison'],
            clientId: args['clientId'],
          );
        },
      };
}