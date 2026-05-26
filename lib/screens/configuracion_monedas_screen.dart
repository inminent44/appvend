// lib/vendedor/screens/configuracion_monedas_screen.dart
//
// Permite al cajero/admin configurar las tasas de cambio manualmente.
// 1 USD = X CUP, 1 EUR = X CUP, etc.
// La tasa de CUP siempre es 1 y no se puede editar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/db_helper_cajero.dart';

class ConfiguracionMonedasScreen extends StatefulWidget {
  const ConfiguracionMonedasScreen({super.key});

  @override
  State<ConfiguracionMonedasScreen> createState() =>
      _ConfiguracionMonedasScreenState();
}

class _ConfiguracionMonedasScreenState
    extends State<ConfiguracionMonedasScreen> {
  static const Color primaryDark = Color(0xFF084B53);

  List<Map<String, dynamic>> _tasas = [];
  final Map<String, TextEditingController> _controllers = {};
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final tasas = await DBHelperCajero.instance.obtenerTasas();
    if (!mounted) return;
    setState(() {
      _tasas = tasas;
      for (final t in tasas) {
        final m = t['moneda'] as String;
        final tasa = (t['tasa'] as num).toDouble();
        _controllers[m] = TextEditingController(
          text: tasa == tasa.truncateToDouble()
              ? tasa.toStringAsFixed(0)
              : tasa.toStringAsFixed(2),
        );
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      for (final t in _tasas) {
        final m = t['moneda'] as String;
        if (m == 'CUP') continue;
        final ctrl = _controllers[m];
        if (ctrl == null) continue;
        final tasa =
            double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 1.0;
        if (tasa <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tasa inválida para $m')),
            );
          }
          return;
        }
        await DBHelperCajero.instance.actualizarTasa(m, tasa);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tasas guardadas ✓'),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasas de Cambio'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text('Tasas manuales',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Ingresa cuántos pesos cubanos (CUP) equivale '
                          'cada moneda extranjera. La app recalculará '
                          'automáticamente al cobrar.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tarjetas de tasas
                  ..._tasas.map((t) {
                    final m    = t['moneda'] as String;
                    final n    = t['nombre'] as String;
                    final esCup = m == 'CUP';
                    final ctrl  = _controllers[m];
                    return _tasaCard(m, n, ctrl, esCup);
                  }),

                  const SizedBox(height: 32),

                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _guardando ? 'Guardando...' : 'Guardar tasas',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tasaCard(
    String moneda,
    String nombre,
    TextEditingController? ctrl,
    bool esCup,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _flagChip(moneda),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(moneda,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryDark)),
                  Text(nombre,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
              if (esCup) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Text('Base',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),

          if (!esCup) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('1 ', style: TextStyle(fontSize: 15)),
                Text(moneda,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: primaryDark)),
                const Text(' = ', style: TextStyle(fontSize: 15)),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                    ],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: primaryDark),
                    decoration: InputDecoration(
                      suffixText: 'CUP',
                      suffixStyle: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.normal,
                          fontSize: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF4F6F8),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (esCup) ...[
            const SizedBox(height: 6),
            const Text(
              'El CUP es la moneda base. Todas las tasas se calculan respecto a él.',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _flagChip(String moneda) {
    final emojis = {
      'CUP': '🇨🇺',
      'USD': '🇺🇸',
      'EUR': '🇪🇺',
      'CAD': '🇨🇦',
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: primaryDark.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(emojis[moneda] ?? '💱', style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}