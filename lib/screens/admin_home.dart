import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 📥 Importamos todas las pantallas necesarias
import 'login_screen.dart';
import 'ver_incidencias_screen.dart';
import 'asignar_tecnicos_screen.dart';
import 'reportes_mensuales_screen.dart';
import 'jefe_notificaciones_screen.dart';
import 'gestion_usuarios_screen.dart';
import 'infraestructura_ti_screen.dart';
import 'registrar_areas_screen.dart';
import '../utils/role_validator.dart';
import '../screens/direct_chat_home.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;
  String? _nombreJefe;
  bool _loadingNombre = true;

  final Color verdeBandera = const Color(0xFF006400);

  @override
  void initState() {
    super.initState();
    _validateAndLoad();
    _cargarNombreJefe();
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _validateAndLoad() async {
    final isValid = await validateUserRole(
      context,
      allowedRoles: ['admin', 'jefe'],
    );
    if (isValid) {
      _cargarNombreJefe();
    }
  }

  Future<void> _cargarNombreJefe() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _nombreJefe = "Jefe";
        _loadingNombre = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _nombreJefe = doc.data()?['nombre'] ?? "Jefe";
      } else {
        _nombreJefe = user.email?.split('@').first ?? "Jefe";
      }
    } catch (e) {
      debugPrint("Error al cargar nombre del jefe: $e");
      _nombreJefe = "Jefe";
    }

    if (mounted) {
      setState(() {
        _loadingNombre = false;
      });
    }
  }

  Stream<int> _contarNotificacionesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('notificaciones')
        .doc(uid)
        .collection('inbox')
        .where('leido', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      body: Column(
        children: [
          // 🟢 Header siempre visible en la pestaña de Inicio
          if (_currentIndex == 0) _buildHeaderCard(),
          
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildPage(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomMenuLimpio(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: verdeBandera,
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DirectChatHome(
                rol: 'jefe',
                nombre: _nombreJefe ?? "Jefe",
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }

  // 🔔 Header Card: Reportes + Notificaciones + Salir
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 45, 16, 10),
      child: Card(
        elevation: 6,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFE8F5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Hola, Jefe",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                    _loadingNombre
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.grey),
                            ))
                        : Text(
                            _nombreJefe ?? "Jefe",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: verdeBandera,
                            ),
                          ),
                  ],
                ),
              ),
              
              // 📊 BOTÓN REPORTES (Nuevo lugar)
              IconButton(
                icon: const Icon(Icons.bar_chart, size: 28, color: Colors.grey),
                tooltip: "Reportes Mensuales",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportesMensualesScreen()),
                  );
                },
              ),

              // 🔔 BOTÓN NOTIFICACIONES
              StreamBuilder<int>(
                stream: _contarNotificacionesStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, size: 28, color: Colors.grey),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const JefeNotificacionesScreen()),
                          );
                        },
                      ),
                      if (count > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(width: 4),

              // 🚪 BOTÓN SALIR
              InkWell(
                onTap: () => _cerrarSesion(context),
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Menú Inferior Ultra Limpio (5 Ítems)
  Widget _buildBottomMenuLimpio() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Theme(
          data: Theme.of(context).copyWith(canvasColor: Colors.white),
          child: BottomNavigationBar(
            elevation: 12,
            currentIndex: _currentIndex,
            backgroundColor: Colors.white.withOpacity(0.95),
            selectedItemColor: verdeBandera,
            unselectedItemColor: Colors.grey.shade400,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 10,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: "Inicio",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt),
                label: "Incidencias",
              ),
              // "Técnicos" ahora es solo para ver lista, asignar está en el home
              BottomNavigationBarItem(
                icon: Icon(Icons.person_search_outlined),
                label: "Técnicos", // Lista general o búsqueda
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                label: "Usuarios",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.dns_outlined),
                label: "Infra",
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Switch Actualizado
  Widget _buildPage() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const VerIncidenciasScreen();
      case 2:
        // Si tienes una pantalla solo para ver lista de técnicos, úsala aquí.
        // Si no, reutilizamos AsignarTecnicosScreen como placeholder o creas una "ListaTecnicosScreen"
        return const AsignarTecnicosScreen(); 
      case 3:
        return const GestionUsuariosScreen();
      case 4:
        return const InfraestructuraTIScreen();
      default:
        return _buildHomeContent();
    }
  }

  // ✅ Contenido del Home (Grid): Asignar Técnicos agregado aquí
  Widget _buildHomeContent() {
    return Container(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Panel de Control",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006400),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Gestión rápida de operaciones",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 15),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                // 1. Asignar Técnicos (Acceso Directo)
                _buildCard(
                  icon: FontAwesomeIcons.userGear, // Icono distintivo
                  title: "Asignar\nTécnicos",
                  color: Colors.orange.shade800,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AsignarTecnicosScreen()),
                    );
                  },
                ),
                
                // 2. Registrar Áreas
                _buildCard(
                  icon: FontAwesomeIcons.mapLocationDot,
                  title: "Registrar\nÁreas",
                  color: Colors.purple.shade700,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegistrarAreasScreen()),
                    );
                  },
                ),

                // 3. Gestión Usuarios (Acceso al tab)
                _buildCard(
                  icon: FontAwesomeIcons.usersCog,
                  title: "Gestión\nUsuarios",
                  color: Colors.teal.shade700,
                  onTap: () => setState(() => _currentIndex = 3),
                ),

                // 4. Infraestructura (Acceso al tab)
                _buildCard(
                  icon: FontAwesomeIcons.server,
                  title: "Infraestructura\nTI",
                  color: Colors.red.shade700,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}