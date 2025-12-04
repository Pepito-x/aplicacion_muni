import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/direct_message.dart';

class DirectChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _miUid => _auth.currentUser!.uid;

  // 🔹 Genera un chatId único para 1v1 (orden alfabético para consistencia)
  String generarChatId(String otroUid) {
    final uids = [_miUid, otroUid]..sort();
    return 'chat_1v1_${uids[0]}_${uids[1]}';
  }

  // 🔹 Obtener lista de chats (Vista previa en el Home)
  Stream<List<ChatPreview>> getChats() {
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

        // Verificamos si soy parte del chat
        if (participantesRaw is List) {
          final participantes = participantesRaw.map((e) => e.toString()).toList();
          if (participantes.contains(_miUid)) {
            try {
              final chatPreview = ChatPreview.fromFirestore(doc, _miUid);
              chats.add(chatPreview);
            } catch (e) {
              print('⚠️ Error al convertir ChatPreview: $e');
            }
          }
        }
      }
      return chats;
    });
  }

  // 🔹 Obtiene los mensajes de un chat específico
  Stream<List<DirectMessage>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('mensajes')
        .orderBy('timestamp', descending: true) // Ordenamos del más reciente al más antiguo
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DirectMessage.fromFirestore(doc))
            .toList());
  }

  // 🔹 Envía un mensaje (SOPORTA TEXTO E IMÁGENES)
  Future<void> sendMessage({
    required String otroUid,
    required String texto,
    required String miNombre,
    required String miRol,
    String? imageUrl,     // 👈 NUEVO: Recibe URL de imagen
    String type = 'text', // 👈 NUEVO: Define tipo ('text' o 'image')
  }) async {
    final chatId = generarChatId(otroUid);
    final timestamp = Timestamp.now();

    // Intentamos obtener datos actualizados del otro usuario (opcional)
    String otroNombre = 'Usuario';
    String otroRol = '—';
    try {
      final otroDoc = await _firestore.collection('usuarios').doc(otroUid).get();
      if (otroDoc.exists) {
        otroNombre = otroDoc.data()?['nombre'] ?? 'Usuario';
        otroRol = otroDoc.data()?['rol'] ?? '—';
      }
    } catch (_) {
      // Si falla, usamos valores por defecto
    }

    // 1. Crear el objeto Mensaje
    final mensaje = DirectMessage(
      uid: _miUid,
      nombre: miNombre,
      rol: miRol,
      texto: texto,
      timestamp: timestamp,
      imageUrl: imageUrl, // 👈 Guardamos la URL
      type: type,         // 👈 Guardamos el tipo
    );

    final batch = _firestore.batch();

    // 2. Añadir el mensaje a la subcolección
    batch.set(
      _firestore.collection('chats').doc(chatId).collection('mensajes').doc(),
      mensaje.toFirestore(),
    );

    // 3. Definir qué texto se muestra en la lista de chats
    String textoPreview = texto;
    if (type == 'image') {
      textoPreview = texto.isNotEmpty ? '📷 $texto' : '📷 Foto enviada';
    }

    // 4. Actualizar el documento principal del chat
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
        'texto': textoPreview, // 👈 Usamos el texto formateado
        'uid': _miUid,
        'timestamp': timestamp,
      },
      'ultimoTimestamp': timestamp,
      'noLeidos': FieldValue.arrayUnion([otroUid]), // 👈 Añadimos al otro a "no leídos"
    };

    // Usamos merge para crear o actualizar
    batch.set(
      _firestore.collection('chats').doc(chatId),
      chatData,
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // 🔹 Marca el chat como leído (quita mi ID de la lista noLeidos)
  Future<void> marcarComoLeidos(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'noLeidos': FieldValue.arrayRemove([_miUid]),
      });
    } catch (e) {
      // Si el chat no existe aún, ignoramos el error
      print('Info: Chat aún no creado o error al marcar leído: $e');
    }
  }
}