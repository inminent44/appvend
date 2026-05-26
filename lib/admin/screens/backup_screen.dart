import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/db_helper_admin.dart';
import '../auth_service.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  static const Color primaryDark = Color(0xFF084B53);
  static const Color primaryMid  = Color(0xFF0A6B77);
  static const Color bgPage      = Color(0xFFF4F6F8);

  Future<void> _exportarBackup(BuildContext context) async {
    try {
      await DBHelperAdmin.instance.exportarBackup();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al exportar: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _restaurarBackup(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18)),
          const SizedBox(width: 12),
          const Text('Restaurar Backup', style: TextStyle(fontSize: 17)),
        ]),
        content: const Text(
          'Esta acción reemplazará TODOS los datos actuales con los del backup.\n\n¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
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
      await DBHelperAdmin.instance.restaurarBackup(File(path));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 10),
          Text('Backup restaurado correctamente ✓'),
        ]),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al restaurar: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _cambiarPassword(BuildContext context) async {
    final actualCtrl    = TextEditingController();
    final nuevoCtrl     = TextEditingController();
    final confirmarCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(margin: const EdgeInsets.only(bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),

            // Ícono + título
            Container(width: 56, height: 56,
              decoration: BoxDecoration(
                color: primaryDark.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.lock_reset, color: primaryDark, size: 26)),
            const SizedBox(height: 12),
            const Text('Cambiar Contraseña',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 24),

            _passField(actualCtrl, 'Contraseña actual'),
            const SizedBox(height: 12),
            _passField(nuevoCtrl, 'Nueva contraseña'),
            const SizedBox(height: 12),
            _passField(confirmarCtrl, 'Confirmar nueva contraseña'),
            const SizedBox(height: 24),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDark, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  onPressed: () async {
                    if (nuevoCtrl.text != confirmarCtrl.text) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Las contraseñas no coinciden')));
                      return;
                    }
                    if (nuevoCtrl.text.length < 4) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Mínimo 4 caracteres')));
                      return;
                    }
                    final ok = await AuthService.login(actualCtrl.text);
                    if (!ctx.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Contraseña actual incorrecta')));
                      return;
                    }
                    await AuthService.setPassword(nuevoCtrl.text);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Row(children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Contraseña actualizada ✓'),
                      ]),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  child: const Text('GUARDAR',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _passField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF4F6F8),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.lock_outline, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: Column(
        children: [
          // ── Header gradiente ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryDark, primaryMid],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20, right: 20, bottom: 32,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backup', style: TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Respalda y restaura los datos del negocio',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),

          // ── Opciones ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _opcionCard(
                  context,
                  icon: Icons.lock_reset,
                  color: primaryDark,
                  titulo: 'Cambiar Contraseña',
                  subtitulo: 'Actualiza tu contraseña de acceso al sistema',
                  onTap: () => _cambiarPassword(context),
                ),
                const SizedBox(height: 14),
                _opcionCard(
                  context,
                  icon: Icons.backup_outlined,
                  color: const Color(0xFF1565C0),
                  titulo: 'Exportar Backup',
                  subtitulo: 'Comparte o guarda una copia de todos los datos',
                  onTap: () => _exportarBackup(context),
                ),
                const SizedBox(height: 14),
                _opcionCard(
                  context,
                  icon: Icons.restore,
                  color: Colors.red.shade600,
                  titulo: 'Restaurar Backup',
                  subtitulo: 'Reemplaza los datos con una copia guardada',
                  onTap: () => _restaurarBackup(context),
                  destructivo: true,
                ),
                const SizedBox(height: 24),

                // Nota informativa
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8, offset: const Offset(0, 3),
                    )],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50, shape: BoxShape.circle),
                        child: Icon(Icons.info_outline,
                            color: Colors.blue.shade400, size: 16)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Realiza backups frecuentes para proteger los datos del negocio. '
                          'Guarda el archivo en un lugar seguro como Drive o correo.',
                          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _opcionCard(BuildContext context, {
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    bool destructivo = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
          border: destructivo
              ? Border.all(color: Colors.red.shade100)
              : null,
        ),
        child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 14, color: destructivo ? Colors.red.shade700
                      : const Color(0xFF1A1A2E))),
              const SizedBox(height: 3),
              Text(subtitulo, style: TextStyle(color: Colors.grey.shade500,
                  fontSize: 12)),
            ],
          )),
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
        ]),
      ),
    );
  }
}