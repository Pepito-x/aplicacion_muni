import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class RegistrarEquipoScreen extends StatefulWidget {
  const RegistrarEquipoScreen({super.key});

  @override
  State<RegistrarEquipoScreen> createState() => _RegistrarEquipoScreenState();
}

class _RegistrarEquipoScreenState extends State<RegistrarEquipoScreen> {
  final _formKey = GlobalKey<FormState>();
  final nombreController = TextEditingController();
  final serieController = TextEditingController();
  final descripcionController = TextEditingController();

  String? areaSeleccionadaId;
  String? areaSeleccionadaNombre;
  bool loading = false;
  
  // Constante de color
  static const Color verdeBandera = Color(0xFF006400);

  Future<void> registrarEquipo() async {
    if (!_formKey.currentState!.validate() || areaSeleccionadaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Selecciona un área antes de continuar')
          ]),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final uuid = const Uuid();
      final idUnico = uuid.v4();

      final equipoData = {
        'id_equipo': idUnico,
        'nombre': nombreController.text.trim(),
        'numero_serie': serieController.text.trim(),
        'id_area': areaSeleccionadaId,
        'area_nombre': areaSeleccionadaNombre,
        'descripcion': descripcionController.text.trim(),
        'fecha_registro': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('equipos').doc(idUnico).set(equipoData);

      if (!mounted) return;

      // Mostrar el QR en un diálogo bonito en lugar de abajo
      _mostrarDialogoExito(idUnico, nombreController.text.trim());

      // Limpiar formulario
      nombreController.clear();
      serieController.clear();
      descripcionController.clear();
      setState(() {
        areaSeleccionadaId = null;
        areaSeleccionadaNombre = null;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al registrar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // 🔹 Función para mostrar el resultado con estilo (CORREGIDA)
  void _mostrarDialogoExito(String codigo, String nombreEquipo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(20),
          // ScrollView es importante por si la pantalla es muy pequeña
          content: SingleChildScrollView( 
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: verdeBandera, size: 60),
                const SizedBox(height: 10),
                const Text(
                  "¡Registro Exitoso!",
                  style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  nombreEquipo, 
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // 🔧 SOLUCIÓN: SizedBox para forzar un tamaño exacto
                SizedBox(
                  height: 200, 
                  width: 200,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    // Center es vital para que el QR no intente estirarse
                    child: Center( 
                      child: QrImageView(
                        data: codigo,
                        version: QrVersions.auto,
                        size: 180, // El tamaño interno del dibujo
                        gapless: false,
                        // padding: const EdgeInsets.all(0), // A veces ayuda quitar el padding interno
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                Text(
                  "ID: ${codigo.substring(0, 8)}...", 
                  style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar", style: TextStyle(color: verdeBandera, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
  // 🔹 Widget auxiliar para inputs
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: verdeBandera),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: verdeBandera, width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.grey[600], fontFamily: 'Montserrat'),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), 
      
      // 🔹 APP BAR MODIFICADO (Estilo AreasAsignadasScreen)
      appBar: AppBar(
        backgroundColor: verdeBandera,
        centerTitle: true,
        elevation: 0,
        // Flecha blanca explícita
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nuevo Equipo',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700, // Negrita fuerte
            color: Colors.white,         // Blanco puro
            fontSize: 20,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado visual
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: verdeBandera.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.devices_other, size: 40, color: verdeBandera),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Complete la información',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Montserrat'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // CAMPO NOMBRE
              TextFormField(
                controller: nombreController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration('Nombre del equipo', Icons.computer),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 15),

              // CAMPO SERIE
              TextFormField(
                controller: serieController,
                decoration: _inputDecoration('Número de serie', Icons.qr_code),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 15),

              // DROPDOWN ÁREAS
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('areas').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: LinearProgressIndicator(color: verdeBandera));
                  }
                  
                  final areas = snapshot.data!.docs;
                  
                  return DropdownButtonFormField<String>(
                    decoration: _inputDecoration('Área asignada', Icons.location_on),
                    value: areaSeleccionadaId,
                    icon: const Icon(Icons.keyboard_arrow_down, color: verdeBandera),
                    dropdownColor: Colors.white,
                    items: areas.map((area) {
                      return DropdownMenuItem<String>(
                        value: area.id,
                        child: Text(
                          area['nombre'],
                          style: const TextStyle(fontFamily: 'Montserrat'),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        areaSeleccionadaId = value;
                        areaSeleccionadaNombre = areas.firstWhere((a) => a.id == value)['nombre'].toString();
                      });
                    },
                    validator: (value) => value == null ? 'Seleccione un área' : null,
                  );
                },
              ),
              const SizedBox(height: 15),

              // CAMPO DESCRIPCIÓN
              TextFormField(
                controller: descripcionController,
                maxLines: 3,
                decoration: _inputDecoration('Descripción o estado', Icons.description_outlined).copyWith(
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 30),

              // BOTÓN DE ACCIÓN
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : registrarEquipo,
                  icon: loading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    loading ? ' Procesando...' : 'Registrar Equipo',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdeBandera,
                    elevation: 5,
                    shadowColor: verdeBandera.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}