import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import 'package:muni_incidencias/Services/direct_chat_service.dart';
// Asegúrate de tener este import o comenta si no usas el modelo
// import '../models/direct_message.dart'; 
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
  
  // Variables de estado
  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _isLoading = true;
  
  static const Color verdeBandera = Color(0xFF006400);

  @override
  void initState() {
    super.initState();
    _cargarContactosIniciales();
    
    // Listener para el buscador
    _searchController.addListener(_filtrarContactos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🔍 Lógica de filtrado local
  void _filtrarContactos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts.where((contact) {
          final nombre = contact['nombre'].toString().toLowerCase();
          final rol = contact['rol'].toString().toLowerCase();
          return nombre.contains(query) || rol.contains(query);
        }).toList();
      }
    });
  }

  // 📥 Carga inicial de datos
  Future<void> _cargarContactosIniciales() async {
    final contactos = await _cargarContactosRelevantes();
    if (mounted) {
      setState(() {
        _allContacts = contactos;
        _filteredContacts = contactos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: verdeBandera,
        title: const Text(
          'Mensajes Directos',
          style: TextStyle(
            fontFamily: 'Montserrat', 
            fontWeight: FontWeight.w600,
            color: Colors.white
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ─── BARRA DE BÚSQUEDA ───────────────────────────────────────────
          Container(
            color: verdeBandera,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar contacto...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ─── LISTA DE CHATS ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: verdeBandera))
                : _filteredContacts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          return _buildContactTile(_filteredContacts[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ⭐ Tarjeta de Chat Inteligente
  Widget _buildContactTile(Map<String, dynamic> contacto) {
    final otroUid = contacto['uid'] as String;
    final chatId = _chatService.generarChatId(otroUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
      builder: (context, snapshot) {
        // Datos por defecto (si nunca han hablado)
        String ultimoMensaje = "Toca para iniciar conversación";
        String horaMensaje = "";
        int noLeidos = 0;
        bool hayActividad = false;
        bool esMensajeMio = false; 

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          // 🛠️ CORRECCIÓN DEL ERROR DE TIPO AQUÍ 👇
          // Verificamos si es String o Map antes de asignarlo
          final rawMsg = data['ultimoMensaje'];
          if (rawMsg is String) {
            ultimoMensaje = rawMsg;
          } else if (rawMsg is Map) {
            // Si es un objeto, intentamos sacar el texto de campos comunes
            ultimoMensaje = rawMsg['texto'] ?? rawMsg['text'] ?? rawMsg['mensaje'] ?? "📷 Mensaje multimedia";
          } else {
            ultimoMensaje = "Mensaje recibido";
          }
          // 🛠️ FIN DE LA CORRECCIÓN 

          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null) {
            horaMensaje = _formatearHora(timestamp);
          }

          final miUid = FirebaseAuth.instance.currentUser!.uid;
          
          // Lógica de No Leídos
          if (data['noLeidos'] is Map) {
             noLeidos = (data['noLeidos'][miUid] ?? 0) as int;
          }

          // Verificar quién envió el último
          if (data['ultimoSenderId'] == miUid) {
            esMensajeMio = true;
          }

          hayActividad = true;
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _colorPorRol(contacto['rol']),
                child: Text(
                  contacto['nombre'].toString().isNotEmpty
                      ? contacto['nombre'][0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              // Indicador de rol pequeño
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Icon(
                    _iconoPorRol(contacto['rol']),
                    size: 12,
                    color: _colorPorRol(contacto['rol']),
                  ),
                ),
              )
            ],
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  contacto['nombre'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Hora del mensaje
              if (hayActividad)
                Text(
                  horaMensaje,
                  style: TextStyle(
                    fontSize: 12,
                    color: noLeidos > 0 ? verdeBandera : Colors.grey,
                    fontWeight: noLeidos > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              // Check de "Tú" si yo lo envié
              if (esMensajeMio && hayActividad)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text("Tú:", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ),
              
              Expanded(
                child: Text(
                  ultimoMensaje,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: noLeidos > 0 ? Colors.black87 : Colors.grey[600],
                    fontWeight: noLeidos > 0 ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          trailing: noLeidos > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: verdeBandera,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    noLeidos > 9 ? '9+' : noLeidos.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              : null,
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

  // 🛠️ Helpers de Diseño y Utilidades
  Color _colorPorRol(String rol) {
    switch (rol.toLowerCase()) {
      case 'jefe': return Colors.deepPurple;
      case 'tecnico': return Colors.orange.shade800;
      case 'usuario': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _iconoPorRol(String rol) {
    switch (rol.toLowerCase()) {
      case 'jefe': return Icons.security;
      case 'tecnico': return Icons.build;
      default: return Icons.person;
    }
  }

  String _formatearHora(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inDays == 0 && now.day == date.day) {
      return DateFormat('HH:mm').format(date); // 14:30
    } else if (diff.inDays < 2) {
      return "Ayer";
    } else {
      return DateFormat('dd/MM').format(date); // 25/11
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("No se encontraron contactos", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // 📡 Lógica de obtención de contactos (Optimizada)
  Future<List<Map<String, dynamic>>> _cargarContactosRelevantes() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    
    final miUid = currentUser.uid;
    final miDoc = await FirebaseFirestore.instance.collection('usuarios').doc(miUid).get();
    if (!miDoc.exists) return [];
    
    final miRol = miDoc.data()?['rol'] ?? 'usuario';
    List<Map<String, dynamic>> contactos = [];

    QuerySnapshot jefes, tecnicos, usuarios;

    try {
      switch (miRol) {
        case 'usuario':
          jefes = await FirebaseFirestore.instance
              .collection('usuarios').where('rol', isEqualTo: 'jefe').get();
          tecnicos = await FirebaseFirestore.instance
              .collection('usuarios').where('rol', isEqualTo: 'tecnico').get();
          
          contactos.addAll(_mapDocs(jefes));
          contactos.addAll(_mapDocs(tecnicos));
          break;

        case 'tecnico':
          jefes = await FirebaseFirestore.instance
              .collection('usuarios').where('rol', isEqualTo: 'jefe').get();
          usuarios = await FirebaseFirestore.instance
              .collection('usuarios').where('rol', isEqualTo: 'usuario').limit(50).get(); 
          
          contactos.addAll(_mapDocs(jefes));
          contactos.addAll(_mapDocs(usuarios));
          break;

        case 'jefe':
        case 'admin':
          final todos = await FirebaseFirestore.instance
              .collection('usuarios')
              .where('rol', whereIn: ['tecnico', 'usuario'])
              .get();
          contactos.addAll(_mapDocs(todos));
          break;
      }
    } catch (e) {
      debugPrint("Error cargando contactos: $e");
    }

    // Filtrar mi propio usuario
    final uniqueContactos = <String, Map<String, dynamic>>{};
    for (var c in contactos) {
      if (c['uid'] != miUid) {
        uniqueContactos[c['uid']] = c;
      }
    }

    return uniqueContactos.values.toList();
  }

  List<Map<String, dynamic>> _mapDocs(QuerySnapshot snapshot) {
    return snapshot.docs.map((d) => {
      'uid': d.id,
      'nombre': d['nombre'] ?? 'Usuario',
      'rol': d['rol'] ?? 'usuario',
    }).toList();
  }
}