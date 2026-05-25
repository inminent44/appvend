import 'package:flutter/material.dart';
import 'package:pos_caja/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import 'login_screen.dart';
import 'inventario_screen.dart';
import '../cierres_admin_screen.dart';
import 'backup_screen.dart';

class MainAdminScreen extends StatelessWidget {
  const MainAdminScreen({super.key});

  void _logout(BuildContext context) {
    AuthService.instance.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('VaraNova Admin', style: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        children: [
          _buildDashboardCard(
            context,
            icon: Icons.inventory_2_outlined,
            label: 'Inventario',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventarioScreen())),
          ),
          _buildDashboardCard(
            context,
            icon: Icons.point_of_sale_outlined,
            label: 'Cierres de Caja',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CierresAdminScreen())),
          ),
          _buildDashboardCard(
            context,
            icon: Icons.cloud_sync_outlined,
            label: 'Backup y Restauración',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
          ),
          if (AuthService.instance.esGestorV) 
            _buildDashboardCard(
              context,
              icon: Icons.shield_moon_outlined,
              label: 'Panel GestorV',
              onTap: () => _mostrarPanelGestorV(context),
              isSpecial: true,
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, bool isSpecial = false}) {
    final cardColor = isSpecial ? AppTheme.accent.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1);
    final iconColor = isSpecial ? AppTheme.accent : AppTheme.primary;

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: iconColor),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: iconColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarPanelGestorV(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Panel GestorV', style: Theme.of(context).textTheme.headlineSmall),
            const Text('Acceso de superusuario', style: TextStyle(color: Colors.grey)),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: AppTheme.primary),
              title: const Text('Resetear contraseña del admin'),
              subtitle: const Text('La deja en 1234'),
              onTap: () async {
                await AuthService.instance.actualizarPassword('1234');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña reseteada a 1234.')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Borrar cuenta del admin', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Permite crear una cuenta nueva'),
              onTap: () => _confirmarBorrarCuenta(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarBorrarCuenta(BuildContext context) async {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Borrar cuenta admin'),
          content: const Text('¿Seguro? El admin tendrá que registrarse de nuevo.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_password');
      await prefs.remove('recup_pregunta');
      await prefs.remove('recup_respuesta');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta admin eliminada.')));
  }
}
