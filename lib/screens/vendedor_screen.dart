import 'package:flutter/material.dart';

import 'cuentas_screen.dart';
import 'inventario_screen.dart';
import 'cierre_caja_screen.dart';
import 'configuracion_screen.dart';

class VendedorScreen extends StatefulWidget {
  const VendedorScreen({super.key});

  @override
  State<VendedorScreen> createState() => _VendedorScreenState();
}

class _VendedorScreenState extends State<VendedorScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    CuentasScreen(),                    // ← CAMBIADO
    InventarioScreen(),
    CierreCajaScreen(),
    ConfiguracionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VaraNova Vendedor'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
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
            icon: Icon(Icons.receipt_long_outlined),   // ← CAMBIADO
            selectedIcon: Icon(Icons.receipt_long),    // ← CAMBIADO
            label: 'Cuentas',                          // ← CAMBIADO
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Cierre',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}
