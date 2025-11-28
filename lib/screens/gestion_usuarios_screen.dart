import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_home.dart'; // 👈 IMPORTANTE: Importa tu Home de Admin

class GestionUsuariosScreen extends StatelessWidget {
  const GestionUsuariosScreen({super.key});

  static const Color verdeBandera = Color(0xFF006400);

  // 🔄 Navegación segura al AdminHome
  void _irAlHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminHome()),
      (route) => false,
    );
  }

  // 🔹 Eliminar usuario de Firestore
  Future<void> _eliminarUsuario(
      BuildContext context, String uid, String nombre) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Eliminar Usuario'),
          ],
        ),
        content: Text(
            '¿Estás seguro de eliminar a "$nombre"?\nEsta acción eliminará sus datos y no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await db.collection('usuarios').doc(uid).delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Usuario "$nombre" eliminado correctamente.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: verdeBandera,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? uidJefeActual = FirebaseAuth.instance.currentUser?.uid;

    // 1. Control del botón físico "Atrás"
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _irAlHome(context);
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100, // Fondo moderno
        appBar: AppBar(
          backgroundColor: verdeBandera,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => _irAlHome(context), // 2. Flecha de regreso
          ),
          title: const Text(
            'Gestión de Usuarios',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .where('rol', isNotEqualTo: 'jefe') // Ocultar otros jefes si aplica
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: verdeBandera));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            final usuarios = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: usuarios.length,
              itemBuilder: (context, index) {
                final doc = usuarios[index];
                final uid = doc.id;
                final data = doc.data() as Map<String, dynamic>;
                final nombre = data['nombre'] ?? 'Sin nombre';
                final correo = data['correo'] ?? 'Sin correo';
                final rol = (data['rol'] as String?)?.toLowerCase() ?? 'usuario';

                // 🔒 Ocultar al jefe actual si aparece en la lista
                if (uid == uidJefeActual) return const SizedBox.shrink();

                return _buildUsuarioCard(context, uid, nombre, correo, rol);
              },
            );
          },
        ),
      ),
    );
  }

  // ⭐ Tarjeta de Usuario Mejorada
  Widget _buildUsuarioCard(BuildContext context, String uid, String nombre, String correo, String rol) {
    final bool esTecnico = rol == 'tecnico';
    final Color colorRol = esTecnico ? Colors.orange.shade800 : Colors.blue.shade700;
    final Color colorFondo = esTecnico ? Colors.orange.shade50 : Colors.blue.shade50;
    final IconData icono = esTecnico ? Icons.build_circle : Icons.person;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorFondo,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, color: colorRol, size: 28),
        ),
        title: Text(
          nombre,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(correo, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorFondo,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colorRol.withOpacity(0.3)),
              ),
              child: Text(
                rol.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colorRol,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _eliminarUsuario(context, uid, nombre),
          tooltip: 'Eliminar usuario',
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No hay usuarios registrados.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}