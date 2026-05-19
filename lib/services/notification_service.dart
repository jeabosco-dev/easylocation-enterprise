import 'dart:typed_data'; // ✅ Requis pour Int64List (vibration)
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

// 1. Fonction Top-level pour le background (obligatoire pour Firebase)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Message reçu en arrière-plan : ${message.messageId}");
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

      // CORRECTION FINALE : Utilisation de l'argument nommé "settings:"
      await _localNotifications.initialize(
        settings: initializationSettings, 
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            navigatorKey.currentState?.pushNamed('/details-maison', arguments: response.payload);
          }
        },
      );

      // 5. Écouter les messages en Foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          // Utilisation des arguments nommés pour .show()
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
                vibrationPattern: Int64List.fromList([0, 500, 200, 500]), // ✅ Aligné aussi pour le Foreground
              ),
            ),
            payload: message.data['propertyId'],
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

  static void _handleMessage(RemoteMessage message) {
    final String? propertyId = message.data['propertyId'];
    if (propertyId != null) {
      navigatorKey.currentState?.pushNamed('/details-maison', arguments: propertyId);
    }
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
      print("Erreur lors de l'envoi : $e");
    }
  }
}