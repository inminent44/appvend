// ════════════════════════════════════════════════════════════════════════════
// lib/services/catalogo_service.dart
// VaraNova POS — Catálogo Service v2
//
// Capa de servicio entre SQLite y la UI del POS.
// Responsabilidades:
//   • Carga productos UNA sola vez y los cachea en memoria
//   • Calcula categorías disponibles sin queries adicionales
//   • Expone filtros sin tocar la DB en cada frame
//   • Soporta: favoritos · más vendidos · búsqueda · categorías · tipos
//
// NO contiene widgets. NO hace queries en build(). NO duplica lógica de DB.
// ════════════════════════════════════════════════════════════════════════════

import '../services/db_helper_cajero.dart';

class CatalogoService {
  // ── Singleton ligero (no persistente, se recrea por sesión) ──────────────
  CatalogoService._();
  static final CatalogoService instance = CatalogoService._();

  // ── Cache en memoria ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _todos = [];
  bool _cargado = false;

  // ── Categorías especiales (pseudo-categorías, no vienen de la DB) ────────
  static const String kTodos      = '__todos__';
  static const String kFavoritos  = '__favoritos__';

  // ═══════════════════════════════════════════════════════════════════════════
  // CARGA / REFRESCO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Carga desde SQLite. Llamar una vez al abrir la pantalla POS.
  /// Llamar de nuevo después de importar inventario.
  Future<void> cargar() async {
    _todos   = await DBHelperCajero.instance.obtenerProductosConStock();
    _cargado = true;
  }

  /// Invalida el cache. El próximo acceso a [estaCargado] devolverá false
  /// y la pantalla deberá llamar [cargar] de nuevo.
  void invalidar() => _cargado = false;

  bool get estaCargado => _cargado;

  // ═══════════════════════════════════════════════════════════════════════════
  // CATEGORÍAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lista ordenada de categorías con al menos 1 producto con stock.
  ///
  /// Orden:
  ///   1. [kTodos]     — siempre presente
  ///   2. [kFavoritos] — solo si hay al menos 1 favorito con stock
  ///   3. Tipos estructurados (Platos, Bebidas…) — ordenados alfabéticamente
  ///   4. Categorías libres (texto del admin)    — ordenadas alfabéticamente
  ///
  /// Los tipos y categorías libres NO se mezclan con las pseudo-categorías.
  List<String> get categorias {
    if (!_cargado) return [kTodos];

    final tipos = <String>{};
    final cats  = <String>{};
    bool  hayFavoritos = false;

    for (final p in _todos) {
      if ((p['stockActual'] as num).toDouble() <= 0) continue;

      if ((p['es_favorito'] as int? ?? 0) == 1) hayFavoritos = true;

      final tipo = p['tipo_producto'] as String?;
      final cat  = p['categoria']    as String?;

      if (tipo != null && tipo.isNotEmpty) tipos.add(_labelDeTipo(tipo));
      if (cat  != null && cat.isNotEmpty)  cats.add(cat);
    }

    return [
      kTodos,
      if (hayFavoritos) kFavoritos,
      ...tipos.toList()..sort(),
      ...cats.toList()..sort(),
    ];
  }

  /// Label legible para un valor raw de tipo_producto.
  /// Público para que [PosSelectorScreen] pueda usarlo al mostrar el label del tab.
  static String labelDeCategoria(String cat) {
    if (cat == kTodos)     return 'Todos';
    if (cat == kFavoritos) return '⭐ Favoritos';
    return cat; // categorías libres ya vienen con su texto
  }

  /// Convierte el valor raw de tipo_producto a label con emoji.
  static String _labelDeTipo(String raw) {
    return switch (raw.toLowerCase()) {
      'plato'  => '🍽 Platos',
      'bebida' => '🥤 Bebidas',
      'postre' => '🍮 Postres',
      'combo'  => '🎁 Combos',
      'extra'  => '➕ Extras',
      _        => raw,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTRADO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve productos con stock > 0, opcionalmente filtrados por categoría
  /// y/o texto de búsqueda. Soporta las pseudo-categorías [kTodos] y [kFavoritos].
  ///
  /// El filtro de búsqueda se aplica sobre el nombre del producto (case-insensitive).
  /// Si la categoría activa es [kFavoritos], solo devuelve productos marcados
  /// como favorito — sin duplicar filas, todos de la misma tabla.
  List<Map<String, dynamic>> filtrar({
    String categoria = kTodos,
    String busqueda  = '',
  }) {
    if (!_cargado) return [];

    // 1. Solo productos con stock
    var lista = _todos
        .where((p) => (p['stockActual'] as num).toDouble() > 0)
        .toList();

    // 2. Filtro de categoría / pseudo-categoría
    if (categoria == kFavoritos) {
      lista = lista
          .where((p) => (p['es_favorito'] as int? ?? 0) == 1)
          .toList();
    } else if (categoria != kTodos) {
      lista = lista.where((p) {
        final tipo = p['tipo_producto'] as String?;
        final cat  = p['categoria']    as String?;
        // Coincide si el tipo mapeado == categoría seleccionada
        // O si la categoría libre == categoría seleccionada
        return _labelDeTipo(tipo ?? '') == categoria || cat == categoria;
      }).toList();
    }

    // 3. Filtro de búsqueda
    final q = busqueda.trim().toLowerCase();
    if (q.isNotEmpty) {
      lista = lista
          .where((p) => p['nombre'].toString().toLowerCase().contains(q))
          .toList();
    }

    return lista;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCESOS RÁPIDOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Todos los productos con stock, sin filtro adicional.
  List<Map<String, dynamic>> get todos => filtrar();

  /// Solo los productos marcados como favorito con stock > 0.
  List<Map<String, dynamic>> get favoritos => filtrar(categoria: kFavoritos);

  /// Productos ordenados por stock descendente (proxy de "más vendidos"
  /// mientras no haya stats en el cajero).
  /// Útil para la sección de acceso rápido del cajero.
  List<Map<String, dynamic>> get masUsados {
    if (!_cargado) return [];
    final lista = _todos
        .where((p) => (p['stockActual'] as num).toDouble() > 0)
        .toList()
      ..sort((a, b) {
        // Favoritos siempre arriba
        final fa = (a['es_favorito'] as int? ?? 0);
        final fb = (b['es_favorito'] as int? ?? 0);
        if (fa != fb) return fb.compareTo(fa);
        // Luego por stock desc
        final sa = (a['stockActual'] as num).toDouble();
        final sb = (b['stockActual'] as num).toDouble();
        return sb.compareTo(sa);
      });
    return lista.take(12).toList(); // máx 12 para la grilla de acceso rápido
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BÚSQUEDA POR ID
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve un producto por su id, o null si no existe en el cache.
  Map<String, dynamic>? porId(int id) {
    try {
      return _todos.firstWhere((p) => p['id'] == id);
    } catch (_) {
      return null;
    }
  }
}