// lib/models/venta.dart

class Venta {
  final String idVenta;
  final String fecha;
  final double total;
  final String metodoPago;
  final String moneda;
  final double montoMoneda;
  final double tasaCambio;
  final String? refTransaccion;
  final String? plataformaQr;

  Venta({
    required this.idVenta,
    required this.fecha,
    required this.total,
    this.metodoPago = 'efectivo',
    this.moneda = 'CUP',
    double? montoMoneda,
    this.tasaCambio = 1.0,
    this.refTransaccion,
    this.plataformaQr,
  }) : montoMoneda = montoMoneda ?? total;

  Map<String, dynamic> toMap() => {
    'id_venta':        idVenta,
    'fecha':           fecha,
    'total':           total,
    'metodo_pago':     metodoPago,
    'moneda':          moneda,
    'monto_moneda':    montoMoneda,
    'tasa_cambio':     tasaCambio,
    'ref_transaccion': refTransaccion,
    'plataforma_qr':   plataformaQr,
  };

  factory Venta.fromMap(Map<String, dynamic> map) => Venta(
    idVenta:        map['id_venta']       as String,
    fecha:          map['fecha']          as String,
    total:          (map['total'] as num).toDouble(),
    metodoPago:     map['metodo_pago']    as String? ?? 'efectivo',
    moneda:         map['moneda']         as String? ?? 'CUP',
    montoMoneda:    (map['monto_moneda'] as num?)?.toDouble(),
    tasaCambio:     (map['tasa_cambio'] as num?)?.toDouble() ?? 1.0,
    refTransaccion: map['ref_transaccion'] as String?,
    plataformaQr:   map['plataforma_qr']  as String?,
  );
}

class DetalleVenta {
  final String idDetalle;
  final String idVenta;
  final int    productoId;
  final double cantidad;
  final double precio;

  DetalleVenta({
    required this.idDetalle,
    required this.idVenta,
    required this.productoId,
    required this.cantidad,
    required this.precio,
  });

  double get total => cantidad * precio;

  Map<String, dynamic> toMap() => {
    'id_detalle':  idDetalle,
    'id_venta':    idVenta,
    'producto_id': productoId,
    'cantidad':    cantidad,
    'precio':      precio,
    'total':       total,
  };
}