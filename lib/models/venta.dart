class Venta {
  final String idVenta;
  final String fecha;
  final double total;

  const Venta({
    required this.idVenta,
    required this.fecha,
    required this.total,
  });

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      idVenta: map['id_venta'] as String,
      fecha: map['fecha'] as String,
      total: (map['total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id_venta': idVenta,
        'fecha': fecha,
        'total': total,
      };

  @override
  String toString() => 'Venta(idVenta: $idVenta, fecha: $fecha, total: $total)';
}

class DetalleVenta {
  final String idDetalle;
  final String idVenta;
  final int productoId;
  final double cantidad;
  final double precio;

  const DetalleVenta({
    required this.idDetalle,
    required this.idVenta,
    required this.productoId,
    required this.cantidad,
    required this.precio,
  });

  double get total => cantidad * precio;

  factory DetalleVenta.fromMap(Map<String, dynamic> map) {
    return DetalleVenta(
      idDetalle: map['id_detalle'] as String,
      idVenta: map['id_venta'] as String,
      productoId: map['producto_id'] as int,
      cantidad: (map['cantidad'] as num).toDouble(),
      precio: (map['precio'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id_detalle': idDetalle,
        'id_venta': idVenta,
        'producto_id': productoId,
        'cantidad': cantidad,
        'precio': precio,
        'total': total,
      };
}
