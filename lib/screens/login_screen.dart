import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:muni_incidencias/Services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

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

  Future<void> _login() async {
    final email = emailController.text.trim();
    final pass = passController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // Intentamos iniciar sesión
      final rol = await AuthService().signIn(email, pass);

      if (rol == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario o credenciales incorrectas')),
        );
        setState(() => loading = false);
        return;
      }

      // ✅ SI EL LOGIN FUE EXITOSO:
      // 1. Guardamos credenciales si marcó "Recordar"
      await _saveCredentials();

      // 2. 🔥 ACTIVAMOS LAS NOTIFICACIONES PUSH AQUÍ 🔥
      // Esto pedirá permiso y guardará el token FCM en la base de datos
      try {
        await NotificationService().initNotifications();
        debugPrint("🔔 Notificaciones inicializadas correctamente");
      } catch (e) {
        debugPrint("⚠️ Error al iniciar notificaciones: $e");
        // No detenemos el login si esto falla, pero lo registramos
      }

      // 3. Redirigimos según el rol
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF006400);

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
                        // ===== Título =====
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

                        Center(
                          child: TextButton.icon(
                            onPressed: () {},
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

  // ===== Campo contraseña =====
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

  // ===== Campo genérico =====
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