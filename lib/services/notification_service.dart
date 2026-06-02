import 'dart:typed_data'; // ✅ Requis pour Int64List (vibration)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

// 1. Fonction Top-level pour le background (obligatoire pour Firebase)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Message reçu en arrière-plan : ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    // 2. Demander les permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 3. Configuration du canal Android (avec vibration activée)
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'easylocation_alerts',
        'Alertes EasyLocation',
        description: 'Notifications pour les visites et paiements',
        importance: Importance.max,
        enableVibration: true, // ✅ Force l'activation de la vibration
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]), // ✅ Rythme : Attente, Vibre, Pause, Vibre
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 4. Initialisation
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotifications.initialize(
        settings: initializationSettings, 
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final String? payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            // Analyse du payload local pour aiguiller précisément au clic en Foreground
            if (payload.startsWith('FAC-') || payload.contains('_CONTRACT_') || payload.length > 15) {
              _redirigerSelonRole(payload);
            } else {
              navigatorKey.currentState?.pushNamed('/details-maison', arguments: payload);
            }
          }
        },
      );

      // 5. Écouter les messages en Foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          String? payloadData = message.data['contractId'] ?? message.data['contratId'] ?? message.data['factureId'] ?? message.data['propertyId'];

          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: android.smallIcon,
                vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
              ),
            ),
            payload: payloadData,
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }
    }
  }

  // 6. Logique de redirection et d'aiguillage au clic (Background / Terminated)
  static void _handleMessage(RemoteMessage message) {
    final data = message.data;
    
    final String? contractId = data['contractId'] ?? data['contratId'] ?? data['factureId'];
    if (contractId != null && contractId.isNotEmpty) {
      _redirigerSelonRole(contractId);
      return;
    }

    final String? propertyId = data['propertyId'];
    if (propertyId != null && propertyId.isNotEmpty) {
      navigatorKey.currentState?.pushNamed('/details-maison', arguments: propertyId);
      return;
    }
  }

  // 🟢 METHODE COMMUNE D'AIGUILLAGE INTELLIGENT (SÉCURISÉE)
  static void _redirigerSelonRole(String contractId) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      // Si non connecté, rediriger vers la page de connexion
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/connexion', (route) => false);
      return;
    }

    FirebaseFirestore.instance.collection('utilisateurs').doc(currentUser.uid).get().then((doc) {
      if (!doc.exists) return; // Sécurité si le doc n'existe pas

      final String role = doc.data()?['role'] ?? 'locataire';
      
      // Vérification que le contexte est valide avant de naviguer
      if (navigatorKey.currentState != null) {
        if (role.toLowerCase() == 'bailleur') {
          navigatorKey.currentState?.pushNamed('/suivi-locations-bailleur', arguments: contractId);
        } else {
          navigatorKey.currentState?.pushNamed('/mes-factures', arguments: contractId);
        }
      }
    }).catchError((e) {
      debugPrint("Erreur critique redirection : $e");
      // Repli sécurisé par défaut sur l'espace factures du locataire
      navigatorKey.currentState?.pushNamed('/mes-factures', arguments: contractId);
    });
  }

  // --- LOGIQUE D'INVITATION SMS/WHATSAPP ---
  static Future<void> sendAsymmetricInvitation({
    required BuildContext context,
    required String telephone,
    required String nomEmetteur,
    required String refMaison,
    required bool isBailleur,
  }) async {
    String cleanTel = telephone.replaceAll(RegExp(r'[^\d]'), '');
    if (!cleanTel.startsWith('243')) cleanTel = '243$cleanTel';

    String message;
    if (isBailleur) {
      message = "Bonjour, votre bailleur $nomEmetteur vous a ajouté sur EasyLocation. "
                "Utilisez le code maison *$refMaison* pour suivre vos paiements. "
                "Téléchargez l'app ici : [LIEN_PLAYSTORE]";
    } else {
      message = "Bonjour, votre locataire $nomEmetteur utilise EasyLocation pour "
                "gérer sa location (Réf: *$refMaison*). Rejoignez-le pour valider "
                "les paiements en un clic ! [LIEN_PLAYSTORE]";
    }

    final Uri whatsappUrl = Uri.parse("https://wa.me/$cleanTel?text=${Uri.encodeComponent(message)}");
    
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("WhatsApp non détecté"),
            content: const Text(
              "Voulez-vous envoyer une invitation par SMS à la place ?\n\n"
              "Note : Des frais d'opérateur peuvent s'appliquer selon votre forfait."
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ANNULER"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () async {
                  Navigator.pop(context);
                  final Uri smsUrl = Uri.parse("sms:$telephone?body=${Uri.encodeComponent(message)}");
                  if (await canLaunchUrl(smsUrl)) {
                    await launchUrl(smsUrl);
                  }
                },
                child: const Text("ENVOYER SMS", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur lors de l'envoi : $e");
    }
  }
}