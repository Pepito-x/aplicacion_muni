import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'usuario_home.dart'; // 👈 Asegúrate de que este import sea correcto para volver al Home

// 🔹 Configuración de Cloudinary
const String cloudName = 'dgzlpxtoq';
const String uploadPreset = 'municipal_unsigned';

class RegistrarIncidenciaScreen extends StatefulWidget {
  final Map<String, dynamic> equipoData;
  final String idEquipo; // ID del documento en Firebase

  const RegistrarIncidenciaScreen({
    super.key,
    required this.equipoData,
    this.idEquipo = '',
  });

  @override
  State<RegistrarIncidenciaScreen> createState() => _RegistrarIncidenciaScreenState();
}

class _RegistrarIncidenciaScreenState extends State<RegistrarIncidenciaScreen> {
  // Controladores y Variables de Estado
  final TextEditingController _descripcionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  bool _enviando = false;
  List<File> _imagenes = []; // Lista de fotos seleccionadas
  
  static const Color verdePrincipal = Color(0xFF006400);

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  // 🔄 Función para regresar al Home limpiando historial
  void _irAlHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const UsuarioHome()),
      (route) => false,
    );
  }

  // 📸 Lógica: Tomar Foto (Cámara)
  Future<void> _tomarFoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxHeight: 1080,
        maxWidth: 1080,
      );
      if (picked != null) {
        setState(() => _imagenes.add(File(picked.path)));
      }
    } catch (e) {
      _mostrarError('Error al acceder a la cámara: $e');
    }
  }

  // 🖼️ Lógica: Seleccionar de Galería
  Future<void> _seleccionarGaleria() async {
    try {
      final pickedList = await _picker.pickMultiImage(
        imageQuality: 75,
        maxHeight: 1080,
        maxWidth: 1080,
      );
      if (pickedList.isNotEmpty) {
        setState(() {
          _imagenes.addAll(pickedList.map((e) => File(e.path)));
        });
      }
    } catch (e) {
      _mostrarError('Error al seleccionar imágenes: $e');
    }
  }

  // 🗑️ Eliminar foto de la lista local
  void _eliminarImagen(File imagen) {
    setState(() => _imagenes.remove(imagen));
  }

  // ☁️ Subir una sola imagen a Cloudinary
  Future<String?> _subirImagenACloudinary(File imagen) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imagen.path));
      
      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = json.decode(resBody);
        return data['secure_url'] as String?;
      } else {
        debugPrint('Error Cloudinary: ${response.statusCode}, $resBody');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción subiendo imagen: $e');
      return null;
    }
  }

  // 🚀 Lógica Principal: Enviar Reporte
  Future<void> _enviarReporte() async {
    if (_descripcionController.text.trim().isEmpty) {
      _mostrarAlertaValidacion();
      return;
    }

    setState(() => _enviando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // 1. Subir imágenes (si hay)
      List<String> urlsCloudinary = [];
      for (final img in _imagenes) {
        final url = await _subirImagenACloudinary(img);
        if (url != null) urlsCloudinary.add(url);
      }

      // 2. Preparar datos
      // Usamos widget.idEquipo si viene, si no buscamos en el mapa, si no vacío
      final idEq = widget.idEquipo.isNotEmpty 
          ? widget.idEquipo 
          : (widget.equipoData['id_equipo']?.toString() ?? '');

      final incidenciaData = {
        'id_equipo': idEq,
        'nombre_equipo': widget.equipoData['nombre'] ?? 'Equipo Desconocido',
        'area': widget.equipoData['area_nombre'] ?? 'General',
        'numero_serie': widget.equipoData['numero_serie'] ?? '',
        'descripcion': _descripcionController.text.trim(),
        'imagenes': urlsCloudinary, // 👈 Aquí van las fotos
        'fecha_reporte': FieldValue.serverTimestamp(),
        'estado': 'Pendiente',
        
        // Datos Usuario
        'uid_reporta': user?.uid,
        'usuario_reporta': user?.email ?? 'Anónimo',
        // Nombres para notificación y app
        'nombreUsuario': user?.displayName ?? user?.email?.split('@').first ?? 'Usuario',
        'usuario_reportante_nombre': user?.displayName ?? user?.email?.split('@').first ?? 'Usuario',
      };

      // 3. Guardar en Firestore
      final docRef = await FirebaseFirestore.instance.collection('incidencias').add(incidenciaData);

      // 4. Notificar a Jefes
      final jefes = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'jefe')
          .get();

      for (final jefe in jefes.docs) {
        await FirebaseFirestore.instance
            .collection('notificaciones')
            .doc(jefe.id)
            .collection('inbox')
            .add({
              'tipo': 'nueva_incidencia',
              'titulo': '🆕 Nueva incidencia reportada',
              'cuerpo': 'En "${widget.equipoData['nombre']}"',
              'incidencia_id': docRef.id,
              'equipo_id': idEq,
              'timestamp': Timestamp.now(),
              'leido': false,
              'usuario_reportante_nombre': incidenciaData['usuario_reportante_nombre'],
            });
      }

      if (!mounted) return;

      // 5. ✅ Mostrar Modal de Éxito
      _mostrarDialogoExito();

    } catch (e) {
      if (!mounted) return;
      _mostrarError("Error al enviar: $e");
      setState(() => _enviando = false);
    }
  }

  // --- Helpers de UI ---

  void _mostrarAlertaValidacion() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text("Por favor, describe el problema.")),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarDialogoExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: verdePrincipal, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              "¡Reporte Enviado!",
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "La incidencia ha sido registrada con éxito (imágenes incluidas).",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); 
                  _irAlHome();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: verdePrincipal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Entendido",
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat'
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombreEquipo = widget.equipoData['nombre'] ?? 'Equipo sin nombre';
    final serie = widget.equipoData['numero_serie'] ?? 'S/N';
    final area = widget.equipoData['area_nombre'] ?? 'Ubicación desconocida';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _irAlHome();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: verdePrincipal,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: _irAlHome, 
          ),
          title: const Text(
            "Nueva Incidencia",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 📦 Tarjeta de Información del Equipo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: verdePrincipal.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.computer, size: 36, color: verdePrincipal),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      nombreEquipo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Serie: $serie  •  $area",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 25),
              
              // 📝 Formulario de Descripción
              const Text(
                "Detalles del Problema",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _descripcionController,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Describe la falla detalladamente...",
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 📷 SECCIÓN DE FOTOS (Agregada)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text(
                    "Evidencias (Opcional)",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _enviando ? null : _tomarFoto,
                        icon: const Icon(Icons.camera_alt, color: verdePrincipal),
                        tooltip: "Cámara",
                      ),
                      IconButton(
                        onPressed: _enviando ? null : _seleccionarGaleria,
                        icon: const Icon(Icons.photo_library, color: verdePrincipal),
                        tooltip: "Galería",
                      ),
                    ],
                  )
                ],
              ),

              // Vista previa de fotos seleccionadas
              if (_imagenes.isNotEmpty)
                Container(
                  height: 100,
                  margin: const EdgeInsets.only(top: 10),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagenes.length,
                    itemBuilder: (context, index) {
                      final img = _imagenes[index];
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(img),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 14,
                            child: GestureDetector(
                              onTap: () => _eliminarImagen(img),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 30),

              // 🚀 Botón Enviar
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _enviarReporte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdePrincipal,
                    elevation: 4,
                    shadowColor: verdePrincipal.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.send_rounded, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              "REGISTRAR INCIDENCIA",
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
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