// lib/vendedor/screens/cuenta_detalle_screen.dart
//
// Pantalla de detalle de una cuenta abierta.
// Permite agregar/quitar productos y cobrar.
//
// El stock se descuenta al agregar (en DBHelper.agregarItemCuenta)
// y se devuelve al quitar o cancelar.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/cuenta_abierta.dart';
import '../services/db_helper.dart';

class CuentaDetalleScreen extends StatefulWidget {
  final String cuentaId;

  const CuentaDetalleScreen({super.key, required this.cuentaId});

  @override
  State<CuentaDetalleScreen> createState() => _CuentaDetalleScreenState();
}

class _CuentaDetalleScreenState extends State<CuentaDetalleScreen> {
  static const Color primaryDark = Color(0xFF084B53);

  CuentaAbierta? _cuenta;
  List<Map<String, dynamic>> _productos = [];
  bool _cargando = true;
  bool _procesando = false;
  bool _turnoCerrado = false;

  // Tab: 0 = Pedido actual, 1 = Agregar productos

  final _formatoMoneda =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _productosFiltrados = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final results = await Future.wait([
      DBHelper.instance.recargarCuenta(widget.cuentaId),
      DBHelper.instance.obtenerProductosConStock(),
      DBHelper.instance.esTurnoCerrado(),
    ]);
    if (!mounted) return;

    final cuenta = results[0] as CuentaAbierta?;
    if (cuenta == null) {
      // La cuenta fue cobrada/cancelada externamente
      if (mounted) Navigator.pop(context);
      return;
    }

    final prods = (results[1] as List<Map<String, dynamic>>)
        .where((p) => (p['stockActual'] as num).toDouble() > 0)
        .toList();

    setState(() {
      _cuenta = cuenta;
      _productos = prods;
      _productosFiltrados = prods;
      _turnoCerrado = results[2] as bool;
      _cargando = false;
    });
  }

  void _filtrar(String query) {
    setState(() {
      _productosFiltrados = _productos
          .where((p) => p['nombre']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  // ── Agregar producto ──────────────────────────────────────────────────────

  Future<void> _agregar(Map<String, dynamic> p, {double cantidad = 1}) async {
    if (_procesando) return;
    setState(() => _procesando = true);
    try {
      await DBHelper.instance.agregarItemCuenta(
        cuentaId: widget.cuentaId,
        productoId: p['id'] as int,
        nombreProducto: p['nombre'] as String,
        cantidad: cantidad,
        precio: (p['precioVenta'] as num).toDouble(),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ── Editar cantidad manualmente ───────────────────────────────────────────

  Future<void> _editarCantidad(Map<String, dynamic> p) async {
    final id = p['id'] as int;
    final stock = (p['stockActual'] as num).toDouble();
    // Stock disponible = stock en BD + lo que ya tiene en la cuenta
    final enCuenta = _cuenta!.items
        .firstWhere((i) => i.productoId == id,
            orElse: () => ItemCuenta(
                productoId: id, nombre: '', cantidad: 0, precio: 0))
        .cantidad;
    final stockTotal = stock + enCuenta; // stock real

    final controller = TextEditingController(
        text: enCuenta > 0 ? enCuenta.toStringAsFixed(0) : '');

    final nueva = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p['nombre']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Disponible: ${stockTotal.toStringAsFixed(0)}',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13)),
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
                backgroundColor: primaryDark,
                foregroundColor: Colors.white),
            onPressed: () {
              final v = double.tryParse(controller.text);
              Navigator.pop(context, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (nueva == null || nueva < 0) return;
    if (nueva > stockTotal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantidad supera el stock disponible')),
      );
      return;
    }

    setState(() => _procesando = true);
    try {
      // Primero devolver todo el stock de ese item
      if (enCuenta > 0) {
        await DBHelper.instance.quitarItemCuenta(
          cuentaId: widget.cuentaId,
          productoId: id,
          cantidad: enCuenta,
        );
      }
      // Luego agregar la nueva cantidad (si es > 0)
      if (nueva > 0) {
        // Recargar producto para ver stock actualizado
        final prods = await DBHelper.instance.obtenerProductosConStock();
        prods.firstWhere((pp) => pp['id'] == id,
            orElse: () => p);
        await DBHelper.instance.agregarItemCuenta(
          cuentaId: widget.cuentaId,
          productoId: id,
          nombreProducto: p['nombre'] as String,
          cantidad: nueva,
          precio: (p['precioVenta'] as num).toDouble(),
        );
      }
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ── Quitar producto ───────────────────────────────────────────────────────

  Future<void> _quitar(int productoId) async {
    if (_procesando) return;
    setState(() => _procesando = true);
    try {
      await DBHelper.instance.quitarItemCuenta(
        cuentaId: widget.cuentaId,
        productoId: productoId,
        cantidad: 1,
      );
      await _cargar();
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ── Cobrar ────────────────────────────────────────────────────────────────

  Future<void> _cobrar() async {
    if (_cuenta == null || _cuenta!.items.isEmpty) return;

    if (_turnoCerrado) {
      _mostrarTurnoCerrado();
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cobro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cuenta: ${_cuenta!.nombre}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._cuenta!.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.nombre} x${item.cantidad.toStringAsFixed(0)}'),
                      Text(_formatoMoneda.format(item.subtotal)),
                    ],
                  ),
                )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _formatoMoneda.format(_cuenta!.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: primaryDark),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('COBRAR'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      await DBHelper.instance.cobrarCuenta(_cuenta!);
      if (!mounted) return;
      final total = _cuenta!.total;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cobrado ${_formatoMoneda.format(total)} — ${_cuenta!.nombre} ✓'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cobrar: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _mostrarTurnoCerrado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.lock_clock, color: Colors.orange),
          SizedBox(width: 8),
          Text('Turno cerrado'),
        ]),
        content: const Text(
            'No se puede cobrar con el turno cerrado.\n'
            'Ve a Cierre → Iniciar Nuevo Día.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Cargando…'),
            backgroundColor: primaryDark,
            foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final cuenta = _cuenta!;

    return Scaffold(
      appBar: AppBar(
        title: Text(cuenta.nombre),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              text: cuenta.items.isEmpty
                  ? 'Pedido'
                  : 'Pedido (${cuenta.items.length})',
            ),
            const Tab(text: 'Agregar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _pedidoTab(cuenta),
          _agregarTab(),
        ],
      ),
      bottomNavigationBar: cuenta.items.isEmpty
          ? null
          : _bottomBar(cuenta),
    );
  }

  // Tab controller lazy init
  TabController? _tabControllerInstance;
  TabController get _tabController {
    _tabControllerInstance ??= TabController(length: 2, vsync: _vsync)
      ..addListener(() {
        if (mounted) {}
      });
    return _tabControllerInstance!;
  }

  // Dummy TickerProvider
  final _vsync = _DummyVsync();

  // ── Tab pedido actual ─────────────────────────────────────────────────────

  Widget _pedidoTab(CuentaAbierta cuenta) {
    if (cuenta.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_shopping_cart,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Pedido vacío',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('Ir a Agregar →'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: cuenta.items.length,
      itemBuilder: (context, i) {
        final item = cuenta.items[i];
        // Buscar stock disponible para este producto
        final prod = _productos.firstWhere(
          (p) => p['id'] == item.productoId,
          orElse: () => <String, dynamic>{},
        );
        final stockDisp = prod.isEmpty
            ? 0.0
            : (prod['stockActual'] as num).toDouble();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      Text(
                        '${_formatoMoneda.format(item.precio)} c/u',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Controles cantidad
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red, size: 22),
                  onPressed:
                      _procesando ? null : () => _quitar(item.productoId),
                ),
                GestureDetector(
                  onTap: prod.isEmpty
                      ? null
                      : () => _editarCantidad(prod),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: primaryDark),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.cantidad.toStringAsFixed(0),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: primaryDark, size: 22),
                  onPressed: (prod.isEmpty || stockDisp <= 0 || _procesando)
                      ? null
                      : () => _agregar(prod),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    _formatoMoneda.format(item.subtotal),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab agregar productos ─────────────────────────────────────────────────

  Widget _agregarTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Buscar producto…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _filtrar,
          ),
        ),
        Expanded(
          child: _productosFiltrados.isEmpty
              ? const Center(
                  child: Text('Sin productos con stock',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _productosFiltrados.length,
                  itemBuilder: (context, i) {
                    final p = _productosFiltrados[i];
                    final id = p['id'] as int;
                    final stock =
                        (p['stockActual'] as num).toDouble();
                    final precio =
                        (p['precioVenta'] as num).toDouble();
                    final enCuenta = _cuenta!.items
                        .firstWhere((item) => item.productoId == id,
                            orElse: () => ItemCuenta(
                                productoId: id,
                                nombre: '',
                                cantidad: 0,
                                precio: 0))
                        .cantidad
                        .toInt();

                    return ListTile(
                      title: Text(p['nombre']),
                      subtitle: Text(
                        'Stock: ${stock.toStringAsFixed(0)}'
                        '${enCuenta > 0 ? ' · En pedido: $enCuenta' : ''}',
                        style: TextStyle(
                            color: stock > 0
                                ? Colors.grey
                                : Colors.red,
                            fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${precio == precio.truncate() ? precio.toStringAsFixed(0) : precio.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: primaryDark),
                            onPressed:
                                (stock <= 0 || _procesando)
                                    ? null
                                    : () => _agregar(p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Barra inferior con total y botón cobrar ───────────────────────────────

  Widget _bottomBar(CuentaAbierta cuenta) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cuenta.cantidadItems} item(s)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  _formatoMoneda.format(cuenta.total),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryDark),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _turnoCerrado ? Colors.grey : primaryDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed:
                  (_procesando || _turnoCerrado) ? null : _cobrar,
              icon: const Icon(Icons.point_of_sale),
              label: const Text('COBRAR',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TickerProvider mínimo para TabController ─────────────────────────────

class _DummyVsync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
