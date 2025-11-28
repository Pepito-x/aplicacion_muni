import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initNotifications() async {
    // 1. Pedir permiso al usuario (Crítico para iOS/Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permiso concedido');
      
      // 2. Obtener el token del dispositivo
      String? token = await _fcm.getToken();
      
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // 3. Escuchar refrescos de token (si el usuario reinstala o borra datos)
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Guardamos el token en el documento del usuario
    await _db.collection('usuarios').doc(uid).update({
      'fcmToken': token, // Campo importante para las Cloud Functions
    });

    // 🔹 ESTRATEGIA PARA JEFES:
    // Si el usuario es Jefe, lo suscribimos a un "TEMA" (Topic).
    // Esto facilita enviar notificaciones masivas a todos los jefes sin buscar sus IDs.
    final userDoc = await _db.collection('usuarios').doc(uid).get();
    if (userDoc.exists && userDoc.data()?['rol'] == 'jefe') {
      await _fcm.subscribeToTopic('jefes');
      print('Suscrito al canal de jefes');
    }
  }
}