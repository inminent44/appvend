import 'package:flutter/material.dart';
import 'package:pos_caja/app_theme.dart';
import 'package:pos_caja/cajero/cierre_caja_screen.dart';
import 'package:pos_caja/cajero/cuentas_screen.dart';
import 'package:pos_caja/cajero/inventario_screen.dart';

class VendedorScreen extends StatefulWidget {
  const VendedorScreen({super.key});

  @override
  State<VendedorScreen> createState() => _VendedorScreenState();
}

class _VendedorScreenState extends State<VendedorScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const CuentasScreen(), // Inicio
    const Text('Ventas Screen'), // Ventas
    const InventarioScreen(), // Productos
    const CierreCajaScreen(), // Más
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: _buildCustomBottomNavBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
        },
        backgroundColor: AppTheme.accent,
        elevation: 2.0,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildCustomBottomNavBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: AppTheme.cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildNavItem(icon: Icons.home_filled, label: 'Inicio', index: 0),
          _buildNavItem(icon: Icons.receipt_long, label: 'Ventas', index: 1),
          const SizedBox(width: 48), // Espacio para el FAB
          _buildNavItem(icon: Icons.inventory_2, label: 'Productos', index: 2),
          _buildNavItem(icon: Icons.more_horiz, label: 'Más', index: 3),
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? AppTheme.primary : AppTheme.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),        ),
      ),
    );
  }
}
