import 'package:flutter/material.dart';
import 'package:pos_caja/app_theme.dart';
import '../../services/db_helper_cajero.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
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
    final data = await DBHelperCajero.instance.obtenerProductosConStock();
    if (!mounted) return;
    setState(() {
      _productos = data;
      _productosFiltrados = data;
      _cargando = false;
    });
  }

  void _filtrar(String query) {
    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = _productos;
      } else {
        _productosFiltrados = _productos
            .where((p) =>
                p['nombre'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarProductos,
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo de búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Contenido principal
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _productosFiltrados.isEmpty
                    ? _buildEmptyState(textTheme)
                    : RefreshIndicator(
                        onRefresh: _cargarProductos,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _productosFiltrados.length,
                          itemBuilder: (context, index) {
                            final item = _productosFiltrados[index];
                            return _buildProductCard(item, textTheme);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 70, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Sin inventario',
            style: textTheme.headlineSmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Importa el archivo del Admin para actualizar.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item, TextTheme textTheme) {
    final stock = (item['stockActual'] as num).toDouble();
    final hasStock = stock > 0;
    final stockColor = hasStock ? Colors.green.shade600 : Colors.red.shade600;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Indicador de Stock
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: stockColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  stock.toStringAsFixed(0),
                  style: textTheme.titleMedium?.copyWith(
                    color: stockColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nombre del Producto
            Expanded(
              child: Text(
                item['nombre'],
                style: textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),

            // Precio de Venta
            Text(
              '\$${item['precioVenta']}',
              style: textTheme.titleMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
