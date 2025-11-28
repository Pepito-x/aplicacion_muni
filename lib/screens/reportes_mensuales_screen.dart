import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'admin_home.dart'; // 👈 IMPORTANTE: Importa tu Home de Admin

class ReportesMensualesScreen extends StatefulWidget {
  const ReportesMensualesScreen({super.key});

  @override
  State<ReportesMensualesScreen> createState() => _ReportesMensualesScreenState();
}

class _ReportesMensualesScreenState extends State<ReportesMensualesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Color verdeBandera = Color(0xFF006400);

  List<Map<String, dynamic>> _incidenciasConUsuario = [];
  List<Map<String, dynamic>> _filteredIncidencias = [];

  String? _selectedTecnico = 'Todos';
  String? _selectedArea = 'Todas';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarIncidenciasConUsuarios();
  }

  // 🔄 Navegación segura al AdminHome
  void _irAlHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminHome()),
      (route) => false,
    );
  }

  Future<void> _cargarIncidenciasConUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('incidencias').get();
      final data = snapshot.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      if (mounted) {
        setState(() {
          _incidenciasConUsuario = data;
          _filteredIncidencias = List.from(data);
          _isLoading = false;
        });
        _filtrarIncidencias(); // Aplicar filtros iniciales si los hubiera
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al cargar datos: $e")),
        );
      }
    }
  }

  // ------------------------------
  // FILTROS
  // ------------------------------
  void _filtrarIncidencias() {
    setState(() {
      _filteredIncidencias = _incidenciasConUsuario.where((inc) {
        bool matchTecnico = true;
        bool matchArea = true;
        bool matchFecha = true;

        // Técnico
        if (_selectedTecnico != null && _selectedTecnico != 'Todos') {
          final lista = inc['tecnicos_asignados'] ?? [];
          matchTecnico = lista.contains(_selectedTecnico);
        }

        // Área
        if (_selectedArea != null && _selectedArea != 'Todas') {
          matchArea = inc['area'] == _selectedArea;
        }

        // Fecha
        DateTime? fecha;
        if (inc['fecha_reporte'] is Timestamp) {
          fecha = (inc['fecha_reporte'] as Timestamp).toDate();
        }
        if (fecha != null) {
          if (_fechaInicio != null && fecha.isBefore(_fechaInicio!)) {
            matchFecha = false;
          }
          if (_fechaFin != null && fecha.isAfter(_fechaFin!.add(const Duration(days: 1)))) {
            // Se agrega 1 día al fin para incluir todo el día seleccionado
            matchFecha = false;
          }
        }

        return matchTecnico && matchArea && matchFecha;
      }).toList();
    });
  }

  List<String> _obtenerTecnicosUnicos() {
    final set = <String>{};
    for (final inc in _incidenciasConUsuario) {
      if (inc['tecnicos_asignados'] is List) {
        for (final t in inc['tecnicos_asignados']) {
          set.add(t);
        }
      }
    }
    return ['Todos', ...set.toList()..sort()];
  }

  List<String> _obtenerAreasUnicas() {
    final set = <String>{};
    for (final inc in _incidenciasConUsuario) {
      if (inc['area'] != null) set.add(inc['area']);
    }
    return ['Todas', ...set.toList()..sort()];
  }

  Future<void> _seleccionarRangoFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: verdeBandera),
          ),
          child: child!,
        );
      },
    );

    if (rango != null) {
      setState(() {
        _fechaInicio = rango.start;
        _fechaFin = rango.end;
      });
      _filtrarIncidencias();
    }
  }

  // ---------------------------------------------------
  // UI PRINCIPAL
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _irAlHome();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: verdeBandera,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: _irAlHome, // 👈 Navegación Segura
          ),
          title: const Text(
            "Reportes & Métricas",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: "Recargar",
              onPressed: _cargarIncidenciasConUsuarios,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: "Exportar PDF",
              onPressed: _exportarAPdf,
            ),
          ],
        ),

        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: verdeBandera))
            : Column(
                children: [
                  _buildDashboard(), // Métricas superiores
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildFiltrosPanel(), // Filtros
                          const SizedBox(height: 16),
                          // Lista
                          Expanded(child: _buildListaIncidencias()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // -----------------------------------------------
  // DASHBOARD CARDS (Métricas)
  // -----------------------------------------------
  Widget _buildDashboard() {
    final total = _filteredIncidencias.length;
    final resueltos = _filteredIncidencias
        .where((i) => (i['estado'] ?? '').toString().toLowerCase() == "resuelto")
        .length;
    
    // Asumimos que todo lo que no es resuelto está pendiente/proceso
    final pendientes = total - resueltos;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: verdeBandera,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          _metricCard("Total", total, Icons.folder_open, Colors.white, Colors.white24),
          const SizedBox(width: 10),
          _metricCard("Resueltos", resueltos, Icons.check_circle, Colors.greenAccent, Colors.white12),
          const SizedBox(width: 10),
          _metricCard("Pendientes", pendientes, Icons.access_time_filled, Colors.orangeAccent, Colors.white12),
        ],
      ),
    );
  }

  Widget _metricCard(String titulo, int valor, IconData icon, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  "$valor",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              style: TextStyle(
                color: textColor.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------
  // PANEL DE FILTROS
  // ------------------------------------------------
  Widget _buildFiltrosPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  "Técnico",
                  _selectedTecnico,
                  _obtenerTecnicosUnicos(),
                  (v) {
                    _selectedTecnico = v;
                    _filtrarIncidencias();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  "Área",
                  _selectedArea,
                  _obtenerAreasUnicas(),
                  (v) {
                    _selectedArea = v;
                    _filtrarIncidencias();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range, color: verdeBandera),
              label: Text(
                _fechaInicio != null && _fechaFin != null
                    ? "${DateFormat('dd/MM/yy').format(_fechaInicio!)} - ${DateFormat('dd/MM/yy').format(_fechaFin!)}"
                    : "Filtrar por rango de fechas",
                style: const TextStyle(color: verdeBandera, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: verdeBandera),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _seleccionarRangoFechas,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  // -----------------------------------------------
  // LISTA DE INCIDENCIAS
  // -----------------------------------------------
  Widget _buildListaIncidencias() {
    if (_filteredIncidencias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 50, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              "No se encontraron resultados.",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredIncidencias.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (_, i) {
        return _incidenciaCard(_filteredIncidencias[i]);
      },
    );
  }

  Widget _incidenciaCard(Map<String, dynamic> inc) {
    final estado = inc['estado'] ?? 'Pendiente';
    final colorEstado = _getColorEstado(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Franja lateral
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: verdeBandera,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            inc['nombre_equipo'] ?? "Equipo Desconocido",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorEstado.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorEstado.withOpacity(0.3)),
                          ),
                          child: Text(
                            estado,
                            style: TextStyle(color: colorEstado, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _infoText(Icons.business, inc['area'] ?? "Sin área"),
                    const SizedBox(height: 4),
                    _infoText(Icons.person_outline, (inc['tecnicos_asignados'] as List?)?.join(", ") ?? "Sin técnico"),
                    const SizedBox(height: 4),
                    _infoText(Icons.calendar_today, _formatFecha(inc['fecha_reporte'])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getColorEstado(String e) {
    switch (e.toLowerCase()) {
      case "resuelto": return Colors.green;
      case "en proceso": return Colors.blue;
      default: return Colors.orange;
    }
  }

  String _formatFecha(dynamic f) {
    if (f is Timestamp) return DateFormat("dd/MM/yyyy HH:mm").format(f.toDate());
    if (f is DateTime) return DateFormat("dd/MM/yyyy HH:mm").format(f);
    return "—";
  }

  // ---------------------------------------------------
  // PDF EXPORT
  // ---------------------------------------------------
  Future<void> _exportarAPdf() async {
    if (_filteredIncidencias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ No hay datos para exportar.")),
      );
      return;
    }

    final pdf = pw.Document();
    
    // Intenta cargar el logo, si falla usa un placeholder
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/img/logo_reque.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      // Si no hay logo, no pasa nada
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          if (logo != null) pw.Center(child: pw.Image(logo, height: 60)),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              "Reporte de Incidencias TI",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
          ),
          pw.Center(
            child: pw.Text(
              "Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ["Equipo", "Área", "Técnicos", "Fecha", "Estado"],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF006400)),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
            cellAlignment: pw.Alignment.centerLeft,
            data: _filteredIncidencias.map((i) {
              return [
                i['nombre_equipo'] ?? "—",
                i['area'] ?? "—",
                (i['tecnicos_asignados'] as List?)?.join(", ") ?? "—",
                _formatFecha(i['fecha_reporte']),
                i['estado'] ?? "—",
              ];
            }).toList(),
          ),
        ],
      ),
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/reporte_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al generar PDF: $e")),
      );
    }
  }
}