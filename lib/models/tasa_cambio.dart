class TasaCambio {
  final String moneda;      // 'USD', 'EUR', 'CAD'
  final double tasaACup;    // 1 moneda = X CUP
  final String actualizado;

  const TasaCambio({
    required this.moneda,
    required this.tasaACup,
    required this.actualizado,
  });

  /// Convierte monto en moneda extranjera a CUP
  double aCup(double monto) => monto * tasaACup;

  /// Convierte CUP a moneda extranjera
  double desdeCup(double cup) => tasaACup > 0 ? cup / tasaACup : 0;

  factory TasaCambio.fromMap(Map<String, dynamic> m) => TasaCambio(
        moneda:      m['moneda'] as String,
        tasaACup:    (m['tasa_a_cup'] as num).toDouble(),
        actualizado: m['actualizado'] as String,
      );

  Map<String, dynamic> toMap() => {
        'moneda':      moneda,
        'tasa_a_cup':  tasaACup,
        'actualizado': actualizado,
      };

  // Monedas soportadas con sus símbolos
  static const Map<String, String> simbolos = {
    'CUP': '\$',
    'USD': 'USD',
    'EUR': '€',
    'CAD': 'CAD',
  };
}