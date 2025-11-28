import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'incidencias_asignadas_screen.dart';
import 'areas_asignadas_screen.dart';
import 'historial_screen.dart';
import 'registrar_equipo_screen.dart'; // 👈 Importado correctamente
import '../utils/role_validator.dart';
import '../screens/direct_chat_home.dart';

class TecnicoHome extends StatefulWidget {
  const TecnicoHome({super.key});

  @override
  State<TecnicoHome> createState() => _TecnicoHomeState();
}

class _TecnicoHomeState extends State<TecnicoHome> with TickerProviderStateMixin {
  int _currentIndex = 0;
  String? _nombreTecnico;
  bool _loadingNombre = true;

  // 🎨 PALETA DE COLORES
  static const Color primaryDark = Color(0xFF0D4D3C);
  static const Color primaryMedium = Color(0xFF157F62);
  static const Color accentGold = Color(0xFFF2C94C);
  static const Color backgroundLight = Color(0xFFF7F9F9);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1E1F20);
  static const Color textSecondary = Color(0xFF6F7173);

  Timer? _relojTimer;
  DateTime _horaActual = DateTime.now();

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, primaryMedium],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _validateAndLoad();
    _startReloj();
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
    super.dispose();
  }

  Future<void> _validateAndLoad() async {
    final isValid = await validateUserRole(
      context,
      allowedRoles: ['tecnico'],
    );
    if (isValid) {
      _cargarNombreTecnico();
    }
  }

  void _startReloj() {
    _relojTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _horaActual = DateTime.now();
        });
      }
    });
  }

  Future<void> _cargarNombreTecnico() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingNombre = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        _nombreTecnico = doc.data()?['nombre'] ?? user.displayName ?? "Técnico";
      } else {
        _nombreTecnico = user.displayName ?? user.email?.split('@').first ?? "Técnico";
      }
    } catch (e) {
      _nombreTecnico = "Técnico";
    }

    if (mounted) setState(() => _loadingNombre = false);
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          // Solo mostramos el Header grande en la pestaña Inicio (0)
          if (_currentIndex == 0) _buildHeaderGradient(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _buildPage(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomMenu(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryMedium,
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DirectChatHome(
                rol: 'tecnico',
                nombre: _nombreTecnico ?? "Técnico",
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // 🔹 HEADER
  Widget _buildHeaderGradient() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
      decoration: const BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(), // Spacer
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => _cerrarSesion(context),
                tooltip: 'Cerrar sesión',
              ),
            ],
          ),
          const Text(
            "Bienvenido,",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 22,
              color: Colors.white70,
            ),
          ),
          _loadingNombre
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
              : Text(
                  _nombreTecnico ?? "Técnico",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ],
      ),
    );
  }

  // 🔹 MENU INFERIOR
  Widget _buildBottomMenu() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: BottomNavigationBar(
          elevation: 10,
          currentIndex: _currentIndex,
          backgroundColor: Colors.white.withOpacity(0.95),
          selectedItemColor: primaryMedium,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "Inicio"),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Incidencias"),
            BottomNavigationBarItem(icon: Icon(Icons.domain), label: "Áreas"),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: "Historial"),
          ],
        ),
      ),
    );
  }

  // 🔹 CONTROL DE PÁGINAS
  Widget _buildPage() {
    switch (_currentIndex) {
      case 1:
        return const IncidenciasAsignadasScreen();
      case 2:
        return const AreasAsignadasScreen();
      case 3:
        return const HistorialScreen();
      default:
        return _buildHomeContent();
    }
  }

  // 🔹 CONTENIDO DEL HOME (DASHBOARD)
  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRelojCard(),
          const SizedBox(height: 25),
          
          const Text(
            "Accesos Rápidos",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 15),

          // 👇 AQUÍ ESTÁN LOS BOTONES DE ACCIÓN (INCIDENCIAS Y REGISTRAR EQUIPO)
          Row(
            children: [
              // 1. Botón Ver Incidencias
              Expanded(
                child: _buildActionCard(
                  title: "Mis\nIncidencias",
                  icon: FontAwesomeIcons.listCheck,
                  color: primaryMedium,
                  isPrimary: true,
                  onTap: () => setState(() => _currentIndex = 1), // Cambia al tab 1
                ),
              ),
              const SizedBox(width: 15),
              
              // 2. Botón Registrar Equipo (NUEVO)
              Expanded(
                child: _buildActionCard(
                  title: "Registrar\nEquipo",
                  icon: FontAwesomeIcons.computer,
                  color: Colors.blue.shade700,
                  isPrimary: false,
                  onTap: () {
                    // Navegar a la pantalla de registro
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegistrarEquipoScreen()),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),
          _buildMarketingBannerTecnico(),
        ],
      ),
    );
  }

  // 🔹 WIDGET: TARJETA DE ACCIÓN
  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          gradient: isPrimary ? primaryGradient : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPrimary ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isPrimary ? Colors.white : color, size: 24),
            ),
            Text(
              title,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isPrimary ? Colors.white : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 RELOJ
  Widget _buildRelojCard() {
    final now = _horaActual;
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

    String fechaStr = '${dias[now.weekday - 1]}, ${now.day} de ${meses[now.month - 1]}';
    String horaStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(horaStr, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary)),
              Text(fechaStr, style: const TextStyle(fontSize: 14, color: textSecondary)),
            ],
          ),
          const Icon(Icons.access_time_filled, color: accentGold, size: 40),
        ],
      ),
    );
  }

  // 🔹 BANNER INFORMATIVO
  Widget _buildMarketingBannerTecnico() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          Icon(Icons.tips_and_updates, color: primaryDark),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Mantén el inventario actualizado registrando los equipos nuevos.",
              style: TextStyle(color: primaryDark, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}