import 'dart:async';
import 'dart:ui'; // Necesario para ImageFilter (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importa tus pantallas
import 'login_screen.dart';
import 'admin_home.dart';
import 'tecnico_home.dart';
import 'usuario_home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Configuración de Animaciones
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Efecto de "respiración" (Breathing effect) para el logo
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _controller.repeat(reverse: true); // El logo pulsa suavemente

    // 2. Iniciar proceso de carga inteligente
    _inicializarApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🧠 Lógica Profesional: Carga paralela
  Future<void> _inicializarApp() async {
    // Ejecutamos dos tareas al mismo tiempo:
    // A. Esperar mínimo 2.5 segundos (para que se vea la marca y la animación)
    // B. Verificar la sesión en Firebase (esto puede ser rápido o lento)
    
    final resultados = await Future.wait([
      Future.delayed(const Duration(milliseconds: 2500)), // Tiempo mínimo visual
      _obtenerSiguientePantalla(), // Lógica de negocio real
    ]);

    // El resultado del índice 1 es el Widget al que debemos ir
    final Widget siguientePantalla = resultados[1] as Widget;

    if (mounted) {
      // Navegación con transición suave (Fade)
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => siguientePantalla,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  // 🔒 Lógica de Autenticación y Roles
  Future<Widget> _obtenerSiguientePantalla() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return const LoginScreen();

      // Consultar Firestore para el rol
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        return const LoginScreen();
      }

      final rol = doc.data()?['rol']; // Usar ? para seguridad null

      if (rol == 'admin' || rol == 'jefe') return const AdminHome();
      if (rol == 'tecnico') return const TecnicoHome();
      
      return const UsuarioHome(); // Default
    } catch (e) {
      // Si falla algo (sin internet, etc), mandamos al login por seguridad
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fondo muy sutil, casi blanco pero premium
    const backgroundColor = Color(0xFFFAFAFA); 
    const verdeBandera = Color(0xFF006400);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 🎨 Fondo decorativo (Opcional: degradado muy sutil)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    Colors.white,
                    Colors.grey.shade100,
                  ],
                ),
              ),
            ),
          ),

          // 🔹 Contenido Central
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo con efecto de respiración y sombra elegante
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: verdeBandera.withOpacity(0.15),
                            blurRadius: 60,
                            spreadRadius: 10,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'logo_app',
                        child: Image.asset(
                          'assets/img/logo_reque.png',
                          width: 140,
                          height: 140,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Texto de Título con tipografía moderna
                  const Text(
                    "MUNICIPALIDAD DISTRITAL\nDE REQUE",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: 1.5,
                      color: Color(0xFF2D3436),
                      height: 1.4,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Text(
                    "Gestión de Incidencias TI",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 💎 Indicador de carga estilo "Glassmorphism" (iOS Style)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 18, 
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(verdeBandera),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Iniciando sesión segura...",
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Versionamiento (detalle sutil al pie)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "v1.0.0",
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 10,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}