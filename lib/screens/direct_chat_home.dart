// lib/screens/direct_chat_home.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:muni_incidencias/Services/direct_chat_service.dart';
import '../models/direct_message.dart';
import 'direct_chat_screen.dart';

class DirectChatHome extends StatefulWidget {
  final String rol;
  final String nombre;

  const DirectChatHome({super.key, required this.rol, required this.nombre});

  @override
  State<DirectChatHome> createState() => _DirectChatHomeState();
}

class _DirectChatHomeState extends State<DirectChatHome> {
  final DirectChatService _chatService = DirectChatService();
  final TextEditingController _searchController = TextEditingController();

  // Cache para chats (para evitar llamar getChats múltiples veces)
  Map<String, ChatPreview?> _chatCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Opcional: implementar búsqueda
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cargarContactosRelevantes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final contactos = snapshot.data ?? [];
          return ListView.builder(
            itemCount: contactos.length,
            itemBuilder: (context, index) {
              final contacto = contactos[index];
              return _buildContactTile(contacto);
            },
          );
        },
      ),
    );
  }

 Widget _buildContactTile(Map<String, dynamic> contacto) {
    final otroUid = contacto['uid'] as String;
    // Generamos el ID único para escuchar ese chat específico
    final chatId = _chatService.generarChatId(otroUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
      builder: (context, snapshot) {
        ChatPreview? chatPreview;
        
        // 1. Intentamos parsear la data si existe
        if (snapshot.hasData && snapshot.data!.exists) {
          try {
            // Asegúrate de importar tu modelo ChatPreview correctamente
            chatPreview = ChatPreview.fromFirestore(
                snapshot.data!, 
                FirebaseAuth.instance.currentUser!.uid
            );
            // Guardamos en caché (opcional, pero útil)
            _chatCache[chatId] = chatPreview;
          } catch (e) {
            debugPrint("Error leyendo chat: $e");
          }
        }

        // 2. Preparamos los datos seguros (Evitamos errores de Null)
        final String ultimoMensaje = chatPreview?.ultimoTexto ?? '';
        final int cantidadNoLeidos = chatPreview?.noLeidos ?? 0;
        final bool hayMensaje = ultimoMensaje.isNotEmpty;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _colorPorRol(contacto['rol']),
            child: Text(
              contacto['nombre'].toString().isNotEmpty
                  ? contacto['nombre'][0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(
            contacto['nombre'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          // 3. AQUÍ ESTÁ LA VISTA PREVIA
          subtitle: hayMensaje
              ? Text(
                  // Muestra: "Hola, ¿cómo estás?... • jefe"
                  '$ultimoMensaje • ${contacto['rol']}', 
                  maxLines: 1, // Solo 1 línea
                  overflow: TextOverflow.ellipsis, // Pone "..." si es largo
                  style: TextStyle(
                    color: cantidadNoLeidos > 0 ? Colors.black87 : Colors.grey[600],
                    fontWeight: cantidadNoLeidos > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                )
              : Text(
                  contacto['rol'], // Si no hay mensajes, solo muestra el rol
                  style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
          trailing: cantidadNoLeidos > 0
              ? Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${cantidadNoLeidos > 9 ? '9+' : cantidadNoLeidos}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              : null, // Si no hay mensajes nuevos, no muestra nada a la derecha (o podrías poner la hora)
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DirectChatScreen(
                  chatId: chatId,
                  otroNombre: contacto['nombre'],
                  otroRol: contacto['rol'],
                  rol: widget.rol,
                  nombre: widget.nombre,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _colorPorRol(String rol) {
    switch (rol) {
      case 'jefe': return Colors.deepPurple;
      case 'tecnico': return Colors.green;
      case 'usuario': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Future<List<Map<String, dynamic>>> _cargarContactosRelevantes() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    
    final miUid = currentUser.uid;
    final miDoc = await FirebaseFirestore.instance.collection('usuarios').doc(miUid).get();
    if (!miDoc.exists) return [];
    
    final miRol = miDoc.data()?['rol'];
    List<Map<String, dynamic>> contactos = [];

    switch (miRol) {
      case 'usuario':
        final jefes = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('rol', isEqualTo: 'jefe')
            .get();
        final tecnicos = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('rol', isEqualTo: 'tecnico')
            .get();

        contactos = [
          ...jefes.docs.map((d) => {
                'uid': d.id,
                'nombre': d['nombre'],
                'rol': 'jefe',
              }),
          ...tecnicos.docs.map((d) => {
                'uid': d.id,
                'nombre': d['nombre'],
                'rol': 'tecnico',
              }),
        ];
        break;

      case 'tecnico':
        final jefes = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('rol', isEqualTo: 'jefe')
            .get();
        final usuarios = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('rol', isEqualTo: 'usuario')
            .limit(20)
            .get();

        contactos = [
          ...jefes.docs.map((d) => {
                'uid': d.id,
                'nombre': d['nombre'],
                'rol': 'jefe'
              }),
          ...usuarios.docs.map((d) => {
                'uid': d.id,
                'nombre': d['nombre'],
                'rol': 'usuario'
              }),
        ];
        break;

      case 'jefe':
        final usuariosYtecnicos = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('rol', whereNotIn: ['jefe'])
            .get();

        contactos = usuariosYtecnicos.docs
            .map((d) => {
                  'uid': d.id,
                  'nombre': d['nombre'],
                  'rol': d['rol'],
                })
            .toList();
        break;
    }

    return contactos.where((c) => c['uid'] != miUid).toList();
  }
}