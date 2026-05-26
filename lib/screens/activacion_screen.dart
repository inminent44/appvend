import 'package:flutter/material.dart';
import '../../services/license_service.dart';

/// Pantalla de activación compartida entre modo Admin y modo Cajero.
///
/// No necesita saber de antemano qué modo va a activarse: acepta BA y BV.
/// Tras una activación exitosa llama a [onActivada] para que [MyApp]
/// detecte el modo y enrute a la pantalla correcta.
class ActivacionScreen extends StatefulWidget {
  final Future<void> Function() onActivada;

  const ActivacionScreen({super.key, required this.onActivada});

  @override
  State<ActivacionScreen> createState() => _ActivacionScreenState();
}

class _ActivacionScreenState extends State<ActivacionScreen> {
  static const Color primaryDark = Color(0xFF084B53);

  final TextEditingController _codigoController = TextEditingController();
  bool   _cargando           = false;
  String _codigoDispositivo  = '';

  @override
  void initState() {
    super.initState();
    _obtenerCodigo();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _obtenerCodigo() async {
    final id = await LicenseService.generarCodigoDispositivo();
    if (!mounted) return;
    setState(() => _codigoDispositivo = id);
  }

  Future<void> _activar() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) return;

    setState(() => _cargando = true);
    final valido = await LicenseService.validarYActivar(codigo);
    if (!mounted) return;
    setState(() => _cargando = false);

    if (valido) {
      // onActivada es async: espera a que main.dart inicialice la DB y cambie el modo
      await widget.onActivada();
    } else {
      _mostrarErrorLicencia(codigo);
    }
  }

  void _mostrarErrorLicencia(String codigoIngresado) {
    // Detectamos qué prefijo usó para dar un mensaje más preciso
    final prefijo = codigoIngresado.trim().toUpperCase().split('-').first;
    String detalle;
    if (prefijo == 'BA') {
      detalle = 'La licencia Admin (BA-...) no es válida para este dispositivo '
          'o ya expiró.';
    } else if (prefijo == 'BV') {
      detalle = 'La licencia Cajero (BV-...) no es válida para este dispositivo '
          'o ya expiró.';
    } else {
      detalle = 'El código no tiene un formato reconocido.\n\n'
          '• Licencias Admin comienzan con BA-\n'
          '• Licencias Cajero comienzan con BV-';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Licencia Inválida'),
          ],
        ),
        content: Text(detalle),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ── Logo ──────────────────────────────────────────────────────
              const Icon(Icons.shield_moon_outlined,
                  size: 90, color: primaryDark),
              const SizedBox(height: 16),
              const Text(
                'VaraNova',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Activa tu licencia para continuar',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 40),

              // ── Código del dispositivo ────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Código de este equipo:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _codigoDispositivo.isEmpty
                          ? '...'
                          : _codigoDispositivo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.blue,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Envía este código al proveedor para obtener tu licencia',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ── Campo de licencia ─────────────────────────────────────────
              TextField(
                controller: _codigoController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Código de licencia (BA-... o BV-...)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  helperText: 'Admin: BA-...   ·   Cajero: BV-...',
                  helperStyle: const TextStyle(fontSize: 11),
                  suffixIcon: _codigoController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _codigoController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // ── Botón activar ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _activar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _cargando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ACTIVAR',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Nota informativa ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La licencia es personal para este dispositivo. '
                        'No puede usarse en otro equipo ni transferirse.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}