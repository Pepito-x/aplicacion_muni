import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registrar_incidencia_screen.dart'; // Asegúrate de que la ruta sea correcta
import 'usuario_home.dart'; // Asegúrate de que la ruta sea correcta

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> with WidgetsBindingObserver {
  
  // Controlador del escáner
  MobileScannerController? controller;

  // Estados
  bool _camaraMontada = false; 
  bool _procesando = false;

  static const Color verdePrincipal = Color(0xFF006400);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Iniciamos la cámara después de que se monte el widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarCamara();
    });
  }

  void _inicializarCamara() {
    if (mounted) {
      controller = MobileScannerController(
        returnImage: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        // Formatos específicos pueden ayudar al rendimiento
        formats: [BarcodeFormat.qrCode], 
      );
      setState(() {
        _camaraMontada = true;
      });
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    // Aseguramos la limpieza del controlador
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null || !controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller?.stop();
    } else if (state == AppLifecycleState.resumed) {
      controller?.start();
    }
  }

  void _regresarAlHome() {
    // Usamos pushAndRemoveUntil para limpiar la pila y evitar volver a la cámara
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const UsuarioHome()), // Ajusta el nombre de tu Home
      (route) => false,
    );
  }

  Future<void> _procesarCodigo(String codigo) async {
    if (_procesando) return; // Bloqueo de seguridad

    // 1. 🛑 FASE CRÍTICA: DESMONTAJE VISUAL INMEDIATO
    if (mounted) {
      setState(() {
        _procesando = true;
        _camaraMontada = false; // Esto elimina el widget MobileScanner del árbol
      });
    }

    // 2. 🛑 FASE CRÍTICA: LIMPIEZA DE HARDWARE
    // Esperamos para que el emulador libere el buffer EGL.
    // Este delay es vital para evitar el conflicto de recursos.
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      if (controller != null) {
        await controller!.stop();
        controller!.dispose(); // Matamos el controlador totalmente
        controller = null;
      }
    } catch (e) {
      debugPrint("Error cerrando cámara (ignorable en este punto): $e");
    }

    // 3. CONSULTA A FIREBASE (Ya sin cámara consumiendo RAM)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('equipos')
          .doc(codigo)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        // ✅ ÉXITO: Navegar a la pantalla de registro
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrarIncidenciaScreen(
              equipoData: doc.data()!,
              idEquipo: doc.id,
            ),
          ),
        );
      } else {
        // ❌ ERROR: Equipo no encontrado
        _mostrarFeedback("⚠️ Equipo no encontrado", esError: true);
        // Esperamos un poco para que el usuario lea el mensaje
        await Future.delayed(const Duration(seconds: 2));
        _reiniciarCamaraCompleta();
      }
    } catch (e) {
      // ❌ ERROR: Problema de conexión o Firebase
      _mostrarFeedback("❌ Error: $e", esError: true);
      await Future.delayed(const Duration(seconds: 2));
      _reiniciarCamaraCompleta();
    }
  }

  // Si falla la búsqueda, reiniciamos la cámara desde cero
  void _reiniciarCamaraCompleta() {
    if (!mounted) return;
    setState(() {
      _procesando = false;
    });
    _inicializarCamara();
  }

  void _mostrarFeedback(String msg, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Interceptar botón atrás físico
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _regresarAlHome();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: verdePrincipal,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text("Escanear QR", style: TextStyle(color: Colors.white)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _regresarAlHome,
          ),
        ),
        
        body: Stack(
          children: [
            // CAPA 1: Cámara (Solo existe si _camaraMontada es true)
            if (_camaraMontada && controller != null)
              MobileScanner(
                controller: controller!,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      _procesarCodigo(barcode.rawValue!);
                      break; // Procesamos solo el primer código detectado
                    }
                  }
                },
              ),

            // CAPA 2: Pantalla de Carga (Fondo sólido negro)
            // Si _camaraMontada es falso, esto tapa todo mientras procesa y evita glitches visuales
            if (!_camaraMontada)
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black, 
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(color: verdePrincipal),
                    SizedBox(height: 20),
                    Text(
                      "Procesando...",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    )
                  ],
                ),
              ),

            // CAPA 3: Overlay visual (Solo si la cámara está activa)
            if (_camaraMontada)
              _buildScannerOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.greenAccent, width: 3),
            ),
          ),
        ),
        const Positioned(
          bottom: 80,
          left: 0, 
          right: 0,
          child: Text(
            "Apunta al código QR",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

extension on MobileScannerController {
  get value => null;
}