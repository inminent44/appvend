import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/db_helper_cajero.dart';
import 'realizar_venta_screen.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  static const Color primaryDark = Color(0xFF084B53);
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
    ]);
    if (!mounted) return;

    final data = results[0];
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

  Future<void> _confirmarEliminarVenta(String idVenta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular venta'),
        content: const Text(
            '¿Anular esta venta? El stock será devuelto automáticamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Anular'),
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

  Future<void> _editarVenta(String idVenta) async {
    final detalles = _detallesPorVenta[idVenta] ?? [];
    if (detalles.isEmpty || !mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _EditarDetallesSheet(
        idVenta: idVenta,
        detalles: detalles,
        onGuardado: _cargarVentas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas de Hoy'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarVentas),
        ],
      ),
      body: Column(
        children: [
          if (_turnoCerrado)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Turno cerrado. Ve a Cierre para iniciar un nuevo día.',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            // ignore: deprecated_member_use
            color: primaryDark.withOpacity(0.05),
            child: Column(
              children: [
                const Text('TOTAL VENDIDO HOY',
                    style: TextStyle(
                        fontSize: 14,
                        color: primaryDark,
                        fontWeight: FontWeight.bold)),
                Text(_formatoMoneda.format(_totalDia),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                Text('${_ventas.length} transacciones',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _ventas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            const Text('No hay ventas hoy',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _ventas.length,
                        itemBuilder: (context, index) {
                          final venta = _ventas[index];
                          final idVenta = venta['id_venta'].toString();
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 8, 0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.receipt_long,
                                          color: primaryDark, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Venta — ${venta['fecha']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: primaryDark)),
                                      const Spacer(),
                                      Text(
                                        _formatoMoneda.format(venta['total']),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.green),
                                      ),
                                      if (!_turnoCerrado) ...[
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red, size: 20),
                                          onPressed: () =>
                                              _confirmarEliminarVenta(idVenta),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Divider(height: 12),
                                ...(_detallesPorVenta[idVenta] ?? []).map((d) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 3),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: primaryDark,
                                          child: Text('${d['producto_id']}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(d['nombre'].toString(),
                                                style: const TextStyle(
                                                    fontSize: 13))),
                                        Text(
                                          'x${(d['cantidad'] as num).toInt()}  ${_formatoMoneda.format(d['precio'])} ',
                                          style: const TextStyle(
                                              fontSize: 13, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (!_turnoCerrado)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Editar'),
                                      onPressed: () => _editarVenta(idVenta),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _turnoCerrado
          ? null
          : FloatingActionButton.extended(
              onPressed: _irANuevaVenta,
              backgroundColor: primaryDark,
              label: const Text('NUEVA VENTA',
                  style: TextStyle(color: Colors.white)),
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
            ),
    );
  }
}

// ─── Widget hoja de edición ───────────────────────────────────────────────

class _EditarDetallesSheet extends StatefulWidget {
  final String idVenta;
  final List<Map<String, dynamic>> detalles;
  final VoidCallback onGuardado;

  const _EditarDetallesSheet({
    required this.idVenta,
    required this.detalles,
    required this.onGuardado,
  });

  @override
  State<_EditarDetallesSheet> createState() => _EditarDetallesSheetState();
}

class _EditarDetallesSheetState extends State<_EditarDetallesSheet> {
  late List<TextEditingController> _cantControllers;
  late List<TextEditingController> _idControllers;
  late List<Map<String, dynamic>> _detallesActuales;

  @override
  void initState() {
    super.initState();
    _detallesActuales = List.from(widget.detalles);
    _cantControllers = _detallesActuales
        .map((d) => TextEditingController(
            text: (d['cantidad'] as num).toInt().toString()))
        .toList();
    _idControllers = _detallesActuales
        .map((d) => TextEditingController(text: d['producto_id'].toString()))
        .toList();
  }

  @override
  void dispose() {
    for (var c in _cantControllers) {
      c.dispose();
    }
    for (var c in _idControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _buscarProducto(int index) async {
    final nuevoId = int.tryParse(_idControllers[index].text.trim());
    if (nuevoId == null) return;

    final productos = await DBHelperCajero.instance.obtenerProductosConStock();
    final encontrado =
        productos.firstWhere((p) => p['id'] == nuevoId, orElse: () => {});

    if (!mounted) return;

    if (encontrado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No existe producto con ID $nuevoId')),
      );
      _idControllers[index].text =
          _detallesActuales[index]['producto_id'].toString();
      return;
    }

    setState(() {
      _detallesActuales[index] = {
        ..._detallesActuales[index],
        'producto_id': nuevoId,
        'nombre': encontrado['nombre'],
        'precio': encontrado['precioVenta'],
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Editar venta',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Cambia el ID para cambiar el producto',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            ...List.generate(_detallesActuales.length, (i) {
              final d = _detallesActuales[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['nombre'].toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _idControllers[i],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: const InputDecoration(
                              labelText: 'ID producto',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                            ),
                            onSubmitted: (_) => _buscarProducto(i),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.search,
                              color: Color(0xFF084B53)),
                          onPressed: () => _buscarProducto(i),
                          tooltip: 'Buscar producto',
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: _cantControllers[i],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              labelText: 'Cant.',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF084B53),
                    foregroundColor: Colors.white),
                onPressed: () async {
                  for (var i = 0; i < _detallesActuales.length; i++) {
                    final dActual = _detallesActuales[i]; // estado actual en UI
                    final dOriginal = widget.detalles[i]; // snapshot al abrir

                    final nuevaCantidad = int.tryParse(
                      _cantControllers[i].text.replaceAll(',', '.'),
                    );
                    if (nuevaCantidad == null || nuevaCantidad <= 0) continue;

                    final productoIdAnterior = dOriginal['producto_id'] as int;
                    final cantidadAnterior =
                        (dOriginal['cantidad'] as num).toInt();
                    final productoIdNuevo = dActual['producto_id'] as int;
                    final nuevoPrecio = (dActual['precio'] as num).toDouble();

                    // Método unificado: maneja cambio de producto Y de cantidad
                    await DBHelperCajero.instance.actualizarProductoDetalle(
                      idDetalle: dOriginal['id_detalle'].toString(),
                      idVenta: widget.idVenta,
                      productoIdAnterior: productoIdAnterior,
                      cantidadAnterior: cantidadAnterior,
                      productoIdNuevo: productoIdNuevo,
                      nuevaCantidad: nuevaCantidad,
                      nuevoPrecio: nuevoPrecio,
                    );
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  widget.onGuardado();
                },
                child: const Text('GUARDAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}