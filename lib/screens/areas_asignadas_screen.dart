import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tecnico_home.dart'; // 👈 IMPORTANTE: Importa tu Home de técnico

class AreasAsignadasScreen extends StatelessWidget {
  const AreasAsignadasScreen({super.key});

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
        backgroundColor: Colors.grey.shade100, // Fondo suave
        appBar: AppBar(
          backgroundColor: verdeBandera,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => _irAlHome(context), // 2. Botón AppBar
          ),
          title: const Text(
            'Áreas Asignadas',
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
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: verdeBandera));
            }

            final nombreTecnico = snapshot.data;
            if (nombreTecnico == null) {
              return _mensajeEstado(
                icon: Icons.error_outline,
                mensaje: 'No se pudo identificar al técnico.',
              );
            }

            // 🔹 Consultar áreas
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('areas')
                  .where(
                    Filter.or(
                      Filter('responsables', arrayContains: nombreTecnico),
                      Filter('responsable', isEqualTo: nombreTecnico),
                    ),
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: verdeBandera));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _mensajeEstado(
                    icon: Icons.domain_disabled,
                    mensaje: 'No tienes áreas asignadas actualmente.',
                  );
                }

                final areas = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: areas.length,
                  itemBuilder: (context, index) {
                    final area = areas[index].data() as Map<String, dynamic>;
                    return _construirTarjetaArea(area);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ⭐ Tarjeta de Área Mejorada
  Widget _construirTarjetaArea(Map<String, dynamic> area) {
    final nombre = area['nombre'] ?? 'Sin nombre';
    
    // Formatear fecha
    String fechaStr = 'Sin fecha';
    if (area['fecha_registro'] != null) {
      final date = (area['fecha_registro'] as Timestamp).toDate();
      fechaStr = '${date.day}/${date.month}/${date.year}';
    }

    // Manejar responsables
    final responsables = area.containsKey('responsables')
        ? List<String>.from(area['responsables'])
        : [area['responsable'] ?? 'No asignado'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 🟩 Franja decorativa lateral
              Container(
                width: 6,
                color: verdeBandera,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🏢 Título e Icono
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: verdeBandera.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.business, color: verdeBandera, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              nombre,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // 📅 Fecha
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text(
                            "Registro: $fechaStr",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),

                      // 👷 Técnicos
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.group_outlined, size: 18, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Responsables:",
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: responsables.map((resp) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        resp,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade800,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ Widget para estados vacíos o errores
  Widget _mensajeEstado({required IconData icon, required String mensaje}) {
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