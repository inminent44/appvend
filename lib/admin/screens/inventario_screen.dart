import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../../services/db_helper_admin.dart';
import 'agregar_producto_screen.dart';
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});
  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  static const Color primaryMid  = Color(0xFF0A6B77);
  static const Color bgPage      = Color(0xFFF4F6F8);
  static const int _limiteMax    = 150;
  static const int _limiteAdvert = 145;

  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _filtrados = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await DBHelperAdmin.instance.obtenerProductosConStock();
    if (!mounted) return;
    setState(() {
      _productos = data;
      _filtrados = _aplicarFiltro(data, _searchCtrl.text);
      _cargando  = false;
    });
  }

  List<Map<String, dynamic>> _aplicarFiltro(List<Map<String, dynamic>> lista, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return lista;
    return lista.where((p) =>
      p['nombre'].toString().toLowerCase().contains(query) ||
      p['id'].toString() == query
    ).toList();
  }

  void _filtrar(String q) =>
      setState(() => _filtrados = _aplicarFiltro(_productos, q));

  Future<void> _irAEditar(Map<String, dynamic> item) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AgregarProductoScreen(producto: Producto.fromMap(item)),
    ));
    if (!mounted) return;
    _cargar();
  }

  Future<void> _irAAgregar() async {
    if (_productos.length >= _limiteMax) {
      _mostrarLimiteDialog(); return;
    }
    if (_productos.length >= _limiteAdvert) {
      final ok = await _mostrarAdvertenciaDialog();
      if (ok != true || !mounted) return;
    }
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const AgregarProductoScreen(),
    ));
    if (!mounted) return;
    _cargar();
  }

  Future<void> _exportarInventario() async {
    try {
      await DBHelperAdmin.instance.exportarInventario();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        titulo: 'Eliminar producto',
        mensaje: '¿Eliminar "${item['nombre']}"? Esta acción no se puede deshacer.',
        labelConfirm: 'Eliminar',
        destructivo: true,
      ),
    );
    if (ok != true) return;
    await DBHelperAdmin.instance.eliminarProducto(item['id'] as int);
    if (!mounted) return;
    _cargar();
  }

  void _mostrarLimiteDialog() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.lock_outline, color: Colors.red, size: 18)),
        const SizedBox(width: 12),
        const Text('Límite alcanzado', style: TextStyle(fontSize: 17)),
      ]),
      content: const Text('Alcanzaste el límite de 150 productos.\nContacta a VaraNova para más.'),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primaryDark, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  Future<bool?> _mostrarAdvertenciaDialog() => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18)),
        const SizedBox(width: 12),
        const Text('Casi en el límite', style: TextStyle(fontSize: 17)),
      ]),
      content: Text('Quedan ${_limiteMax - _productos.length} lugares disponibles. ¿Continuar?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primaryDark, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );

  // ── colores por índice ──
  static const _colores = [
    Color(0xFF084B53), Color(0xFFE53935), Color(0xFFF57C00),
    Color(0xFF7B1FA2), Color(0xFF1565C0), Color(0xFF2E7D32),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: Column(
        children: [
          // ── Header gradiente ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryDark, primaryMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20, right: 20, bottom: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Inventario', style: TextStyle(
                              color: Colors.white, fontSize: 22,
                              fontWeight: FontWeight.bold)),
                          Text('Productos y stock', style: TextStyle(
                              color: Colors.white60, fontSize: 13)),
                        ],
                      ),
                    ),
                    _headerBtn(Icons.upload_file, 'Exportar', _exportarInventario),
                    const SizedBox(width: 8),
                    _headerBtn(Icons.refresh, '', _cargar),
                  ],
                ),
                const SizedBox(height: 16),
                // Buscador integrado en header
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filtrar,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o ID...',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(153), fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withAlpha(178), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Chips de stats
                Row(
                  children: [
                    _statChip(Icons.inventory_2_outlined,
                        '${_productos.length}/$_limiteMax productos'),
                    if (_productos.length >= _limiteAdvert) ...[
                      const SizedBox(width: 8),
                      _statChip(Icons.warning_amber_rounded,
                          '${_limiteMax - _productos.length} restantes',
                          color: Colors.orange.shade200),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Lista ──────────────────────────────────────────────────
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _filtrados.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _filtrados.length,
                        itemBuilder: (_, i) => _productoCard(_filtrados[i], i),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irAAgregar,
        backgroundColor: _productos.length >= _limiteMax ? Colors.grey : primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _headerBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(46),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color ?? Colors.white70, size: 13),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 11)),
      ]),
    );
  }

  Widget _productoCard(Map<String, dynamic> item, int index) {
    final color  = _colores[index % _colores.length];
    final stock  = (item['stockActual'] as num).toDouble();
    final precio = (item['precioVenta'] as num).toDouble();
    final stockBajo = stock < 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withAlpha(13),
          blurRadius: 8, offset: const Offset(0, 3),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar letra
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(
                  item['nombre'].toString().substring(0, 1).toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 14, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text('ID ${item['id']}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: stockBajo ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Stock: ${stock.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: stockBajo ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            // Precio + acciones
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${precio.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 15, color: Color(0xFF084B53))),
                const SizedBox(height: 6),
                Row(children: [
                  _accionBtn(Icons.edit_outlined, primaryDark,
                      () => _irAEditar(item)),
                  const SizedBox(width: 6),
                  _accionBtn(Icons.delete_outline, Colors.red.shade400,
                      () => _confirmarEliminar(item)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _accionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF084B53).withAlpha(18),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.inventory_2_outlined, size: 36, color: primaryDark),
        ),
        const SizedBox(height: 16),
        const Text('Sin productos', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 8),
        Text(_searchCtrl.text.isEmpty
            ? 'Toca "Nuevo" para agregar el primer producto'
            : 'No hay resultados para "${_searchCtrl.text}"',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ]),
    );
  }
}

// ── Dialog reutilizable ───────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String titulo, mensaje, labelConfirm;
  final bool destructivo;
  const _ConfirmDialog({
    required this.titulo, required this.mensaje,
    required this.labelConfirm, this.destructivo = false,
  });
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(titulo, style: const TextStyle(fontSize: 17)),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: destructivo ? Colors.red : const Color(0xFF084B53),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(labelConfirm),
        ),
      ],
    );
  }
}