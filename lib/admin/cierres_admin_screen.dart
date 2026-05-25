import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_caja/app_theme.dart';
import '../services/db_helper_admin.dart';

class CierresAdminScreen extends StatefulWidget {
  const CierresAdminScreen({super.key});

  @override
  State<CierresAdminScreen> createState() => _CierresAdminScreenState();
}

class _CierresAdminScreenState extends State<CierresAdminScreen> {
  final _formatoMoneda =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');

  List<Map<String, dynamic>> _historial = [];
  bool _cargando = true;
  double _totalHoy = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargando = true);
    final data = await DBHelperAdmin.instance.obtenerHistorialCierres();
    double total = await DBHelperAdmin.instance.obtenerTotalVentasHoy();
    if (mounted) {
      setState(() {
        _historial = data;
        _totalHoy = total;
        _cargando = false;
      });
    }
  }

  Future<void> _importarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gv'],
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final nombreArchivo = path.split(Platform.pathSeparator).last;

    final yaImportado =
        await DBHelperAdmin.instance.cierreYaImportado(nombreArchivo);
    if (!mounted) return;

    if (yaImportado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El archivo "$nombreArchivo" ya fue importado.')),
      );
      return;
    }

    try {
      await DBHelperAdmin.instance.importarCierreCaja(File(path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cierre importado y stock actualizado ✓')),
      );
      _cargarHistorial();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar: $e')),
      );
    }
  }

  Future<void> _verDetalle(String fechaImp) async {
    final resumen =
        await DBHelperAdmin.instance.obtenerResumenPorFecha(fechaImp);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DetalleCierreSheet(
        resumen: resumen,
        fecha: fechaImp,
        formatoMoneda: _formatoMoneda,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierres de Caja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarHistorial,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTotalHoyCard(),
                _buildImportarButton(),
                const Divider(height: 1),
                Expanded(
                  child: _historial.isEmpty
                      ? _buildEmptyState()
                      : _buildHistorialList(),
                ),
              ],
            ),
    );
  }

  Widget _buildTotalHoyCard() {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(16),
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            const Icon(Icons.today, color: Colors.white70, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total ventas de hoy', style: textTheme.titleMedium?.copyWith(color: Colors.white70)),
                Text(
                  _formatoMoneda.format(_totalHoy),
                  style: textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportarButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ElevatedButton.icon(
        onPressed: _importarArchivo,
        icon: const Icon(Icons.file_open_outlined),
        label: const Text('Importar Cierre (.gv)'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }

  Widget _buildHistorialList() {
    return ListView.builder(
      itemCount: _historial.length,
      itemBuilder: (context, index) {
        final item = _historial[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.receipt_long_outlined),
            ),
            title: Text(item['archivo'], style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text('Importado: ${item['fecha_imp']}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _verDetalle(item['fecha_imp']),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 70, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text('Sin cierres importados', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('Usa el botón para importar un archivo de cierre.'),
        ],
      ),
    );
  }
}

class _DetalleCierreSheet extends StatelessWidget {
  final Map<String, dynamic> resumen;
  final String fecha;
  final NumberFormat formatoMoneda;

  const _DetalleCierreSheet({
    required this.resumen,
    required this.fecha,
    required this.formatoMoneda,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detalle = resumen['detalle'] as List<dynamic>;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Detalle del Cierre', style: textTheme.headlineSmall),
              Text(fecha, style: textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      label: 'Ventas',
                      value: '${resumen['numeroVentas']}',
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoChip(
                      label: 'Total',
                      value: formatoMoneda.format(resumen['totalVentas']),
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('Productos Vendidos', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: detalle.isEmpty
                    ? const Center(child: Text('Sin detalle de productos.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: detalle.length,
                        itemBuilder: (context, i) {
                          final item = detalle[i];
                          return ListTile(
                            dense: true,
                            leading: Text('${item['cantidadTotal']}x', style: textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),
                            title: Text(item['nombre'], style: textTheme.bodyLarge),
                            trailing: Text(
                              formatoMoneda.format(item['totalVendido']),
                              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
    );
  }
}
