import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importante para Timestamp
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
  // Eliminamos _scrollController porque usaremos reverse: true

  @override
  void initState() {
    super.initState();
    // Descomenta esto cuando quieras que funcione el "leído"
    // _chatService.marcarComoLeidos(widget.chatId); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _colorPorRol(widget.otroRol),
              child: Text(
                widget.otroNombre.isNotEmpty ? widget.otroNombre[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otroNombre, style: const TextStyle(fontSize: 16)),
                Text(
                  widget.otroRol,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DirectMessage>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                // Obtenemos los mensajes
                final mensajes = snapshot.data ?? [];

                // 1. SI ESTÁ VACÍO: Mostramos un mensaje amigable
                if (mensajes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.waving_hand, size: 50, color: Colors.amber.shade300),
                        const SizedBox(height: 10),
                        Text('Di hola a ${widget.otroNombre}', 
                             style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                // 2. LISTA INVERSA: Truco estándar para chats
                // Invertimos la lista de datos para que el index 0 sea el más NUEVO
                // y usamos reverse: true en el ListView.
                final mensajesOrdenados = mensajes.reversed.toList();

                return ListView.builder(
                  reverse: true, // Esto hace que la lista empiece desde abajo
                  padding: const EdgeInsets.all(16),
                  itemCount: mensajesOrdenados.length,
                  itemBuilder: (context, index) {
                    final msg = mensajesOrdenados[index];
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
    // 3. SEGURIDAD TIMESTAMP: Evitamos el crash si timestamp es null
    // (pasa justo cuando envías el mensaje antes de que el servidor responda)
    final DateTime fecha = msg.timestamp != null 
        ? msg.timestamp.toDate() 
        : DateTime.now();
        
    final time = DateFormat('HH:mm').format(fecha);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.green : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Importante para que no ocupe todo el ancho
          children: [
            if (!isMe) // Solo mostramos nombre si no soy yo
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
            Text(
              msg.texto,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
                // 4. CORRECCIÓN IMPORTANTE: Eliminé el onTap que rompía el foco
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              mini: true,
              elevation: 0,
              backgroundColor: Colors.green,
              child: const Icon(Icons.send, size: 20, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear(); // Limpiamos antes para mejor UX

    _chatService.sendMessage(
      otroUid: _extraerOtroUid(widget.chatId),
      texto: text,
      miNombre: widget.nombre,
      miRol: widget.rol,
    );
  }

  String _extraerOtroUid(String chatId) {
    // chatId formato: chat_1v1_uidA_uidB
    final parts = chatId.split('_');
    // Validamos que el ID tenga el formato correcto para evitar crash
    if (parts.length < 4) return ''; 
    
    final uids = [parts[2], parts[3]];
    final miUid = FirebaseAuth.instance.currentUser!.uid;
    return uids.firstWhere((u) => u != miUid, orElse: () => '');
  }

  Color _colorPorRol(String rol) {
    switch (rol) {
      case 'jefe': return Colors.deepPurple;
      case 'tecnico': return Colors.green;
      case 'usuario': return Colors.blue;
      default: return Colors.grey;
    }
  }
}