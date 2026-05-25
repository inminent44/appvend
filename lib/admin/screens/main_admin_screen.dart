import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import 'login_screen.dart';
import 'inventario_screen.dart';
import '../cierres_admin_screen.dart';
import 'backup_screen.dart';

class MainAdminScreen extends StatefulWidget {
  const MainAdminScreen({super.key});

  @override
  State<MainAdminScreen> createState() => _MainAdminScreenState();
}

class _MainAdminScreenState extends State<MainAdminScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const InventarioScreen(),
    const CierresAdminScreen(),
    const BackupScreen(),
  ];

  Future<void> _cerrarSesion() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _mostrarPanelGestorV() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Panel GestorV',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryDark)),
            const SizedBox(height: 4),
            const Text('Acceso de superusuario',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(height: 24),
            ListTile(
              leading:
                  const Icon(Icons.lock_reset, color: primaryDark),
              title: const Text('Resetear contraseña del admin'),
              subtitle: const Text('La deja en 1234'),
              onTap: () async {
                await AuthService.instance.actualizarPassword('1234');
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Contraseña reseteada a 1234. Dile al admin que la cambie.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever,
                  color: Colors.red),
              title: const Text('Borrar cuenta del admin',
                  style: TextStyle(color: Colors.red)),
              subtitle:
                  const Text('Permite crear una cuenta nueva'),
              onTap: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Borrar cuenta admin'),
                    content: const Text(
                        '¿Seguro? El admin tendrá que registrarse de nuevo desde cero.'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        onPressed: () =>
                            Navigator.pop(context, true),
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
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Cuenta admin eliminada.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined,
                  color: primaryDark),
              title: const Text('Ir a Backup / Exportar'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 2);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VaraNova Admin'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: primaryDark,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_moon_outlined,
                        color: Colors.white, size: 40),
                    SizedBox(height: 10),
                    Text('Administrador',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('VaraNova Admin',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (AuthService.instance.esGestorV)
                ListTile(
                  leading: const Icon(Icons.shield_moon_outlined,
                      color: primaryDark),
                  title: const Text('Panel GestorV',
                      style: TextStyle(
                          color: primaryDark,
                          fontWeight: FontWeight.bold)),
                  onTap: _mostrarPanelGestorV,
                ),
              ListTile(
                leading:
                    const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar Sesión',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _cerrarSesion();
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) =>
            setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.move_to_inbox_outlined),
            selectedIcon: Icon(Icons.move_to_inbox),
            label: 'Cierres',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_sync_outlined),
            selectedIcon: Icon(Icons.cloud_sync),
            label: 'Backup',
          ),
        ],
      ),
    );
  }
}
