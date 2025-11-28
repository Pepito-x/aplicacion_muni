import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_home.dart'; // 👈 IMPORTANTE: Importa tu Home de Admin

class VerIncidenciasScreen extends StatefulWidget {
  const VerIncidenciasScreen({super.key});

  @override
  State<VerIncidenciasScreen> createState() => _VerIncidenciasScreenState();
}

class _VerIncidenciasScreenState extends State<VerIncidenciasScreen> {
  // Configuración de estilo
  static const Color verdeBandera = Color(0xFF006400);

  // Filtros
  String? filtroArea;
  String? filtroEstado;
  String? filtroTecnico;
  bool _filtrosVisibles = true; // Para ocultar/mostrar la barra de filtros

  // Datos
  List<String> tecnicosDisponibles = [];
  
  static const List<String> estados = ['Pendiente', 'En proceso', 'Resuelto'];
  static const List<String> areas = [
    'informática', 'mantenimiento', 'redes', 'soporte', 'administración', 'infraestructura'
  ];

  @override
  void initState() {
    super.initState();
    _cargarTecnicos();
  }

  // 🔄 Navegación segura al AdminHome
  void _irAlHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminHome()),
      (route) => false,
    );
  }

  Future<void> _cargarTecnicos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'tecnico')
          .get();

      final List<String> nombres = snapshot.docs
          .map((doc) => doc['nombre'] as String?)
          .whereType<String>()
          .toList();

      if (mounted) setState(() => tecnicosDisponibles = nombres);
    } catch (e) {
      debugPrint('Error al cargar técnicos: $e');
    }
  }

  void _limpiarFiltros() {
    setState(() {
      filtroArea = null;
      filtroEstado = null;
      filtroTecnico = null;
    });
  }

  bool _coincideConFiltros(Map<String, dynamic> incidencia) {
    final area = incidencia['area'] as String?;
    final estado = incidencia['estado'] as String?;
    
    // Normalizar técnicos
    List<String> tecnicosAsignados = [];
    if (incidencia['tecnicos_asignados'] is List) {
      tecnicosAsignados = List<String>.from(incidencia['tecnicos_asignados']);
    } else if (incidencia['tecnico_asignado'] is String) {
      tecnicosAsignados = [incidencia['tecnico_asignado']];
    }

    if (filtroArea != null && area != filtroArea) return false;
    if (filtroEstado != null && estado != filtroEstado) return false;
    if (filtroTecnico != null && !tecnicosAsignados.contains(filtroTecnico)) return false;

    return true;
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha is Timestamp) {
      final d = fecha.toDate();
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return 'Sin fecha';
  }

  Color _obtenerColorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente': return Colors.orange.shade700;
      case 'en proceso': return Colors.blue.shade700;
      case 'resuelto': return Colors.green.shade700;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: verdeBandera,
        title: const Text(
          'Monitor de Incidencias',
          style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: _irAlHome, // 👈 Flecha para regresar
        ),
        actions: [
          IconButton(
            icon: Icon(_filtrosVisibles ? Icons.filter_list_off : Icons.filter_list, color: Colors.white),
            onPressed: () => setState(() => _filtrosVisibles = !_filtrosVisibles),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── BARRA DE FILTROS ANIMADA ─────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _filtrosVisibles ? 80 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: _filtrosVisibles 
              ? Row(
                  children: [
                    Expanded(child: _buildDropdown('Área', filtroArea, areas, (v) => filtroArea = v)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDropdown('Estado', filtroEstado, estados, (v) => filtroEstado = v)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDropdown('Técnico', filtroTecnico, tecnicosDisponibles, (v) => filtroTecnico = v)),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: verdeBandera),
                      onPressed: _limpiarFiltros,
                      tooltip: "Limpiar",
                    )
                  ],
                ) 
              : null,
          ),

          // ─── LISTA ────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidencias')
                  .orderBy('fecha_reporte', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: verdeBandera));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState('No hay incidencias registradas.');
                }

                final incidenciasFiltradas = snapshot.data!.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .where(_coincideConFiltros)
                    .toList();

                if (incidenciasFiltradas.isEmpty) {
                  return _buildEmptyState('No coinciden resultados con los filtros.');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: incidenciasFiltradas.length,
                  itemBuilder: (context, index) {
                    final data = incidenciasFiltradas[index];
                    return _buildIncidenciaCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Widget para Dropdowns compactos
  Widget _buildDropdown(String hint, String? value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) => setState(() => onChanged(v)),
        ),
      ),
    );
  }

  // 🔹 Tarjeta de Incidencia Moderna
  Widget _buildIncidenciaCard(Map<String, dynamic> data) {
    final estado = data['estado'] ?? 'Pendiente';
    final color = _obtenerColorEstado(estado);
    final area = data['area'] ?? 'General';
    final equipo = data['nombre_equipo'] ?? 'Equipo';

    // Manejo seguro de imagen
    String? imgUrl;
    if (data['imagenes'] is List && (data['imagenes'] as List).isNotEmpty) {
      imgUrl = data['imagenes'][0];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _mostrarDetalleBottomSheet(data, imgUrl),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Imagen o Icono
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50, height: 50,
                    color: color.withOpacity(0.1),
                    child: imgUrl != null 
                        ? Image.network(imgUrl, fit: BoxFit.cover)
                        : Icon(Icons.computer, color: color),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(equipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(area.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 10, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(_formatearFecha(data['fecha_reporte']), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      )
                    ],
                  ),
                ),

                // Estado Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(estado, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 BottomSheet de Detalle (Más Pro que un Alert)
  void _mostrarDetalleBottomSheet(Map<String, dynamic> data, String? imgUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  
                  if (imgUrl != null) 
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(imgUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                  
                  const SizedBox(height: 15),
                  Text(data['nombre_equipo'] ?? 'Equipo', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                  const Divider(),
                  _infoRow('Descripción', data['descripcion']),
                  _infoRow('Área', data['area']),
                  _infoRow('Estado', data['estado'], isEstado: true),
                  _infoRow('Técnico', _getTecnicosString(data)),
                  _infoRow('Fecha', _formatearFecha(data['fecha_reporte'])),
                  
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: verdeBandera),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
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

  Widget _infoRow(String label, String? val, {bool isEstado = false}) {
    Color? colorText;
    if (isEstado && val != null) colorText = _obtenerColorEstado(val);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(val ?? '---', style: TextStyle(fontSize: 15, fontWeight: isEstado ? FontWeight.bold : FontWeight.normal, color: colorText))),
        ],
      ),
    );
  }

  String _getTecnicosString(Map<String, dynamic> data) {
    if (data['tecnicos_asignados'] is List) {
      return (data['tecnicos_asignados'] as List).join(', ');
    } else if (data['tecnico_asignado'] is String) {
      return data['tecnico_asignado'];
    }
    return 'Sin asignar';
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(msg, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}