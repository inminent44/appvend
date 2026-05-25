import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/db_helper.dart';

class CierreCajaScreen extends StatefulWidget {
  const CierreCajaScreen({super.key});

  @override
  State<CierreCajaScreen> createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  static const Color primaryDark = Color(0xFF084B53);

  final _formatoMoneda =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');
  final _formatoFecha = DateFormat('dd/MM/yyyy');

  Map<String, dynamic>? _resumen;
  bool _cargando = false;
  bool _turnoCerrado = false;
  bool _puedeIniciarNuevoDia = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        DBHelper.instance.obtenerResumenCierre(),
        DBHelper.instance.esTurnoCerrado(),
        DBHelper.instance.obtenerFechaCierreTurno(),
      ]);
      if (!mounted) return;

      final turnoCerrado = results[1] as bool;
      final fechaCierre = results[2] as String?;

      // Solo puede iniciar nuevo día si el cierre fue en un día anterior
      bool puedeNuevoDia = false;
      if (turnoCerrado && fechaCierre != null) {
        final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
        puedeNuevoDia = fechaCierre != hoy;
      }

      setState(() {
        _resumen = results[0] as Map<String, dynamic>;
        _turnoCerrado = turnoCerrado;
        _puedeIniciarNuevoDia = puedeNuevoDia;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  Future<void> _exportarCierre() async {
    try {
      await DBHelper.instance.exportarCierreCaja();
      if (!mounted) return;
      await _cargarDatos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cierre exportado y turno cerrado ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  Future<void> _confirmarNuevoDia() async {
    if (!_puedeIniciarNuevoDia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'El nuevo día solo puede iniciarse a partir del día siguiente al cierre.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: Color(0xFF084B53)),
            SizedBox(width: 8),
            Text('Nuevo Día'),
          ],
        ),
        content: const Text(
          'Al iniciar un nuevo día se borrarán todas las ventas de hoy '
          'del dispositivo.\n\n'
          '⚠️ Asegúrate de haber exportado el cierre al Admin antes de continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Iniciar Nuevo Día'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      await DBHelper.instance.iniciarNuevoDia();
      if (!mounted) return;
      await _cargarDatos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuevo día iniciado. ¡Buenas ventas! 🌅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar nuevo día: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final detalle = _resumen?['detalle'] as List<dynamic>? ?? [];
    final hayVentas = (_resumen?['numeroVentas'] as int? ?? 0) > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de Caja'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Banner turno cerrado ──────────────────────────────
                  if (_turnoCerrado)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_clock, color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _puedeIniciarNuevoDia
                                  ? 'Turno cerrado. Puedes iniciar un nuevo día.'
                                  : 'Turno cerrado. El nuevo día estará disponible mañana.',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Fecha ─────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatoFecha.format(hoy),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.calendar_today,
                          color: Colors.grey, size: 20),
                    ],
                  ),
                  const Divider(height: 30),

                  // ── Tarjetas resumen ──────────────────────────────────
                  Row(
                    children: [
                      _buildCard(
                        'Total Ventas',
                        _formatoMoneda.format(_resumen?['totalVentas'] ?? 0),
                        Icons.attach_money,
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _buildCard(
                        'Cant. Ventas',
                        '${_resumen?['numeroVentas'] ?? 0}',
                        Icons.shopping_bag,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // ── Detalle productos ─────────────────────────────────
                  const Text(
                    'Productos Vendidos Hoy',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryDark),
                  ),
                  const SizedBox(height: 10),
                  detalle.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                              child: Text('No hay ventas registradas hoy')),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: detalle.length,
                          itemBuilder: (context, index) {
                            final item = detalle[index];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side:
                                    BorderSide(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                title: Text(item['nombre'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    'Cant: ${(item['cantidadTotal'] as num).toStringAsFixed(0)}'),
                                trailing: Text(
                                  _formatoMoneda
                                      .format(item['totalVendido']),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 30),

                  // ── Botón exportar cierre ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: (!hayVentas || _turnoCerrado)
                          ? null
                          : _exportarCierre,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text(
                        'EXPORTAR CIERRE AL ADMIN',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _turnoCerrado
                          ? 'El cierre ya fue exportado hoy.'
                          : 'Envía este archivo al Admin para actualizar el inventario.',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),

                  // ── Botón nuevo día ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: _puedeIniciarNuevoDia
                          ? _confirmarNuevoDia
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryDark,
                        side: BorderSide(
                          color: _puedeIniciarNuevoDia
                              ? primaryDark
                              : Colors.grey,
                        ),
                        disabledForegroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.wb_sunny_outlined),
                      label: const Text(
                        'INICIAR NUEVO DÍA',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _puedeIniciarNuevoDia
                          ? 'Borra las ventas de hoy del dispositivo.'
                          : 'Disponible a partir del día siguiente al cierre.',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(
      String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          // ignore: deprecated_member_use
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color),
            const SizedBox(height: 10),
            Text(titulo,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text(valor,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}