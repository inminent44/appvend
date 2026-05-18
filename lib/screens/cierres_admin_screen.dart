import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/db_helper.dart';

class CierresAdminScreen extends StatefulWidget {
  const CierresAdminScreen({super.key});

  @override
  State<CierresAdminScreen> createState() => _CierresAdminScreenState();
}

class _CierresAdminScreenState extends State<CierresAdminScreen> {
  static const Color primaryDark = Color(0xFF084B53);

  // ── Formatos ───────────────────────────────────────────────────────────────
  // Moneda con separador de miles y 2 decimales: $10,000.00
  final _formatoMoneda = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
    locale: 'en_US', // coma como separador de miles, punto decimal
  );

  List<Map<String, dynamic>> _historial = [];
  double _totalHoy = 0.0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    final data = await DBHelper.instance.obtenerHistorialCierres();
    final totalHoy = await DBHelper.instance.obtenerTotalVentasHoy();

    if (!mounted) return;
    setState(() {
      _historial = data;
      _totalHoy = totalHoy;
      _cargando = false;
    });
  }

  Future<void> _importarArchivo() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    final path = result.files.single.path;
    if (path == null) return;

    try {
      await DBHelper.instance.importarCierreCaja(File(path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cierre importado y stock actualizado ✓')),
      );
      _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _verDetalle(String fechaImp) async {
    final resumen = await DBHelper.instance.obtenerResumenPorFecha(fechaImp);
    if (!mounted) return;

    final detalle = resumen['detalle'] as List<dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Detalle del cierre — $fechaImp',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryDark)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _chipResumen(
                      'Ventas', '${resumen['numeroVentas']}', Colors.blue),
                  const SizedBox(width: 10),
                  _chipResumen(
                      'Total',
                      _formatoMoneda.format(resumen['totalVentas']),
                      Colors.green),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: detalle.length,
                  itemBuilder: (context, i) {
                    final item = detalle[i];
                    return ListTile(
                      title: Text(item['nombre']),
                      subtitle: Text(
                        'Cant: ${_formatearCantidad(item['cantidadTotal'])}',
                      ),
                      trailing: Text(
                        _formatoMoneda.format(item['totalVendido']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formatea cantidades: sin decimales si es entero, con 2 si tiene fracción.
  String _formatearCantidad(dynamic valor) {
    final d = (valor as num).toDouble();
    return d == d.truncateToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(2);
  }

  Widget _chipResumen(String label, String valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          // ignore: deprecated_member_use
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            Text(valor,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  // ── Card: total del día ────────────────────────────────────────────────────
  Widget _cardTotalHoy() {
    final hoy = DateFormat('d MMM yyyy', 'es').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF084B53), Color(0xFF0D7A87)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: const Color(0xFF084B53).withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícono
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.today_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ventas del día · $hoy',
                    style: TextStyle(
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        letterSpacing: 0.4)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatoMoneda.format(_totalHoy),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierres Recibidos'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Card total del día ──────────────────────────────────────────
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            _cardTotalHoy(),

          // ── Botón importar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _importarArchivo,
                icon: const Icon(Icons.file_open),
                label: const Text('IMPORTAR CIERRE DEL VENDEDOR (.gv)'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDark,
                    foregroundColor: Colors.white),
              ),
            ),
          ),

          const Divider(height: 24),

          // ── Historial ───────────────────────────────────────────────────
          Expanded(
            child: _cargando
                ? const SizedBox()
                : _historial.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 80, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Aún no hay cierres importados',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historial.length,
                        itemBuilder: (context, index) {
                          final item = _historial[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: primaryDark,
                              child: Icon(Icons.receipt_long,
                                  color: Colors.white, size: 18),
                            ),
                            title: Text(item['archivo'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('Importado: ${item['fecha_imp']}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _verDetalle(item['fecha_imp']),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
