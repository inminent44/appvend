// lib/vendedor/models/cuenta_abierta.dart
//
// Modelo de cuenta abierta para modo restaurante/caja.
// Una CuentaAbierta es un pedido en curso que aún no se ha cobrado.
//
// El stock se descuenta al AGREGAR items (no al cobrar),
// y se DEVUELVE si se cancela la cuenta o se quita un item.

class ItemCuenta {
  final int productoId;
  final String nombre;
  final double cantidad;
  final double precio;

  const ItemCuenta({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precio,
  });

  double get subtotal => cantidad * precio;

  factory ItemCuenta.fromMap(Map<String, dynamic> map) => ItemCuenta(
        productoId: map['producto_id'] as int,
        nombre: map['nombre'] as String,
        cantidad: (map['cantidad'] as num).toDouble(),
        precio: (map['precio'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'producto_id': productoId,
        'nombre': nombre,
        'cantidad': cantidad,
        'precio': precio,
      };

  ItemCuenta copyWith({double? cantidad}) => ItemCuenta(
        productoId: productoId,
        nombre: nombre,
        cantidad: cantidad ?? this.cantidad,
        precio: precio,
      );

  @override
  String toString() =>
      'ItemCuenta($nombre x$cantidad @ \$$precio = \$$subtotal)';
}

// ─────────────────────────────────────────────────────────────────────────────

class CuentaAbierta {
  final String id;
  final String nombre; // "Mesa 3", "Para llevar", "Juan" — libre
  final List<ItemCuenta> items;
  final DateTime abiertaEn;

  const CuentaAbierta({
    required this.id,
    required this.nombre,
    required this.items,
    required this.abiertaEn,
  });

  double get total => items.fold(0, (s, i) => s + i.subtotal);
  int get cantidadItems => items.fold(0, (s, i) => s + i.cantidad.toInt());

  factory CuentaAbierta.fromMap(Map<String, dynamic> map,
      List<Map<String, dynamic>> itemMaps) =>
      CuentaAbierta(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        items: itemMaps.map(ItemCuenta.fromMap).toList(),
        abiertaEn: DateTime.parse(map['abierta_en'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'abierta_en': abiertaEn.toIso8601String(),
      };

  CuentaAbierta copyWith({String? nombre, List<ItemCuenta>? items}) =>
      CuentaAbierta(
        id: id,
        nombre: nombre ?? this.nombre,
        items: items ?? this.items,
        abiertaEn: abiertaEn,
      );
}
