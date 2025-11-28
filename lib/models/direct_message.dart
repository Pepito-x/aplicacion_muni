import 'package:cloud_firestore/cloud_firestore.dart';

class DirectMessage {
  final String uid;
  final String nombre;
  final String rol;
  final String texto;
  final Timestamp timestamp;
  final bool leido;

  DirectMessage({
    required this.uid,
    required this.nombre,
    required this.rol,
    required this.texto,
    required this.timestamp,
    this.leido = false,
  });

  factory DirectMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DirectMessage(
      uid: data['uid'] ?? '',
      nombre: data['nombre'] ?? 'Usuario',
      rol: data['rol'] ?? 'usuario',
      texto: data['texto'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      leido: data['leido'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'nombre': nombre,
      'rol': rol,
      'texto': texto,
      'timestamp': timestamp,
      'leido': leido,
    };
  }
}

class ChatPreview {
  final String chatId;
  final List<String> participantes;
  final String otroNombre;
  final String otroRol;
  final String ultimoTexto;
  final Timestamp ultimoTimestamp;
  final int noLeidos;

  ChatPreview({
    required this.chatId,
    required this.participantes,
    required this.otroNombre,
    required this.otroRol,
    required this.ultimoTexto,
    required this.ultimoTimestamp,
    this.noLeidos = 0,
  });

  factory ChatPreview.fromFirestore(DocumentSnapshot doc, String miUid) {
    final data = doc.data() as Map<String, dynamic>;
    
    // 1. Participantes
    final participantes = List<String>.from(data['participantes'] ?? []);
    
    // 2. Identificar al otro usuario
    final otroUid = participantes.firstWhere(
      (u) => u != miUid, 
      orElse: () => 'Desconocido'
    );

    // 3. Obtener nombres y roles del mapa
    final nombres = Map<String, dynamic>.from(data['nombres'] ?? {});
    final roles = Map<String, dynamic>.from(data['roles'] ?? {});

    final otroNombre = nombres[otroUid] ?? 'Usuario';
    final otroRol = roles[otroUid] ?? '—';
    
    // 4. Último mensaje
    final ultimoInfo = data['ultimoMensaje'] as Map<String, dynamic>?;
    final ultimoTexto = ultimoInfo?['texto'] ?? '';
    final ultimoTimestamp = ultimoInfo?['timestamp'] ?? Timestamp.now();

    // 5. ⚠️ CORRECCIÓN CLAVE: Lógica de No Leídos
    // En el servicio usamos arrayUnion, así que 'noLeidos' es una LISTA de UIDs [uid1, uid2]
    final listaNoLeidos = List.from(data['noLeidos'] ?? []);
    
    // Si MI uid está en la lista, significa que NO he leído el mensaje.
    // Retornamos 1 para activar el punto rojo, 0 si ya lo leí.
    final int cantidadNoLeidos = listaNoLeidos.contains(miUid) ? 1 : 0;

    return ChatPreview(
      chatId: doc.id,
      participantes: participantes,
      otroNombre: otroNombre,
      otroRol: otroRol,
      ultimoTexto: ultimoTexto,
      ultimoTimestamp: ultimoTimestamp,
      noLeidos: cantidadNoLeidos, // ✅ Usamos la variable calculada arriba
    );
  }
}