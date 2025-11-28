import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Asegúrate de importar tu pantalla de asignación si quieres navegar directo
import 'asignar_tecnicos_screen.dart'; 

class JefeNotificacionesScreen extends StatelessWidget {
  const JefeNotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos cambios en la autenticación para seguridad
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data;
        if (user == null) {
          // Si no hay usuario, volvemos al login
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

  @override
  Widget build(BuildContext context) {
    const verdeBandera = Color(0xFF006400);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: verdeBandera,
        title: const Text(
          'Centro de Notificaciones',
          style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Botón para marcar todo como leído (Opcional)
          IconButton(
            icon: const Icon(Icons.done_all),
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
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Estás al día',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontFamily: 'Montserrat'),
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

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              // Seguridad contra nulos
              final titulo = data['titulo'] ?? 'Notificación';
              final cuerpo = data['cuerpo'] ?? '';
              final esNuevo = data['leido'] == false;
              final tipo = data['tipo'] ?? 'general';

              // 🟢 Funcionalidad: Deslizar para borrar
              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                ),
                onDismissed: (direction) {
                  // Borramos de Firebase
                  doc.reference.delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Notificación eliminada"), duration: Duration(seconds: 1)),
                  );
                },
                child: Card(
                  elevation: esNuevo ? 4 : 1,
                  shadowColor: esNuevo ? Colors.orange.withOpacity(0.4) : Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: esNuevo 
                        ? const BorderSide(color: Colors.orangeAccent, width: 1.5) 
                        : BorderSide.none,
                  ),
                  color: esNuevo ? Colors.white : Colors.grey.shade50,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: _buildIcono(tipo, esNuevo),
                    title: Text(
                      titulo,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: esNuevo ? FontWeight.bold : FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          cuerpo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(data['timestamp']),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    onTap: () async {
                      // 1. Marcar como leído
                      if (esNuevo) {
                        await doc.reference.update({'leido': true});
                      }

                      // 2. Navegar según el tipo
                      if (tipo == 'nueva_incidencia') {
                         // Opción A: Ir a Asignar Técnicos
                         Navigator.push(
                           context, 
                           MaterialPageRoute(builder: (_) => const AsignarTecnicosScreen())
                         );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Icono según el tipo de notificación
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

    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorFondo,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(iconData, color: colorIcono, size: 20),
          ),
        ),
        if (esNuevo)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
              ),
            ),
          ),
      ],
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
      if (diff.inDays == 1) return 'Ayer a las ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
      
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