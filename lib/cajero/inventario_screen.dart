// lib/vendedor/screens/inventario_screen.dart  (cajero)
import 'dart:io';
import 'package:file_picker/file_picker.dart';
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

  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  bool _cargando   = true;
  bool _importando = false;

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
    try {
      // Usa obtenerProductosConStock (que devuelve TODOS los productos con y sin stock)
      final data = await DBHelperCajero.instance.obtenerProductosConStock();
      if (!mounted) return;
      setState(() {
        _productos = data;
        _productosFiltrados = _searchController.text.isEmpty
            ? data
            : _aplicarFiltro(data, _searchController.text);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar productos: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _aplicarFiltro(
      List<Map<String, dynamic>> lista, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return lista;
    return lista.where((p) {
      final porNombre = p['nombre'].toString().toLowerCase().contains(q);
      final porId     = p['id'].toString() == q;
      return porNombre || porId;
    }).toList();
  }

  void _filtrar(String query) {
    setState(() {
      _productosFiltrados = _aplicarFiltro(_productos, query);
    });
  }

  Future<void> _importarInventario() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _importando = true);
    try {
      final file = File(result.files.single.path!);
      await DBHelperCajero.instance.importarInventarioAdmin(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventario importado correctamente ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      await _cargarProductos(); // recargar lista
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario / Stock'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          if (_importando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Importar inventario',
              onPressed: _importarInventario,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarProductos,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o ID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: const Color(0xFFF4F6F8),
              ),
              onChanged: _filtrar,
            ),
          ),

          // Banner de total
          if (!_cargando) _buildBannerTotal(),

          // Lista
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _productosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 72, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _productos.isEmpty
                                  ? 'Sin productos. Importa un inventario.'
                                  : 'Sin resultados para la búsqueda.',
                              style: const TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            if (_productos.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryDark,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Importar inventario'),
                                onPressed: _importarInventario,
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarProductos,
                        child: ListView.builder(
                          itemCount: _productosFiltrados.length,
                          itemBuilder: (context, index) {
                            final item = _productosFiltrados[index];
                            final stock =
                                (item['stockActual'] as num).toDouble();
                            final sinStock = stock <= 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: sinStock
                                      ? Colors.red.shade200
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      sinStock ? Colors.red.shade100 : primaryDark,
                                  child: Text(
                                    '${item['id']}',
                                    style: TextStyle(
                                      color: sinStock
                                          ? Colors.red.shade700
                                          : Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(item['nombre'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Row(
                                  children: [
                                    Icon(
                                      sinStock
                                          ? Icons.warning_amber_rounded
                                          : Icons.check_circle_outline,
                                      size: 13,
                                      color: sinStock
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Stock: ${stock.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          color: sinStock
                                              ? Colors.red
                                              : Colors.grey.shade600,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  '\$${(item['precioVenta'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerTotal() {
    final total    = _productos.length;
    final sinStock = _productos.where(
        (p) => (p['stockActual'] as num).toDouble() <= 0).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Text('$total productos',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          if (sinStock > 0) ...[
            const SizedBox(width: 10),
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade400, size: 13),
            const SizedBox(width: 3),
            Text('$sinStock sin stock',
                style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}