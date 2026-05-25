import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_caja/app_theme.dart';
import '../../models/venta.dart';
import '../../services/db_helper_cajero.dart';

class RealizarVentaScreen extends StatefulWidget {
  const RealizarVentaScreen({super.key});

  @override
  State<RealizarVentaScreen> createState() => _RealizarVentaScreenState();
}

class _RealizarVentaScreenState extends State<RealizarVentaScreen> {
  static const int maxProductosCarrito = 10; // Aumentado a 10

  final Map<int, Map<String, dynamic>> _carrito = {};
  List<Map<String, dynamic>> _productos = [];
  bool _cargando = false;
  bool _turnoCerrado = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final results = await Future.wait([
      DBHelperCajero.instance.obtenerProductosConStock(),
      DBHelperCajero.instance.esTurnoCerrado(),
    ]);
    if (!mounted) return;
    final data = results[0] as List<Map<String, dynamic>>;
    final turnoCerrado = results[1] as bool;
    setState(() {
      _turnoCerrado = turnoCerrado;
      _productos = turnoCerrado
          ? []
          : data
              .where((p) => (p['stockActual'] as num).toDouble() > 0)
              .toList();
    });
  }

  String _formatPrecio(num precio) {
    final p = precio.toDouble();
    return p == p.truncate() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
  }

  void _agregarAlCarrito(Map<String, dynamic> p) {
    final id = p['id'] as int;
    final stock = (p['stockActual'] as num).toDouble();

    if (!_carrito.containsKey(id) && _carrito.length >= maxProductosCarrito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo $maxProductosCarrito productos distintos por venta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      if (_carrito.containsKey(id)) {
        if (_carrito[id]!['cantidad'] < stock) {
          _carrito[id]!['cantidad']++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay más stock disponible')),
          );
        }
      } else {
        _carrito[id] = {
          'id': id,
          'nombre': p['nombre'],
          'precio': p['precioVenta'],
          'cantidad': 1.0,
          'stock': stock,
        };
      }
    });
  }

  void _quitarDelCarrito(int id) {
    setState(() {
      if (_carrito.containsKey(id)) {
        if (_carrito[id]!['cantidad'] > 1) {
          _carrito[id]!['cantidad']--;
        } else {
          _carrito.remove(id);
        }
      }
    });
  }

  Future<void> _confirmarVenta() async {
    if (_carrito.isEmpty) return;

    final turnoCerrado = await DBHelperCajero.instance.esTurnoCerrado();
    if (turnoCerrado) {
      if (!mounted) return;
      setState(() => _turnoCerrado = true);
      return;
    }

    setState(() => _cargando = true);

    final idVenta = const Uuid().v4();
    double totalVenta = 0;
    final detalles = <DetalleVenta>[];

    _carrito.forEach((id, item) {
      totalVenta += item['precio'] * item['cantidad'];
      detalles.add(DetalleVenta(
        idDetalle: const Uuid().v4(),
        idVenta: idVenta,
        productoId: id,
        cantidad: item['cantidad'],
        precio: item['precio'],
      ));
    });

    final venta = Venta(
      idVenta: idVenta,
      fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      total: totalVenta,
    );

    await DBHelperCajero.instance.realizarVenta(venta, detalles);
    if (!mounted) return;

    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Venta \$${_formatPrecio(totalVenta)} registrada ✓')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_turnoCerrado) {
      return _buildTurnoCerradoScaffold(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Venta Rápida'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _productos.isEmpty
                ? const Center(child: Text('No hay productos con stock.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9, 
                    ),
                    itemCount: _productos.length,
                    itemBuilder: (context, index) {
                      final p = _productos[index];
                      return _buildProductCard(p, textTheme);
                    },
                  ),
          ),
          _buildCarritoSheet(textTheme),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p, TextTheme textTheme) {
    final enCarrito = _carrito[p['id']]?['cantidad'] ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _agregarAlCarrito(p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Placeholder de imagen
            Container(
              height: 80,
              color: AppTheme.primary.withOpacity(0.1),
              child: const Icon(Icons.fastfood_outlined, color: AppTheme.primary, size: 40),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['nombre'],
                    style: textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_formatPrecio(p['precioVenta'] as num)}',
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            if (enCarrito > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: AppTheme.accent,
                child: Text(
                  'x${(enCarrito as double).toStringAsFixed(0)} en carrito',
                  style: textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildCarritoSheet(TextTheme textTheme) {
    final total = _carrito.values.fold<double>(0, (s, i) => s + i['precio'] * i['cantidad']);

    return Material(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_carrito.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text('Selecciona productos para agregarlos al carrito'),
              )
            else
              ..._carrito.values.map((item) {
                return ListTile(
                  dense: true,
                  title: Text(item['nombre'], style: textTheme.bodyMedium),
                  subtitle: Text('${(item['cantidad'] as double).toStringAsFixed(0)} x \$${_formatPrecio(item['precio'] as num)}'),
                  trailing: Text(
                    '\$${_formatPrecio(item['precio'] * item['cantidad'] as num)}',
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    onPressed: () => _quitarDelCarrito(item['id'] as int),
                  ),
                );
              }),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL:', style: textTheme.titleLarge),
                Text('\$${_formatPrecio(total)}', style: textTheme.titleLarge?.copyWith(color: AppTheme.accent, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cargando || _carrito.isEmpty ? null : _confirmarVenta,
                child: _cargando
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('CONFIRMAR VENTA'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnoCerradoScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Turno Cerrado'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock, color: Colors.orange, size: 56),
              ),
              const SizedBox(height: 24),
              Text('Turno cerrado', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text(
                'El cierre de caja ya fue exportado. No se pueden registrar más ventas hasta que el Admin inicie un nuevo día.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
