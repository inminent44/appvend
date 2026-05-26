import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/venta.dart';
import '../../services/db_helper_cajero.dart';
import 'package:another_telephony/telephony.dart';
import 'package:vibration/vibration.dart';

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

  Future<Map<String, dynamic>?> _mostrarConfirmacion(double total) async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmacionVentaSheet(
        carrito: _carrito,
        total: total,
        formatPrecio: _formatPrecio,
      ),
    );
  }

  Future<void> _confirmarVenta() async {
    if (_carrito.isEmpty) return;

    final turnoCerrado = await DBHelperCajero.instance.esTurnoCerrado();
    if (turnoCerrado) {
      if (!mounted) return;
      setState(() => _turnoCerrado = true);
      _mostrarBloqueo();
      return;
    }

    final total = _carrito.values
        .fold<double>(0, (s, i) => s + i['precio'] * i['cantidad']);

    final resultado = await _mostrarConfirmacion(total);
    if (resultado == null || !mounted) return;

    setState(() => _cargando = true);

    final metodoPago = resultado['metodo'] as String;
    final idVenta = const Uuid().v4();
    final detalles = <DetalleVenta>[];

    _carrito.forEach((id, item) {
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
      total: total,
    );

    try {
      if (metodoPago == 'QR') {
        final plataforma    = resultado['plataforma']    as String;
        final idTransaccion = resultado['idTransaccion'] as String;
        final montoQR       = resultado['monto']         as double;
        final moneda        = resultado['moneda']        as String;
        final fechaSms      = resultado['fechaSms']      as String?;

        await DBHelperCajero.instance.realizarVentaQR(
          venta:         venta,
          detalles:      detalles,
          plataforma:    plataforma,
          idTransaccion: idTransaccion,
          montoQR:       montoQR,
          moneda:        moneda,
          fechaSms:      fechaSms,
        );
      } else {
        await DBHelperCajero.instance
            .realizarVenta(venta, detalles, metodoPago: metodoPago);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Venta \$${_formatPrecio(total)} — $metodoPago registrada ✓'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('DUPLICADO:')) {
        final idDuplicado =
            msg.replaceFirst('Exception: DUPLICADO:', '').trim();
        _mostrarAlertaDuplicado(idDuplicado);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar la venta: $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarAlertaDuplicado(String idTransaccion) async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500, amplitude: 128);
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 50),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡PAGO DUPLICADO!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red),
            ),
            const SizedBox(height: 12),
            Text(
              'La transacción con ID #$idTransaccion ya fue registrada anteriormente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('ENTENDIDO',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _mostrarBloqueo() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Turno cerrado'),
          ],
        ),
        content: const Text(
          'El turno ya fue cerrado.\n\n'
          'No se pueden registrar más ventas hasta que el Admin inicie un nuevo día.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
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
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'El cierre de caja ya fue exportado.\nNo se pueden registrar más ventas hasta que el Admin inicie un nuevo día.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
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
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        icon:
                            const Icon(Icons.add_circle, color: primaryDark),
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

// ════════════════════════════════════════════════════════════════════════════
// Sheet de confirmación con selector de método de pago
// ════════════════════════════════════════════════════════════════════════════
class _ConfirmacionVentaSheet extends StatefulWidget {
  final Map<int, Map<String, dynamic>> carrito;
  final double total;
  final String Function(num) formatPrecio;

  const _ConfirmacionVentaSheet({
    required this.carrito,
    required this.total,
    required this.formatPrecio,
  });

  @override
  State<_ConfirmacionVentaSheet> createState() =>
      _ConfirmacionVentaSheetState();
}

class _ConfirmacionVentaSheetState extends State<_ConfirmacionVentaSheet> {
  static const Color primaryDark = Color(0xFF084B53);
  String _metodo = 'Efectivo';

  final _fmt =
      NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_MX');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),

            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: primaryDark.withAlpha(20), shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long,
                  color: primaryDark, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('Confirmar venta',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),

            ...widget.carrito.values.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            color: primaryDark.withAlpha(20),
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          child: Text(
                            (item['cantidad'] as double).toStringAsFixed(0),
                            style: const TextStyle(
                                color: primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item['nombre'],
                              style: const TextStyle(fontSize: 14))),
                      Text(
                        _fmt.format(item['precio'] * item['cantidad']),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1)),
                Text(
                  _fmt.format(widget.total),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'Efectivo',
                    label: Text('Efectivo'),
                    icon: Icon(Icons.money_rounded)),
                ButtonSegment(
                    value: 'Tarjeta',
                    label: Text('Tarjeta'),
                    icon: Icon(Icons.credit_card)),
                ButtonSegment(
                    value: 'QR',
                    label: Text('QR'),
                    icon: Icon(Icons.qr_code_2)),
              ],
              selected: {_metodo},
              onSelectionChanged: (s) => setState(() => _metodo = s.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: primaryDark,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: primaryDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (_metodo == 'QR') ...[
              const SizedBox(height: 16),
              _PagoPorQRPanel(
                totalEsperado: widget.total,
                onConfirmar: (datos) => Navigator.pop(context, {
                  'metodo': 'QR',
                  ...datos,
                }),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                      onPressed: () =>
                          Navigator.pop(context, {'metodo': _metodo}),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text('Confirmar',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Panel de pago por QR — Transfermóvil y EnZona
// ════════════════════════════════════════════════════════════════════════════
class _PagoPorQRPanel extends StatefulWidget {
  final double totalEsperado;
  final void Function(Map<String, dynamic> datos) onConfirmar;

  const _PagoPorQRPanel({
    required this.totalEsperado,
    required this.onConfirmar,
  });

  @override
  State<_PagoPorQRPanel> createState() => _PagoPorQRPanelState();
}

class _PagoPorQRPanelState extends State<_PagoPorQRPanel> {
  static const Color primaryDark = Color(0xFF084B53);

  String _plataforma = 'Transfermovil';
  String _moneda = 'CUP';

  final _idController    = TextEditingController();
  final _montoController = TextEditingController();

  bool _escaneandoSms = false;
  String? _advertencia;
  DateTime? _fechaSms;

  @override
  void dispose() {
    _idController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  // ─── Parseo RegEx para Transfermóvil ─────────────────────────────────────
  // Formato SMS Bandec/BPA:
  //   "La Transferencia fue completada.\nFecha: 22/5/2026\n
  //    Beneficiario: ...\nMonto: 50.00 CUP\nNro Transaccion:\nKW60108C12999"
  Map<String, String>? _parsearTransfermovil(String cuerpo) {
    try {
      final regExpId     = RegExp(r'Nro\s+Transaccion:\s*\n?\s*([A-Z0-9]+)', caseSensitive: false);
      final regExpMonto  = RegExp(r'Monto:\s*([\d.]+)');
      final regExpMoneda = RegExp(r'Monto:\s*[\d.]+\s*(CUP|MLC)', caseSensitive: false);
      final regExpFecha  = RegExp(r'Fecha:\s*(\d{1,2}/\d{1,2}/\d{4})');

      final matchId     = regExpId.firstMatch(cuerpo);
      final matchMonto  = regExpMonto.firstMatch(cuerpo);
      final matchMoneda = regExpMoneda.firstMatch(cuerpo);
      final matchFecha  = regExpFecha.firstMatch(cuerpo);

      if (matchId == null || matchMonto == null) return null;

      return {
        'id':     matchId.group(1)              ?? '',
        'monto':  matchMonto.group(1)           ?? '',
        'moneda': matchMoneda?.group(1)?.toUpperCase() ?? 'CUP',
        'fecha':  matchFecha?.group(1)          ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  // ─── Parseo RegEx para EnZona ─────────────────────────────────────────────
  // Formato SMS EnZona:
  //   "ENZONA pago recibido,\nImporte: 5000.00 CUP No.:\ni90xuwCuL9UU"
  Map<String, String>? _parsearEnZona(String cuerpo) {
    try {
      final regExpId     = RegExp(r'No\.?:?\s*\n?\s*([A-Za-z0-9_\-]+)');
      final regExpMonto  = RegExp(r'Importe:\s*([\d.]+)');
      final regExpMoneda = RegExp(r'Importe:\s*[\d.]+\s*(CUP|MLC)', caseSensitive: false);

      final matchId     = regExpId.firstMatch(cuerpo);
      final matchMonto  = regExpMonto.firstMatch(cuerpo);
      final matchMoneda = regExpMoneda.firstMatch(cuerpo);

      if (matchId == null || matchMonto == null) return null;

      return {
        'id':     matchId.group(1)              ?? '',
        'monto':  matchMonto.group(1)           ?? '',
        'moneda': matchMoneda?.group(1)?.toUpperCase() ?? 'CUP',
        'fecha':  '',
      };
    } catch (_) {
      return null;
    }
  }

  // ─── Escanear SMS ─────────────────────────────────────────────────────────
  Future<void> _escanearSms() async {
    setState(() {
      _escaneandoSms = true;
      _advertencia   = null;
    });

    try {
      final telephony = Telephony.instance;

      final bool? permiso = await telephony.requestPhoneAndSmsPermissions;
      if (permiso != true) {
        setState(() => _advertencia =
            'Permiso de SMS denegado. Actívalo en Ajustes.');
        return;
      }

      final remitente = _plataforma == 'Transfermovil'
          ? 'PAGOxMOVIL' // remitente oficial Transfermóvil (Bandec/BPA)
          : 'EnZona';    // remitente oficial EnZona

      final List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals(remitente),
      );

      if (messages.isEmpty) {
        setState(() => _advertencia =
            'No se encontraron mensajes de $remitente en la bandeja.');
        return;
      }

      final ultimo = messages.first;
      final cuerpo = ultimo.body ?? '';

      // Validación de tiempo: alerta si el SMS tiene más de 15 minutos
      if (ultimo.date != null) {
        final horaSms =
            DateTime.fromMillisecondsSinceEpoch(ultimo.date!);
        _fechaSms = horaSms;
        final minutos = DateTime.now().difference(horaSms).inMinutes;
        if (minutos > 15) {
          setState(() => _advertencia =
              '⚠ Este SMS fue recibido hace $minutos minutos. Verifique que sea el pago actual.');
        }
      }

      final datos = _plataforma == 'Transfermovil'
          ? _parsearTransfermovil(cuerpo)
          : _parsearEnZona(cuerpo);

      if (datos == null) {
        setState(() => _advertencia =
            'No se pudo leer el formato del SMS. Ingrese el ID manualmente.');
        return;
      }

      // Vibración suave de confirmación
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 80, amplitude: 60);
      }

      setState(() {
        _idController.text    = datos['id']    ?? '';
        _montoController.text = datos['monto'] ?? '';
        _moneda               = datos['moneda'] ?? 'CUP';
      });
    } catch (e) {
      setState(() => _advertencia = 'Error al leer SMS: $e');
    } finally {
      setState(() => _escaneandoSms = false);
    }
  }

  // ─── Validar y confirmar ──────────────────────────────────────────────────
  void _confirmar() {
    final id    = _idController.text.trim();
    final monto = double.tryParse(_montoController.text.trim());

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ingresa el ID de transacción'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ingresa un monto válido'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    widget.onConfirmar({
      'plataforma':    _plataforma,
      'idTransaccion': id,
      'monto':         monto,
      'moneda':        _moneda,
      'fechaSms': _fechaSms != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(_fechaSms!)
          : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ────────────────────────────────────────────────
          const Row(
            children: [
              Icon(Icons.qr_code_2, color: primaryDark, size: 20),
              SizedBox(width: 8),
              Text('Datos del pago QR',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: primaryDark)),
            ],
          ),
          const SizedBox(height: 14),

          // ── Selector de plataforma ────────────────────────────────────
          const Text('Plataforma',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Transfermovil',
                label: Text('Transfermóvil'),
                icon: Icon(Icons.phone_android, size: 16),
              ),
              ButtonSegment(
                value: 'EnZona',
                label: Text('EnZona'),
                icon: Icon(Icons.qr_code, size: 16),
              ),
            ],
            selected: {_plataforma},
            onSelectionChanged: (s) => setState(() {
              _plataforma = s.first;
              _idController.clear();
              _montoController.clear();
              _advertencia = null;
              _fechaSms    = null;
            }),
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryDark,
              selectedForegroundColor: Colors.white,
              selectedBackgroundColor: primaryDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),

          // ── Botón escanear SMS ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryDark,
                side: const BorderSide(color: primaryDark),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _escaneandoSms ? null : _escanearSms,
              icon: _escaneandoSms
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: primaryDark))
                  : const Icon(Icons.sms_outlined, size: 18),
              label: Text(_escaneandoSms
                  ? 'Leyendo SMS...'
                  : 'Escanear último SMS de $_plataforma'),
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.teal.shade200)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('o ingresa manualmente',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ),
                Expanded(child: Divider(color: Colors.teal.shade200)),
              ],
            ),
          ),

          // ── Campo ID de transacción (alfanumérico) ────────────────────
          const Text('ID de Transacción',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _idController,
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: _plataforma == 'Transfermovil'
                  ? 'Ej: KW60108C12999'
                  : 'Ej: i90xuwCuL9UU',
              prefixIcon: const Icon(Icons.confirmation_number_outlined,
                  color: primaryDark),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.teal.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: primaryDark, width: 2)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // ── Fila: Monto + Moneda ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monto recibido',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _montoController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.attach_money,
                            color: primaryDark),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: primaryDark, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Moneda',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _moneda,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'CUP',
                              child: Row(children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                const Text('CUP',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ]),
                            ),
                            DropdownMenuItem(
                              value: 'MLC',
                              child: Row(children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                const Text('MLC',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _moneda = v ?? 'CUP'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Advertencia ───────────────────────────────────────────────
          if (_advertencia != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_advertencia!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orange)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Botón Confirmar pago QR ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: _confirmar,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Confirmar pago QR',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}