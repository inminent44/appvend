import 'package:flutter/material.dart';
import 'package:pos_caja/app_theme.dart';
import '../models/producto.dart';
import '../../../services/db_helper_admin.dart';
import 'agregar_producto_screen.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  static const int _limiteMaximo = 150;
  static const int _limiteAdvertencia = 145;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _searchController.addListener(() {
      _filtrar(_searchController.text);
    });
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
      _productosFiltrados = _aplicarFiltro(data, _searchController.text);
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> _aplicarFiltro(List<Map<String, dynamic>> lista, String query) {
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
    _cargarProductos();
  }

  Future<void> _irAAgregar() async {
    if (_productos.length >= _limiteMaximo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Límite de productos alcanzado.')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgregarProductoScreen()),
    );
    _cargarProductos();
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Seguro que deseas eliminar "${item['nombre']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DBHelperAdmin.instance.eliminarProducto(item['id'] as int);
    _cargarProductos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _productosFiltrados.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _cargarProductos,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _productosFiltrados.length,
                          itemBuilder: (context, index) {
                            final item = _productosFiltrados[index];
                            return _buildProductCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irAAgregar,
        label: const Text('Nuevo Producto'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o ID...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          _buildBannerLimite(),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    final textTheme = Theme.of(context).textTheme;
    final stock = (item['stockActual'] as num).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text('${item['id']}'),
        ),
        title: Text(item['nombre'], style: textTheme.titleMedium),
        subtitle: Text('\$${(item['precioVenta'] as num).toStringAsFixed(2)}', style: textTheme.bodyLarge?.copyWith(color: AppTheme.accent)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStockIndicator(stock),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _irAEditar(item);
                } else if (value == 'delete') {
                  _confirmarEliminar(item);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                const PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
        onTap: () => _irAEditar(item),
      ),
    );
  }
  
  Widget _buildStockIndicator(double stock) {
    Color color;
    if (stock <= 0) {
      color = Colors.red;
    } else if (stock <= 10) {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide.none,
      label: Text(
        'Stock: ${stock.toStringAsFixed(0)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBannerLimite() {
    final total = _productos.length;
    Color color = AppTheme.textSecondary;
    String text = '$total / $_limiteMaximo productos';

    if (total >= _limiteMaximo) {
      color = Colors.red;
      text = 'Límite alcanzado: $total / $_limiteMaximo';
    } else if (total >= _limiteAdvertencia) {
      color = Colors.orange;
      text = 'Casi en el límite: $total / $_limiteMaximo';
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Chip(
        label: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 70, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text('No hay productos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('Toca "+ Nuevo Producto" para empezar', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
