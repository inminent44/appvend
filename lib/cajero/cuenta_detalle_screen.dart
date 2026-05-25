import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos_caja/app_theme.dart';
import '../../models/cuenta_abierta.dart';
import '../../services/db_helper_cajero.dart';

class CuentaDetalleScreen extends StatefulWidget {
  final String cuentaId;
  const CuentaDetalleScreen({super.key, required this.cuentaId});

  @override
  State<CuentaDetalleScreen> createState() => _CuentaDetalleScreenState();
}

class _CuentaDetalleScreenState extends State<CuentaDetalleScreen> {
  CuentaAbierta? _cuenta;
  List<Map<String, dynamic>> _productos = [];
  bool _cargando = true;
  bool _cobrando = false;

  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');

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

  Future<void> _mostrarSelectorProductos() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductGridSheet(
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

  Future<void> _sumarItem(ItemCuenta item) async {
    final prod = _productos.firstWhere((p) => p['id'] == item.productoId, orElse: () => {});
    if (prod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin stock disponible')));
      return;
    }
    await _agregarProducto(prod, 1);
  }

  Future<void> _cobrar() async {
    if (_cuenta == null || _cuenta!.items.isEmpty) return;

    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketCobroSheet(cuenta: _cuenta!, fmt: _fmt),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _cobrando = true);
    try {
      await DBHelperCajero.instance.cobrarCuenta(_cuenta!);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_cuenta!.nombre} — ${_fmt.format(_cuenta!.total)} cobrado ✓'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _cobrando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al cobrar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_cuenta == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Cuenta no encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_cuenta!.nombre),
            Text(
              '${_cuenta!.items.length} productos',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _cuenta!.items.isEmpty
          ? _buildEmptyState(textTheme)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
              itemCount: _cuenta!.items.length,
              itemBuilder: (_, i) => _buildItemCard(_cuenta!.items[i], textTheme),
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        onPressed: _mostrarSelectorProductos,
      ),
      bottomSheet: _buildFooter(textTheme),
    );
  }

  Widget _buildItemCard(ItemCuenta item, TextTheme textTheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.nombre, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('${_fmt.format(item.precio)} c/u', style: textTheme.bodySmall),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _quitarItem(item),
                ),
                Text(item.cantidad.toStringAsFixed(0), style: textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                  onPressed: () => _sumarItem(item),
                ),
              ],
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 75,
              child: Text(
                _fmt.format(item.subtotal),
                textAlign: TextAlign.end,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(TextTheme textTheme) {
    final hayItems = _cuenta!.items.isNotEmpty;
    return Material(
      elevation: 8,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL', style: textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary)),
                  Text(_fmt.format(_cuenta!.total), style: textTheme.displaySmall),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: (_cobrando || !hayItems) ? null : _cobrar,
              icon: _cobrando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.payments_outlined),
              label: const Text('Cobrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_shopping_cart_outlined, size: 72, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text('Cuenta vacía', style: textTheme.headlineSmall?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('Toca "Agregar" para añadir productos', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ProductGridSheet extends StatefulWidget {
  final List<Map<String, dynamic>> productos;
  final Future<void> Function(Map<String, dynamic>, double) onAgregar;

  const _ProductGridSheet({required this.productos, required this.onAgregar});

  @override
  State<_ProductGridSheet> createState() => _ProductGridSheetState();
}

class _ProductGridSheetState extends State<_ProductGridSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtrados = [];
  final Set<int> _agregando = {};

  @override
  void initState() {
    super.initState();
    _filtrados = widget.productos.where((p) => (p['stockActual'] as num) > 0).toList();
    _searchCtrl.addListener(() => _filtrar(_searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filtrar(String q) {
    setState(() {
      _filtrados = widget.productos.where((p) =>
              (p['stockActual'] as num) > 0 &&
              p['nombre'].toString().toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  Future<void> _onAgregar(Map<String, dynamic> p) async {
    final id = p['id'] as int;
    setState(() => _agregando.add(id));
    await widget.onAgregar(p, 1);
    if (mounted) {
      setState(() => _agregando.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Agregar Producto', style: textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _filtrados.isEmpty
                ? Center(child: Text('No hay productos con stock', style: textTheme.bodyMedium))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: _filtrados.length,
                    itemBuilder: (_, i) {
                      final p = _filtrados[i];
                      final cargando = _agregando.contains(p['id']);
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: cargando ? null : () => _onAgregar(p),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 80,
                                color: AppTheme.primary.withOpacity(0.1),
                                child: cargando
                                  ? const Center(child: CircularProgressIndicator())
                                  : const Icon(Icons.fastfood_outlined, color: AppTheme.primary, size: 40),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['nombre'], style: textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text('\$${p['precioVenta']}', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                  ],
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

class _TicketCobroSheet extends StatelessWidget {
  final CuentaAbierta cuenta;
  final NumberFormat fmt;

  const _TicketCobroSheet({required this.cuenta, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Text('Cobrar Cuenta', style: textTheme.headlineSmall),
          Text(cuenta.nombre, style: textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          const Divider(height: 20),
          ...cuenta.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Text('${item.cantidad.toStringAsFixed(0)}x', style: textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(width: 10),
                Expanded(child: Text(item.nombre, style: textTheme.bodyLarge)),
                Text(fmt.format(item.subtotal), style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          )),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: textTheme.titleLarge),
              Text(fmt.format(cuenta.total), style: textTheme.displaySmall?.copyWith(color: AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar Cobro'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
