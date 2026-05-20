import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/db_helper.dart';
import 'agregar_producto_screen.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    setState(() => _cargando = true);
    final data = await DBHelper.instance.obtenerProductosConStock();
    if (!mounted) return;
    setState(() {
      _productos = data;
      _productosFiltrados = _searchController.text.isEmpty
          ? data
          : _aplicarFiltro(data, _searchController.text);
      _cargando = false;
    });
  }

  // ── Búsqueda por nombre O por ID ──────────────────────────────────────────
  List<Map<String, dynamic>> _aplicarFiltro(
      List<Map<String, dynamic>> lista, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return lista;
    return lista.where((p) {
      final porNombre = p['nombre'].toString().toLowerCase().contains(q);
      final porId = p['id'].toString() == q; // coincidencia exacta de ID
      return porNombre || porId;
    }).toList();
  }

  void _filtrar(String query) {
    setState(() {
      _productosFiltrados = _aplicarFiltro(_productos, query);
    });
  }

  Future<void> _irAEditar(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AgregarProductoScreen(producto: Producto.fromMap(item))),
    );
    if (!mounted) return;
    _cargarProductos();
  }

  Future<void> _irAAgregar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgregarProductoScreen()),
    );
    if (!mounted) return;
    _cargarProductos();
  }

  Future<void> _exportarInventario() async {
    try {
      await DBHelper.instance.exportarInventario();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  Future<void> _mostrarAjusteStock(Map<String, dynamic> item) async {
    final stockController = TextEditingController();
    final notaController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajustar stock: ${item['nombre']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stockController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    'Cantidad (actual: ${(item['stockActual'] as num).toInt()})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notaController,
              decoration: const InputDecoration(
                labelText: 'Nota / motivo',
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
            onPressed: () async {
              final cantidad = double.tryParse(
                  stockController.text.trim().replaceAll(',', '.'));
              if (cantidad == null) return;
              await DBHelper.instance.ajustarStock(
                productoId: item['id'] as int,
                cantidad: cantidad,
                nota: notaController.text.trim().isEmpty
                    ? 'Ajuste manual'
                    : notaController.text.trim(),
              );
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _cargarProductos();
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Seguro que deseas eliminar "${item['nombre']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DBHelper.instance.eliminarProducto(item['id'] as int);
    if (!mounted) return;
    _cargarProductos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario / Stock'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar inventario',
            onPressed: _cargarProductos,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Exportar al vendedor',
            onPressed: _exportarInventario,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filtrar,
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _productosFiltrados.length,
                    itemBuilder: (context, index) {
                      final item = _productosFiltrados[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryDark,
                                child: Text('${item['id']}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ),
                              title: Text(item['nombre'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'Stock: ${(item['stockActual'] as num).toStringAsFixed(0)}'),
                              trailing: Text(
                                  '\$${(item['precioVenta'] as num).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              onTap: () => _irAEditar(item),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.tune, size: 16),
                                  label: const Text('Stock'),
                                  onPressed: () => _mostrarAjusteStock(item),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Editar'),
                                  onPressed: () => _irAEditar(item),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete,
                                      size: 16, color: Colors.red),
                                  label: const Text('Eliminar',
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () => _confirmarEliminar(item),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _irAAgregar,
        backgroundColor: primaryDark,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
