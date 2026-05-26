import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/venta.dart';
import '../../services/db_helper_cajero.dart';

class RealizarVentaScreen extends StatefulWidget {
  const RealizarVentaScreen({super.key});

  @override
  State<RealizarVentaScreen> createState() => _RealizarVentaScreenState();
}

class _RealizarVentaScreenState extends State<RealizarVentaScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  static const int maxProductosCarrito = 8;

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
    ]);
    if (!mounted) return;
    final data = results[0];
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

    // Verificar límite de productos distintos
    if (!_carrito.containsKey(id) &&
        _carrito.length >= maxProductosCarrito) {
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

  void _editarCantidadManual(Map<String, dynamic> p) {
    final id = p['id'] as int;
    final stock = (p['stockActual'] as num).toDouble();
    final cantActual = _carrito[id]?['cantidad'] ?? 0.0;
    final controller = TextEditingController(
        text: cantActual > 0 ? (cantActual as double).toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p['nombre']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stock disponible: ${stock.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark, foregroundColor: Colors.white),
            onPressed: () {
              final nueva = double.tryParse(controller.text);
              if (nueva == null || nueva <= 0) {
                Navigator.pop(context);
                return;
              }
              if (nueva > stock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cantidad supera el stock')),
                );
                return;
              }
              setState(() {
                _carrito[id] = {
                  'id': id,
                  'nombre': p['nombre'],
                  'precio': p['precioVenta'],
                  'cantidad': nueva,
                  'stock': stock,
                };
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarVenta() async {
    if (_carrito.isEmpty) return;

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
      SnackBar(
          content: Text(
              'Venta \$${_formatPrecio(totalVenta)} registrada ✓')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _carrito.values
        .fold<double>(0, (s, i) => s + i['precio'] * i['cantidad']);

    if (_turnoCerrado) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nueva Venta'),
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
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
                  child: const Icon(Icons.lock_clock,
                      color: Colors.orange, size: 56),
                ),
                const SizedBox(height: 24),
                const Text('Turno cerrado',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'El cierre de caja ya fue exportado.\nNo se pueden registrar más ventas hasta que el Admin inicie un nuevo día.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryDark,
                      side: const BorderSide(color: primaryDark),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Venta'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Banner límite carrito
          if (_carrito.length >= maxProductosCarrito)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Text(
                'Límite de $maxProductosCarrito productos distintos alcanzado.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _productos.length,
              itemBuilder: (context, index) {
                final p = _productos[index];
                final id = p['id'] as int;
                final enCarrito = _carrito[id]?['cantidad'] ?? 0;
                final precio = (p['precioVenta'] as num);

                return ListTile(
                  title: Text(p['nombre']),
                  subtitle: Text(
                      'Stock: ${(p['stockActual'] as num).toStringAsFixed(0)} — \$${_formatPrecio(precio)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (enCarrito > 0) ...[
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () => _quitarDelCarrito(id),
                        ),
                        GestureDetector(
                          onTap: () => _editarCantidadManual(p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: primaryDark),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (enCarrito as double).toStringAsFixed(0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: primaryDark),
                        onPressed: () => _agregarAlCarrito(p),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_carrito.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_carrito.length}/$maxProductosCarrito producto(s) en carrito',
                      style: const TextStyle(color: Colors.grey)),
                  ..._carrito.values.map((item) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['nombre']),
                          Text(
                              'x${(item['cantidad'] as double).toStringAsFixed(0)}  \$${_formatPrecio((item['precio'] * item['cantidad']) as num)}'),
                        ],
                      )),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ITEMS: ${_carrito.length}',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    Text('TOTAL: \$${_formatPrecio(total)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white),
                    onPressed: _cargando || _carrito.isEmpty
                        ? null
                        : _confirmarVenta,
                    child: _cargando
                        ? const CircularProgressIndicator(
                            color: Colors.white)
                        : const Text('CONFIRMAR VENTA'),
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
