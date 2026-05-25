import 'package:flutter/material.dart';
import '../../services/db_helper_cajero.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _productos          = [];
  List<Map<String, dynamic>> _productosFiltrados  = [];
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
    final data = await DBHelperCajero.instance.obtenerProductosConStock();
    if (!mounted) return;
    setState(() {
      _productos          = data;
      _productosFiltrados = data;
      _cargando           = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarProductos,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo — solo lectura
          Container(
            width: double.infinity,
            color: Colors.amber.shade50,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Vista de consulta — importa el inventario del Admin para actualizar',
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filtrar,
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _productosFiltrados.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 70, color: Colors.grey),
                            SizedBox(height: 10),
                            Text(
                              'Sin inventario.\nImporta el archivo del Admin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _productosFiltrados.length,
                        itemBuilder: (context, index) {
                          final item = _productosFiltrados[index];
                          final stock =
                              (item['stockActual'] as num).toDouble();
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: stock > 0
                                    ? primaryDark
                                    : Colors.red.shade300,
                                child: Text('${item['id']}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12)),
                              ),
                              title: Text(item['nombre'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                stock > 0
                                    ? 'Stock: $stock'
                                    : 'Sin stock',
                                style: TextStyle(
                                    color: stock > 0
                                        ? Colors.grey
                                        : Colors.red),
                              ),
                              trailing: Text(
                                '\$${item['precioVenta']}',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
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
