import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetallesEquipoScreen extends StatelessWidget {
  final Map<String, dynamic> equipoData;

  const DetallesEquipoScreen({super.key, required this.equipoData});

  static const Color verdeBandera = Color(0xFF006400);

  // 🔹 Helper para formatear fecha
  String _formatearFecha(dynamic fecha) {
    if (fecha is Timestamp) {
      final d = fecha.toDate();
      return "${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
    }
    return "Fecha no disponible";
  }

  @override
  Widget build(BuildContext context) {
    final nombre = equipoData['nombre'] ?? 'Sin nombre';
    final serie = equipoData['numero_serie'] ?? 'N/A';
    final area = equipoData['area_nombre'] ?? 'Sin área asignada';
    final descripcion = equipoData['descripcion'] ?? 'Sin descripción';
    final idEquipo = equipoData['id_equipo'] ?? 'N/A';
    final estado = equipoData['estado'] ?? 'Operativo'; // Asumiendo que existe, si no default

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: verdeBandera,
        centerTitle: true,
        elevation: 0,
        // 🔙 Flecha de regreso
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ficha del Equipo',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── TARJETA DE CABECERA ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: verdeBandera.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.computer, size: 50, color: verdeBandera),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      estado,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // ─── DETALLES TÉCNICOS ────────────────────────────────────────
            _buildSectionTitle("Información Técnica"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.qr_code, "Número de Serie", serie),
                  const Divider(height: 24),
                  _buildDetailRow(Icons.fingerprint, "ID Interno", idEquipo),
                  const Divider(height: 24),
                  _buildDetailRow(Icons.description_outlined, "Descripción", descripcion),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── UBICACIÓN Y REGISTRO ─────────────────────────────────────
            _buildSectionTitle("Ubicación y Registro"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.location_on_outlined, "Área Asignada", area),
                  const Divider(height: 24),
                  _buildDetailRow(
                    Icons.calendar_today, 
                    "Fecha de Registro", 
                    _formatearFecha(equipoData['fecha_registro'])
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: verdeBandera.withOpacity(0.7)),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}