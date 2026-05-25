import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pos_caja/app_theme.dart';
import '../../services/db_helper_admin.dart';
import '../auth_service.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  Future<void> _exportarBackup(BuildContext context) async {
    try {
      final ruta = await DBHelperAdmin.instance.exportarBackup();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup guardado en: \n$ruta')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  Future<void> _restaurarBackup(BuildContext context) async {
    final confirmar = await _showConfirmationDialog(
      context,
      title: 'Restaurar Backup',
      content: 'Esta acción reemplazará TODOS los datos actuales. ¿Estás seguro?',
      confirmText: 'Restaurar',
    );
    if (confirmar != true) return;

    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['db']);
    if (result == null || result.files.single.path == null) return;

    try {
      await DBHelperAdmin.instance.restaurarBackup(File(result.files.single.path!));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restaurado correctamente ✓')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $e')),
        );
      }
    }
  }

  Future<void> _cambiarPassword(BuildContext context) async {
    final actualController = TextEditingController();
    final nuevoController = TextEditingController();
    final confirmarController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: actualController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual')),
            const SizedBox(height: 12),
            TextField(controller: nuevoController, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contraseña')),
            const SizedBox(height: 12),
            TextField(controller: confirmarController, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nuevoController.text != confirmarController.text) {
                _showError(context, 'Las contraseñas no coinciden');
                return;
              }
              if (nuevoController.text.length < 4) {
                _showError(context, 'Mínimo 4 caracteres');
                return;
              }
              final ok = await AuthService.instance.login(actualController.text);
              if (!context.mounted) return;
              if (!ok) {
                 _showError(context, 'Contraseña actual incorrecta');
                return;
              }
              await AuthService.instance.actualizarPassword(nuevoController.text);
              if(context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada ✓')));
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }
  
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<bool?> _showConfirmationDialog(BuildContext context, {required String title, required String content, required String confirmText}) {
     return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sistema')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionCard(
            context: context,
            icon: Icons.security_outlined,
            title: 'Seguridad',
            content: 'Gestiona la seguridad de tu cuenta de administrador.',
            actions: [
              _buildActionButton(
                context,
                icon: Icons.lock_reset_outlined,
                label: 'Cambiar Contraseña',
                onTap: () => _cambiarPassword(context),
              ),
            ],
          ),
          _buildSectionCard(
            context: context,
            icon: Icons.storage_outlined,
            title: 'Base de Datos',
            content: 'Crea copias de seguridad de todos tus datos o restaura a partir de un archivo.',
            actions: [
              _buildActionButton(
                context,
                icon: Icons.backup_outlined,
                label: 'Exportar Backup (.db)',
                onTap: () => _exportarBackup(context),
              ),
              const SizedBox(height: 12),
               _buildActionButton(
                context,
                icon: Icons.restore_page_outlined,
                label: 'Restaurar desde Backup',
                onTap: () => _restaurarBackup(context),
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required BuildContext context, required IconData icon, required String title, required String content, required List<Widget> actions}) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 30, color: AppTheme.primary),
                const SizedBox(width: 12),
                Text(title, style: textTheme.headlineSmall?.copyWith(color: AppTheme.primary)),
              ],
            ),
            const Divider(height: 24),
            Text(content, style: textTheme.bodyLarge),
            const SizedBox(height: 20),
            ...actions,
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, bool isDestructive = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDestructive ? Colors.red.shade700 : AppTheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }
}
