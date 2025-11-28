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
  
  static const Color verdeBandera = Color(0xFF006400);

  @override
  void initState() {
    super.initState();
    // Marcar como leído al entrar (opcional, implementar en tu servicio)
    // _chatService.marcarComoLeido(widget.chatId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5), // Color de fondo estilo WhatsApp
      appBar: AppBar(
        backgroundColor: verdeBandera,
        leadingWidth: 30, // Reduce espacio para acercar el avatar
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                widget.otroNombre.isNotEmpty ? widget.otroNombre[0].toUpperCase() : '?',
                style: TextStyle(color: _colorPorRol(widget.otroRol), fontWeight: FontWeight.bold),
              ),
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DirectMessage>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: verdeBandera));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar mensajes', style: TextStyle(color: Colors.grey)));
                }

                final mensajes = snapshot.data ?? [];

                if (mensajes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Saluda a ${widget.otroNombre} 👋', 
                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                // Invertimos para Chat UX (El más reciente abajo)
                // Asegúrate que tu servicio devuelva ordenado por fecha DESC o ASC según prefieras.
                // Aquí asumo que vienen ordenados por fecha, así que invertimos visualmente.
                // Si ya vienen DESC, no necesitas .reversed si usas reverse: true.
                
                // Opción A: reverse: true en ListView (Estándar)
                // Requiere que la lista empiece con el mensaje MÁS NUEVO en index 0.
                
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
    );
  }

  Widget _buildMessageBubble(DirectMessage msg, bool isMe) {
    // Seguridad para Timestamp nulo (latencia de red al enviar)
    final DateTime fecha = msg.timestamp != null 
        ? msg.timestamp.toDate() 
        : DateTime.now();
        
    final time = DateFormat('HH:mm').format(fecha);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : Colors.white, // Colores tipo WhatsApp
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 14), // Espacio para la hora
                child: Text(
                  msg.texto,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      // Icono de "enviado" (estático por ahora, puedes conectarlo al estado del mensaje)
                      const Icon(Icons.done_all, size: 14, color: Colors.blue), 
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

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.transparent, // Transparente para ver el fondo
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: TextField(
                  controller: _textController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5, // Crece hacia arriba si escribes mucho
                  decoration: const InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: verdeBandera,
                child: const Icon(Icons.send, color: Colors.white, size: 20),
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
    // chatId formato esperado: chat_1v1_uidA_uidB
    final parts = chatId.split('_');
    if (parts.length < 4) return ''; 
    
    final uids = [parts[2], parts[3]];
    final miUid = FirebaseAuth.instance.currentUser!.uid;
    
    // Retorna el UID que NO es el mío
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
}