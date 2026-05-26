// lib/vendedor/screens/pago_sheet.dart
//
// Bottom sheet para seleccionar método de pago y moneda.
// Soporta: efectivo, tarjeta, QR (Transfermovil / ENZONA).
// Multimoneda: CUP, USD, EUR, CAD con tasas configurables.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/db_helper_cajero.dart';

class PagoSheet extends StatefulWidget {
  /// Total de la venta en CUP.
  final double totalCup;

  const PagoSheet({super.key, required this.totalCup});

  /// Muestra el sheet y devuelve [PagoResult] o null si se cancela.
  static Future<PagoResult?> mostrar(BuildContext context, double totalCup) {
    return showModalBottomSheet<PagoResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PagoSheet(totalCup: totalCup),
    );
  }

  @override
  State<PagoSheet> createState() => _PagoSheetState();
}

class _PagoSheetState extends State<PagoSheet> {
  static const Color primaryDark = Color(0xFF084B53);

  // Método de pago
  String _metodo = 'efectivo'; // efectivo | tarjeta | qr

  // Moneda
  String _moneda = 'CUP';
  List<Map<String, dynamic>> _tasas = [];

  // QR
  String _plataforma = 'Transfermovil';
  final _refCtrl     = TextEditingController();
  final _montoCtrl   = TextEditingController();
  final _fechaCtrl   = TextEditingController();
  String _monedaQr   = 'CUP';

  final _fmtCup = NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'es_MX');

  @override
  void initState() {
    super.initState();
    _cargarTasas();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _montoCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTasas() async {
    final t = await DBHelperCajero.instance.obtenerTasas();
    if (!mounted) return;
    setState(() => _tasas = t);
  }

  double get _tasaActual {
    if (_tasas.isEmpty) return 1.0;
    final t = _tasas.firstWhere((t) => t['moneda'] == _moneda, orElse: () => {'tasa': 1.0});
    return (t['tasa'] as num).toDouble();
  }

  /// Total en la moneda seleccionada
  double get _totalEnMoneda {
    if (_moneda == 'CUP') return widget.totalCup;
    return widget.totalCup / _tasaActual;
  }

  String get _simboloMoneda {
    const simbolos = {'CUP': '\$', 'USD': 'US\$', 'EUR': '€', 'CAD': 'CA\$'};
    return simbolos[_moneda] ?? '\$';
  }

  bool get _puedeConfirmar {
    if (_metodo == 'qr') {
      return _refCtrl.text.trim().isNotEmpty &&
             _montoCtrl.text.trim().isNotEmpty &&
             _fechaCtrl.text.trim().isNotEmpty;
    }
    return true;
  }

  void _confirmar() {
    double montoMoneda = _totalEnMoneda;
    String monedaFinal = _moneda;
    double tasaFinal   = _tasaActual;

    if (_metodo == 'qr') {
      montoMoneda = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? _totalEnMoneda;
      monedaFinal = _monedaQr;
      final tasaQr = _tasas.firstWhere((t) => t['moneda'] == _monedaQr, orElse: () => {'tasa': 1.0});
      tasaFinal = (tasaQr['tasa'] as num).toDouble();
    }

    Navigator.pop(context, PagoResult(
      metodo:        _metodo,
      moneda:        monedaFinal,
      montoMoneda:   montoMoneda,
      tasaCambio:    tasaFinal,
      refTransaccion: _metodo == 'qr' ? _refCtrl.text.trim() : null,
      plataformaQr:   _metodo == 'qr' ? _plataforma : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Método de Pago',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),

            // ── Total a pagar ──────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total CUP',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(
                    _fmtCup.format(widget.totalCup),
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: primaryDark,
                    ),
                  ),
                ],
              ),
            ),

            // ── Selector de método ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _metodoBtn('efectivo', Icons.payments_outlined, 'Efectivo'),
                  const SizedBox(width: 8),
                  _metodoBtn('tarjeta', Icons.credit_card_outlined, 'Tarjeta'),
                  const SizedBox(width: 8),
                  _metodoBtn('qr', Icons.qr_code_outlined, 'QR / Transfer'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Panel según método ─────────────────────────────────────
            if (_metodo == 'efectivo') _panelEfectivo(),
            if (_metodo == 'tarjeta')  _panelTarjeta(),
            if (_metodo == 'qr')       _panelQr(),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Botón confirmar ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _puedeConfirmar ? primaryDark : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _puedeConfirmar ? _confirmar : null,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Confirmar cobro',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Botón de método ──────────────────────────────────────────────────────
  Widget _metodoBtn(String key, IconData icon, String label) {
    final selected = _metodo == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metodo = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primaryDark : const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primaryDark : Colors.grey.shade200,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.grey.shade600,
                  size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Panel Efectivo ──────────────────────────────────────────────────────
  Widget _panelEfectivo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Moneda de pago',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          _selectorMoneda(_moneda, (v) => setState(() => _moneda = v!)),
          if (_moneda != 'CUP') ...[
            const SizedBox(height: 12),
            _equivalenciaCard(),
          ],
        ],
      ),
    );
  }

  // ── Panel Tarjeta ──────────────────────────────────────────────────────
  Widget _panelTarjeta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Moneda de la tarjeta',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          _selectorMoneda(_moneda, (v) => setState(() => _moneda = v!)),
          if (_moneda != 'CUP') ...[
            const SizedBox(height: 12),
            _equivalenciaCard(),
          ],
        ],
      ),
    );
  }

  // ── Panel QR ────────────────────────────────────────────────────────────
  Widget _panelQr() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plataforma
          const Text('Plataforma',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              _plataformaBtn('Transfermovil', 'TM'),
              const SizedBox(width: 10),
              _plataformaBtn('ENZONA', 'EZ'),
            ],
          ),

          const SizedBox(height: 16),
          const Text('Moneda de la transferencia',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          _selectorMoneda(_monedaQr, (v) => setState(() => _monedaQr = v!)),

          const SizedBox(height: 16),

          // ID de transacción
          TextField(
            controller: _refCtrl,
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco(
              'ID / Código de transacción *',
              Icons.tag_outlined,
            ),
          ),

          const SizedBox(height: 10),

          // Monto pagado (en moneda seleccionada)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _montoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDeco(
                    'Monto pagado ($_monedaQr) *',
                    Icons.attach_money,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Fecha de la transacción
          TextField(
            controller: _fechaCtrl,
            keyboardType: TextInputType.datetime,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco(
              'Fecha (dd/mm/aaaa) *',
              Icons.calendar_today_outlined,
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) {
                _fechaCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
                setState(() {});
              }
            },
          ),

          const SizedBox(height: 12),

          // Equivalencia
          _equivalenciaCardQr(),
        ],
      ),
    );
  }

  Widget _plataformaBtn(String nombre, String sigla) {
    final sel = _plataforma == nombre;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _plataforma = nombre),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? primaryDark.withAlpha(20) : const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? primaryDark : Colors.grey.shade200,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(nombre,
                style: TextStyle(
                  color: sel ? primaryDark : Colors.grey.shade700,
                  fontWeight:
                      sel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                )),
          ),
        ),
      ),
    );
  }

  Widget _selectorMoneda(String valor, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: const Color(0xFFF4F6F8),
      ),
      items: _tasas.isEmpty
          ? const []
          : _tasas.map((t) {
              final m = t['moneda'] as String;
              final n = t['nombre'] as String;
              final tasa = (t['tasa'] as num).toDouble();
              return DropdownMenuItem<String>(
                value: m,
                child: Text(
                  m == 'CUP'
                      ? 'CUP — Peso Cubano'
                      : '$m — $n (1 $m = ${tasa.toStringAsFixed(0)} CUP)',
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _equivalenciaCard() {
    final equiv = _totalEnMoneda;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryDark.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryDark.withAlpha(40)),
      ),
      child: Column(
        children: [
          Text(
            '$_simboloMoneda${equiv.toStringAsFixed(2)} $_moneda',
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '1 $_moneda = ${_tasaActual.toStringAsFixed(0)} CUP',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _equivalenciaCardQr() {
    final tasaQ = _tasas.firstWhere(
      (t) => t['moneda'] == _monedaQr,
      orElse: () => {'tasa': 1.0},
    );
    final tasa = (tasaQ['tasa'] as num).toDouble();
    final equiv = _monedaQr == 'CUP'
        ? widget.totalCup
        : widget.totalCup / tasa;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryDark.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryDark.withAlpha(40)),
      ),
      child: Column(
        children: [
          Text(
            'Equivale a: ${equiv.toStringAsFixed(2)} $_monedaQr',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: primaryDark),
          ),
          if (_monedaQr != 'CUP') ...[
            const SizedBox(height: 3),
            Text(
              '1 $_monedaQr = ${tasa.toStringAsFixed(0)} CUP',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF4F6F8),
    );
  }
}

// ─── Resultado del pago ────────────────────────────────────────────────────

class PagoResult {
  final String  metodo;
  final String  moneda;
  final double  montoMoneda;
  final double  tasaCambio;
  final String? refTransaccion;
  final String? plataformaQr;

  const PagoResult({
    required this.metodo,
    required this.moneda,
    required this.montoMoneda,
    required this.tasaCambio,
    this.refTransaccion,
    this.plataformaQr,
  });

  String get etiquetaMetodo {
    switch (metodo) {
      case 'tarjeta': return 'Tarjeta';
      case 'qr':      return plataformaQr ?? 'QR';
      default:        return 'Efectivo';
    }
  }

  IconData get iconoMetodo {
    switch (metodo) {
      case 'tarjeta': return Icons.credit_card_outlined;
      case 'qr':      return Icons.qr_code_outlined;
      default:        return Icons.payments_outlined;
    }
  }
}