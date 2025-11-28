// lib/services/direct_chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/direct_message.dart';

class DirectChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _miUid => _auth.currentUser!.uid;

  // 🔹 Genera un chatId único para 1v1 (sin guion bajo: público)
  String generarChatId(String otroUid) {
    final uids = [_miUid, otroUid]..sort();
    return 'chat_1v1_${uids[0]}_${uids[1]}';
  }
Stream<List<ChatPreview>> getChats() {
  print('🔍 UID del usuario actual: $_miUid'); // Para depuración

  return _firestore
      .collection('chats')
      .orderBy('ultimoTimestamp', descending: true)
      .snapshots()
      .map((snapshot) {
    final chats = <ChatPreview>[];

    for (final doc in snapshot.docs) {
      if (!doc.exists) continue;

      final data = doc.data();
      final participantesRaw = data['participantes'];

      // Verifica si 'participantes' es una lista
      if (participantesRaw is List) {
        // Convierte cada elemento a string y verifica si contiene el UID
        final participantes = participantesRaw.map((e) => e.toString()).toList();
        if (participantes.contains(_miUid)) {
          try {
            final chatPreview = ChatPreview.fromFirestore(doc, _miUid);
            chats.add(chatPreview);
          } catch (e) {
            print('⚠️ Error al convertir documento a ChatPreview: $e');
          }
        }
      } else {
        // Si no es una lista, imprime un aviso
        print('❌ Documento ${doc.id} tiene "participantes" como ${participantesRaw.runtimeType}');
      }
    }

    print('✅ Chats encontrados: ${chats.length}');
    return chats;
  });
}

  // 🔹 Obtiene los mensajes de un chat
  Stream<List<DirectMessage>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('mensajes')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DirectMessage.fromFirestore(doc))
            .toList());
  }

  // 🔹 Envía un mensaje 1:1 (crea el chat si no existe)
  Future<void> sendMessage({
  required String otroUid,
  required String texto,
  required String miNombre,
  required String miRol,
}) async {
  final chatId = generarChatId(otroUid);
  final timestamp = Timestamp.now();

  // Datos del otro usuario
  final otroDoc = await _firestore.collection('usuarios').doc(otroUid).get();
  final otroNombre = otroDoc.data()?['nombre'] ?? '—';
  final otroRol = otroDoc.data()?['rol'] ?? '—';

  final mensaje = DirectMessage(
    uid: _miUid,
    nombre: miNombre,
    rol: miRol,
    texto: texto,
    timestamp: timestamp,
  );

  final batch = _firestore.batch();

  // 1. Añade el mensaje
  batch.set(
    _firestore.collection('chats').doc(chatId).collection('mensajes').doc(),
    mensaje.toFirestore(),
  );

  // 2. Actualiza el doc del chat (con merge: true)
  final chatData = {
    'participantes': [_miUid, otroUid],
    'nombres': {
      _miUid: miNombre,
      otroUid: otroNombre,
    },
    'roles': {
      _miUid: miRol,
      otroUid: otroRol,
    },
    'ultimoMensaje': {
      'texto': texto,
      'uid': _miUid,
      'timestamp': timestamp,
    },
    'ultimoTimestamp': timestamp,
    'createdAt': FieldValue.serverTimestamp(),
    // 👇 Inicializamos 'noLeidos' como array con el UID del otro
    'noLeidos': [otroUid], // ← El otro usuario lo verá como "no leído"
  };

  // ✅ Usa merge: true → crea si no existe, actualiza si sí
  batch.set(
    _firestore.collection('chats').doc(chatId),
    chatData,
    SetOptions(merge: true),
  );

  await batch.commit();
}

  // 🔹 Marca mensajes como leídos (seguro para chats inexistentes)
  Future<void> marcarComoLeidos(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (doc.exists) {
        await _firestore.collection('chats').doc(chatId).update({
          'noLeidos': FieldValue.arrayRemove([_miUid]),
        });
      }
      // Si no existe, no hace nada → normal en primer mensaje
    } catch (e) {
      // No interrumpe la app
      print('⚠️ marcarComoLeidos error (no crítico): $e');
    }
  }
}