import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/db_helper.dart';

class CierresAdminScreen extends StatefulWidget {
  const CierresAdminScreen({super.key});

  @override
  State<CierresAdminScreen> createState() => _CierresAdminScreenState();
}

class _CierresAdminScreenState extends State<CierresAdminScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  final _formatoMoneda = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  List<Map<String, dynamic>> _historial = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargando = true);
    final data = await DBHelper.instance.obtenerHistorialCierres();
    if (!mounted) return;
    setState(() {
      _historial = data;
      _cargando = false;
    });
  }

  Future<void> _importarArchivo() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    final path = result.files.single.path;
    if (path == null) return;

    try {
      await DBHelper.instance.importarCierreCaja(File(path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cierre importado y stock actualizado ✓')),
      );
      _cargarHistorial();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _verDetalle(String fecha) async {
    final resumen = await DBHelper.instance.obtenerResumenPorFecha(fecha);
    if (!mounted) return;

    final detalle = resumen['detalle'] as List<dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Detalle del cierre — $fecha',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryDark)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _chipResumen(
                      'Ventas', '${resumen['numeroVentas']}', Colors.blue),
                  const SizedBox(width: 10),
                  _chipResumen(
                      'Total',
                      _formatoMoneda.format(resumen['totalVentas']),
                      Colors.green),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: detalle.length,
                  itemBuilder: (context, i) {
                    final item = detalle[i];
                    return ListTile(
                      title: Text(item['nombre']),
                      subtitle: Text('Cant: ${item['cantidadTotal']}'),
                      trailing: Text(
                        _formatoMoneda.format(item['totalVendido']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipResumen(String label, String valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          // ignore: deprecated_member_use
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            Text(valor,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierres Recibidos'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarHistorial,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _importarArchivo,
                icon: const Icon(Icons.file_open),
                label: const Text('IMPORTAR CIERRE DEL VENDEDOR (.gv)'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDark,
                    foregroundColor: Colors.white),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _historial.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 80, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Aún no hay cierres importados',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historial.length,
                        itemBuilder: (context, index) {
                          final item = _historial[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: primaryDark,
                              child: Icon(Icons.receipt_long,
                                  color: Colors.white, size: 18),
                            ),
                            title: Text(item['archivo'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('Importado: ${item['fecha_imp']}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _verDetalle(item['fecha_imp']),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
