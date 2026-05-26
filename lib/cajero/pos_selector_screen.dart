// lib/vendedor/screens/pos_selector_screen.dart
//
// Pantalla POS moderna tipo Toast/Square para seleccionar productos.
// REEMPLAZA el _ProductoSheet (bottom sheet básico) de cuenta_detalle_screen.
//
// Layout adaptativo:
//   • Tablet landscape → 3 columnas: categorías | grid productos | resumen
//   • Tablet portrait  → 2 columnas: categorías | grid productos
//   • Teléfono         → columna única con tabs de categorías en top
//
// Recibe: cuentaId + lista de items actuales (para mostrar cantidades)
// Devuelve: nada (llama onAgregar directo, igual que _ProductoSheet anterior)
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/catalogo_service.dart';

// ── Constantes de diseño ────────────────────────────────────────────────────
const Color _kPrimary    = Color(0xFF084B53);
const Color _kPrimaryMid = Color(0xFF0A6B77);
const Color _kBg         = Color(0xFFF0F2F5);
const Color _kCard       = Colors.white;
const Color _kCategBg    = Color(0xFF0D3B43);  // sidebar oscuro
const Color _kAccent     = Color(0xFF1DE9B6);  // teal brillante para selección

class PosSelectorScreen extends StatefulWidget {

  /// Para mostrar badge de cantidad encima de cada card.
  final Map<int, double> itemsActuales;

  /// Callback cuando el usuario toca un producto.
  /// La pantalla no hace lógica de DB, solo notifica.
  final Future<void> Function(Map<String, dynamic> producto, double cantidad) onAgregar;

  /// Nombre de la cuenta (para el header)
  final String nombreCuenta;

  const PosSelectorScreen({
    super.key,
    required this.itemsActuales,
    required this.onAgregar,
    required this.nombreCuenta,
  });

  @override
  State<PosSelectorScreen> createState() => _PosSelectorScreenState();
}

class _PosSelectorScreenState extends State<PosSelectorScreen> {
  final _catalogo    = CatalogoService.instance;
  final _searchCtrl  = TextEditingController();
  final _fmt         = NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_MX');

  String _categoriaActiva = CatalogoService.kTodos;
  String _busqueda        = '';
  bool   _cargando        = true;

  // Productos visibles según filtro activo
  List<Map<String, dynamic>> _productosVisibles = [];

  // IDs con operación en curso (para deshabilitar doble tap)
  final Set<int> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Carga ────────────────────────────────────────────────────────────────

  Future<void> _cargar() async {
    if (!_catalogo.estaCargado) {
      await _catalogo.cargar();
    }
    _aplicarFiltro();
    if (mounted) setState(() => _cargando = false);
  }

  void _aplicarFiltro() {
    _productosVisibles = _catalogo.filtrar(
      categoria: _categoriaActiva,
      busqueda:  _busqueda,
    );
  }

  void _seleccionarCategoria(String cat) {
    HapticFeedback.selectionClick();
    setState(() {
      _categoriaActiva = cat;
      _aplicarFiltro();
    });
  }

  void _onBusqueda(String q) {
    setState(() {
      _busqueda = q;
      _aplicarFiltro();
    });
  }

  // ─── Agregar producto ─────────────────────────────────────────────────────

  Future<void> _agregar(Map<String, dynamic> p) async {
    final id = p['id'] as int;
    if (_procesando.contains(id)) return;

    HapticFeedback.lightImpact();
    setState(() => _procesando.add(id));

    try {
      await widget.onAgregar(p, 1);
    } finally {
      if (mounted) setState(() => _procesando.remove(id));
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.of(context).size;
    final isTablet  = size.width >= 720;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: _kBg,
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : isTablet && isLandscape
              ? _layoutTabletLandscape()
              : isTablet
                  ? _layoutTabletPortrait()
                  : _layoutTelefono(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LAYOUTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Tablet landscape: sidebar categorías | grid productos
  Widget _layoutTabletLandscape() {
    return Column(
      children: [
        _buildTopBar(showSearchInline: true),
        Expanded(
          child: Row(
            children: [
              _buildSidebarCategorias(width: 180),
              Expanded(child: _buildGridProductos(crossAxisCount: 4)),
            ],
          ),
        ),
      ],
    );
  }

  /// Tablet portrait: sidebar angosto | grid 3 col
  Widget _layoutTabletPortrait() {
    return Column(
      children: [
        _buildTopBar(showSearchInline: true),
        Expanded(
          child: Row(
            children: [
              _buildSidebarCategorias(width: 140),
              Expanded(child: _buildGridProductos(crossAxisCount: 3)),
            ],
          ),
        ),
      ],
    );
  }

  /// Teléfono: top bar + tabs horizontales + grid 2 col
  Widget _layoutTelefono() {
    return Column(
      children: [
        _buildTopBar(showSearchInline: false),
        _buildSearchBar(),
        _buildTabsCategorias(),
        Expanded(child: _buildGridProductos(crossAxisCount: 2)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMPONENTES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar({required bool showSearchInline}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary, _kPrimaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 16,
        bottom: showSearchInline ? 8 : 12,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agregar productos',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    Text(widget.nombreCuenta,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              // Badge total items en cuenta
              if (widget.itemsActuales.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          color: _kPrimary, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.itemsActuales.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)} items',
                        style: const TextStyle(
                            color: _kPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (showSearchInline) ...[
            const SizedBox(height: 10),
            _buildSearchBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onBusqueda,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            hintText: 'Buscar producto...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: _kPrimary, size: 18),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.grey, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onBusqueda('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // ── Sidebar vertical (tablet) ────────────────────────────────────────────

  Widget _buildSidebarCategorias({required double width}) {
    final cats = _catalogo.categorias;
    return Container(
      width: width,
      color: _kCategBg,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final cat        = cats[i];
          final seleccionada = cat == _categoriaActiva;
          final label      = cat == CatalogoService.kTodos ? 'Todos' : cat;

          return GestureDetector(
            onTap: () => _seleccionarCategoria(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: seleccionada
                    ? _kAccent.withAlpha(40)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: seleccionada
                    ? Border.all(color: _kAccent, width: 1.5)
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: seleccionada ? _kAccent : Colors.white60,
                  fontWeight: seleccionada
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tabs horizontales (teléfono) ─────────────────────────────────────────

  Widget _buildTabsCategorias() {
    final cats = _catalogo.categorias;
    return Container(
      height: 46,
      color: _kCategBg,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final cat        = cats[i];
          final seleccionada = cat == _categoriaActiva;
          final label      = cat == CatalogoService.kTodos ? 'Todos' : cat;

          return GestureDetector(
            onTap: () => _seleccionarCategoria(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: seleccionada ? _kAccent : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: seleccionada ? _kPrimary : Colors.white,
                    fontWeight: seleccionada
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Grid de productos ─────────────────────────────────────────────────────

  Widget _buildGridProductos({required int crossAxisCount}) {
    if (_productosVisibles.isEmpty) {
      return _emptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:    crossAxisCount,
        crossAxisSpacing:  10,
        mainAxisSpacing:   10,
        childAspectRatio:  0.85,   // cards ligeramente altas
      ),
      itemCount: _productosVisibles.length,
      itemBuilder: (_, i) => _ProductoCard(
        producto:       _productosVisibles[i],
        cantidadEnCuenta: widget.itemsActuales[_productosVisibles[i]['id'] as int] ?? 0,
        procesando:     _procesando.contains(_productosVisibles[i]['id'] as int),
        fmt:            _fmt,
        onTap:          () => _agregar(_productosVisibles[i]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _busqueda.isNotEmpty
                ? 'Sin resultados para "$_busqueda"'
                : 'Sin productos en esta categoría',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ProductoCard — widget puro, sin acceso a DB
// ════════════════════════════════════════════════════════════════════════════

class _ProductoCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final double               cantidadEnCuenta;
  final bool                 procesando;
  final NumberFormat         fmt;
  final VoidCallback         onTap;

  // Paleta de colores para avatares (por índice de hash del nombre)
  static const _colores = [
    Color(0xFF084B53), Color(0xFFE53935), Color(0xFFF57C00),
    Color(0xFF7B1FA2), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFFAD1457), Color(0xFF00695C), Color(0xFF4527A0),
  ];

  const _ProductoCard({
    required this.producto,
    required this.cantidadEnCuenta,
    required this.procesando,
    required this.fmt,
    required this.onTap,
  });

  Color get _colorAvatar {
    final hash = producto['nombre'].toString().codeUnits
        .fold(0, (a, b) => a + b);
    return _colores[hash % _colores.length];
  }

  @override
  Widget build(BuildContext context) {
    final nombre = producto['nombre'].toString();
    final precio = (producto['precioVenta'] as num).toDouble();
    final stock  = (producto['stockActual'] as num).toDouble();
    final sinStock = stock <= 0;
    final hayEnCuenta = cantidadEnCuenta > 0;
    final color = _colorAvatar;

    return GestureDetector(
      onTap: sinStock || procesando ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: sinStock ? 0.45 : 1.0,
        child: Stack(
          children: [
            // ── Card principal ────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: hayEnCuenta
                    ? Border.all(color: _kPrimary, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: hayEnCuenta
                        ? _kPrimary.withAlpha(40)
                        : Colors.black.withAlpha(13),
                    blurRadius: hayEnCuenta ? 10 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar con inicial
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          nombre.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Nombre
                    Text(
                      nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1A1A2E),
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Fila precio + botón add
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fmt.format(precio),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _kPrimary,
                            ),
                          ),
                        ),
                        // Botón +
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: procesando
                                ? Colors.grey.shade300
                                : sinStock
                                    ? Colors.grey.shade200
                                    : _kPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: procesando
                              ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add,
                                  color: Colors.white, size: 18),
                        ),
                      ],
                    ),

                    // Stock bajo (sutil)
                    if (stock > 0 && stock < 5) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Quedan ${stock.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    if (sinStock) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Sin stock',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Badge cantidad en cuenta ──────────────────────────────────
            if (hayEnCuenta)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: _kPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      cantidadEnCuenta.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}