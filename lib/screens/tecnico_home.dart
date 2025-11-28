// ✅ TecnicoHome — versión corregida con chat 1:1 integrado
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
import 'registrar_equipo_screen.dart';
import '../utils/role_validator.dart';
import '../screens/direct_chat_home.dart'; // 👈 asegúrate que la ruta es correcta

class TecnicoHome extends StatefulWidget {
  const TecnicoHome({super.key});

  @override
  State<TecnicoHome> createState() => _TecnicoHomeState();
}

class _TecnicoHomeState extends State<TecnicoHome> with TickerProviderStateMixin {
  int _currentIndex = 0;
  String? _nombreTecnico;
  bool _loadingNombre = true;

  // 🌿 MISMA PALETA QUE USUARIOHOME — CONSISTENCIA MULTI-ROL
  static const Color primaryDark = Color(0xFF0D4D3C);
  static const Color primaryMedium = Color(0xFF157F62);
  static const Color accentGold = Color(0xFFF2C94C);
  static const Color backgroundLight = Color(0xFFF7F9F9);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1E1F20);
  static const Color textSecondary = Color(0xFF6F7173);
  static const Color divider = Color(0xFFE2E5E6);

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
      if (mounted) {
        setState(() {
          _nombreTecnico = "Técnico";
          _loadingNombre = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _nombreTecnico = doc.data()?['nombre'] ?? user.displayName ?? "Técnico";
      } else {
        _nombreTecnico = user.displayName ?? user.email?.split('@').first ?? "Técnico";
      }
    } catch (e) {
      _nombreTecnico = "Técnico";
    }

    if (mounted) {
      setState(() => _loadingNombre = false);
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
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
      // ✅ FAB dentro del Scaffold → ¡CORREGIDO!
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryMedium,
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () {
          // ✅ Solo usa _nombreTecnico (no otras variables inexistentes)
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
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat, // opcional: más discreto
    );
  }

  // ✅ HEADER GRADIENTE — IGUAL QUE USUARIOHOME (pero mensaje técnico)
  Widget _buildHeaderGradient() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 35),
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              Tooltip(
                message: 'Cerrar sesión',
                child: InkWell(
                  onTap: () => _cerrarSesion(context),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "Hola,",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 26,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          _loadingNombre
              ? const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                )
              : Text(
                  "$_nombreTecnico 👨‍🔧",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 31,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
          const SizedBox(height: 8),
          Text(
            "¿Qué vas a solucionar hoy?",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ BOTTOM NAV — MISMO ESTILO PROFESIONAL QUE USUARIOHOME
  Widget _buildBottomMenu() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: BottomNavigationBar(
          elevation: 9,
          currentIndex: _currentIndex,
          backgroundColor: Colors.white.withOpacity(0.93),
          selectedItemColor: primaryMedium,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: "Inicio",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              label: "Incidencias",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_city_outlined),
              label: "Áreas",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              label: "Historial",
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRelojCard(),
          const SizedBox(height: 20),
          _buildMarketingBannerTecnico(),
          const SizedBox(height: 25),
          _buildMainActionButton(),
        ],
      ),
    );
  }

  // ✅ RELOJ — MISMO DISEÑO QUE USUARIOHOME
  Widget _buildRelojCard() {
    final now = _horaActual;

    final dias = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo'
    ];
    final meses = [
      'Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
    ];

    String diaSemana = dias[now.weekday - 1];
    String fechaStr = '${now.day} de ${meses[now.month - 1]}';
    String horaStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diaSemana,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fechaStr,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: accentGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  horaStr,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accentGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (now.hour * 3600 + now.minute * 60 + now.second) / 86400,
            backgroundColor: Colors.white24,
            color: accentGold,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  // ✅ BANNER TÉCNICO — MENSAJE RELEVANTE PARA EL ROL
  Widget _buildMarketingBannerTecnico() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryMedium.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.build,
                  color: primaryMedium,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "El 89% de las incidencias se resuelven en menos de 2 horas cuando se priorizan adecuadamente.",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Revisa tus asignaciones y responde con rapidez.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 14,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ BOTÓN PRINCIPAL: "Ver Incidencias" — ENFOCADO EN LA ACCIÓN CLAVE DEL TÉCNICO
  Widget _buildMainActionButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => setState(() => _currentIndex = 1), // ← Ir directo a pestaña Incidencias
      child: Container(
        padding: const EdgeInsets.all(28),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: primaryGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: const [
            Icon(FontAwesomeIcons.listCheck, size: 55, color: Colors.white),
            SizedBox(height: 18),
            Text(
              "Ver Incidencias",
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}