class Producto {
  final int id;
  final String nombre;
  final double precioVenta;

  const Producto({
    required this.id,
    required this.nombre,
    required this.precioVenta,
  });

  factory Producto.fromMap(Map<String, dynamic> map) => Producto(
        id: map['id'] as int,
        nombre: map['nombre'] as String,
        precioVenta: (map['precioVenta'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'precioVenta': precioVenta,
      };

  Producto copyWith({int? id, String? nombre, double? precioVenta}) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precioVenta: precioVenta ?? this.precioVenta,
    );
  }

  @override
  String toString() =>
      'Producto(id: $id, nombre: $nombre, precioVenta: $precioVenta)';
}
