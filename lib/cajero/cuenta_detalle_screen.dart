import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/cuenta_abierta.dart';
import '../../services/db_helper_cajero.dart';

class CuentaDetalleScreen extends StatefulWidget {
  final String cuentaId;
  const CuentaDetalleScreen({super.key, required this.cuentaId});

  @override
  State<CuentaDetalleScreen> createState() => _CuentaDetalleScreenState();
}

class _CuentaDetalleScreenState extends State<CuentaDetalleScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  static const Color primaryMid = Color(0xFF0A6B77);
  static const Color bgPage = Color(0xFFF4F6F8);

  CuentaAbierta? _cuenta;
  List<Map<String, dynamic>> _productos = [];
  bool _cargando = true;
  bool _cobrando = false;

  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_MX');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final results = await Future.wait([
      DBHelperCajero.instance.recargarCuenta(widget.cuentaId),
      DBHelperCajero.instance.obtenerProductosConStock(),
    ]);
    if (!mounted) return;
    setState(() {
      _cuenta = results[0] as CuentaAbierta?;
      _productos = results[1] as List<Map<String, dynamic>>;
      _cargando = false;
    });
  }

  Future<void> _mostrarSelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductoSheet(
        productos: _productos,
        onAgregar: _agregarProducto,
      ),
    );
  }

  Future<void> _agregarProducto(Map<String, dynamic> p, double cantidad) async {
    try {
      await DBHelperCajero.instance.agregarItemCuenta(
        cuentaId: widget.cuentaId,
        productoId: p['id'] as int,
        nombreProducto: p['nombre'] as String,
        cantidad: cantidad,
        precio: (p['precioVenta'] as num).toDouble(),
      );
      HapticFeedback.lightImpact();
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _quitarItem(ItemCuenta item) async {
    HapticFeedback.selectionClick();
    await DBHelperCajero.instance.quitarItemCuenta(
      cuentaId: widget.cuentaId,
      productoId: item.productoId,
      cantidad: 1,
    );
    await _cargar();
  }

  Future<void> _sumarItem(ItemCuenta item) {
    final prod = _productos.firstWhere(
      (p) => p['id'] == item.productoId,
      orElse: () => {},
    );
    if (prod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sin stock disponible'),
        backgroundColor: Colors.red,
      ));
      return Future.value();
    }
    return _agregarProducto(prod, 1);
  }

  Future<void> _cobrar() async {
    if (_cuenta == null || _cuenta!.items.isEmpty) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketCobro(cuenta: _cuenta!, fmt: _fmt),
    );

    if (result == null || result['confirmado'] != true || !mounted) return;

    final metodoPago = result['metodo'] as String;

    setState(() => _cobrando = true);
    try {
      await DBHelperCajero.instance.cobrarCuenta(_cuenta!, metodoPago);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Text('${_cuenta!.nombre} — ${_fmt.format(_cuenta!.total)} cobrado ✓'),
        ]),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _cobrando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al cobrar: $e'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_cuenta == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cuenta'), backgroundColor: primaryDark, foregroundColor: Colors.white),
        body: const Center(child: Text('Cuenta no encontrada')),
      );
    }

    return Scaffold(
      backgroundColor: bgPage,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _cuenta!.items.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _cuenta!.items.length,
                    itemBuilder: (_, i) => _itemCard(_cuenta!.items[i], i),
                  ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final minutos = DateTime.now().difference(_cuenta!.abiertaEn).inMinutes;
    final tiempoStr = minutos < 60 ? '$minutos min' : '${(minutos / 60).floor()}h ${minutos % 60}min';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryDark, primaryMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 16,
        bottom: 20,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cuenta!.nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Abierta hace $tiempoStr',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _mostrarSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(46),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(77)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text('Agregar', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 16),
              _statChip(Icons.shopping_bag_outlined, '${_cuenta!.items.length} producto${_cuenta!.items.length != 1 ? 's' : ''}'),
              const SizedBox(width: 10),
              _statChip(Icons.attach_money, _fmt.format(_cuenta!.total)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _itemCard(ItemCuenta item, int index) {
    final colores = [const Color(0xFF084B53), const Color(0xFFE53935), const Color(0xFFF57C00), const Color(0xFF7B1FA2), const Color(0xFF1565C0), const Color(0xFF2E7D32)];
    final color = colores[index % colores.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(item.nombre.substring(0, 1).toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Text('${_fmt.format(item.precio)} c/u', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF4F6F8), borderRadius: BorderRadius.circular(30)),
              child: Row(
                children: [
                  _circleBtn(icon: Icons.remove, color: Colors.red.shade400, onTap: () => _quitarItem(item)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(item.cantidad.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A2E))),
                  ),
                  _circleBtn(icon: Icons.add, color: primaryDark, onTap: () => _sumarItem(item)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 68,
              child: Text(_fmt.format(item.subtotal), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildFooter() {
    final hayItems = _cuenta!.items.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hayItems) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_cuenta!.cantidadItems} unidad${_cuenta!.cantidadItems != 1 ? 'es' : ''}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                Text('${_cuenta!.items.length} concepto${_cuenta!.items.length != 1 ? 's' : ''}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text(_fmt.format(_cuenta!.total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E), height: 1.1)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hayItems ? primaryDark : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      elevation: hayItems ? 3 : 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: (_cobrando || !hayItems) ? null : _cobrar,
                    child: _cobrando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payments_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Cobrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: primaryDark.withAlpha(18), shape: BoxShape.circle),
            child: const Icon(Icons.add_shopping_cart_outlined, size: 36, color: primaryDark),
          ),
          const SizedBox(height: 16),
          const Text('Cuenta vacía', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text('Toca "Agregar" para añadir productos', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Agregar producto', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _mostrarSelector,
          ),
        ],
      ),
    );
  }
}

class _ProductoSheet extends StatefulWidget {
  final List<Map<String, dynamic>> productos;
  final Future<void> Function(Map<String, dynamic>, double) onAgregar;

  const _ProductoSheet({required this.productos, required this.onAgregar});

  @override
  State<_ProductoSheet> createState() => _ProductoSheetState();
}

class _ProductoSheetState extends State<_ProductoSheet> {
  static const Color primaryDark = Color(0xFF084B53);

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtrados = [];
  final Set<int> _agregando = {};

  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_MX');

  @override
  void initState() {
    super.initState();
    _filtrados = widget.productos.where((p) => (p['stockActual'] as num).toDouble() > 0).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filtrar(String q) {
    setState(() {
      _filtrados = widget.productos.where((p) => (p['stockActual'] as num).toDouble() > 0 && p['nombre'].toString().toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  Future<void> _onAgregar(Map<String, dynamic> p) async {
    final id = p['id'] as int;
    setState(() => _agregando.add(id));
    await widget.onAgregar(p, 1);
    if (!mounted) return;
    setState(() => _agregando.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 4), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Agregar producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A1A2E))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl, autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true, fillColor: const Color(0xFFF4F6F8),
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onChanged: _filtrar,
            ),
          ),
          Expanded(
            child: _filtrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Sin productos con stock', style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filtrados.length,
                    itemBuilder: (_, i) {
                      final p = _filtrados[i];
                      final id = p['id'] as int;
                      final stock = (p['stockActual'] as num).toDouble();
                      final precio = (p['precioVenta'] as num).toDouble();
                      final cargando = _agregando.contains(id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF4F6F8), borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: primaryDark.withAlpha(26), borderRadius: BorderRadius.circular(10)),
                            child: Center(child: Text(p['nombre'].toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: primaryDark, fontWeight: FontWeight.bold, fontSize: 16))),
                          ),
                          title: Text(p['nombre'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1A2E))),
                          subtitle: Text('Stock: ${stock.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_fmt.format(precio), style: const TextStyle(color: primaryDark, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: cargando ? null : () => _onAgregar(p),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: cargando ? Colors.grey.shade300 : primaryDark, shape: BoxShape.circle),
                                  child: cargando
                                      ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.add, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TicketCobro extends StatefulWidget {
  final CuentaAbierta cuenta;
  final NumberFormat fmt;

  const _TicketCobro({required this.cuenta, required this.fmt});

  @override
  State<_TicketCobro> createState() => _TicketCobroState();
}

class _TicketCobroState extends State<_TicketCobro> {
  static const Color primaryDark = Color(0xFF084B53);
  String _metodoSeleccionado = 'Efectivo';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Container(width: 60, height: 60, decoration: BoxDecoration(color: primaryDark.withAlpha(20), shape: BoxShape.circle), child: const Icon(Icons.receipt_long, color: primaryDark, size: 28)),
          const SizedBox(height: 12),
          const Text('Cobrar cuenta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text(widget.cuenta.nombre, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          ...widget.cuenta.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: primaryDark.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text(item.cantidad.toStringAsFixed(0), style: const TextStyle(color: primaryDark, fontWeight: FontWeight.bold, fontSize: 12))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.nombre, style: const TextStyle(fontSize: 14))),
                    Text(widget.fmt.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
              Text(widget.fmt.format(widget.cuenta.total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryDark)),
            ],
          ),
          const SizedBox(height: 20),
          _buildMetodoPagoSelector(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade600, side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.pop(context, {'confirmado': false}),
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryDark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 3),
                  onPressed: () => Navigator.pop(context, {'confirmado': true, 'metodo': _metodoSeleccionado}),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Confirmar cobro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetodoPagoSelector() {
    return SegmentedButton<String>(
      segments: const <ButtonSegment<String>>[
        ButtonSegment<String>(value: 'Efectivo', label: Text('Efectivo'), icon: Icon(Icons.money_rounded)),
        ButtonSegment<String>(value: 'Tarjeta', label: Text('Tarjeta'), icon: Icon(Icons.credit_card)),
        ButtonSegment<String>(value: 'QR', label: Text('QR'), icon: Icon(Icons.qr_code_2)),
      ],
      selected: {_metodoSeleccionado},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _metodoSeleccionado = newSelection.first;
        });
      },
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: primaryDark,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}