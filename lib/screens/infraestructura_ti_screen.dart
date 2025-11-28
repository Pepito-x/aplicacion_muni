import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'equipos_por_area_screen.dart';
import 'admin_home.dart'; // 👈 IMPORTANTE: Importa tu Home de Admin

class InfraestructuraTIScreen extends StatelessWidget {
  const InfraestructuraTIScreen({super.key});

  static const Color verdeBandera = Color(0xFF006400);

  // 🔄 Navegación segura al AdminHome
  void _irAlHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminHome()),
      (route) => false,
    );
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
            onPressed: () => _irAlHome(context), // 2. Flecha de regreso
          ),
          title: const Text(
            'Infraestructura TI',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('areas').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: verdeBandera));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            final areas = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: areas.length,
              itemBuilder: (context, index) {
                final doc = areas[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildAreaCard(context, doc.id, data);
              },
            );
          },
        ),
      ),
    );
  }

  // ⭐ Tarjeta de Área Mejorada
  Widget _buildAreaCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final nombre = data['nombre'] ?? 'Sin nombre';
    
    // Lógica robusta para responsables (Lista o String)
    List<String> listaResponsables = [];
    if (data['responsables'] is List) {
      listaResponsables = List<String>.from(data['responsables']);
    } else if (data['responsable'] is String) { // Soporte para campo antiguo
      listaResponsables = [data['responsable']];
    }
    
    final textoResponsables = listaResponsables.isNotEmpty 
        ? listaResponsables.join(', ') 
        : 'Sin asignar';

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
                builder: (_) => EquiposPorAreaScreen(
                  idArea: docId,
                  nombreArea: nombre,
                ),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Franja lateral verde
                Container(
                  width: 6,
                  decoration: const BoxDecoration(
                    color: verdeBandera,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: verdeBandera.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.domain, color: verdeBandera, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                nombre,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.people_outline, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Responsables: $textoResponsables",
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No hay áreas registradas.',
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