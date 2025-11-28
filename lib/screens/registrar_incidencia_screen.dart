import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 🔹 Configuración de Cloudinary
const String cloudName = 'dgzlpxtoq';
const String uploadPreset = 'municipal_unsigned';

class RegistrarIncidenciaScreen extends StatefulWidget {
  final Map<String, dynamic> equipoData;
  const RegistrarIncidenciaScreen({super.key, required this.equipoData});

  @override
  State<RegistrarIncidenciaScreen> createState() => _RegistrarIncidenciaScreenState();
}

class _RegistrarIncidenciaScreenState extends State<RegistrarIncidenciaScreen> {
  final descripcionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool loading = false;
  List<File> imagenes = [];

  // 🧹 Liberar controladores al salir
  @override
  void dispose() {
    descripcionController.dispose();
    super.dispose();
  }

  // 📤 Subir imagen a Cloudinary
  Future<String?> subirImagenACloudinary(File imagen) async {
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
        print('Cloudinary upload failed: ${response.statusCode}, body: $resBody');
        return null;
      }
    } catch (e) {
      print('Error subiendo a Cloudinary: $e');
      return null;
    }
  }

  // 📸 Tomar foto con cámara
  Future<void> tomarFoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxHeight: 1080,
        maxWidth: 1080,
      );
      if (picked != null) {
        setState(() {
          imagenes.add(File(picked.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar foto: $e')),
      );
    }
  }

  // 🖼️ Seleccionar desde galería (múltiple)
  Future<void> seleccionarDesdeGaleria() async {
    try {
      final pickedList = await _picker.pickMultiImage(
        imageQuality: 75,
        maxHeight: 1080,
        maxWidth: 1080,
      );
      if (pickedList.isNotEmpty) {
        setState(() {
          imagenes.addAll(pickedList.map((e) => File(e.path)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imágenes: $e')),
      );
    }
  }

  // 🗑️ Eliminar una imagen de la lista
  void _eliminarImagen(File imagen) {
    setState(() {
      imagenes.remove(imagen);
    });
  }

  // 📝 Registrar incidencia en Firestore + notificar al jefe
  Future<void> registrarIncidencia() async {
    // 🕒 Log breve (solo en debug)
    print("🚀 Registrando incidencia...");

    // 🔒 Verificar contexto
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Sesión expirada')),
        );
        Navigator.maybePop(context);
      }
      return;
    }

    final descripcion = descripcionController.text.trim();
    if (descripcion.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Describe la incidencia')),
        );
      }
      return;
    }

    setState(() => loading = true);

    try {
      // 🖼️ Subir imágenes (si hay)
      List<String> urlsCloudinary = [];
      for (final imagen in imagenes) {
        if (!mounted) return;
        final url = await subirImagenACloudinary(imagen);
        if (url != null) urlsCloudinary.add(url);
      }

      final equipo = widget.equipoData;

      // 📄 Datos de incidencia
     // 📄 Datos de incidencia
      final incidenciaData = {
        'id_equipo': equipo['id_equipo'] as String,
        'nombre_equipo': equipo['nombre'] as String,
        'area': equipo['area_nombre'] as String,
        'descripcion': descripcion,
        'imagenes': urlsCloudinary,
        'fecha_reporte': Timestamp.now(),
        'estado': 'Pendiente',
        
        // Datos del usuario
        'usuario_reportante_id': user.uid,
        'usuario_reportante_email': user.email ?? '—',
        
        // ⚠️ CORRECCIÓN AQUÍ:
        // Enviamos con AMBOS nombres para que funcione tu Cloud Function y tu App
        'nombreUsuario': user.displayName ?? user.email?.split('@').first ?? 'Usuario', // Para la Notificación Push
        'usuario_reportante_nombre': user.displayName ?? user.email?.split('@').first ?? 'Usuario', // Para tu App
      };

      // ✅ Guardar incidencia
      final incidenciaDoc = await FirebaseFirestore.instance
          .collection('incidencias')
          .add(incidenciaData);

      // 🔔 Notificar a jefes
      final jefes = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'jefe')
          .get();
      for (final jefe in jefes.docs) {
        if (!mounted) break;
        await FirebaseFirestore.instance
            .collection('notificaciones')
            .doc(jefe.id)
            .collection('inbox')
            .add({
          'tipo': 'nueva_incidencia',
          'titulo': '🆕 Nueva incidencia reportada',
          'cuerpo': 'En "${equipo['nombre']}" (${equipo['area_nombre']})',
          'incidencia_id': incidenciaDoc.id,
          'equipo_id': equipo['id_equipo'],
          'timestamp': Timestamp.now(),
          'leido': false,
          'usuario_reportante_nombre': incidenciaData['usuario_reportante_nombre'],
        });
      }

      // ✅ Éxito + navegación segura
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Incidencia registrada'),
            backgroundColor: Colors.green,
          ),
        );
        // Limpiar descripcionController.clear();
        setState(() {
          imagenes.clear();
          loading = false;
        });

        // 🔁 Navegación robusta: vuelve a UsuarioHome
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // 👇 Usa esta ruta → debe existir en main.dart
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/usuario_home', // ← ¡CRÍTICO! Debe estar en routes
              (route) => false,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e is FirebaseException ? e.message ?? 'Error' : '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted && loading) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const verdeBandera = Color(0xFF006400);
    final equipo = widget.equipoData;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: verdeBandera,
        title: const Text(
          'Registrar Incidencia',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖥️ Datos del equipo (resaltados)
            Card(
              color: verdeBandera.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equipo: ${equipo['nombre']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: verdeBandera,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Área: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: equipo['area_nombre']),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Serie: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: equipo['numero_serie'] ?? '—'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 📝 Descripción
            const Text(
              'Describe el problema',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descripcionController,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Ej: No enciende, pantalla rota, error al imprimir...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            // 📷 Acciones de imagen
            const Text(
              'Adjuntar fotos (opcional)',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : tomarFoto,
                    icon: const Icon(Icons.camera_alt, size: 20),
                    label: const Text('Tomar foto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : seleccionarDesdeGaleria,
                    icon: const Icon(Icons.photo_library, size: 20),
                    label: const Text('Galería'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 🖼️ Vista previa horizontal
            if (imagenes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${imagenes.length} foto${imagenes.length == 1 ? '' : 's'} seleccionada${imagenes.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontFamily: 'Montserrat'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imagenes.length,
                      itemBuilder: (context, index) {
                        final img = imagenes[index];
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  img,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 14,
                              child: GestureDetector(
                                onTap: () => _eliminarImagen(img),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            // 🔘 Botón principal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : registrarIncidencia,
                style: ElevatedButton.styleFrom(
                  backgroundColor: verdeBandera,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text(
                        '✅ Registrar Incidencia',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
