// lib/screens/cuentas_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cuenta_abierta.dart';
import '../services/db_helper.dart';
import 'cuenta_detalle_screen.dart';
import 'cierre_caja_screen.dart';
import 'inventario_screen.dart';

class CuentasScreen extends StatefulWidget {
  const CuentasScreen({super.key});

  @override
  State<CuentasScreen> createState() => _CuentasScreenState();
}

class _CuentasScreenState extends State<CuentasScreen>
    with SingleTickerProviderStateMixin {
  // ── Colores ───────────────────────────────────────────────────────────────
  static const Color primaryDark = Color(0xFF084B53);
  static const Color primaryMid = Color(0xFF0A6B77);
  static const Color bgPage = Color(0xFFF4F6F8);
  static const Color cardBg = Colors.white;

  List<CuentaAbierta> _cuentas = [];
  Map<String, dynamic> _resumen = {'totalVentas': 0.0, 'numeroVentas': 0};
  bool _cargando = true;
  bool _turnoCerrado = false;

  late AnimationController _headerAnim;
  late Animation<double> _fadeAnim;

  final _formatoMoneda =
      NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_MX');
  final _formatoFecha = DateFormat("d 'de' MMMM", 'es_MX');

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _cargar();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final results = await Future.wait([
      DBHelper.instance.obtenerCuentasAbiertas(),
      DBHelper.instance.esTurnoCerrado(),
      DBHelper.instance.obtenerResumenCierre(),
    ]);
    if (!mounted) return;
    setState(() {
      _cuentas = results[0] as List<CuentaAbierta>;
      _turnoCerrado = results[1] as bool;
      _resumen = results[2] as Map<String, dynamic>;
      _cargando = false;
    });
    _headerAnim.forward(from: 0);
  }

  // ── Crear cuenta ──────────────────────────────────────────────────────────
  Future<void> _nuevaCuenta() async {
    if (_turnoCerrado) { _mostrarTurnoCerrado(); return; }
    final controller = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nueva cuenta',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Nombre o número',
            hintText: 'Ej: Mesa 3, Para llevar, Juan…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.receipt_long_outlined),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    final cuenta = await DBHelper.instance.crearCuenta(nombre);
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => CuentaDetalleScreen(cuentaId: cuenta.id)));
    _cargar();
  }

  Future<void> _abrirCuenta(CuentaAbierta cuenta) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => CuentaDetalleScreen(cuentaId: cuenta.id)));
    _cargar();
  }

  Future<void> _cancelarCuenta(CuentaAbierta cuenta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancelar cuenta'),
        content: Text(
            'Se cancelará "${cuenta.nombre}" y se devolverá el stock.\n\n¿Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar cuenta'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await DBHelper.instance.cancelarCuenta(cuenta);
    if (!mounted) return;
    _cargar();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta cancelada — stock devuelto')));
  }

  void _mostrarTurnoCerrado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.lock_clock, color: Colors.orange),
          SizedBox(width: 8),
          Text('Turno cerrado'),
        ]),
        content: const Text(
            'No se pueden crear cuentas nuevas.\nVe a Cierre → Iniciar Nuevo Día.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              color: primaryDark,
              child: CustomScrollView(
                slivers: [
                  // ── Header ───────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildHeader()),
                  // ── Tarjetas acceso rápido ───────────────────────────
                  SliverToBoxAdapter(child: _buildAccesoRapido()),
                  // ── Resumen ventas ───────────────────────────────────
                  SliverToBoxAdapter(child: _buildResumenVentas()),
                  // ── Título cuentas abiertas ──────────────────────────
                  SliverToBoxAdapter(child: _buildSeccionTitulo()),
                  // ── Lista cuentas ────────────────────────────────────
                  _cuentas.isEmpty
                      ? SliverToBoxAdapter(child: _emptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _cuentaCard(_cuentas[i]),
                            childCount: _cuentas.length,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaCuenta,
        backgroundColor: _turnoCerrado ? Colors.grey.shade400 : primaryDark,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text('Nueva cuenta',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Header con logo ───────────────────────────────────────────────────────
  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryDark, primaryMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          bottom: 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo y nombre app
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VaraNova',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                    Text('Punto de Venta',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            letterSpacing: 0.3)),
                  ],
                ),
                const Spacer(),
                // Indicador turno
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _turnoCerrado
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _turnoCerrado
                          ? Colors.orange.withOpacity(0.5)
                          : Colors.green.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _turnoCerrado
                            ? Icons.lock_clock
                            : Icons.lock_open_outlined,
                        size: 13,
                        color: _turnoCerrado ? Colors.orange : Colors.greenAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _turnoCerrado ? 'Cerrado' : 'Abierto',
                        style: TextStyle(
                          color: _turnoCerrado
                              ? Colors.orange
                              : Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Fecha
            Text(
              _formatoFecha.format(DateTime.now()),
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, letterSpacing: 0.3),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_cuentas.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      height: 1),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('cuentas abiertas',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tarjetas acceso rápido ────────────────────────────────────────────────
  Widget _buildAccesoRapido() {
    final items = [
      _QuickItem(
        label: 'Nueva\ncuenta',
        icon: Icons.add_circle_outline_rounded,
        color: const Color(0xFFE53935),
        onTap: _nuevaCuenta,
      ),
      _QuickItem(
        label: 'Ver\ncuentas',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFFF57C00),
        onTap: () {}, // ya estamos aquí, hace scroll
      ),
      _QuickItem(
        label: 'Stock /\nInventario',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF7B1FA2),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InventarioScreen())),
      ),
      _QuickItem(
        label: 'Cierre\nde caja',
        icon: Icons.calculate_outlined,
        color: const Color(0xFF1565C0),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CierreCajaScreen())),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: items
            .map((item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _quickCard(item),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _quickCard(_QuickItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(item.icon, color: Colors.white, size: 26),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Resumen de ventas ─────────────────────────────────────────────────────
  Widget _buildResumenVentas() {
    final total = (_resumen['totalVentas'] as num).toDouble();
    final cantidad = (_resumen['numeroVentas'] as num).toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primaryDark, primaryMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryDark.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ventas de hoy',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    _formatoMoneda.format(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$cantidad venta${cantidad != 1 ? 's' : ''} registrada${cantidad != 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.trending_up_rounded,
                  color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  // ── Título sección cuentas ────────────────────────────────────────────────
  Widget _buildSeccionTitulo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Cuentas abiertas',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          if (_cuentas.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_cuentas.length} activa${_cuentas.length != 1 ? 's' : ''}',
                style: const TextStyle(
                    color: primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  // ── Card de cuenta ────────────────────────────────────────────────────────
  Widget _cuentaCard(CuentaAbierta cuenta) {
    final minutos = DateTime.now().difference(cuenta.abiertaEn).inMinutes;
    final tiempoStr = minutos < 60
        ? '${minutos}min'
        : '${(minutos / 60).floor()}h ${minutos % 60}min';

    // Color del número de cuenta basado en el índice
    final colores = [
      const Color(0xFFE53935),
      const Color(0xFFF57C00),
      const Color(0xFF7B1FA2),
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFF00838F),
    ];
    final colorIdx = _cuentas.indexOf(cuenta) % colores.length;
    final color = colores[colorIdx];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: () => _abrirCuenta(cuenta),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Número / ícono cuenta
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      cuenta.nombre.length <= 2
                          ? cuenta.nombre.toUpperCase()
                          : cuenta.nombre.substring(0, 2).toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cuenta.nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 3),
                      Text(
                        cuenta.items.isEmpty
                            ? 'Vacía — toca para agregar'
                            : '${cuenta.cantidadItems} producto(s) · $tiempoStr abierta',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Total + cancelar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatoMoneda.format(cuenta.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryDark),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _cancelarCuenta(cuenta),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                            color: Colors.red.shade400, fontSize: 11),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primaryDark.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 38, color: primaryDark),
          ),
          const SizedBox(height: 16),
          const Text('Sin cuentas abiertas',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text('Toca "+ Nueva cuenta" para empezar',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────
class _QuickItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickItem(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
}