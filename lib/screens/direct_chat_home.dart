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

  // ⭐ Tarjeta de Chat Inteligente (CORREGIDA)
  Widget _buildContactTile(Map<String, dynamic> contacto) {
    final otroUid = contacto['uid'] as String;
    final chatId = _chatService.generarChatId(otroUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
      builder: (context, snapshot) {
        // Datos por defecto
        String ultimoMensaje = "Toca para iniciar conversación";
        String horaMensaje = "";
        int noLeidos = 0; // 0 = Leído, 1 = No leído
        bool hayActividad = false;
        bool esMensajeMio = false; 

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          // 1. OBTENER EL ÚLTIMO MENSAJE
          final rawMsg = data['ultimoMensaje'];
          if (rawMsg is String) {
            ultimoMensaje = rawMsg;
          } else if (rawMsg is Map) {
            ultimoMensaje = rawMsg['texto'] ?? "📷 Foto enviada";
          }
          
          // 2. OBTENER LA HORA
          final timestamp = data['ultimoTimestamp'] as Timestamp?; // ⚠️ Corregido a 'ultimoTimestamp' que es más fiable en la raíz
          if (timestamp != null) {
            horaMensaje = _formatearHora(timestamp);
          }

          final miUid = FirebaseAuth.instance.currentUser!.uid;

          // 3. ⚠️ CORRECCIÓN CLAVE: LÓGICA DE NO LEÍDOS (LISTA, NO MAPA)
          // El servicio usa arrayUnion, así que esto es una Lista de UIDs
          if (data['noLeidos'] is List) {
             final listaPendientes = List.from(data['noLeidos']);
             // Si MI uid está en la lista, significa que NO he leído el mensaje
             if (listaPendientes.contains(miUid)) {
                noLeidos = 1; // Marcamos como pendiente
             }
          }

          // 4. VERIFICAR SI FUE MI MENSAJE
          // Revisamos si el último UID registrado en el mensaje es el mío
          if (rawMsg is Map && rawMsg['uid'] == miUid) {
             esMensajeMio = true;
          }

          hayActividad = true;
        }

        // --- RENDERIZADO VISUAL ---

        // Definimos el estilo basado en si hay mensajes no leídos
        final bool isUnread = noLeidos > 0;
        final FontWeight fontWeight = isUnread ? FontWeight.w800 : FontWeight.normal;
        final Color textColor = isUnread ? Colors.black : Colors.grey.shade600;

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
              Positioned(
                right: 0, bottom: 0,
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
              if (hayActividad)
                Text(
                  horaMensaje,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnread ? verdeBandera : Colors.grey,
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
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
                    color: textColor, // ⚫ Color negro si no leído
                    fontWeight: fontWeight, // 𝗕 Negrita si no leído
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          // Punto verde indicador
          trailing: isUnread
              ? Container(
                  width: 12, height: 12,
                  decoration: const BoxDecoration(
                    color: verdeBandera,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () {
            // AL ENTRAR, MARCAMOS COMO LEÍDO
            _chatService.marcarComoLeidos(chatId); // 👈 Importante llamar a esto
            
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