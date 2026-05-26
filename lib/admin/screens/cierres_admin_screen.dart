import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/db_helper_admin.dart';

class CierresAdminScreen extends StatefulWidget {
  const CierresAdminScreen({super.key});
  @override
  State<CierresAdminScreen> createState() => _CierresAdminScreenState();
}

class _CierresAdminScreenState extends State<CierresAdminScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  static const Color primaryMid  = Color(0xFF0A6B77);
  static const Color bgPage      = Color(0xFFF4F6F8);

  final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_ES');

  List<Map<String, dynamic>> _historial = [];
  bool   _cargando  = true;
  double _totalHoy  = 0.0;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await DBHelperAdmin.instance.obtenerHistorialCierres();
    double total = 0.0;
    try { total = await DBHelperAdmin.instance.obtenerTotalVentasHoy(); } catch (_) {}
    if (!mounted) return;
    setState(() { _historial = data; _totalHoy = total; _cargando = false; });
  }

  Future<void> _importar() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;

    final nombreArchivo = path.split('/').last;
    final yaImportado = await DBHelperAdmin.instance.cierreYaImportado(nombreArchivo);
    if (!mounted) return;

    if (yaImportado) {
      _mostrarDuplicado(nombreArchivo); return;
    }

    try {
      await DBHelperAdmin.instance.importarCierreCaja(File(path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 10),
          Text('Cierre importado y stock actualizado ✓'),
        ]),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _mostrarDuplicado(String nombre) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18)),
          const SizedBox(width: 12),
          const Text('Cierre duplicado', style: TextStyle(fontSize: 17)),
        ]),
        content: Text('"$nombre" ya fue importado anteriormente.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _verDetalle(String fechaImp) async {
    final resumen = await DBHelperAdmin.instance.obtenerResumenPorFecha(fechaImp);
    if (!mounted) return;
    final detalle = resumen['detalle'] as List<dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleSheet(
        fecha: fechaImp,
        resumen: resumen,
        detalle: detalle,
        fmt: _fmt,
      ),
    );
  }

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
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20, right: 20, bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cierres', style: TextStyle(color: Colors.white,
                            fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('Ventas recibidas del cajero',
                            style: TextStyle(color: Colors.white60, fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _cargar,
                    child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.refresh, color: Colors.white, size: 20)),
                  ),
                ]),
                const SizedBox(height: 20),

                // Tarjeta total hoy
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.today, color: Colors.white, size: 22)),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total ventas de hoy',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_fmt.format(_totalHoy),
                          style: const TextStyle(color: Colors.white,
                              fontSize: 28, fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ]),
                  ]),
                ),
              ],
            ),
          ),

          // ── Botón importar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _importar,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('IMPORTAR CIERRE DEL CAJERO (.gv)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),

          // ── Lista ──────────────────────────────────────────────────
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _historial.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _historial.length,
                        itemBuilder: (_, i) => _cierreCard(_historial[i], i),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _cierreCard(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8, offset: const Offset(0, 3),
        )],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: primaryDark.withOpacity(0.08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.receipt_long_outlined, color: primaryDark, size: 22),
        ),
        title: Text(item['archivo'],
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 13, color: Color(0xFF1A1A2E))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text('Importado: ${item['fecha_imp']}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ),
        trailing: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: primaryDark.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.chevron_right, color: primaryDark, size: 18),
        ),
        onTap: () => _verDetalle(item['fecha_imp']),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(
            color: primaryDark.withOpacity(0.07), shape: BoxShape.circle),
          child: const Icon(Icons.inbox_outlined, size: 36, color: primaryDark)),
        const SizedBox(height: 16),
        const Text('Sin cierres importados', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 8),
        Text('Importa el archivo .gv del cajero',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ]),
    );
  }
}

// ── Sheet de detalle ──────────────────────────────────────────────────────────
class _DetalleSheet extends StatelessWidget {
  final String fecha;
  final Map<String, dynamic> resumen;
  final List<dynamic> detalle;
  final NumberFormat fmt;

  const _DetalleSheet({
    required this.fecha, required this.resumen,
    required this.detalle, required this.fmt,
  });

  static const Color primaryDark = Color(0xFF084B53);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82),
      child: Column(
        children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),

          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: primaryDark.withOpacity(0.08), shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long, color: primaryDark, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Detalle del cierre',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 16, color: Color(0xFF1A1A2E))),
                  Text(fecha, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // Chips resumen
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _chip('Ventas', '${resumen['numeroVentas']}', Colors.blue),
              const SizedBox(width: 10),
              _chip('Total', fmt.format(resumen['totalVentas']), Colors.green),
            ]),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Lista detalle
          Expanded(
            child: detalle.isEmpty
                ? Center(child: Text('Sin detalle disponible',
                    style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: detalle.length,
                    itemBuilder: (_, i) {
                      final item = detalle[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6F8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Container(width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: primaryDark.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                            child: Center(child: Text(
                              item['nombre'].toString().substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: primaryDark,
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['nombre'], style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13,
                                  color: Color(0xFF1A1A2E))),
                              Text('Cant: ${item['cantidadTotal']}',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          )),
                          Text(fmt.format(item['totalVendido']),
                              style: const TextStyle(fontWeight: FontWeight.bold,
                                  fontSize: 14, color: primaryDark)),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontSize: 11,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
              color: Color(0xFF1A1A2E))),
        ]),
      ),
    );
  }
}