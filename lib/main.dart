import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 1. Importar Messaging
import 'firebase_options.dart'; // 2. Importar opciones generadas

import 'screens/splash_screen.dart';
import 'screens/admin_home.dart';
import 'screens/jefe_notificaciones_screen.dart';
import 'screens/usuario_home.dart';

// 3. 🔴 CRÍTICO: Manejador de notificaciones en segundo plano
// Debe estar FUERA del main() y ser una función top-level.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Aseguramos que Firebase esté inicializado antes de usarlo en segundo plano
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("mensaje en segundo plano recibido: ${message.messageId}");
}

// 4. Llave global para poder navegar desde notificaciones (opcional pero muy útil)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializamos Firebase con las opciones correctas
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 5. Registramos el manejador de segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
  } catch (e) {
    print('⚠️ Error inicializando Firebase: $e');
  }

  runApp(const MuniIncidenciasApp());
}

class MuniIncidenciasApp extends StatelessWidget {
  const MuniIncidenciasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Incidencias Reque',
      navigatorKey: navigatorKey, // Asignamos la llave de navegación
      theme: ThemeData(
        fontFamily: 'Montserrat',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006400)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/admin_home': (context) => const AdminHome(),
        '/notificaciones': (context) => const JefeNotificacionesScreen(),
        '/usuario_home': (context) => const UsuarioHome(),
      },
    );
  }
}