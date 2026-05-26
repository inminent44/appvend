class Modificador {
  final int? id;
  final String nombre;
  final double precioExtra;
  final bool afectaStock;
  final int? productoId; // null = global

  const Modificador({
    this.id,
    required this.nombre,
    this.precioExtra = 0,
    this.afectaStock = false,
    this.productoId,
  });

  factory Modificador.fromMap(Map<String, dynamic> m) => Modificador(
        id:          m['id'] as int?,
        nombre:      m['nombre'] as String,
        precioExtra: (m['precio_extra'] as num).toDouble(),
        afectaStock: (m['afecta_stock'] as int) == 1,
        productoId:  m['producto_id'] as int?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nombre':       nombre,
        'precio_extra': precioExtra,
        'afecta_stock': afectaStock ? 1 : 0,
        'producto_id':  productoId,
      };
}