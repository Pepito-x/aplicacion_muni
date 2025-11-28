import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'asignar_tecnicos_screen.dart'; 
import 'admin_home.dart'; // 👈 IMPORTANTE: Importa tu Home de Admin

class JefeNotificacionesScreen extends StatelessWidget {
  const JefeNotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data;
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          });
          return const Scaffold(body: Center(child: SizedBox()));
        }

        return _NotificacionesContent(uid: user.uid);
      },
    );
  }
}

class _NotificacionesContent extends StatelessWidget {
  final String uid;

  const _NotificacionesContent({required this.uid});

  static const Color verdeBandera = Color(0xFF006400);

  // 🔄 Navegación segura al AdminHome
  void _irAlHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminHome()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Control del botón físico "Atrás"
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _irAlHome(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5), // Fondo moderno
        appBar: AppBar(
          backgroundColor: verdeBandera,
          elevation: 0,
          centerTitle: true,
          // 2. Flecha de regreso en AppBar
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => _irAlHome(context),
          ),
          title: const Text(
            'Notificaciones',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: "Marcar todo como leído",
              onPressed: () => _marcarTodoLeido(),
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notificaciones')
              .doc(uid)
              .collection('inbox')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: verdeBandera));
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Estás al día',
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No hay notificaciones nuevas',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildNotificacionItem(context, doc, data);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificacionItem(BuildContext context, QueryDocumentSnapshot doc, Map<String, dynamic> data) {
    final titulo = data['titulo'] ?? 'Notificación';
    final cuerpo = data['cuerpo'] ?? '';
    final esNuevo = data['leido'] == false;
    final tipo = data['tipo'] ?? 'general';

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text("Eliminar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ],
        ),
      ),
      onDismissed: (direction) {
        doc.reference.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notificación eliminada"), duration: Duration(seconds: 1)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(esNuevo ? 0.08 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (esNuevo) {
                await doc.reference.update({'leido': true});
              }
              if (tipo == 'nueva_incidencia') {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const AsignarTecnicosScreen())
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono
                  _buildIcono(tipo, esNuevo),
                  const SizedBox(width: 16),
                  
                  // Contenido
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                titulo,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: esNuevo ? FontWeight.bold : FontWeight.w600,
                                  color: Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (esNuevo)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cuerpo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            color: esNuevo ? Colors.grey.shade800 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(data['timestamp']),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcono(String tipo, bool esNuevo) {
    IconData iconData;
    Color colorFondo;
    Color colorIcono;

    switch (tipo) {
      case 'nueva_incidencia':
        iconData = FontAwesomeIcons.triangleExclamation;
        colorFondo = Colors.orange.shade50;
        colorIcono = Colors.orange;
        break;
      case 'asignacion':
        iconData = FontAwesomeIcons.screwdriverWrench;
        colorFondo = Colors.blue.shade50;
        colorIcono = Colors.blue;
        break;
      case 'resuelto':
        iconData = FontAwesomeIcons.check;
        colorFondo = Colors.green.shade50;
        colorIcono = Colors.green;
        break;
      default:
        iconData = FontAwesomeIcons.bell;
        colorFondo = Colors.grey.shade100;
        colorIcono = Colors.grey;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(iconData, color: colorIcono, size: 20),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Hace un momento';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
      if (diff.inDays == 1) return 'Ayer';
      
      return '${date.day}/${date.month}/${date.year}';
    }
    return '';
  }

  Future<void> _marcarTodoLeido() async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('notificaciones')
        .doc(uid)
        .collection('inbox')
        .where('leido', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'leido': true});
    }
    await batch.commit();
  }
}