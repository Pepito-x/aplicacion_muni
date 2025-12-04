import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:muni_incidencias/Services/direct_chat_service.dart';
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

  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _isLoading = true;

  // Paleta de colores profesional
  static const Color kPrimaryColor = Color(0xFF006400); // Verde Bandera
  static const Color kBackgroundColor = Color(0xFFF5F7FA); // Gris muy suave para fondo
  static const Color kTextPrimary = Color(0xFF1A1A1A);
  static const Color kTextSecondary = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _cargarContactosIniciales();
    _searchController.addListener(_filtrarContactos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      backgroundColor: kBackgroundColor,
      // Usamos un Stack para lograr el efecto de cabecera superpuesta profesional
      body: Column(
        children: [
          _buildProfessionalHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : _filteredContacts.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        itemCount: _filteredContacts.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 80, endIndent: 20, color: Color(0xFFEEEEEE)),
                        itemBuilder: (context, index) {
                          return _ContactChatTile(
                            contacto: _filteredContacts[index],
                            chatService: _chatService,
                            currentRol: widget.rol,
                            currentNombre: widget.nombre,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          // AppBar Custom Row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Expanded(
                child: Text(
                  'Mensajes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 20), // Para balancear el icono de back
            ],
          ),
          const SizedBox(height: 20),
          // Buscador Moderno
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o rol...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_search_outlined, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            "No se encontraron contactos",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE DATOS (Mantenida igual para no romper backend) ---
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
          jefes = await FirebaseFirestore.instance.collection('usuarios').where('rol', isEqualTo: 'jefe').get();
          tecnicos = await FirebaseFirestore.instance.collection('usuarios').where('rol', isEqualTo: 'tecnico').get();
          contactos.addAll(_mapDocs(jefes));
          contactos.addAll(_mapDocs(tecnicos));
          break;
        case 'tecnico':
          jefes = await FirebaseFirestore.instance.collection('usuarios').where('rol', isEqualTo: 'jefe').get();
          usuarios = await FirebaseFirestore.instance.collection('usuarios').where('rol', isEqualTo: 'usuario').limit(50).get(); 
          contactos.addAll(_mapDocs(jefes));
          contactos.addAll(_mapDocs(usuarios));
          break;
        case 'jefe':
        case 'admin':
          final todos = await FirebaseFirestore.instance.collection('usuarios').where('rol', whereIn: ['tecnico', 'usuario']).get();
          contactos.addAll(_mapDocs(todos));
          break;
      }
    } catch (e) {
      debugPrint("Error cargando contactos: $e");
    }

    final uniqueContactos = <String, Map<String, dynamic>>{};
    for (var c in contactos) {
      if (c['uid'] != miUid) uniqueContactos[c['uid']] = c;
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

// ---------------------------------------------------------------------------
// WIDGET SEPARADO PARA LA TARJETA DEL CHAT (Mejor rendimiento y orden)
// ---------------------------------------------------------------------------

class _ContactChatTile extends StatelessWidget {
  final Map<String, dynamic> contacto;
  final DirectChatService chatService;
  final String currentRol;
  final String currentNombre;

  const _ContactChatTile({
    required this.contacto,
    required this.chatService,
    required this.currentRol,
    required this.currentNombre,
  });

  @override
  Widget build(BuildContext context) {
    final otroUid = contacto['uid'] as String;
    final chatId = chatService.generarChatId(otroUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
      builder: (context, snapshot) {
        String ultimoMensaje = "Iniciar conversación";
        String horaMensaje = "";
        bool isUnread = false;
        bool esMensajeMio = false; 

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          final rawMsg = data['ultimoMensaje'];
          if (rawMsg is String) {
            ultimoMensaje = rawMsg;
          } else if (rawMsg is Map) {
            ultimoMensaje = rawMsg['texto'] ?? "📷 Foto";
            // Verificar si fui yo
            if (rawMsg['uid'] == FirebaseAuth.instance.currentUser!.uid) {
              esMensajeMio = true;
            }
          }
          
          final timestamp = data['ultimoTimestamp'] as Timestamp?;
          if (timestamp != null) {
            horaMensaje = _formatearHora(timestamp);
          }

          if (data['noLeidos'] is List) {
             final listaPendientes = List.from(data['noLeidos']);
             if (listaPendientes.contains(FirebaseAuth.instance.currentUser!.uid)) {
                isUnread = true;
             }
          }
        }

        // Diseño visual condicional
        final bgColor = isUnread ? const Color(0xFFE8F5E9) : Colors.transparent; // Verde muy suave si no leído
        final fontWeight = isUnread ? FontWeight.w700 : FontWeight.w400;
        final msgColor = isUnread ? Colors.black87 : Colors.grey.shade600;

        return Material(
          color: bgColor,
          child: InkWell(
            onTap: () {
              chatService.marcarComoLeidos(chatId);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DirectChatScreen(
                    chatId: chatId,
                    otroNombre: contacto['nombre'],
                    otroRol: contacto['rol'],
                    rol: currentRol,
                    nombre: currentNombre,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // 1. Avatar con Badge
                  _buildAvatar(contacto['nombre'], contacto['rol']),
                  
                  const SizedBox(width: 15),
                  
                  // 2. Información Central
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                contacto['nombre'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                            if (horaMensaje.isNotEmpty)
                              Text(
                                horaMensaje,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isUnread ? const Color(0xFF006400) : Colors.grey.shade500,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (esMensajeMio && horaMensaje.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.done_all, size: 14, color: Colors.blue.shade300),
                              ),
                            Expanded(
                              child: Text(
                                ultimoMensaje,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: msgColor,
                                  fontWeight: fontWeight,
                                  fontSize: 13.5,
                                  height: 1.2
                                ),
                              ),
                            ),
                            // Indicador de no leído (Círculo verde)
                            if (isUnread)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                width: 10, height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF006400),
                                  shape: BoxShape.circle,
                                ),
                              )
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String nombre, String rol) {
    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _colorPorRol(rol).withOpacity(0.1), // Fondo pastel del color del rol
          ),
          child: Center(
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: TextStyle(
                color: _colorPorRol(rol),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _colorPorRol(rol),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
            ),
            child: Icon(
              _iconoPorRol(rol),
              size: 10,
              color: Colors.white,
            ),
          ),
        )
      ],
    );
  }

  Color _colorPorRol(String rol) {
    switch (rol.toLowerCase()) {
      case 'jefe': return Colors.deepPurple;
      case 'tecnico': return const Color(0xFFE65100); // Naranja oscuro profesional
      case 'usuario': return const Color(0xFF1976D2); // Azul standard
      default: return Colors.grey;
    }
  }

  IconData _iconoPorRol(String rol) {
    switch (rol.toLowerCase()) {
      case 'jefe': return Icons.security;
      case 'tecnico': return Icons.handyman;
      default: return Icons.person;
    }
  }

  String _formatearHora(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inDays == 0 && now.day == date.day) {
      return DateFormat('HH:mm').format(date);
    } else if (diff.inDays < 2) {
      return "AYER";
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }
}