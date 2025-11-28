import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔹 Inicia sesión y devuelve el rol del usuario si es válido
  Future<String?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userDoc = await _firestore
          .collection('usuarios')
          .doc(cred.user!.uid)
          .get();

      // ✅ Solo devolvemos el rol si el usuario existe en Firestore
      return userDoc.data()?['rol'] as String?;
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ AuthService.signIn error: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('❌ AuthService.signIn error desconocido: $e');
      return null;
    }
  }

  /// 🔹 Valida si el correo y código existen y no han sido usados
  Future<Map<String, dynamic>?> validarCodigo(
    String correo,
    String codigo,
  ) async {
    try {
      final query = await _firestore
          .collection('usuarios_pendientes')
          .where('correo', isEqualTo: correo.trim())
          .where('codigo', isEqualTo: codigo.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      if (doc['registrado'] == true) return null;

      return {
        'docId': doc.id,
        'rol': doc['rol'],
        'correo': doc['correo'],
      };
    } catch (e) {
      debugPrint('❌ AuthService.validarCodigo error: $e');
      return null;
    }
  }

  /// 🔹 Registra al usuario en Firebase Auth y actualiza Firestore
  Future<void> registrarUsuario({
    required String docId,
    required String correo,
    required String password,
    required String nombre,
    required String rol,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: password.trim(),
      );

      await _firestore.collection('usuarios_pendientes').doc(docId).update({
        'registrado': true,
        'nombre': nombre.trim(),
        'fechaRegistro': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('usuarios').doc(cred.user!.uid).set({
        'correo': correo.trim(),
        'nombre': nombre.trim(),
        'rol': rol,
        'creadoEn': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ AuthService.registrarUsuario FirebaseAuth error: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('❌ AuthService.registrarUsuario error: $e');
      rethrow;
    }
  }

  /// 🔹 Cierra sesión (versión limpia: SIN FCM)
  Future<void> signOut() async {
    await _auth.signOut();
    // ✅ Ya no borramos 'fcmToken' → no lo usamos
  }
}