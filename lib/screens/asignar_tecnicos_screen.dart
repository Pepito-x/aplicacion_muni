import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AsignarTecnicosScreen extends StatefulWidget {
  const AsignarTecnicosScreen({super.key});

  @override
  State<AsignarTecnicosScreen> createState() => _AsignarTecnicosScreenState();
}

class _AsignarTecnicosScreenState extends State<AsignarTecnicosScreen> {
  String? tecnicoSeleccionado;
  Map<String, List<String>> mapaResponsables = {}; 

  @override
  void initState() {
    super.initState();
    cargarResponsables();
  }

  Future<void> cargarResponsables() async {
    final snapshot = await FirebaseFirestore.instance.collection('areas').get();
    setState(() {
      mapaResponsables = {
        for (var doc in snapshot.docs)
          doc['nombre']: doc.data().toString().contains('responsables')
              ? List<String>.from(doc['responsables'])
              : [doc['responsable'] ?? 'Sin técnico asignado']
      };
    });
  }

  // 🔹 CORRECCIÓN IMPORTANTE AQUÍ
  Future<void> asignarIncidencia(String idIncidencia, String areaIncidencia) async {
    if (tecnicoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un técnico antes de asignar')),
      );
      return;
    }

    final responsables = mapaResponsables[areaIncidencia] ?? [];

    // Validaciones de área (Tu lógica original)
    if (responsables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ No hay técnicos para el área "$areaIncidencia".')),
      );
      return;
    }

    if (!responsables.contains(tecnicoSeleccionado)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ El técnico no pertenece al área "$areaIncidencia".')),
      );
      return;
    }

    try {
      // 1. BUSCAR EL UID DEL TÉCNICO
      // Tu Dropdown tiene el Nombre, pero la notificación necesita el UID.
      final queryTecnico = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'tecnico')
          .where('nombre', isEqualTo: tecnicoSeleccionado)
          .limit(1)
          .get();

      if (queryTecnico.docs.isEmpty) {
        throw "No se encontró el UID del técnico seleccionado.";
      }

      final uidTecnico = queryTecnico.docs.first.id; // Este es el ID que activa la Push

      // 2. ACTUALIZAR FIREBASE
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
        // Campo VISUAL (Lista de nombres para mostrar en la app)
        'tecnicos_asignados': tecnicosAsignados, 
        
        // 🔥 CAMPO CRÍTICO PARA NOTIFICACIONES 🔥
        // Esto es lo que la Cloud Function está escuchando: 'tecnicoId'
        'tecnicoId': uidTecnico, 
        
        'estado': 'En proceso',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Asignado a $tecnicoSeleccionado y notificado.')),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const verdeBandera = Color(0xFF006400);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: verdeBandera,
        title: const Text(
          'Asignar Técnicos',
          style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleccionar Técnico:',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            // Dropdown de técnicos
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('usuarios')
                  .where('rol', isEqualTo: 'tecnico')
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final tecnicos = snapshot.data!.docs;
                if (tecnicos.isEmpty) return const Text('No hay técnicos registrados.');

                // Filtramos nombres únicos para evitar duplicados en el dropdown
                final tecnicosUnicos = tecnicos.map((d) => d['nombre'] as String).toSet().toList();

                return DropdownButtonFormField<String>(
                  value: tecnicoSeleccionado,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    hintText: 'Seleccione un técnico',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: tecnicosUnicos.map((nombre) {
                    return DropdownMenuItem<String>(
                      value: nombre,
                      child: Text(nombre, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => tecnicoSeleccionado = value),
                );
              },
            ),

            const SizedBox(height: 25),
            const Text(
              'Incidencias Pendientes:',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('incidencias')
                    .where('estado', isEqualTo: 'Pendiente')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No hay incidencias pendientes.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  final incidencias = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: incidencias.length,
                    itemBuilder: (context, index) {
                      final data = incidencias[index].data() as Map<String, dynamic>;
                      final idIncidencia = incidencias[index].id;
                      final area = data['area'] ?? 'Sin área';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: verdeBandera.withOpacity(0.1),
                            child: const Icon(Icons.build, color: verdeBandera),
                          ),
                          title: Text(
                            data['nombre_equipo'] ?? 'Equipo',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Área: $area'),
                              Text(
                                data['descripcion'] ?? '',
                                maxLines: 2, 
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => asignarIncidencia(idIncidencia, area),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: verdeBandera,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: const Size(60, 36),
                            ),
                            child: const Text('Asignar'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}