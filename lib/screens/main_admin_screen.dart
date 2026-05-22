import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/db_helper.dart';
import 'login_screen.dart';
import 'inventario_screen.dart';
import 'cierres_admin_screen.dart';
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

  // ─── SESIÓN ───────────────────────────────────────────────────────────────

  Future<void> _cerrarSesion() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ─── GESTOR V ─────────────────────────────────────────────────────────────

  void _mostrarPanelGestorV() {
    Navigator.pop(context); // cierra el drawer
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado ────────────────────────────────────────
            const Row(
              children: [
                Icon(Icons.shield_moon_outlined, color: primaryDark, size: 24),
                SizedBox(width: 8),
                Text('Panel GestorV',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryDark)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Modo soporte técnico',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(height: 24),

            // ── Opción 1: Ver estado interno ──────────────────────
            ListTile(
              leading: const Icon(Icons.info_outline, color: primaryDark),
              title: const Text('Ver estado interno'),
              subtitle: const Text('Diagnóstico sin modificar nada'),
              onTap: () {
                Navigator.pop(context);
                _verEstadoInterno();
              },
            ),

            // ── Opción 2: Resetear contraseña admin ───────────────
            ListTile(
              leading: const Icon(Icons.lock_reset, color: primaryDark),
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

            // ── Opción 3: Borrar cuenta admin ─────────────────────
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.orange),
              title: const Text('Borrar cuenta del admin',
                  style: TextStyle(color: Colors.orange)),
              subtitle: const Text('Permite crear una cuenta nueva'),
              onTap: () {
                Navigator.pop(context);
                _confirmarAccion(
                  titulo: 'Borrar cuenta admin',
                  mensaje:
                      '¿Seguro? El admin tendrá que registrarse de nuevo desde cero.',
                  accion: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('admin_password');
                    await prefs.remove('recup_pregunta');
                    await prefs.remove('recup_respuesta');
                  },
                  esDestructivo: true,
                );
              },
            ),

            // ── Opción 4: Limpiar inventario ──────────────────────
            ListTile(
              leading:
                  const Icon(Icons.inventory_2_outlined, color: Colors.orange),
              title: const Text('Limpiar inventario completo',
                  style: TextStyle(color: Colors.orange)),
              subtitle: const Text('Borra todos los productos y movimientos'),
              onTap: () {
                Navigator.pop(context);
                _confirmarAccion(
                  titulo: 'Limpiar inventario',
                  mensaje:
                      '¿Borrar TODOS los productos y movimientos? No se puede deshacer.',
                  accion: () async {
                    final db = await DBHelper.instance.database;
                    await db.transaction((txn) async {
                      await txn.delete('movimientos');
                      await txn.delete('productos');
                    });
                  },
                  esDestructivo: true,
                );
              },
            ),

            // ── Opción 5: Reset total ─────────────────────────────
            ListTile(
              leading:
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
              title: const Text('RESET TOTAL',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle:
                  const Text('Borra TODO: productos, movimientos y cierres'),
              onTap: () {
                Navigator.pop(context);
                _confirmarAccion(
                  titulo: '⚠️ RESET TOTAL',
                  mensaje:
                      'Esto borrará TODOS los productos, movimientos y cierres importados.\n\n'
                      'La app quedará como recién instalada.\n\n'
                      '¿Estás completamente seguro?',
                  accion: () async {
                    final db = await DBHelper.instance.database;
                    await db.transaction((txn) async {
                      await txn.delete('detalle_venta_importada');
                      await txn.delete('ventas_importadas');
                      await txn.delete('cierres_importados');
                      await txn.delete('movimientos');
                      await txn.delete('productos');
                    });
                  },
                  esDestructivo: true,
                );
              },
            ),

            // ── Opción 6: Ir a Backup ─────────────────────────────
            ListTile(
              leading:
                  const Icon(Icons.cloud_sync_outlined, color: primaryDark),
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

  // ─── HELPERS GESTOR V ─────────────────────────────────────────────────────

  /// Muestra un resumen del estado actual de la base de datos.
  Future<void> _verEstadoInterno() async {
    final db = await DBHelper.instance.database;
    final productos =
        await db.rawQuery('SELECT COUNT(*) as c FROM productos');
    final movimientos =
        await db.rawQuery('SELECT COUNT(*) as c FROM movimientos');
    final cierres =
        await db.rawQuery('SELECT COUNT(*) as c FROM cierres_importados');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: primaryDark),
            SizedBox(width: 8),
            Text('Estado interno'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filaEstado(
                'Productos', '${(productos.first['c'] as num).toInt()}'),
            _filaEstado(
                'Movimientos', '${(movimientos.first['c'] as num).toInt()}'),
            _filaEstado('Cierres importados',
                '${(cierres.first['c'] as num).toInt()}'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _filaEstado(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(valor,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Diálogo de confirmación reutilizable para acciones destructivas.
  Future<void> _confirmarAccion({
    required String titulo,
    required String mensaje,
    required Future<void> Function() accion,
    bool esDestructivo = false,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: esDestructivo ? Colors.red : primaryDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await accion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operación completada ✓'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

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
              // ── Encabezado del drawer ──────────────────────────────
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
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Opción GestorV (solo si es superusuario) ───────────
              if (AuthService.instance.esGestorV)
                ListTile(
                  leading: const Icon(Icons.shield_moon_outlined,
                      color: primaryDark),
                  title: const Text('Panel GestorV',
                      style: TextStyle(
                          color: primaryDark, fontWeight: FontWeight.bold)),
                  onTap: _mostrarPanelGestorV,
                ),

              // ── Cerrar sesión ──────────────────────────────────────
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
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
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
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