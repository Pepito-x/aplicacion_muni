import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'usuario_home.dart'; // 👈 IMPORTANTE: Asegúrate de importar tu Home

class GuiaUsoScreen extends StatelessWidget {
  const GuiaUsoScreen({super.key});

  // 🔄 Función para ir al Home limpiando el historial
  void _irAlHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const UsuarioHome()),
      (route) => false, // Elimina todas las pantallas anteriores de la pila
    );
  }

  @override
  Widget build(BuildContext context) {
    const verdeBandera = Color(0xFF006400);

    // 1. Envolvemos con PopScope para controlar el botón físico "Atrás"
    return PopScope(
      canPop: false, // Bloquea el cierre automático
      onPopInvoked: (didPop) {
        if (didPop) return;
        _irAlHome(context); // Redirige al Home
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            // 2. Usamos la función segura en el botón de la AppBar
            onPressed: () => _irAlHome(context),
          ),
          title: const Text(
            "Guía de Uso",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: verdeBandera,
          elevation: 0,
        ),

        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildGuideCard(
              icon: FontAwesomeIcons.qrcode,
              title: "Escanear QR",
              description:
                  "Escanea el código del equipo para registrar una nueva incidencia de forma rápida.",
              color: verdeBandera,
            ),
            _buildGuideCard(
              icon: FontAwesomeIcons.bug,
              title: "Reportar Incidencia",
              description:
                  "Reporta daños, fallas y problemas detectados en los equipos o laboratorios.",
              color: verdeBandera,
            ),
            _buildGuideCard(
              icon: FontAwesomeIcons.list,
              title: "Mis Reportes",
              description:
                  "Consulta el historial de tu actividad, estados de seguimiento y detalles.",
              color: verdeBandera,
            ),
            _buildGuideCard(
              icon: FontAwesomeIcons.bell,
              title: "Notificaciones",
              description:
                  "Recibe avisos cuando el estado de tus reportes cambie o sea actualizado.",
              color: verdeBandera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}