import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// 🎙️ NUEVAS IMPORTACIONES DE AUDIO
import 'package:record/record.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:muni_incidencias/Services/direct_chat_service.dart';
import '../models/direct_message.dart';

// 🔹 CONFIGURACIÓN DE CLOUDINARY
const String cloudName = 'dgzlpxtoq';
const String uploadPreset = 'municipal_unsigned';

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String otroNombre;
  final String otroRol;
  final String rol;
  final String nombre;

  const DirectChatScreen({
    super.key,
    required this.chatId,
    required this.otroNombre,
    required this.otroRol,
    required this.rol,
    required this.nombre,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  // Controladores
  final _textController = TextEditingController();
  final _chatService = DirectChatService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Variables para Imágenes
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false; 

  // 🎙️ VARIABLES DE AUDIO
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _audioPath;

  static const Color verdeBandera = Color(0xFF006400);

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder.dispose(); // Limpiar grabadora
    _textController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // 📸 LÓGICA DE IMÁGENES (CLOUDINARY IMAGE)
  // ----------------------------------------------------------------------

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
        debugPrint('Error Cloudinary Imagen: ${response.statusCode}, $resBody');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción subiendo imagen: $e');
      return null;
    }
  }

  Future<void> _seleccionarYEnviarImagen(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70, 
        maxHeight: 1080,
        maxWidth: 1080,
      );

      if (picked == null) return;

      setState(() => _isUploading = true);

      File imagenFile = File(picked.path);
      String? secureUrl = await _subirImagenACloudinary(imagenFile);

      if (secureUrl != null) {
        await _chatService.sendMessage(
          otroUid: _extraerOtroUid(widget.chatId),
          texto: "📷 Foto enviada",
          miNombre: widget.nombre,
          miRol: widget.rol,
          imageUrl: secureUrl,
          type: 'image',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir la imagen')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error seleccionando imagen: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ----------------------------------------------------------------------
  // 🎙️ LÓGICA DE AUDIO (GRABAR Y SUBIR A CLOUDINARY VIDEO)
  // ----------------------------------------------------------------------

  // 1. Iniciar Grabación
  Future<void> _startRecording() async {
    try {
      // Verificar permisos
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        // Guardamos como .m4a
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        
        setState(() {
          _isRecording = true;
          _audioPath = path;
        });
        debugPrint("🎙️ Grabando en: $path");
      }
    } catch (e) {
      debugPrint("Error al iniciar grabación: $e");
    }
  }

  // 2. Detener Grabación y Enviar
  Future<void> _stopAndSendRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        debugPrint("✅ Grabación finalizada: $path");
        _subirYEnviarAudio(File(path));
      }
    } catch (e) {
      debugPrint("Error al detener grabación: $e");
    }
  }

  // 3. Subir Audio (Endpoint VIDEO)
  Future<void> _subirYEnviarAudio(File audioFile) async {
    setState(() => _isUploading = true);
    try {
      // ⚠️ IMPORTANTE: Usamos 'video/upload' para audios en Cloudinary
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));
      
      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = json.decode(resBody);
        String secureUrl = data['secure_url'];

        // Enviar mensaje tipo 'audio'
        await _chatService.sendMessage(
          otroUid: _extraerOtroUid(widget.chatId),
          texto: "🎤 Nota de voz", 
          miNombre: widget.nombre,
          miRol: widget.rol,
          imageUrl: secureUrl, // Guardamos URL del audio aquí
          type: 'audio',       
        );
      } else {
        debugPrint('Error Cloudinary Audio: ${response.statusCode}, $resBody');
      }
    } catch (e) {
      debugPrint('Excepción subiendo audio: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ----------------------------------------------------------------------
  // 🖥️ UI (BUILD)
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFE5DDD5),
      
      // 1. APP BAR
      appBar: AppBar(
        backgroundColor: verdeBandera,
        elevation: 2,
        leadingWidth: 30,
        title: InkWell(
          onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.otroNombre.isNotEmpty ? widget.otroNombre[0].toUpperCase() : '?',
                      style: TextStyle(color: _colorPorRol(widget.otroRol), fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: verdeBandera, width: 1.5),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otroNombre, 
                      style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.otroRol.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined, color: Colors.white),
            tooltip: 'Ver incidencias en común',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // 2. DRAWER
      endDrawer: _buildIncidenciasDrawer(),

      // 3. BODY
      body: Stack(
        children: [
          // Fondo
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5DDD5),
              image: DecorationImage(
                image: const NetworkImage("https://www.transparenttextures.com/patterns/subtle-white-feathers.png"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.05), BlendMode.dstATop),
              ),
            ),
          ),
          
          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<DirectMessage>>(
                  stream: _chatService.getMessages(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: verdeBandera));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error de conexión', style: TextStyle(color: Colors.grey)));
                    }

                    final mensajes = snapshot.data ?? [];

                    if (mensajes.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Ordenar descendente
                    mensajes.sort((a, b) {
                        final tA = a.timestamp?.toDate() ?? DateTime.now();
                        final tB = b.timestamp?.toDate() ?? DateTime.now();
                        return tB.compareTo(tA);
                    });

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                      itemCount: mensajes.length,
                      itemBuilder: (context, index) {
                        final msg = mensajes[index];
                        final isMe = msg.uid == FirebaseAuth.instance.currentUser!.uid;
                        return _buildMessageBubble(msg, isMe);
                      },
                    );
                  },
                ),
              ),

              // Barra de carga general (Imagen o Audio)
              if (_isUploading)
                Container(
                  color: Colors.black12,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text("Subiendo archivo...", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),

              _buildInput(),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // WIDGETS AUXILIARES
  // ----------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
            ),
            child: Icon(Icons.waving_hand_outlined, size: 40, color: Colors.amber.shade600),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20)
            ),
            child: Text(
              'Inicia la conversación con ${widget.otroNombre}', 
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 BURBUJA DE MENSAJE
  Widget _buildMessageBubble(DirectMessage msg, bool isMe) {
    final DateTime fecha = msg.timestamp != null ? msg.timestamp.toDate() : DateTime.now();
    final time = DateFormat('HH:mm').format(fecha);

    final bool esImagen = msg.type == 'image';
    final bool esAudio = msg.type == 'audio';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: (esImagen || esAudio)
            ? const EdgeInsets.all(4) 
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE7FFDB) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              
              // 📸 IMAGEN
              if (esImagen && msg.imageUrl != null)
                Container(
                  constraints: const BoxConstraints(maxHeight: 280, minHeight: 100, minWidth: 150),
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PhotoViewScreen(imageUrl: msg.imageUrl!),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Image.network(
                            msg.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 150, width: 200,
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(height: 150, width: 150, child: Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                          ),
                          Positioned.fill(child: Container(color: Colors.transparent)),
                        ],
                      ),
                    ),
                  ),
                ),

              // 🎤 AUDIO (REPRODUCTOR)
              if (esAudio && msg.imageUrl != null)
                 AudioMessageBubble(audioUrl: msg.imageUrl!, isMe: isMe),

              // 📝 TEXTO (Si no es multimedia)
              if (!esImagen && !esAudio)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4, left: 4),
                  child: Text(
                    msg.texto,
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                    textAlign: TextAlign.left,
                  ),
                ),

              // 🕒 HORA
              Padding(
                padding: const EdgeInsets.only(right: 2, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.done_all, size: 14, color: Colors.blueAccent),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 INPUT (BOTONES DE FOTO, GALERÍA Y AUDIO)
  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            // Indicador visual si está grabando
            if (_isRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.mic, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text("Grabando... Toca el botón rojo para enviar", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 5, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        // Galería
                        IconButton(
                          icon: Icon(Icons.photo_library_outlined, color: Colors.grey.shade600),
                          onPressed: (_isUploading || _isRecording) ? null : () => _seleccionarYEnviarImagen(ImageSource.gallery),
                        ),
                        
                        // Campo de texto
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 5,
                            onChanged: (val) {
                                setState(() {}); // Actualizar para cambiar icono Mic/Send
                            },
                            decoration: const InputDecoration(
                              hintText: 'Mensaje...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                            ),
                          ),
                        ),
                        
                        // Cámara
                        IconButton(
                          icon: Icon(Icons.camera_alt_outlined, color: Colors.grey.shade600),
                          onPressed: (_isUploading || _isRecording) ? null : () => _seleccionarYEnviarImagen(ImageSource.camera),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // BOTÓN DINÁMICO (ENVIAR O GRABAR)
                GestureDetector(
                  onTap: () {
                     if (_textController.text.trim().isNotEmpty) {
                        _sendMessage(); // Enviar texto
                     } else {
                        // Lógica de grabación (Toque simple: Iniciar / Detener)
                        if (_isRecording) {
                          _stopAndSendRecording();
                        } else {
                          _startRecording();
                        }
                     }
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: _isRecording ? Colors.red : verdeBandera,
                    child: _isUploading 
                      ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : Icon(
                          _textController.text.trim().isNotEmpty ? Icons.send_rounded : (_isRecording ? Icons.stop : Icons.mic), 
                          color: Colors.white, 
                          size: 22
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    _textController.clear();
    setState(() {}); // Actualizar estado para que vuelva el icono de mic
    
    _chatService.sendMessage(
      otroUid: _extraerOtroUid(widget.chatId),
      texto: text,
      miNombre: widget.nombre,
      miRol: widget.rol,
      type: 'text',
    );
  }

  // 🔹 PANEL LATERAL (DRAWER)
  Widget _buildIncidenciasDrawer() {
    final miUid = FirebaseAuth.instance.currentUser!.uid;
    final otroUid = _extraerOtroUid(widget.chatId);

    Query query = FirebaseFirestore.instance.collection('incidencias');
    
    if (widget.rol.toLowerCase() == 'tecnico') {
       query = query.where('tecnicoId', isEqualTo: miUid)
                    .where('usuario_reportante_id', isEqualTo: otroUid);
    } else {
       query = query.where('usuario_reportante_id', isEqualTo: miUid)
                    .where('tecnicoId', isEqualTo: otroUid);
    }

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            color: verdeBandera,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Historial Compartido",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  "Incidencias entre tú y ${widget.otroNombre}",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 50, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text("No hay incidencias en común", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final estado = data['estado'] ?? 'Pendiente';
                    final equipo = data['nombre_equipo'] ?? 'Equipo';
                    final desc = data['descripcion'] ?? '';
                    
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _colorEstado(estado).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.devices, color: _colorEstado(estado)),
                        ),
                        title: Text(equipo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorEstado(estado),
                                borderRadius: BorderRadius.circular(4)
                              ),
                              child: Text(
                                estado.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
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
    );
  }

  // HELPERS
  String _extraerOtroUid(String chatId) {
    final parts = chatId.split('_');
    if (parts.length < 4) return ''; 
    final uids = [parts[2], parts[3]];
    final miUid = FirebaseAuth.instance.currentUser!.uid;
    return uids.firstWhere((u) => u != miUid, orElse: () => '');
  }

  Color _colorPorRol(String rol) {
    switch (rol.toLowerCase()) {
      case 'jefe': return Colors.deepPurple;
      case 'tecnico': return Colors.orange.shade800;
      case 'usuario': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente': return Colors.orange;
      case 'en proceso': return Colors.blue;
      case 'resuelto': return Colors.green;
      default: return Colors.grey;
    }
  }
}

// ----------------------------------------------------------------------
// 📦 WIDGETS EXTERNOS (PhotoView & AudioPlayer)
// ----------------------------------------------------------------------

// 1. Pantalla Completa de Foto
class PhotoViewScreen extends StatelessWidget {
  final String imageUrl;

  const PhotoViewScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
          ),
        ),
      ),
    );
  }
}

// 2. Burbuja de Audio Reproductor
class AudioMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const AudioMessageBubble({super.key, required this.audioUrl, required this.isMe});

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _player.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _player.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$min:$sec";
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
            iconSize: 35,
            color: widget.isMe ? Colors.green[800] : Colors.grey[700],
            onPressed: _togglePlay,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 2,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                    value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                    activeColor: widget.isMe ? Colors.green[800] : Colors.blue,
                    inactiveColor: Colors.grey[300],
                    onChanged: (value) async {
                      final position = Duration(seconds: value.toInt());
                      await _player.seek(position);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position), style: const TextStyle(fontSize: 10)),
                      Text(_formatDuration(_duration), style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}