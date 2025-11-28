import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tecnico_home.dart'; 
// 👇 IMPORTA TU PANTALLA DE CHAT AQUÍ (Ajusta la ruta según tus carpetas)
import 'direct_chat_screen.dart'; 

class IncidenciasAsignadasScreen extends StatelessWidget {
  const IncidenciasAsignadasScreen({super.key});

  static const Color verdeBandera = Color(0xFF006400);

  void _irAlHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const TecnicoHome()),
      (route) => false,
    );
  }

  Future<String?> obtenerNombreTecnico() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('correo', isEqualTo: user.email)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first['nombre'];
  }

  Future<List<String>> obtenerAreasAsignadas(String nombreTecnico) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('areas')
        .where(
          Filter.or(
            Filter('responsables', arrayContains: nombreTecnico),
            Filter('responsable', isEqualTo: nombreTecnico),
          ),
        )
        .get();

    return snapshot.docs.map((doc) => doc['nombre'].toString()).toList();
  }

  Future<void> marcarComoResuelta(String id) async {
    await FirebaseFirestore.instance
        .collection('incidencias')
        .doc(id)
        .update({'estado': 'Resuelto'});
  }

  // 🔹 NUEVO: Función para ir al chat
  void _irAlChat(BuildContext context, Map<String, dynamic> dataIncidencia, String miNombreTecnico) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final otroUid = dataIncidencia['usuario_reportante_id'];
    final otroNombre = dataIncidencia['usuario_reportante_nombre'] ?? 'Usuario';
    
    if (otroUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No se encontró el ID del usuario reportante")),
      );
      return;
    }

    // Generar ID único ordenando los UIDs (para que siempre sea el mismo chat entre A y B)
    final uids = [currentUser.uid, otroUid];
    uids.sort(); 
    final chatId = 'chat_1v1_${uids[0]}_${uids[1]}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectChatScreen(
          chatId: chatId,
          otroNombre: otroNombre,
          otroRol: 'Usuario', // Sabemos que quien reporta es usuario (o ajusta según lógica)
          rol: 'Tecnico',     // Yo soy el técnico
          nombre: miNombreTecnico,
        ),
      ),
    );
  }

  String formatearFecha(Timestamp fecha) {
    final d = fecha.toDate();
    return "${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
  }

  Color colorPorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente': return Colors.orange;
      case 'en proceso': return Colors.blueAccent;
      case 'resuelto': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _irAlHome(context);
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: verdeBandera,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => _irAlHome(context),
          ),
          title: const Text(
            'Mis Incidencias',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
        body: FutureBuilder<String?>(
          future: obtenerNombreTecnico(),
          builder: (context, tecnicoSnapshot) {
            if (tecnicoSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: verdeBandera));
            }

            final nombreTecnico = tecnicoSnapshot.data;
            if (nombreTecnico == null) {
              return _mensajeError('No se pudo identificar al técnico.');
            }

            return FutureBuilder<List<String>>(
              future: obtenerAreasAsignadas(nombreTecnico),
              builder: (context, areasSnapshot) {
                if (areasSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: verdeBandera));
                }

                final areas = areasSnapshot.data ?? [];
                if (areas.isEmpty) {
                  return _mensajeVacio('No tienes áreas asignadas actualmente.');
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('incidencias')
                      .where(
                        Filter.or(
                          Filter('tecnico_asignado', isEqualTo: nombreTecnico),
                          Filter('tecnicos_asignados', arrayContains: nombreTecnico),
                        ),
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: verdeBandera));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _mensajeVacio('¡Todo limpio! No tienes incidencias pendientes.');
                    }

                    final incidenciasFiltradas = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final area = data['area'] ?? '';
                      return areas.contains(area);
                    }).toList();

                    if (incidenciasFiltradas.isEmpty) {
                      return _mensajeVacio('No hay incidencias activas en tus áreas.');
                    }

                    final Map<String, List<QueryDocumentSnapshot>> incidenciasPorArea = {};
                    for (var doc in incidenciasFiltradas) {
                      final data = doc.data() as Map<String, dynamic>;
                      final area = data['area'] ?? 'Sin área';
                      incidenciasPorArea.putIfAbsent(area, () => []).add(doc);
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: incidenciasPorArea.entries.map((entry) {
                        final area = entry.key;
                        final incidencias = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    height: 24, width: 4,
                                    decoration: BoxDecoration(
                                      color: verdeBandera,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    area.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                      fontSize: 14,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            ...incidencias.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              // 👇 PASAMOS EL NOMBRE DEL TECNICO AQUI
                              return _construirTarjetaIncidencia(context, doc.id, data, nombreTecnico);
                            }),
                          ],
                        );
                      }).toList(),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // 👇 RECIBE nombreTecnico
  Widget _construirTarjetaIncidencia(BuildContext context, String id, Map<String, dynamic> data, String nombreTecnico) {
    final equipo = data['nombre_equipo'] ?? 'Equipo desconocido';
    final descripcion = data['descripcion'] ?? 'Sin descripción';
    final estado = data['estado'] ?? 'Pendiente';
    final fecha = data['fecha_reporte'] != null
        ? formatearFecha(data['fecha_reporte'] as Timestamp)
        : 'Sin fecha';
    final colorEstado = colorPorEstado(estado);

    String? urlImagen;
    final imagenesList = data['imagenes'];
    if (imagenesList is List && imagenesList.isNotEmpty && imagenesList[0] is String) {
      urlImagen = imagenesList[0];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // 👇 PASAMOS EL NOMBRE DEL TECNICO AL BOTTOM SHEET
          onTap: () => _mostrarDetalleBottomSheet(context, id, data, urlImagen, nombreTecnico),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70, height: 70,
                    color: Colors.grey.shade100,
                    child: urlImagen != null && urlImagen.isNotEmpty
                        ? Image.network(urlImagen, fit: BoxFit.cover)
                        : Icon(Icons.build_circle_outlined, color: verdeBandera.withOpacity(0.5), size: 30),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipo,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.2,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            fecha.split(' ')[0], 
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorEstado.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colorEstado.withOpacity(0.3)),
                            ),
                            child: Text(
                              estado,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorEstado,
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 👇 RECIBE nombreTecnico
  void _mostrarDetalleBottomSheet(BuildContext context, String id, Map<String, dynamic> data, String? urlImagen, String nombreTecnico) {
    final estado = data['estado'] ?? 'Desconocido';
    final esResuelto = estado.toString().toLowerCase() == 'resuelto';
    final nombreUsuario = data['usuario_reportante_nombre'] ?? 'Usuario';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70, // Un poco más alto para que quepa el botón nuevo
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  if (urlImagen != null && urlImagen.isNotEmpty)
                    Container(
                      height: 200,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(urlImagen),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  Text(
                    data['nombre_equipo'] ?? 'Equipo',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  _infoFila(Icons.description, "Descripción", data['descripcion']),
                  _infoFila(Icons.person, "Usuario Reportante", nombreUsuario), // Mostramos quién reportó
                  _infoFila(Icons.business, "Área", data['area']),
                  _infoFila(Icons.calendar_today, "Fecha Reporte", 
                      data['fecha_reporte'] != null 
                      ? formatearFecha(data['fecha_reporte'] as Timestamp) 
                      : 'N/A'),
                  
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Text("Estado actual:", style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Chip(
                        label: Text(
                          estado,
                          style: TextStyle(color: esResuelto ? Colors.white : Colors.black87),
                        ),
                        backgroundColor: colorPorEstado(estado),
                        side: BorderSide.none,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 🔵 BOTÓN DE CHAT (NUEVO)
                  if (!esResuelto) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Cierra el detalle para ir al chat limpio
                          _irAlChat(context, data, nombreTecnico);
                        },
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                        label: Text(
                          "CONTACTAR CON $nombreUsuario".toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.blueAccent)
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 🟢 BOTÓN DE RESOLVER
                  if (!esResuelto)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await marcarComoResuelta(id);
                          if(context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: const Text(
                          "MARCAR COMO RESUELTO",
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: verdeBandera,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  
                  if (esResuelto)
                    Center(
                      child: Text(
                        "Esta incidencia ya ha sido cerrada.",
                        style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                      ),
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoFila(IconData icon, String label, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                Text(valor ?? '---', style: const TextStyle(fontSize: 15, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajeVacio(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensajeError(String mensaje) {
    return Center(
      child: Text(mensaje, style: const TextStyle(color: Colors.red)),
    );
  }
}