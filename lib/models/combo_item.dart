class ComboItem {
  final int? id;
  final int comboId;
  final int productoId;
  final double cantidad;

  // Campos extra para display (JOIN con productos)
  final String? nombreProducto;

  const ComboItem({
    this.id,
    required this.comboId,
    required this.productoId,
    this.cantidad = 1,
    this.nombreProducto,
  });

  factory ComboItem.fromMap(Map<String, dynamic> m) => ComboItem(
        id:             m['id'] as int?,
        comboId:        m['combo_id'] as int,
        productoId:     m['producto_id'] as int,
        cantidad:       (m['cantidad'] as num).toDouble(),
        nombreProducto: m['nombre'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'combo_id':    comboId,
        'producto_id': productoId,
        'cantidad':    cantidad,
      };
}