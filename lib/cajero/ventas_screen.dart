import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_caja/app_theme.dart';
import '../../services/db_helper_cajero.dart';
import 'realizar_venta_screen.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final _formatoMoneda =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');

  List<Map<String, dynamic>> _ventas = [];
  Map<String, List<Map<String, dynamic>>> _detallesPorVenta = {};
  double _totalDia = 0;
  bool _cargando = true;
  bool _turnoCerrado = false;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  Future<void> _cargarVentas() async {
    setState(() => _cargando = true);
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final results = await Future.wait([
      DBHelperCajero.instance.obtenerVentasDelDia(hoy),
      DBHelperCajero.instance.esTurnoCerrado(),
    ]);
    if (!mounted) return;

    final data = results[0] as List<Map<String, dynamic>>;
    final turnoCerrado = results[1] as bool;
    double suma = 0;
    final Map<String, List<Map<String, dynamic>>> detalles = {};
    for (var v in data) {
      suma += (v['total'] as num).toDouble();
      final id = v['id_venta'].toString();
      detalles[id] = await DBHelperCajero.instance.obtenerDetallesDeVenta(id);
    }

    setState(() {
      _ventas = data;
      _detallesPorVenta = detalles;
      _totalDia = suma;
      _turnoCerrado = turnoCerrado;
      _cargando = false;
    });
  }

  Future<void> _irANuevaVenta() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RealizarVentaScreen()),
    );
    if (!mounted) return;
    if (resultado == true) _cargarVentas();
  }

  Future<void> _confirmarAnularVenta(String idVenta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular venta'),
        content: const Text(
            '¿Anular esta venta? El stock de los productos será devuelto.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Anular Venta'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    await DBHelperCajero.instance.eliminarVenta(idVenta);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Venta anulada. Stock devuelto.')),
    );
    _cargarVentas();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas de Hoy'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarVentas),
        ],
      ),
      body: Column(
        children: [
          _buildResumenDia(textTheme),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _ventas.isEmpty
                    ? _buildEmptyState(textTheme)
                    : RefreshIndicator(
                      onRefresh: _cargarVentas,
                      child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _ventas.length,
                          itemBuilder: (context, index) {
                            final venta = _ventas[index];
                            return _buildVentaCard(venta, textTheme);
                          },
                        ),
                    ),
          ),
        ],
      ),
      floatingActionButton: _turnoCerrado
          ? null
          : FloatingActionButton.extended(
              onPressed: _irANuevaVenta,
              label: const Text('NUEVA VENTA'),
              icon: const Icon(Icons.add_shopping_cart),
            ),
    );
  }

  Widget _buildResumenDia(TextTheme textTheme) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: AppTheme.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'TOTAL VENDIDO HOY',
              style: textTheme.labelLarge?.copyWith(color: AppTheme.primary)
            ),
            const SizedBox(height: 8),
            Text(
              _formatoMoneda.format(_totalDia),
              style: textTheme.displayLarge?.copyWith(color: AppTheme.primary)
            ),
            const SizedBox(height: 4),
            Text(
              '${_ventas.length} transacciones',
              style: textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            if (_turnoCerrado)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Chip(
                  avatar: const Icon(Icons.lock_clock, size: 16),
                  label: const Text('Turno cerrado'),
                  backgroundColor: Colors.orange.shade100,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 70, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Sin ventas hoy',
            style: textTheme.headlineSmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca "+ NUEVA VENTA" para empezar.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildVentaCard(Map<String, dynamic> venta, TextTheme textTheme) {
    final idVenta = venta['id_venta'].toString();
    final detalles = _detallesPorVenta[idVenta] ?? [];
    final fecha = DateFormat.jm().format(DateTime.parse(venta['fecha']));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Venta a las $fecha',
                style: textTheme.titleMedium,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0, left: 40),
          child: Text(
            _formatoMoneda.format(venta['total']),
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.accent)
          ),
        ),
        trailing: _turnoCerrado
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Anular venta',
              onPressed: () => _confirmarAnularVenta(idVenta),
            ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: detalles.map((d) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${d['nombre']} x${(d['cantidad'] as num).toInt()}',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        _formatoMoneda.format(d['precio'] * d['cantidad'] as num),
                        style: textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
