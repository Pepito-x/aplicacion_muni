import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tecnico_home.dart'; // 👈 IMPORTANTE: Importa tu home de técnico

class IncidenciasAsignadasScreen extends StatelessWidget {
  const IncidenciasAsignadasScreen({super.key});

  // 🟢 Color corporativo
  static const Color verdeBandera = Color(0xFF006400);

  // 🔄 Función para regresar al Home limpiando el historial
  void _irAlHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const TecnicoHome()),
      (route) => false,
    );
  }

  /// 🔹 Obtener el nombre del técnico logueado
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

  /// 🔹 Obtener las áreas actuales del técnico
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

  /// 🔹 Cambiar estado a resuelto
  Future<void> marcarComoResuelta(String id) async {
    await FirebaseFirestore.instance
        .collection('incidencias')
        .doc(id)
        .update({'estado': 'Resuelto'});
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
    // 1. Control del botón físico de atrás
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
            onPressed: () => _irAlHome(context), // 2. Botón atrás AppBar
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

                // Aunque no tenga áreas, podría tener asignaciones directas, 
                // pero si la lógica de negocio exige áreas, mantenemos este check:
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

                    // Filtrado en cliente por área (según tu lógica original)
                    final incidenciasFiltradas = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final area = data['area'] ?? '';
                      return areas.contains(area);
                    }).toList();

                    if (incidenciasFiltradas.isEmpty) {
                      return _mensajeVacio('No hay incidencias activas en tus áreas.');
                    }

                    // Agrupar por área
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
                            // 🏷️ Cabecera del Área
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
                            
                            // 📄 Lista de tarjetas
                            ...incidencias.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _construirTarjetaIncidencia(context, doc.id, data);
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

  // ⭐ Widget de Tarjeta Mejorada
  Widget _construirTarjetaIncidencia(BuildContext context, String id, Map<String, dynamic> data) {
    final equipo = data['nombre_equipo'] ?? 'Equipo desconocido';
    final descripcion = data['descripcion'] ?? 'Sin descripción';
    final estado = data['estado'] ?? 'Pendiente';
    final fecha = data['fecha_reporte'] != null
        ? formatearFecha(data['fecha_reporte'] as Timestamp)
        : 'Sin fecha';
    final colorEstado = colorPorEstado(estado);

    // Imagen
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
          onTap: () => _mostrarDetalleBottomSheet(context, id, data, urlImagen),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🖼️ Miniatura de imagen
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
                
                // 📝 Info
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
                          // Fecha pequeña
                          Text(
                            fecha.split(' ')[0], // Solo fecha, sin hora para ahorrar espacio
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                          // Chip de estado
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

  // ⭐ Panel Inferior (BottomSheet) Moderno
  void _mostrarDetalleBottomSheet(BuildContext context, String id, Map<String, dynamic> data, String? urlImagen) {
    final estado = data['estado'] ?? 'Desconocido';
    final esResuelto = estado.toString().toLowerCase() == 'resuelto';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ➖ Barra de arrastre
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

                  // 🖼️ Imagen Grande
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

                  // 🏷️ Título
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

                  // 🔘 Botón de Acción
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