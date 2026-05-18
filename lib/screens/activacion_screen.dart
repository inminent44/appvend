import 'package:flutter/material.dart';
import '../services/license_service.dart';

class ActivacionScreen extends StatefulWidget {
  final VoidCallback onActivada;
  const ActivacionScreen({super.key, required this.onActivada});

  @override
  State<ActivacionScreen> createState() => _ActivacionScreenState();
}

class _ActivacionScreenState extends State<ActivacionScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  final TextEditingController _codigoController = TextEditingController();
  bool _cargando = false;
  String _codigoDispositivo = '';

  @override
  void initState() {
    super.initState();
    _obtenerId();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _obtenerId() async {
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
      widget.onActivada();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Licencia Inválida'),
          content: const Text(
            'El código no es válido para este dispositivo.\n\n'
            'Asegúrate de usar una licencia de tipo ADMIN (BA-...).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_moon_outlined,
                  size: 90, color: primaryDark),
              const SizedBox(height: 16),
              const Text(
                'VaraNova Admin',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: primaryDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Activa tu licencia para continuar',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
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
                    const Text('Código de este equipo:',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    SelectableText(
                      _codigoDispositivo.isEmpty ? '...' : _codigoDispositivo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.blue,
                          letterSpacing: 2),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Envía este código al administrador del sistema',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _codigoController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Licencia Admin (BA-...)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _activar,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryDark,
                      foregroundColor: Colors.white),
                  child: _cargando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ACTIVAR ADMIN',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
