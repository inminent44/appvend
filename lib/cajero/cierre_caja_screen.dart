// lib/vendedor/screens/cierre_caja_screen.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/db_helper_cajero.dart';

class CierreCajaScreen extends StatefulWidget {
  const CierreCajaScreen({super.key});

  @override
  State<CierreCajaScreen> createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  static const Color primaryDark = Color(0xFF084B53);

  final _fmtMoneda =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');
  final _fmtFecha = DateFormat('dd/MM/yyyy');

  Map<String, dynamic>? _resumen;
  bool _cargando  = false;
  bool _operando  = false; // spinner genérico para acciones

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final resumen = await DBHelperCajero.instance.obtenerResumenCierre();
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _snack('Error al cargar datos: $e');
    }
  }

  // ─── Exportar cierre ───────────────────────────────────────────────────

  Future<void> _exportarCierre() async {
    setState(() => _operando = true);
    try {
      await DBHelperCajero.instance.exportarCierreCaja();
      if (!mounted) return;
      _snack('Cierre exportado ✓', color: Colors.green);
    } catch (e) {
      if (!mounted) return;
      _snack('Error al exportar: $e');
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  // ─── Importar inventario ───────────────────────────────────────────────

  Future<void> _importarInventario() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _operando = true);
    try {
      final file = File(result.files.single.path!);
      await DBHelperCajero.instance.importarInventarioAdmin(file);
      if (!mounted) return;
      _snack('Inventario importado ✓', color: Colors.green);
      await _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      _snack('Error: ${e.toString().replaceFirst('Exception: ', '')}',
          color: Colors.red);
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  // ─── Importar cierre de turno anterior ────────────────────────────────

  Future<void> _importarCierreTurno() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _operando = true);
    try {
      final file = File(result.files.single.path!);
      final n = await DBHelperCajero.instance.importarCierreTurno(file);
      if (!mounted) return;
      _snack('Cierre importado: $n producto(s) descontados ✓',
          color: Colors.green);
      await _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      _snack('Error: ${e.toString().replaceFirst('Exception: ', '')}',
          color: Colors.red);
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoy     = DateTime.now();
    final detalle = _resumen?['detalle']   as List<dynamic>? ?? [];
    final hayVentas = (_resumen?['numeroVentas'] as int? ?? 0) > 0;
    final porMetodo = _resumen?['porMetodo'] as List<dynamic>? ?? [];
    final porMoneda = _resumen?['porMoneda'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de Caja'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fecha ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmtFecha.format(hoy),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.calendar_today,
                          color: Colors.grey, size: 20),
                    ],
                  ),
                  const Divider(height: 30),

                  // ── Tarjetas totales ─────────────────────────────────
                  Row(
                    children: [
                      _buildCard(
                        'Total Ventas (CUP)',
                        _fmtMoneda.format(_resumen?['totalVentas'] ?? 0),
                        Icons.attach_money,
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _buildCard(
                        'Cant. Ventas',
                        '${_resumen?['numeroVentas'] ?? 0}',
                        Icons.shopping_bag,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Desglose por método de pago ──────────────────────
                  if (porMetodo.isNotEmpty) ...[
                    const Text('Por método de pago',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryDark)),
                    const SizedBox(height: 8),
                    ...porMetodo.map((m) => _metodoPagoRow(m)),
                    const SizedBox(height: 20),
                  ],

                  // ── Desglose por moneda ──────────────────────────────
                  if (porMoneda.isNotEmpty) ...[
                    const Text('Por moneda',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryDark)),
                    const SizedBox(height: 8),
                    ...porMoneda.map((m) => _monedaRow(m)),
                    const SizedBox(height: 20),
                  ],

                  // ── Productos vendidos ───────────────────────────────
                  const Text('Productos Vendidos Hoy',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryDark)),
                  const SizedBox(height: 10),
                  detalle.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child:
                                  Text('No hay ventas registradas hoy',
                                      style: TextStyle(color: Colors.grey))),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: detalle.length,
                          itemBuilder: (context, index) {
                            final item = detalle[index];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                title: Text(item['nombre'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    'Cant: ${(item['cantidadTotal'] as num).toStringAsFixed(0)}'),
                                trailing: Text(
                                  _fmtMoneda.format(item['totalVendido']),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 24),

                  // ── Botón importar inventario ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _operando ? null : _importarInventario,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B7A84),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _operando
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.inventory_2_outlined),
                      label: Text(
                        _operando ? 'PROCESANDO...' : 'IMPORTAR INVENTARIO',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Importa el archivo .gv del Admin para actualizar productos y stock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Botón exportar cierre ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: (!hayVentas || _operando) ? null : _exportarCierre,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _operando
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.share),
                      label: Text(
                        _operando ? 'EXPORTANDO...' : 'EXPORTAR CIERRE AL ADMIN',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Envía este archivo al Admin para actualizar el inventario.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── Botón importar cierre de turno anterior ───────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _operando ? null : _importarCierreTurno,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _operando
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.download_for_offline_outlined),
                      label: Text(
                        _operando ? 'IMPORTANDO...' : 'IMPORTAR CIERRE DE TURNO',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Importa el cierre del turno anterior para descontar su stock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _metodoPagoRow(dynamic m) {
    const iconos = {
      'efectivo': Icons.payments_outlined,
      'tarjeta':  Icons.credit_card_outlined,
      'qr':       Icons.qr_code_outlined,
    };
    const colores = {
      'efectivo': Colors.green,
      'tarjeta':  Colors.blue,
      'qr':       Colors.purple,
    };
    final metodo   = m['metodo_pago'] as String? ?? 'efectivo';
    final totalCup = (m['totalCUP'] as num).toDouble();
    final cant     = (m['cantidad'] as num).toInt();
    final color    = colores[metodo] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(iconos[metodo] ?? Icons.attach_money, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _etiquetaMetodo(metodo),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text('$cant venta${cant != 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 10),
          Text(
            _fmtMoneda.format(totalCup),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _monedaRow(dynamic m) {
    final moneda     = m['moneda'] as String? ?? 'CUP';
    final totalCup   = (m['totalCUP'] as num).toDouble();
    final totalMon   = (m['totalMoneda'] as num).toDouble();
    final tasa       = (m['tasa'] as num?)?.toDouble() ?? 1.0;
    final cant       = (m['cantidad'] as num).toInt();
    final emojis     = {'CUP': '🇨🇺', 'USD': '🇺🇸', 'EUR': '🇪🇺', 'CAD': '🇨🇦'};

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(emojis[moneda] ?? '💱', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(moneda,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (moneda != 'CUP')
                  Text(
                    '${totalMon.toStringAsFixed(2)} $moneda · 1 $moneda = ${tasa.toStringAsFixed(0)} CUP',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text('$cant',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 10),
          Text(
            _fmtMoneda.format(totalCup),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryDark,
                fontSize: 15),
          ),
        ],
      ),
    );
  }

  String _etiquetaMetodo(String m) {
    switch (m) {
      case 'tarjeta': return 'Tarjeta';
      case 'qr':      return 'QR / Transferencia';
      default:        return 'Efectivo';
    }
  }

  Widget _buildCard(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color),
            const SizedBox(height: 8),
            Text(titulo,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            Text(valor,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}