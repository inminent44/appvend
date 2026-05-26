import 'package:flutter/material.dart';
import '../admin/models/producto.dart';
import '../../services/db_helper_admin.dart';
import '../admin/screens/agregar_producto_screen.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  static const int _limiteMaximo = 300;
  static const int _limiteAdvertencia = 295;

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
    final data = await DBHelperAdmin.instance.obtenerProductosConStock();
    if (!mounted) return;
    setState(() {
      _productos = data;
      _productosFiltrados = _searchController.text.isEmpty
          ? data
          : _aplicarFiltro(data, _searchController.text);
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> _aplicarFiltro(
      List<Map<String, dynamic>> lista, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return lista;
    return lista.where((p) {
      final porNombre = p['nombre'].toString().toLowerCase().contains(q);
      final porId = p['id'].toString() == q;
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
        builder: (_) => AgregarProductoScreen(producto: Producto.fromMap(item)),
      ),
    );
    if (!mounted) return;
    _cargarProductos();
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
    await DBHelperAdmin.instance.eliminarProducto(item['id'] as int);
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
            tooltip: 'Actualizar',
            onPressed: _cargarProductos,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Exportar al cajero',
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
          if (!_cargando) _buildBannerTotal(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _productosFiltrados.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 80, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Sin productos',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
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
                                      '\$${(item['precioVenta'] as num).toStringAsFixed(2)}',
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
    );
  }

  Widget _buildBannerTotal() {
    final total = _productos.length;
    if (total >= _limiteMaximo) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.red, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Límite de 300 productos alcanzado. Contacta a VaraNova para la versión Básica Plus.',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (total >= _limiteAdvertencia) {
      final restantes = _limiteMaximo - total;
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Casi en el límite: $total/300 productos. '
                '${restantes == 1 ? 'Solo queda 1 lugar.' : 'Quedan $restantes lugares.'}',
                style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(
        '$total / $_limiteMaximo productos',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}
