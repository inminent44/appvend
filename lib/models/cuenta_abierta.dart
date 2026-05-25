// lib/models/cuenta_abierta.dart

class ItemCuenta {
  final int id;
  final String cuentaId;
  final int productoId;
  final String nombre;
  final double cantidad;
  final double precio;

  const ItemCuenta({
    required this.id,
    required this.cuentaId,
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precio,
  });

  double get subtotal => cantidad * precio;

  factory ItemCuenta.fromMap(Map<String, dynamic> m) => ItemCuenta(
        id: m['id'] as int,
        cuentaId: m['cuenta_id'] as String,
        productoId: m['producto_id'] as int,
        nombre: m['nombre'] as String,
        cantidad: (m['cantidad'] as num).toDouble(),
        precio: (m['precio'] as num).toDouble(),
      );
}

class CuentaAbierta {
  final String id;
  final String nombre;
  final List<ItemCuenta> items;
  final DateTime abiertaEn;

  const CuentaAbierta({
    required this.id,
    required this.nombre,
    required this.items,
    required this.abiertaEn,
  });

  /// Suma de (precio × cantidad) de todos los items
  double get total =>
      items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Total de unidades — usado en cuentas_screen y cuenta_detalle_screen
  int get cantidadItems =>
      items.fold(0, (sum, item) => sum + item.cantidad.toInt());

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'abierta_en': abiertaEn.toIso8601String(),
      };

  factory CuentaAbierta.fromMap(
    Map<String, dynamic> m,
    List<Map<String, dynamic>> itemMaps,
  ) =>
      CuentaAbierta(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        abiertaEn: DateTime.parse(m['abierta_en'] as String),
        items: itemMaps.map(ItemCuenta.fromMap).toList(),
      );
}