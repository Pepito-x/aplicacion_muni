import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tecnico_home.dart'; // 👈 IMPORTANTE: Importa tu Home de técnico

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  static const Color verdeBandera = Color(0xFF006400);

  // 🔄 Función para ir al Home limpiando el historial
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

  String formatearFecha(Timestamp fecha) {
    final d = fecha.toDate();
    return "${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
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
        backgroundColor: Colors.grey.shade100, // Fondo moderno
        appBar: AppBar(
          backgroundColor: verdeBandera,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => _irAlHome(context), // 2. Botón AppBar
          ),
          title: const Text(
            'Historial Resuelto',
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
              return _mensajeVacio(Icons.error_outline, 'No se pudo identificar al técnico.');
            }

            // 🔹 Obtener incidencias resueltas
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidencias')
                  .where(
                    Filter.or(
                      Filter('tecnico_asignado', isEqualTo: nombreTecnico),
                      Filter('tecnicos_asignados', arrayContains: nombreTecnico),
                    ),
                  )
                  .where('estado', isEqualTo: 'Resuelto') // Solo resueltas
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: verdeBandera));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _mensajeVacio(
                    Icons.history,
                    'Aún no tienes incidencias resueltas en tu historial.',
                  );
                }

                final incidencias = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: incidencias.length,
                  itemBuilder: (context, index) {
                    final doc = incidencias[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _construirTarjetaHistorial(context, data);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ⭐ Tarjeta de Historial Mejorada
  Widget _construirTarjetaHistorial(BuildContext context, Map<String, dynamic> data) {
    final equipo = data['nombre_equipo'] ?? 'Equipo desconocido';
    final descripcion = data['descripcion'] ?? 'Sin descripción';
    final area = data['area'] ?? 'Sin área';
    final fecha = data['fecha_reporte'] != null
        ? formatearFecha(data['fecha_reporte'] as Timestamp)
        : 'Sin fecha';

    // Imagen
    String? urlImagen;
    final imagenesList = data['imagenes'];
    if (imagenesList is List && imagenesList.isNotEmpty && imagenesList[0] is String) {
      urlImagen = imagenesList[0];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          onTap: () => _mostrarDetalleBottomSheet(context, data, urlImagen),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 🖼️ Miniatura o Icono de Check
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60, height: 60,
                    color: verdeBandera.withOpacity(0.1),
                    child: urlImagen != null && urlImagen.isNotEmpty
                        ? Image.network(urlImagen, fit: BoxFit.cover)
                        : const Icon(Icons.check_circle, color: verdeBandera, size: 30),
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
                          color: Colors.black87,
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
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            fecha.split(' ')[0], // Solo fecha
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              area,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                
                // Flechita indicativa
                Icon(Icons.chevron_right, color: Colors.grey.shade300),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ⭐ Detalle en Panel Inferior
  void _mostrarDetalleBottomSheet(BuildContext context, Map<String, dynamic> data, String? urlImagen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(20),
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
                      height: 200, width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(urlImagen),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: verdeBandera),
                      const SizedBox(width: 8),
                      const Text(
                        "Incidencia Resuelta",
                        style: TextStyle(
                          color: verdeBandera,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Text(
                    data['nombre_equipo'] ?? 'Equipo',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  _infoFila("Descripción", data['descripcion']),
                  _infoFila("Área", data['area']),
                  _infoFila("Fecha Reporte", 
                      data['fecha_reporte'] != null 
                      ? formatearFecha(data['fecha_reporte'] as Timestamp) 
                      : 'N/A'),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verdeBandera,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Cerrar Detalle",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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

  Widget _infoFila(String label, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(valor ?? '---', style: const TextStyle(fontSize: 16, height: 1.3)),
          const Divider(),
        ],
      ),
    );
  }

  Widget _mensajeVacio(IconData icon, String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade300),
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
}