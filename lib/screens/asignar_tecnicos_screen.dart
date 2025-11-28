import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_home.dart'; // 👈 IMPORTANTE: Importa tu Home de Admin

class AsignarTecnicosScreen extends StatefulWidget {
  const AsignarTecnicosScreen({super.key});

  @override
  State<AsignarTecnicosScreen> createState() => _AsignarTecnicosScreenState();
}

class _AsignarTecnicosScreenState extends State<AsignarTecnicosScreen> {
  // Configuración de estilo
  static const Color verdeBandera = Color(0xFF006400);
  
  String? tecnicoSeleccionado;
  Map<String, List<String>> mapaResponsables = {}; 

  @override
  void initState() {
    super.initState();
    cargarResponsables();
  }

  // 🔄 Navegación segura al AdminHome
  void _irAlHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminHome()),
      (route) => false,
    );
  }

  Future<void> cargarResponsables() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('areas').get();
      if (mounted) {
        setState(() {
          mapaResponsables = {
            for (var doc in snapshot.docs)
              doc['nombre']: doc.data().toString().contains('responsables')
                  ? List<String>.from(doc['responsables'])
                  : [doc['responsable'] ?? 'Sin técnico asignado']
          };
        });
      }
    } catch (e) {
      debugPrint("Error cargando responsables: $e");
    }
  }

  void _mostrarFeedback(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(esError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? Colors.red.shade700 : verdeBandera,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> asignarIncidencia(String idIncidencia, String areaIncidencia) async {
    if (tecnicoSeleccionado == null) {
      _mostrarFeedback('Seleccione un técnico antes de asignar', esError: true);
      return;
    }

    final responsables = mapaResponsables[areaIncidencia] ?? [];

    if (responsables.isEmpty) {
      _mostrarFeedback('⚠️ No hay técnicos registrados para el área "$areaIncidencia".', esError: true);
      return;
    }

    if (!responsables.contains(tecnicoSeleccionado)) {
      _mostrarFeedback('❌ El técnico no pertenece al área "$areaIncidencia".', esError: true);
      return;
    }

    try {
      // 1. Obtener UID para notificación
      final queryTecnico = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'tecnico')
          .where('nombre', isEqualTo: tecnicoSeleccionado)
          .limit(1)
          .get();

      if (queryTecnico.docs.isEmpty) {
        throw "No se encontró el UID del técnico seleccionado.";
      }

      final uidTecnico = queryTecnico.docs.first.id;

      // 2. Actualizar Incidencia
      final doc = FirebaseFirestore.instance.collection('incidencias').doc(idIncidencia);
      final snapshot = await doc.get();
      final data = snapshot.data() ?? {};
      
      List<String> tecnicosAsignados = [];
      if (data.containsKey('tecnicos_asignados')) {
        tecnicosAsignados = List<String>.from(data['tecnicos_asignados']);
      }

      if (!tecnicosAsignados.contains(tecnicoSeleccionado)) {
        tecnicosAsignados.add(tecnicoSeleccionado!);
      }

      await doc.update({
        'tecnicos_asignados': tecnicosAsignados, 
        'tecnicoId': uidTecnico, 
        'estado': 'En proceso',
      });

      _mostrarFeedback('✅ Asignado a $tecnicoSeleccionado correctamente.');
      
    } catch (e) {
      _mostrarFeedback('❌ Error: $e', esError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: verdeBandera,
        title: const Text(
          'Asignación de Técnicos',
          style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: _irAlHome, // 👈 Flecha de regreso
        ),
      ),
      body: Column(
        children: [
          // ─── SECCIÓN DE SELECCIÓN DE TÉCNICO ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccionar Técnico Responsable',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: verdeBandera,
                  ),
                ),
                const SizedBox(height: 12),
                
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('usuarios')
                      .where('rol', isEqualTo: 'tecnico')
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator(color: verdeBandera);
                    
                    final tecnicos = snapshot.data!.docs;
                    if (tecnicos.isEmpty) return const Text('No hay técnicos disponibles.');

                    final tecnicosUnicos = tecnicos.map((d) => d['nombre'] as String).toSet().toList();

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: tecnicoSeleccionado,
                          isExpanded: true,
                          hint: const Text('Toque para seleccionar...'),
                          icon: const Icon(Icons.person_search, color: verdeBandera),
                          items: tecnicosUnicos.map((nombre) {
                            return DropdownMenuItem<String>(
                              value: nombre,
                              child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w500)),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => tecnicoSeleccionado = value),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // ─── TÍTULO DE SECCIÓN ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  "Incidencias Pendientes",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),

          // ─── LISTA DE INCIDENCIAS ───────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidencias')
                  .where('estado', isEqualTo: 'Pendiente')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: verdeBandera));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final incidencias = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: incidencias.length,
                  itemBuilder: (context, index) {
                    final data = incidencias[index].data() as Map<String, dynamic>;
                    final idIncidencia = incidencias[index].id;
                    return _buildIncidenciaCard(data, idIncidencia);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Tarjeta de Incidencia Estilizada
  Widget _buildIncidenciaCard(Map<String, dynamic> data, String idIncidencia) {
    final area = data['area'] ?? 'Sin área';
    final equipo = data['nombre_equipo'] ?? 'Equipo';
    final descripcion = data['descripcion'] ?? 'Sin descripción';
    
    // Manejo de imagen
    String? imgUrl;
    if (data['imagenes'] is List && (data['imagenes'] as List).isNotEmpty) {
      imgUrl = data['imagenes'][0];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen o Icono
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 50, height: 50,
                    color: verdeBandera.withOpacity(0.1),
                    child: imgUrl != null 
                        ? Image.network(imgUrl, fit: BoxFit.cover)
                        : const Icon(Icons.build_circle, color: verdeBandera, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Info Principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(equipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "AREA: $area",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        descripcion,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Botón de Acción
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => asignarIncidencia(idIncidencia, area),
                icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.white),
                label: const Text(
                  "ASIGNAR AL TÉCNICO",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: verdeBandera,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '¡Todo al día!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          const Text(
            'No hay incidencias pendientes.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}