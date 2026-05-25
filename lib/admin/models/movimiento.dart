class Movimiento {
  final int? id;
  final int productoId;
  final double cantidad;
  final String fecha;
  final String tipo;
  final String? nota;

  const Movimiento({
    this.id,
    required this.productoId,
    required this.cantidad,
    required this.fecha,
    required this.tipo,
    this.nota,
  });

  static const String tipoEntrada = 'entrada';
  static const String tipoVenta = 'venta';
  static const String tipoAjuste = 'ajuste';

  factory Movimiento.fromMap(Map<String, dynamic> map) {
    return Movimiento(
      id: map['id'] as int?,
      productoId: map['producto_id'] as int,
      cantidad: (map['cantidad'] as num).toDouble(),
      fecha: map['fecha'] as String,
      tipo: map['tipo'] as String,
      nota: map['nota'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'producto_id': productoId,
      'cantidad': cantidad,
      'fecha': fecha,
      'tipo': tipo,
      'nota': nota,
    };
  }

  @override
  String toString() =>
      'Movimiento(id: $id, productoId: $productoId, cantidad: $cantidad, '
      'fecha: $fecha, tipo: $tipo, nota: $nota)';
}
