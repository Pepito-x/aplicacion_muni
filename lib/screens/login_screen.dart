import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importante para reset pass
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'package:muni_incidencias/Services/notification_service.dart';

import 'admin_home.dart';
import 'tecnico_home.dart';
import 'usuario_home.dart';
import 'onboarding_registro.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passController = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;
  bool _rememberSession = false;

  static const Color verde = Color(0xFF006400);

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  // 📥 Cargar credenciales guardadas
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email') ?? '';
    final savedPass = prefs.getString('password') ?? '';
    final shouldRemember = prefs.getBool('remember_session') ?? false;

    if (shouldRemember && savedEmail.isNotEmpty) {
      setState(() {
        emailController.text = savedEmail;
        passController.text = savedPass;
        _rememberSession = true;
      });
    }
  }

  // 💾 Guardar credenciales
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    if (_rememberSession) {
      await prefs.setString('email', emailController.text.trim());
      await prefs.setString('password', passController.text.trim());
      await prefs.setBool('remember_session', true);
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('remember_session', false);
    }
  }

  // 🔐 Iniciar Sesión
  Future<void> _login() async {
    final email = emailController.text.trim();
    final pass = passController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _showSnack('Completa todos los campos', Colors.orange);
      return;
    }

    setState(() => loading = true);

    try {
      final rol = await AuthService().signIn(email, pass);

      if (rol == null) {
        _showSnack('Usuario o credenciales incorrectas', Colors.red);
        setState(() => loading = false);
        return;
      }

      await _saveCredentials();

      try {
        await NotificationService().initNotifications();
      } catch (e) {
        debugPrint("⚠️ Error al iniciar notificaciones: $e");
      }

      Widget destino;
      if (rol == 'admin' || rol == 'jefe') {
        destino = const AdminHome();
      } else if (rol == 'tecnico') {
        destino = const TecnicoHome();
      } else {
        destino = const UsuarioHome();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destino),
      );
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // 🔄 LÓGICA RECUPERAR CONTRASEÑA
  void _mostrarOlvidePassword() {
    final recoverEmailController = TextEditingController();
    
    // Si ya escribió algo en el login, lo usamos
    if (emailController.text.isNotEmpty) {
      recoverEmailController.text = emailController.text;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que suba con el teclado
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20, left: 24, right: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(FontAwesomeIcons.unlockKeyhole, color: verde, size: 22),
                  SizedBox(width: 10),
                  Text(
                    "Recuperar Contraseña",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: verde,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: recoverEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo electrónico",
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final email = recoverEmailController.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      _showSnack("Ingresa un correo válido", Colors.orange);
                      return;
                    }
                    
                    Navigator.pop(context); // Cierra el modal
                    _enviarCorreoRecuperacion(email);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Enviar Enlace",
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold,
                      fontFamily: "Montserrat"
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _enviarCorreoRecuperacion(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      // Mostrar diálogo de éxito
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: const [
              Icon(Icons.mark_email_read, color: verde, size: 50),
              SizedBox(height: 10),
              Text("¡Correo Enviado!", textAlign: TextAlign.center),
            ],
          ),
          content: Text(
            "Revisa tu bandeja de entrada en $email para restablecer tu contraseña.\n\n(Revisa también SPAM)",
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Entendido", style: TextStyle(color: verde)),
            )
          ],
        ),
      );
    } catch (e) {
      _showSnack("Error al enviar correo: ${e.toString()}", Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    final isSmall = height < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // ===== Fondo verde =====
              Container(
                height: height * 0.38,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A7A3F), Color(0xFF006400)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // ===== Logo =====
              Positioned(
                top: isSmall ? 40 : 70,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Image.asset('assets/img/logo_reque.png', width: width * 0.22),
                    const SizedBox(height: 12),
                    const Text(
                      "Municipalidad Distrital de Reque",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // ===== Tarjeta inferior =====
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: isSmall ? height * 0.72 : height * 0.65,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),

                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Bienvenido",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Ingrese sus credenciales para continuar",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),

                        const SizedBox(height: 26),

                        // ===== Email =====
                        _inputField(
                          label: "Correo institucional",
                          icon: FontAwesomeIcons.envelope,
                          controller: emailController,
                          isPassword: false,
                        ),

                        const SizedBox(height: 16),

                        // ===== Password =====
                        _passwordField(),

                        const SizedBox(height: 6),

                        CheckboxListTile(
                          title: const Text(
                            "Recordar sesión",
                            style: TextStyle(fontFamily: "Montserrat"),
                          ),
                          value: _rememberSession,
                          onChanged: (v) =>
                              setState(() => _rememberSession = v ?? false),
                          activeColor: verde,
                          checkColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),

                        const SizedBox(height: 10),

                        // ===== Botón login =====
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: verde,
                              minimumSize: const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    "Iniciar Sesión",
                                    style: TextStyle(
                                      fontFamily: "Montserrat",
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ✅ BOTÓN OLVIDASTE CONTRASEÑA CONECTADO
                        Center(
                          child: TextButton.icon(
                            onPressed: _mostrarOlvidePassword, // 👈 Aquí conectamos la función
                            icon: const Icon(FontAwesomeIcons.circleQuestion,
                                size: 16, color: verde),
                            label: const Text(
                              "¿Olvidaste tu contraseña?",
                              style: TextStyle(color: verde),
                            ),
                          ),
                        ),

                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const OnboardingRegistro(),
                                ),
                              );
                            },
                            icon: const Icon(FontAwesomeIcons.userPlus,
                                size: 16, color: verde),
                            label: const Text(
                              "Registrar nuevo usuario",
                              style: TextStyle(
                                color: verde,
                                fontWeight: FontWeight.w600,
                                fontFamily: "Montserrat",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== Widgets Auxiliares =====
  Widget _passwordField() {
    return TextField(
      controller: passController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: "Contraseña",
        labelStyle: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.black54,
        ),
        prefixIcon: const Icon(FontAwesomeIcons.lock, color: Colors.black54),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
            color: Colors.black54,
            size: 18,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool isPassword,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.black54,
        ),
        prefixIcon: Icon(icon, color: Colors.black54),
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}