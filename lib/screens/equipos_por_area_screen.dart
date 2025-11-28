import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalles_equipo_screen.dart';

class EquiposPorAreaScreen extends StatelessWidget {
  final String idArea;
  final String nombreArea;

  const EquiposPorAreaScreen({
    super.key,
    required this.idArea,
    required this.nombreArea,
  });

  static const Color verdeBandera = Color(0xFF006400);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Fondo moderno
      appBar: AppBar(
        backgroundColor: verdeBandera,
        centerTitle: true,
        elevation: 0,
        // 🔙 Flecha de retroceso (regresa a la lista de áreas)
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'Inventario',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            Text(
              nombreArea,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('equipos')
            .where('id_area', isEqualTo: idArea)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: verdeBandera));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final equipos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: equipos.length,
            itemBuilder: (context, index) {
              final doc = equipos[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildEquipoCard(context, data);
            },
          );
        },
      ),
    );
  }

  // ⭐ Tarjeta de Equipo Mejorada
  Widget _buildEquipoCard(BuildContext context, Map<String, dynamic> data) {
    final nombre = data['nombre'] ?? 'Equipo sin nombre';
    final serie = data['numero_serie'] ?? 'S/N';
    final estado = data['estado'] ?? 'Operativo'; // Ejemplo: Operativo, En reparación

    // Determinar color según estado (opcional)
    Color colorEstado = Colors.grey;
    if (estado.toString().toLowerCase() == 'operativo') colorEstado = Colors.green;
    if (estado.toString().toLowerCase() == 'en reparación') colorEstado = Colors.orange;
    if (estado.toString().toLowerCase() == 'baja') colorEstado = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetallesEquipoScreen(
                  equipoData: data,
                ),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Franja lateral
                Container(
                  width: 5,
                  decoration: const BoxDecoration(
                    color: verdeBandera,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Icono
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: verdeBandera.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.computer, color: verdeBandera, size: 28),
                        ),
                        const SizedBox(width: 14),
                        
                        // Información
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.qr_code, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Serie: $serie",
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Chip de estado pequeño
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorEstado.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  estado,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colorEstado,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No hay equipos en esta área.',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}