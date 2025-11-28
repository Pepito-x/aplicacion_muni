import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'usuario_home.dart'; // 👈 IMPORTANTE: Importa tu Home aquí

class MisReportesScreen extends StatelessWidget {
  const MisReportesScreen({super.key});

  // 🔄 Función para ir al Home limpiando el historial
  void _irAlHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const UsuarioHome()),
      (route) => false, // Elimina todas las pantallas anteriores
    );
  }

  // 🔹 Formato bonito de fecha
  String _formatearFecha(Timestamp? fecha) {
    if (fecha == null) return 'Fecha no disponible';
    final date = fecha.toDate();
    final hora = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    final fechaStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return '$fechaStr a las $hora';
  }

  // 🔹 Colores del estado
  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente': return Colors.orange;
      case 'en proceso': return Colors.blueAccent;
      case 'resuelto': return Colors.green;
      default: return Colors.grey;
    }
  }

  // 🔹 Iconos del estado
  IconData _iconoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente': return Icons.hourglass_bottom;
      case 'en proceso': return Icons.autorenew;
      case 'resuelto': return Icons.check_circle;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    const verdeBandera = Color(0xFF006400);

    // 1. Envolvemos con PopScope para controlar el botón físico "Atrás"
    return PopScope(
      canPop: false, // Desactiva el pop automático
      onPopInvoked: (didPop) {
        if (didPop) return;
        _irAlHome(context); // Redirige al Home
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: verdeBandera,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Mis Reportes',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            // 2. Usamos la función de ir al Home en el botón de la AppBar
            onPressed: () => _irAlHome(context), 
          ),
        ),

        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('incidencias')
              .orderBy('fecha_reporte', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.data!.docs.isEmpty) return _emptyState();

            final reportes = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reportes.length,
              itemBuilder: (context, index) {
                final data = reportes[index].data() as Map<String, dynamic>;
                final estado = data['estado'] ?? 'Desconocido';
                final imagenes = List<String>.from(data['imagenes'] ?? []);

                return _cardReporte(
                  context: context,
                  data: data,
                  estado: estado,
                  imagen: imagenes.isNotEmpty ? imagenes.first : null,
                  colorEstado: _colorEstado(estado),
                  iconEstado: _iconoEstado(estado),
                  index: index,
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ⭐ Diseño del estado vacío
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 90, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "No tienes reportes aún",
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Tus incidencias aparecerán aquí.",
            style: TextStyle(color: Colors.grey.shade500),
          )
        ],
      ),
    );
  }

  // ⭐ Card moderna y elegante
  Widget _cardReporte({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String estado,
    required Color colorEstado,
    required IconData iconEstado,
    required int index,
    String? imagen,
  }) {
    return AnimatedOpacity(
      opacity: 1,
      duration: Duration(milliseconds: 400 + index * 80),
      child: Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _mostrarDetalle(context, data, colorEstado, estado),
          child: Row(
            children: [
              // 📌 Imagen
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                child: Container(
                  width: 110,
                  height: double.infinity,
                  color: Colors.grey.shade200,
                  child: imagen != null
                      ? Image.network(imagen, fit: BoxFit.cover)
                      : const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                ),
              ),

              // 📌 Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['nombre_equipo'] ?? 'Equipo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['descripcion'] ?? 'Sin descripción',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Área: ${data['area']}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorEstado.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(iconEstado, color: colorEstado, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  estado,
                                  style: TextStyle(
                                    color: colorEstado,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ Modal moderno
  void _mostrarDetalle(
    BuildContext context,
    Map<String, dynamic> data,
    Color colorEstado,
    String estado,
  ) {
    final imagenes = List<String>.from(data['imagenes'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  data['nombre_equipo'] ?? 'Incidencia',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (imagenes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: PageView(
                      children: imagenes
                          .map((img) => ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(img, fit: BoxFit.cover),
                              ))
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _rowDetalle("Área", data['area']),
                _rowDetalle("Descripción", data['descripcion']),
                _rowDetalle("Estado", estado),
                _rowDetalle("Fecha", _formatearFecha(data['fecha_reporte'])),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorEstado,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      "Cerrar",
                      style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rowDetalle(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
          )
        ],
      ),
    );
  }
}