import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:muni_incidencias/Services/direct_chat_service.dart';
import '../models/direct_message.dart';

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
  final _textController = TextEditingController();
  final _chatService = DirectChatService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Para controlar el Drawer
  
  static const Color verdeBandera = Color(0xFF006400);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Asignamos la key
      backgroundColor: const Color(0xFFE5DDD5), 
      
      // 1. APP BAR CON ACCESO AL HISTORIAL
      appBar: AppBar(
        backgroundColor: verdeBandera,
        elevation: 2,
        leadingWidth: 30,
        title: InkWell(
          onTap: () => _scaffoldKey.currentState?.openEndDrawer(), // Tocar el nombre abre info
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
                  // Indicador de "En línea" (Simulado visualmente)
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
          // Botón explícito para ver incidencias
          IconButton(
            icon: const Icon(Icons.assignment_outlined, color: Colors.white),
            tooltip: 'Ver incidencias en común',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // 2. DRAWER (PANEL LATERAL) CON INCIDENCIAS
      endDrawer: _buildIncidenciasDrawer(),

      body: Stack(
        children: [
          // Fondo con patrón (Simulado con opacidad)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5DDD5),
              image: DecorationImage(
                image: NetworkImage("https://www.transparenttextures.com/patterns/subtle-white-feathers.png"), // Patrón sutil online
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

                    // Ordenar descendente (Nuevo -> Viejo)
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
              _buildInput(),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

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
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
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

  // 🔹 PANEL LATERAL DE INCIDENCIAS (VALOR AGREGADO)
  Widget _buildIncidenciasDrawer() {
    final miUid = FirebaseAuth.instance.currentUser!.uid;
    final otroUid = _extraerOtroUid(widget.chatId);

    // Lógica de consulta:
    // Si soy técnico, busco incidencias donde yo sea el técnico y el otro el reportante.
    // Si soy usuario, al revés. O usamos un Filter.or si Firestore lo permite en tu índice.
    // Para simplificar y asegurar compatibilidad, hacemos la consulta basada en los roles.
    
    Query query = FirebaseFirestore.instance.collection('incidencias');
    
    // Asumimos que la colección tiene 'tecnicoId' y 'usuario_reportante_id'
    // Ajusta los nombres de campo exactos según tu base de datos.
    if (widget.rol.toLowerCase() == 'tecnico') {
       // Soy técnico, busco reportes del usuario asignados a mí
       query = query.where('tecnicoId', isEqualTo: miUid)
                    .where('usuario_reportante_id', isEqualTo: otroUid);
    } else {
       // Soy usuario, busco mis reportes asignados a este técnico
       query = query.where('usuario_reportante_id', isEqualTo: miUid)
                    .where('tecnicoId', isEqualTo: otroUid);
    }
    
    // Opcional: Ordenar por fecha
    // query = query.orderBy('fecha_reporte', descending: true);

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

  Widget _buildMessageBubble(DirectMessage msg, bool isMe) {
    final DateTime fecha = msg.timestamp != null ? msg.timestamp.toDate() : DateTime.now();
    final time = DateFormat('HH:mm').format(fecha);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE7FFDB) : Colors.white, // Color verde más suave
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
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 4),
                child: Text(
                  msg.texto,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                  textAlign: TextAlign.left,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all, size: 14, color: Colors.blueAccent), // Check azul
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.transparent,
      child: SafeArea(
        child: Row(
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
                    // Botón decorativo de adjuntar (Icono emoji o clip)
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: Colors.grey.shade500),
                      onPressed: () {}, // Funcionalidad futura
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Mensaje...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                       icon: Icon(Icons.camera_alt_outlined, color: Colors.grey.shade500),
                       onPressed: () {}, // Funcionalidad futura
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: verdeBandera,
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
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
    _chatService.sendMessage(
      otroUid: _extraerOtroUid(widget.chatId),
      texto: text,
      miNombre: widget.nombre,
      miRol: widget.rol,
    );
  }

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