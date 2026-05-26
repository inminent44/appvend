import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'login_screen.dart';
import 'inventario_screen.dart';
import 'cierres_admin_screen.dart';
import 'backup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainAdminScreen extends StatefulWidget {
  const MainAdminScreen({super.key});
  @override
  State<MainAdminScreen> createState() => _MainAdminScreenState();
}

class _MainAdminScreenState extends State<MainAdminScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    InventarioScreen(),
    CierresAdminScreen(),
    BackupScreen(),
  ];

  Future<void> _cerrarSesion() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _mostrarPanelGestorV() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GestorVSheet(
        onResetPass: () async {
          await AuthService.setPassword('1234');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Contraseña reseteada a 1234')));
        },
        onBorrarAdmin: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('admin_password');
          await prefs.remove('recup_pregunta');
          await prefs.remove('recup_respuesta');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Cuenta admin eliminada')));
        },
        onIrBackup: () => setState(() => _selectedIndex = 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      drawer: _buildDrawer(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black26,
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

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(children: [
          // Header del drawer con gradiente
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryDark, Color(0xFF0A6B77)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_moon_outlined,
                    color: Colors.white, size: 26)),
              const SizedBox(height: 14),
              const Text('Administrador',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Text('VaraNova Admin',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),

          const SizedBox(height: 12),

          if (AuthService.esGestorV)
            _drawerItem(
              icon: Icons.shield_moon_outlined,
              label: 'Panel GestorV',
              color: primaryDark,
              onTap: _mostrarPanelGestorV,
            ),

          _drawerItem(
            icon: Icons.logout,
            label: 'Cerrar Sesión',
            color: Colors.red,
            onTap: () { Navigator.pop(context); _cerrarSesion(); },
          ),
        ]),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18)),
      title: Text(label, style: TextStyle(color: color,
          fontWeight: FontWeight.w600, fontSize: 14)),
      onTap: onTap,
    );
  }
}

// ── Panel GestorV como BottomSheet ────────────────────────────────────────────
class _GestorVSheet extends StatelessWidget {
  final VoidCallback onResetPass;
  final VoidCallback onBorrarAdmin;
  final VoidCallback onIrBackup;

  const _GestorVSheet({
    required this.onResetPass,
    required this.onBorrarAdmin,
    required this.onIrBackup,
  });

  static const Color primaryDark = Color(0xFF084B53);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(bottom: 20),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),

        Container(width: 56, height: 56,
          decoration: BoxDecoration(
            color: primaryDark.withAlpha(20), shape: BoxShape.circle),
          child: const Icon(Icons.shield_moon_outlined, color: primaryDark, size: 26)),
        const SizedBox(height: 12),
        const Text('Panel GestorV', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        Text('Acceso de superusuario',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),

        const SizedBox(height: 24),

        _opcion(context, icon: Icons.lock_reset, color: primaryDark,
            label: 'Resetear contraseña del admin',
            sub: 'La deja en 1234 temporalmente',
            onTap: () { Navigator.pop(context); onResetPass(); }),

        const SizedBox(height: 10),

        _opcion(context, icon: Icons.cloud_sync_outlined, color: primaryDark,
            label: 'Ir a Backup / Exportar',
            sub: 'Accede directamente a la pantalla de backup',
            onTap: () { Navigator.pop(context); onIrBackup(); }),

        const SizedBox(height: 10),

        _opcion(context, icon: Icons.delete_forever, color: Colors.red,
            label: 'Borrar cuenta del admin',
            sub: 'Permite crear una cuenta nueva desde cero',
            destructivo: true,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('¿Borrar cuenta admin?'),
                  content: const Text(
                      'El admin tendrá que registrarse de nuevo desde cero.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Borrar'),
                    ),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              Navigator.pop(context);
              onBorrarAdmin();
            }),
      ]),
    );
  }

  Widget _opcion(BuildContext context, {
    required IconData icon, required Color color,
    required String label, required String sub,
    required VoidCallback onTap, bool destructivo = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: destructivo ? Colors.red.shade50 : const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(14),
          border: destructivo ? Border.all(color: Colors.red.shade100) : null,
        ),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600,
                  fontSize: 13, color: destructivo ? Colors.red.shade700
                      : const Color(0xFF1A1A2E))),
              Text(sub, style: TextStyle(color: Colors.grey.shade500,
                  fontSize: 11)),
            ])),
          Icon(Icons.chevron_right,
              color: destructivo ? Colors.red.shade300 : Colors.grey.shade400,
              size: 18),
        ]),
      ),
    );
  }
}