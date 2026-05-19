import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/auth_service.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  static const Color primaryDark = Color(0xFF084B53);

  Future<void> _exportarBackup(BuildContext context) async {
    try {
      await DBHelper.instance.exportarBackup();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar backup: $e')),
      );
    }
  }

  Future<void> _restaurarBackup(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Backup'),
        content: const Text(
          '⚠️ Esta acción reemplazará TODOS los datos actuales con los del backup.\n\n'
          '¿Estás seguro?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;

    try {
      await DBHelper.instance.restaurarBackup(File(path));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado correctamente ✓')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al restaurar: $e')),
      );
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
            TextField(
              controller: actualController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Contraseña actual', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nuevoController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Nueva contraseña', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmarController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark, foregroundColor: Colors.white),
            onPressed: () async {
              if (nuevoController.text != confirmarController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Las contraseñas no coinciden')),
                );
                return;
              }
              if (nuevoController.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mínimo 4 caracteres')),
                );
                return;
              }
              final ok =
                  await AuthService.instance.login(actualController.text);
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contraseña actual incorrecta')),
                );
                return;
              }
              await AuthService.instance
                  .actualizarPassword(nuevoController.text);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Contraseña actualizada correctamente ✓')),
              );
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup / Restaurar'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_sync_outlined, size: 90, color: primaryDark),
            const SizedBox(height: 16),
            const Text(
              'Respalda o restaura todos los datos del negocio',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 48),
            _buildBoton(
              context,
              icon: Icons.lock_reset,
              label: 'CAMBIAR CONTRASEÑA',
              subtitle: 'Actualiza tu contraseña de acceso',
              color: primaryDark,
              onTap: () => _cambiarPassword(context),
            ),
            const SizedBox(height: 16),
            _buildBoton(
              context,
              icon: Icons.backup_outlined,
              label: 'EXPORTAR BACKUP',
              subtitle: 'Guarda una copia de todos los datos',
              color: primaryDark,
              onTap: () => _exportarBackup(context),
            ),
            const SizedBox(height: 16),
            _buildBoton(
              context,
              icon: Icons.restore,
              label: 'RESTAURAR BACKUP',
              subtitle: 'Reemplaza los datos con una copia guardada',
              color: Colors.red.shade700,
              onTap: () => _restaurarBackup(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
