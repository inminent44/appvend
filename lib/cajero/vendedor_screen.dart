// lib/screens/vendedor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _selectedIndex = 0;

  final _cuentasKey = GlobalKey<CuentasScreenState>();

  List<Widget> get _screens => [
        CuentasScreen(key: _cuentasKey),
        const InventarioScreen(),
        const CierreCajaScreen(),
        const ConfiguracionScreen(),
      ];

  void _onTabSelected(int index) {
    HapticFeedback.selectionClick();
    if (_selectedIndex == index) return;

    setState(() => _selectedIndex = index);

    if (index == 0) {
      _cuentasKey.currentState?.cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}

// ── Barra de navegación inferior personalizada ────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  static const Color primaryDark = Color(0xFF084B53);

  static const _items = [
    _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Cuentas'),
    _NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Stock'),
    _NavItem(icon: Icons.calculate_outlined, activeIcon: Icons.calculate, label: 'Cierre'),
    _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Config'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isSelected = selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryDark.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            key: ValueKey(isSelected),
                            color: isSelected ? primaryDark : Colors.grey.shade400,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? primaryDark
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}