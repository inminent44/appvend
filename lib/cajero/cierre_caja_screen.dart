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

  final _formatoMoneda =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');
  final _formatoFecha = DateFormat('dd/MM/yyyy');

  Map<String, dynamic>? _resumen;
  bool _cargando = false;
  bool _turnoCerrado = false;
  bool _importando = false; // Nueva variable de estado

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        DBHelperCajero.instance.obtenerResumenCierre(),
        DBHelperCajero.instance.esTurnoCerrado(),
      ]);
      if (!mounted) return;
      setState(() {
        _resumen = results[0] as Map<String, dynamic>;
        _turnoCerrado = results[1] as bool;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  Future<void> _exportarCierre() async {
    setState(() => _importando = true);
    try {
      await DBHelperCajero.instance.exportarCierreCaja();
      if (!mounted) return;
      await _cargarDatos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cierre exportado y turno cerrado ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    } finally {
      if(mounted) {
        setState(() => _importando = false);
      }
    }
  }

  Future<void> _importarCierreTurno() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _importando = true);
    try {
      final file = File(result.files.single.path!);
      final productosRebajados =
          await DBHelperCajero.instance.importarCierreTurno(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cierre importado: $productosRebajados producto(s) descontados ✓'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      await _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final detalle = _resumen?['detalle'] as List<dynamic>? ?? [];
    final hayVentas = (_resumen?['numeroVentas'] as int? ?? 0) > 0;

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
                  // ── Banner turno cerrado ──────────────────────────────
                  if (_turnoCerrado)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_clock, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Turno cerrado.',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Fecha ─────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatoFecha.format(hoy),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.calendar_today,
                          color: Colors.grey, size: 20),
                    ],
                  ),
                  const Divider(height: 30),

                  // ── Tarjetas resumen ──────────────────────────────────
                  Row(
                    children: [
                      _buildCard(
                        'Total Ventas',
                        _formatoMoneda.format(_resumen?['totalVentas'] ?? 0),
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
                  const SizedBox(height: 30),

                  // ── Detalle productos vendidos ────────────────────────
                  const Text(
                    'Productos Vendidos Hoy',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryDark),
                  ),
                  const SizedBox(height: 10),
                  detalle.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                              child: Text('No hay ventas registradas hoy')),
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
                                  _formatoMoneda.format(item['totalVendido']),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 30),

                  // ── Botón exportar cierre ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: (!hayVentas || _turnoCerrado || _importando)
                          ? null
                          : _exportarCierre,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _importando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                            )
                          : const Icon(Icons.share),
                      label: Text(
                        _importando ? 'EXPORTANDO...' : 'EXPORTAR CIERRE AL ADMIN',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _turnoCerrado
                          ? 'El cierre ya fue exportado hoy.'
                          : 'Envía este archivo al Admin para actualizar el inventario.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── Botón importar cierre de turno anterior ───────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _importando ? null : _importarCierreTurno,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B7A84),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _importando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.download_for_offline_outlined),
                      label: Text(
                        _importando ? 'IMPORTANDO...' : 'IMPORTAR CIERRE DE TURNO',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Importa el cierre del turno anterior para actualizar tu inventario.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(
      String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color),
            const SizedBox(height: 10),
            Text(titulo,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text(valor,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
