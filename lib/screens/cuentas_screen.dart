// lib/vendedor/screens/cuentas_screen.dart
//
// Pantalla principal del modo restaurante/caja.
// Reemplaza VentasScreen como tab 0 en VendedorScreen.
//
// Muestra la lista de cuentas abiertas y permite:
//   • Crear nueva cuenta (pide nombre)
//   • Entrar a una cuenta existente (agregar/quitar items, cobrar)
//   • Cancelar una cuenta (devuelve stock)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cuenta_abierta.dart';
import '../services/db_helper.dart';
import 'cuenta_detalle_screen.dart';

class CuentasScreen extends StatefulWidget {
  const CuentasScreen({super.key});

  @override
  State<CuentasScreen> createState() => CuentasScreenState();
}

class CuentasScreenState extends State<CuentasScreen> {
  static const Color primaryDark = Color(0xFF084B53);

  List<CuentaAbierta> _cuentas = [];
  bool _cargando = true;
  bool _turnoCerrado = false;

  final _formatoMoneda =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    setState(() => _cargando = true);
    final results = await Future.wait([
      DBHelper.instance.obtenerCuentasAbiertas(),
      DBHelper.instance.esTurnoCerrado(),
    ]);
    if (!mounted) return;
    setState(() {
      _cuentas = results[0] as List<CuentaAbierta>;
      _turnoCerrado = results[1] as bool;
      _cargando = false;
    });
  }

  // ── Crear cuenta nueva ────────────────────────────────────────────────────

  Future<void> _nuevaCuenta() async {
    if (_turnoCerrado) {
      _mostrarTurnoCerrado();
      return;
    }

    final controller = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva cuenta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre o número',
            hintText: 'Ej: Mesa 3, Para llevar, Juan…',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark, foregroundColor: Colors.white),
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (nombre == null || nombre.isEmpty) return;

    final cuenta = await DBHelper.instance.crearCuenta(nombre);
    if (!mounted) return;

    // Ir directo a la cuenta recién creada
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CuentaDetalleScreen(cuentaId: cuenta.id),
      ),
    );
    cargar();
  }

  // ── Abrir cuenta existente ────────────────────────────────────────────────

  Future<void> _abrirCuenta(CuentaAbierta cuenta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CuentaDetalleScreen(cuentaId: cuenta.id),
      ),
    );
    cargar();
  }

  // ── Cancelar cuenta ───────────────────────────────────────────────────────

  Future<void> _cancelarCuenta(CuentaAbierta cuenta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cuenta'),
        content: Text(
          'Se cancelará "${cuenta.nombre}" y se devolverá el stock de '
          '${cuenta.items.length} producto(s).\n\n¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
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
    cargar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta cancelada — stock devuelto')),
    );
  }

  void _mostrarTurnoCerrado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.lock_clock, color: Colors.orange),
          SizedBox(width: 8),
          Text('Turno cerrado'),
        ]),
        content: const Text(
          'No se pueden crear cuentas nuevas.\n'
          'Ve a Cierre → Iniciar Nuevo Día para continuar.',
        ),
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
      appBar: AppBar(
        title: const Text('Cuentas'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Banner turno cerrado
                if (_turnoCerrado)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade50,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_clock,
                            color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Turno cerrado — no se pueden crear cuentas nuevas',
                          style: TextStyle(
                              color: Colors.orange, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Lista de cuentas
                Expanded(
                  child: _cuentas.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          onRefresh: cargar,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _cuentas.length,
                            itemBuilder: (context, i) =>
                                _cuentaCard(_cuentas[i]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaCuenta,
        backgroundColor: _turnoCerrado ? Colors.grey : primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva cuenta'),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Sin cuentas abiertas',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toca "+ Nueva cuenta" para empezar',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _cuentaCard(CuentaAbierta cuenta) {
    final minutos = DateTime.now().difference(cuenta.abiertaEn).inMinutes;
    final tiempoStr = minutos < 60
        ? '${minutos}min'
        : '${(minutos / 60).floor()}h ${minutos % 60}min';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirCuenta(cuenta),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono cuenta
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_outlined,
                    color: primaryDark, size: 22),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cuenta.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cuenta.items.isEmpty
                          ? 'Vacía — toca para agregar productos'
                          : '${cuenta.items.length} producto(s) · $tiempoStr abierta',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
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
                          color: Colors.red.shade400, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
