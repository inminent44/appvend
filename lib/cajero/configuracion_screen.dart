import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pos_caja/app_theme.dart';
import '../services/db_helper_cajero.dart';
import '../services/license_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  String _codigoDispositivo = '';
  bool _cargando = true;
  bool _turnoCerrado = false;
  String _fechaTurno = '';
  bool _importando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final codigo = await LicenseService.generarCodigoDispositivo();
    final cerrado = await DBHelperCajero.instance.esTurnoCerrado();
    final hoy = DateFormat('dd/MM/yyyy').format(DateTime.now());
    if (!mounted) return;
    setState(() {
      _codigoDispositivo = codigo;
      _turnoCerrado = cerrado;
      _fechaTurno = hoy;
      _cargando = false;
    });
  }

  void _copiarCodigo() {
    Clipboard.setData(ClipboardData(text: _codigoDispositivo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado al portapapeles')),
    );
  }

  Future<void> _importarInventario() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _importando = true);
    try {
      final file = File(result.files.single.path!);
      await DBHelperCajero.instance.importarInventarioAdmin(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventario importado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Turno actual', textTheme),
                  _buildTurnoCard(textTheme),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Inventario', textTheme),
                  _buildInventarioCard(textTheme),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Licencia', textTheme),
                  _buildLicenciaCard(textTheme),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Acerca de', textTheme),
                  _buildAcercaDeCard(textTheme),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, letterSpacing: 0.9),
      ),
    );
  }

  Widget _buildTurnoCard(TextTheme textTheme) {
    final turnoColor = _turnoCerrado ? Colors.orange : Colors.green;
    return Card(
      color: turnoColor.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              _turnoCerrado ? Icons.lock_clock : Icons.lock_open_outlined,
              color: turnoColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _turnoCerrado ? 'Turno cerrado' : 'Turno abierto',
                  style: textTheme.titleMedium?.copyWith(color: turnoColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fecha: $_fechaTurno',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventarioCard(TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Importar inventario del Admin',
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Carga el archivo .gv enviado por el administrador para actualizar productos y precios.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _importando ? null : _importarInventario,
                icon: _importando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(_importando ? 'Importando…' : 'Seleccionar archivo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenciaCard(TextTheme textTheme) {
    return Card(
      color: AppTheme.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smartphone_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Código de este equipo',
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SelectableText(
              _codigoDispositivo,
              style: textTheme.headlineSmall?.copyWith(color: AppTheme.primary, letterSpacing: 2, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copiarCodigo,
                style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.primary.withOpacity(0.5))),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar código'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Comparte este código con el Admin para generar o renovar tu licencia.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcercaDeCard(TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'VaraNova Vendedor',
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Versión 1.0.0',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'App de ventas simplificada. Toda la gestión del negocio se realiza desde la app Admin.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
