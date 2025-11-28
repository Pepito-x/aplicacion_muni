import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IncidenciasAsignadasScreen extends StatelessWidget {
  const IncidenciasAsignadasScreen({super.key});

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
        .update({
          // Aseguramos que sea "Resuelto" con mayúscula inicial
          // para que coincida con tu Cloud Function (si la ajustas)
          'estado': 'Resuelto' 
        });
  }
  String formatearFecha(Timestamp fecha) {
    final d = fecha.toDate();
    return "${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
  }

  Color colorPorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'en proceso':
        return Colors.blue;
      case 'resuelto':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    const verdeBandera = Color(0xFF006400);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: verdeBandera,
        centerTitle: true,
        title: const Text(
          'Mis Incidencias (por Áreas Activas)',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: FutureBuilder<String?>(
        future: obtenerNombreTecnico(),
        builder: (context, tecnicoSnapshot) {
          if (tecnicoSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final nombreTecnico = tecnicoSnapshot.data;
          if (nombreTecnico == null) {
            return const Center(
              child: Text(
                'No se pudo identificar al técnico.',
                style: TextStyle(fontFamily: 'Montserrat', fontSize: 16),
              ),
            );
          }

          return FutureBuilder<List<String>>(
            future: obtenerAreasAsignadas(nombreTecnico),
            builder: (context, areasSnapshot) {
              if (areasSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final areas = areasSnapshot.data ?? [];

              if (areas.isEmpty) {
                return const Center(
                  child: Text(
                    'No tienes áreas asignadas actualmente.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('incidencias')
                    .where(
                      Filter.or(
                        Filter('tecnico_asignado', isEqualTo: nombreTecnico),
                        Filter('tecnicos_asignados',
                            arrayContains: nombreTecnico),
                      ),
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No tienes incidencias asignadas actualmente.',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final incidenciasFiltradas = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final area = data['area'] ?? '';
                    return areas.contains(area);
                  }).toList();

                  if (incidenciasFiltradas.isEmpty) {
                    return const Center(
                      child: Text(
                        'No tienes incidencias activas en tus áreas asignadas.',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final Map<String, List<QueryDocumentSnapshot>>
                      incidenciasPorArea = {};
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
                          Container(
                            margin: const EdgeInsets.only(bottom: 8, top: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: verdeBandera.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.business,
                                    color: verdeBandera),
                                const SizedBox(width: 8),
                                Text(
                                  area,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                    color: verdeBandera,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...incidencias.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final id = doc.id;
                            final equipo =
                                data['nombre_equipo'] ?? 'Equipo desconocido';
                            final descripcion =
                                data['descripcion'] ?? 'Sin descripción';
                            final estado = data['estado'] ?? 'Sin estado';
                            final fecha = data['fecha_reporte'] != null
                                ? formatearFecha(
                                    data['fecha_reporte'] as Timestamp)
                                : 'Sin fecha';
                            final colorEstado = colorPorEstado(estado);

                            // 🔹 Extraer imágenes de forma segura
                            final imagenesList = data['imagenes'];
                            String? urlImagen;
                            if (imagenesList is List && imagenesList.isNotEmpty) {
                              final first = imagenesList[0];
                              if (first is String) {
                                urlImagen = first.trim();
                              }
                            }

                            // Verificar que sea una URL válida
                            bool isValidUrl(String? url) {
                              if (url == null || url.isEmpty) return false;
                              return Uri.tryParse(url)?.hasAbsolutePath == true;
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: isValidUrl(urlImagen)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          urlImagen!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                              stackTrace) {
                                            return const Icon(
                                              Icons.image,
                                              color: Colors.grey,
                                              size: 24,
                                            );
                                          },
                                        ),
                                      )
                                    : const Icon(Icons.build_circle,
                                        color: verdeBandera),
                                title: Text(
                                  equipo,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Descripción: $descripcion',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontFamily: 'Montserrat'),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Fecha: $fecha',
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.circle,
                                        color: colorEstado, size: 12),
                                    const SizedBox(height: 4),
                                    Text(
                                      estado,
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.bold,
                                        color: colorEstado,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) {
                                      return AlertDialog(
                                        title: Text(equipo),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (isValidUrl(urlImagen))
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 12),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color:
                                                          Colors.grey.shade300),
                                                ),
                                                child: SizedBox(
                                                  width: MediaQuery.sizeOf(
                                                              context)
                                                          .width *
                                                      0.9,
                                                  height: 150,
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: FittedBox(
                                                      fit: BoxFit.cover,
                                                      child: Image.network(
                                                        urlImagen!,
                                                        loadingBuilder: (context,
                                                            child,
                                                            loadingProgress) {
                                                          if (loadingProgress ==
                                                              null)
                                                            return child;
                                                          return Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                              value: loadingProgress
                                                                          .expectedTotalBytes !=
                                                                      null
                                                                  ? loadingProgress
                                                                          .cumulativeBytesLoaded /
                                                                      loadingProgress
                                                                          .expectedTotalBytes!
                                                                  : null,
                                                            ),
                                                          );
                                                        },
                                                        errorBuilder: (context,
                                                            error, stackTrace) {
                                                          return const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            size: 60,
                                                            color: Colors.grey,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Text('Área: $area'),
                                            Text('Descripción: $descripcion'),
                                            Text('Estado: $estado'),
                                            Text('Fecha: $fecha'),
                                          ],
                                        ),
                                        actions: [
                                          if (estado.toLowerCase() != 'resuelto')
                                            ElevatedButton(
                                              onPressed: () async {
                                                await marcarComoResuelta(id);
                                                Navigator.pop(context);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      verdeBandera),
                                              child: const Text(
                                                'Marcar como Resuelta',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cerrar'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            );
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
    );
  }
}