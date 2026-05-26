// ════════════════════════════════════════════════════════════════════════════
// lib/admin/models/producto.dart
// ════════════════════════════════════════════════════════════════════════════

/// Tipos de producto para modo restaurante/cafetería.
/// El valor [ninguno] representa productos sin clasificar (retail clásico).
enum TipoProducto {
  ninguno,
  plato,
  bebida,
  postre,
  combo,
  extra;

  /// Texto legible para mostrar en UI
  String get label => switch (this) {
        TipoProducto.ninguno => 'Sin tipo',
        TipoProducto.plato   => 'Plato',
        TipoProducto.bebida  => 'Bebida',
        TipoProducto.postre  => 'Postre',
        TipoProducto.combo   => 'Combo',
        TipoProducto.extra   => 'Extra',
      };

  /// Emoji para botones rápidos en el cajero
  String get emoji => switch (this) {
        TipoProducto.ninguno => '📦',
        TipoProducto.plato   => '🍽️',
        TipoProducto.bebida  => '🥤',
        TipoProducto.postre  => '🍮',
        TipoProducto.combo   => '🎁',
        TipoProducto.extra   => '➕',
      };

  /// Serialización a String para SQLite (guarda el name del enum)
  String? toDb() => this == TipoProducto.ninguno ? null : name;

  /// Deserialización desde SQLite
  static TipoProducto fromDb(String? value) {
    if (value == null || value.isEmpty) return TipoProducto.ninguno;
    return TipoProducto.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TipoProducto.ninguno,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class Producto {
  final int id;
  final String nombre;
  final double precioVenta;

  /// Categoría libre: "Bebidas", "Entradas", "Del día", etc.
  /// null = sin categoría (compatible con productos existentes)
  final String? categoria;

  /// Tipo estructurado. null / ninguno = retail clásico sin cambios.
  final TipoProducto tipoProducto;

  const Producto({
    required this.id,
    required this.nombre,
    required this.precioVenta,
    this.categoria,
    this.tipoProducto = TipoProducto.ninguno,
  });

  // ── Serialización ──────────────────────────────────────────────────────────

  factory Producto.fromMap(Map<String, dynamic> map) => Producto(
        id:           map['id'] as int,
        nombre:       map['nombre'] as String,
        precioVenta:  (map['precioVenta'] as num).toDouble(),
        // Compatibilidad total: si la columna no existe en el map, usa null/ninguno
        categoria:    map['categoria'] as String?,
        tipoProducto: TipoProducto.fromDb(map['tipo_producto'] as String?),
      );

  Map<String, dynamic> toMap() => {
        'id':            id,
        'nombre':        nombre,
        'precioVenta':   precioVenta,
        'categoria':     categoria,                  // null es válido en SQLite
        'tipo_producto': tipoProducto.toDb(),        // null si es ninguno
      };

  // ── Utilidades ─────────────────────────────────────────────────────────────

  /// true si el producto tiene clasificación de restaurante
  bool get esRestaurante => tipoProducto != TipoProducto.ninguno;

  /// Etiqueta compuesta para mostrar en listas: "Plato · Entradas"
  String get etiquetaTipo {
    final tipo = tipoProducto != TipoProducto.ninguno ? tipoProducto.label : null;
    final cat  = (categoria?.isNotEmpty == true) ? categoria : null;
    if (tipo == null && cat == null) return '';
    if (tipo == null) return cat!;
    if (cat == null) return tipo;
    return '$tipo · $cat';
  }

  Producto copyWith({
    int?          id,
    String?       nombre,
    double?       precioVenta,
    String?       categoria,
    TipoProducto? tipoProducto,
    bool          clearCategoria = false,   // permite pasar null explícitamente
  }) {
    return Producto(
      id:           id           ?? this.id,
      nombre:       nombre       ?? this.nombre,
      precioVenta:  precioVenta  ?? this.precioVenta,
      categoria:    clearCategoria ? null : (categoria ?? this.categoria),
      tipoProducto: tipoProducto ?? this.tipoProducto,
    );
  }

  @override
  String toString() =>
      'Producto(id: $id, nombre: $nombre, precioVenta: $precioVenta, '
      'categoria: $categoria, tipo: ${tipoProducto.name})';
}