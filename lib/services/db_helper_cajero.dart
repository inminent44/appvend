import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../models/venta.dart';
import '../models/cuenta_abierta.dart';
import '../services/license_service.dart';

class DBHelperCajero {
  static final DBHelperCajero instance = DBHelperCajero._internal();
  factory DBHelperCajero() => instance;
  DBHelperCajero._internal();

  static const String _aesKey = 'GestorV2024#SecureKey!XYZ@123456';
  static const String _aesIV = 'GestorV2024!IV8#';

  enc.Encrypter get _encrypter =>
      enc.Encrypter(enc.AES(enc.Key.fromUtf8(_aesKey)));
  enc.IV get _iv => enc.IV.fromUtf8(_aesIV);

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  // ─── INIT ──────────────────────────────────────────────────────────────────

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pos_vendedor.db');

    return await openDatabase(
      path,
      version: 6, // Incrementar la versión de la base de datos
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE productos (
            id          INTEGER PRIMARY KEY,
            nombre      TEXT NOT NULL,
            precioVenta REAL NOT NULL,
            stockActual REAL NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE ventas (
            id_venta     TEXT PRIMARY KEY,
            fecha        TEXT NOT NULL,
            total        REAL NOT NULL,
            metodo_pago  TEXT NOT NULL DEFAULT 'Efectivo'
          )
        ''');
        await db.execute('''
          CREATE TABLE detalle_venta (
            id_detalle  TEXT PRIMARY KEY,
            id_venta    TEXT NOT NULL,
            producto_id INTEGER NOT NULL,
            cantidad    REAL NOT NULL,
            precio      REAL NOT NULL,
            total       REAL NOT NULL,
            FOREIGN KEY (id_venta)    REFERENCES ventas (id_venta),
            FOREIGN KEY (producto_id) REFERENCES productos (id)
          )
        ''');
        await db.execute('''
          CREATE TABLE cierres_turno (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            fecha   TEXT NOT NULL,
            cerrado INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE inventarios_importados (
            id    INTEGER PRIMARY KEY AUTOINCREMENT,
            hash  TEXT NOT NULL UNIQUE,
            fecha TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cuentas_abiertas (
            id         TEXT PRIMARY KEY,
            nombre     TEXT NOT NULL,
            abierta_en TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE items_cuenta (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            cuenta_id   TEXT NOT NULL,
            producto_id INTEGER NOT NULL,
            nombre      TEXT NOT NULL,
            cantidad    REAL NOT NULL,
            precio      REAL NOT NULL,
            FOREIGN KEY (cuenta_id)   REFERENCES cuentas_abiertas (id),
            FOREIGN KEY (producto_id) REFERENCES productos (id)
          )
        ''');
        await db.execute('''
          CREATE TABLE cierres_turno_importados (
            id    INTEGER PRIMARY KEY AUTOINCREMENT,
            hash  TEXT NOT NULL UNIQUE,
            fecha TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pagos_qr (
            id_pago      TEXT PRIMARY KEY,
            id_venta     TEXT NOT NULL,
            plataforma   TEXT NOT NULL,
            id_transaccion TEXT NOT NULL UNIQUE,
            monto        REAL NOT NULL,
            moneda       TEXT NOT NULL DEFAULT 'CUP',
            fecha_sms    TEXT,
            FOREIGN KEY (id_venta) REFERENCES ventas (id_venta)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS inventarios_importados (
              id    INTEGER PRIMARY KEY AUTOINCREMENT,
              hash  TEXT NOT NULL UNIQUE,
              fecha TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cuentas_abiertas (
              id         TEXT PRIMARY KEY,
              nombre     TEXT NOT NULL,
              abierta_en TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS items_cuenta (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              cuenta_id   TEXT NOT NULL,
              producto_id INTEGER NOT NULL,
              nombre      TEXT NOT NULL,
              cantidad    REAL NOT NULL,
              precio      REAL NOT NULL,
              FOREIGN KEY (cuenta_id)   REFERENCES cuentas_abiertas (id),
              FOREIGN KEY (producto_id) REFERENCES productos (id)
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cierres_turno_importados (
              id    INTEGER PRIMARY KEY AUTOINCREMENT,
              hash  TEXT NOT NULL UNIQUE,
              fecha TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute(
              "ALTER TABLE ventas ADD COLUMN metodo_pago TEXT NOT NULL DEFAULT 'Efectivo'");
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pagos_qr (
              id_pago        TEXT PRIMARY KEY,
              id_venta       TEXT NOT NULL,
              plataforma     TEXT NOT NULL,
              id_transaccion TEXT NOT NULL UNIQUE,
              monto          REAL NOT NULL,
              moneda         TEXT NOT NULL DEFAULT 'CUP',
              fecha_sms      TEXT,
              FOREIGN KEY (id_venta) REFERENCES ventas (id_venta)
            )
          ''');
        }
      },
      onOpen: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ─── INVENTARIO ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerProductosConStock() async {
    final db = await database;
    return db.query('productos', orderBy: 'nombre ASC');
  }

  /// Devuelve true si este inventario ya fue importado antes (mismo contenido).
  Future<bool> inventarioYaImportado(String contenido) async {
    final db = await database;
    final hash = contenido.length > 64 ? contenido.substring(0, 64) : contenido;
    final res = await db.query(
      'inventarios_importados',
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<void> _registrarInventarioImportado(String contenido) async {
    final db = await database;
    final hash = contenido.length > 64 ? contenido.substring(0, 64) : contenido;
    final fecha = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    await db.insert(
      'inventarios_importados',
      {'hash': hash, 'fecha': fecha},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ─── VENTAS ────────────────────────────────────────────────────────────────

  Future<void> realizarVenta(Venta venta, List<DetalleVenta> detalles,
      {String metodoPago = 'Efectivo'}) async {
    final db = await database;
    await db.transaction((txn) async {
      final ventaMap = venta.toMap();
      ventaMap['metodo_pago'] = metodoPago;
      await txn.insert('ventas', ventaMap);
      for (var d in detalles) {
        await txn.insert('detalle_venta', d.toMap());
        await txn.rawUpdate(
          'UPDATE productos SET stockActual = stockActual - ? WHERE id = ?',
          [d.cantidad, d.productoId],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> obtenerVentasDelDia(String fecha) async {
    final db = await database;
    return db.query('ventas',
        where: 'fecha = ?', whereArgs: [fecha], orderBy: 'id_venta DESC');
  }

  Future<void> eliminarVenta(String idVenta) async {
    final db = await database;
    await db.transaction((txn) async {
      final detalles = await txn
          .query('detalle_venta', where: 'id_venta = ?', whereArgs: [idVenta]);
      for (var d in detalles) {
        await txn.rawUpdate(
          'UPDATE productos SET stockActual = stockActual + ? WHERE id = ?',
          [(d['cantidad'] as num).toDouble(), d['producto_id']],
        );
      }
      await txn
          .delete('detalle_venta', where: 'id_venta = ?', whereArgs: [idVenta]);
      await txn.delete('ventas', where: 'id_venta = ?', whereArgs: [idVenta]);
    });
  }

  Future<List<Map<String, dynamic>>> obtenerDetallesDeVenta(
      String idVenta) async {
    final db = await database;
    return db.rawQuery('''
      SELECT dv.*, p.nombre
      FROM detalle_venta dv
      JOIN productos p ON p.id = dv.producto_id
      WHERE dv.id_venta = ?
    ''', [idVenta]);
  }

  Future<void> actualizarProductoDetalle({
    required String idDetalle,
    required String idVenta,
    required int productoIdAnterior,
    required int cantidadAnterior,
    required int productoIdNuevo,
    required int nuevaCantidad,
    required double nuevoPrecio,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE productos SET stockActual = stockActual + ? WHERE id = ?',
        [cantidadAnterior, productoIdAnterior],
      );
      await txn.rawUpdate(
        '''UPDATE detalle_venta
           SET producto_id = ?, cantidad = ?, precio = ?, total = ?
           WHERE id_detalle = ?''',
        [
          productoIdNuevo,
          nuevaCantidad,
          nuevoPrecio,
          nuevaCantidad * nuevoPrecio,
          idDetalle,
        ],
      );
      await txn.rawUpdate(
        'UPDATE productos SET stockActual = stockActual - ? WHERE id = ?',
        [nuevaCantidad, productoIdNuevo],
      );
      await txn.rawUpdate('''
        UPDATE ventas SET total = (
          SELECT COALESCE(SUM(total), 0) FROM detalle_venta WHERE id_venta = ?
        ) WHERE id_venta = ?
      ''', [idVenta, idVenta]);
    });
  }

  // ─── TURNO ─────────────────────────────────────────────────────────────────

  Future<bool> esTurnoCerrado() async {
    final db = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await db.query('cierres_turno',
        where: 'fecha = ? AND cerrado = 1', whereArgs: [hoy], limit: 1);
    return res.isNotEmpty;
  }

  /// Devuelve la fecha en que se cerró el turno, o null si no hay cierre.
  Future<String?> obtenerFechaCierreTurno() async {
    final db = await database;
    final res = await db.query(
      'cierres_turno',
      where: 'cerrado = 1',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first['fecha'] as String?;
  }

  Future<void> cerrarTurno() async {
    final db = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await db.insert('cierres_turno', {'fecha': hoy, 'cerrado': 1},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> iniciarNuevoDia() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('detalle_venta');
      await txn.delete('ventas');
      await txn.delete('cierres_turno');
    });
  }

  // ─── CIERRE DE CAJA ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> obtenerResumenCierre() async {
    final db = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final totales = await db.rawQuery(
      'SELECT COALESCE(SUM(total),0.0) AS totalVentas, COUNT(*) AS numeroVentas '
      'FROM ventas WHERE fecha = ?',
      [hoy],
    );
    final detalle = await db.rawQuery('''
      SELECT p.nombre, SUM(dv.cantidad) AS cantidadTotal, SUM(dv.total) AS totalVendido
      FROM detalle_venta dv
      JOIN ventas    v ON v.id_venta = dv.id_venta
      JOIN productos p ON p.id       = dv.producto_id
      WHERE v.fecha = ?
      GROUP BY p.id ORDER BY totalVendido DESC
    ''', [hoy]);

    // Consulta de totales agrupados por método de pago
    final porMetodo = await db.rawQuery(
      'SELECT metodo_pago, COALESCE(SUM(total),0.0) AS subtotal '
      'FROM ventas WHERE fecha = ? GROUP BY metodo_pago',
      [hoy],
    );
    final Map<String, double> totalesMetodo = {
      for (final row in porMetodo)
        row['metodo_pago'] as String: (row['subtotal'] as num).toDouble()
    };

    // Contar ventas QR por plataforma para el resumen
    final ventasQR = await db.rawQuery('''
      SELECT pq.plataforma, COUNT(*) AS cantidad, COALESCE(SUM(pq.monto), 0.0) AS total_qr
      FROM pagos_qr pq
      JOIN ventas v ON v.id_venta = pq.id_venta
      WHERE v.fecha = ?
      GROUP BY pq.plataforma
    ''', [hoy]);

    return {
      'totalVentas': (totales.first['totalVentas'] as num).toDouble(),
      'numeroVentas': (totales.first['numeroVentas'] as num).toInt(),
      'detalle': detalle,
      'totalesPorMetodo': totalesMetodo,
      'ventasQR': ventasQR, // lista con plataforma, cantidad, total_qr
    };
  }

  /// Exporta el cierre incluyendo el número de dispositivo en el nombre del archivo.
  Future<void> exportarCierreCaja() async {
    final db = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final ventas =
        await db.query('ventas', where: 'fecha = ?', whereArgs: [hoy]);
    final detalles = await db.rawQuery(
      'SELECT dv.* FROM detalle_venta dv '
      'JOIN ventas v ON v.id_venta = dv.id_venta WHERE v.fecha = ?',
      [hoy],
    );

    final codigoDispositivo = await LicenseService.generarCodigoDispositivo();

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('CierreCaja', nest: () {
      builder.element('Dispositivo', nest: codigoDispositivo);
      builder.element('Fecha', nest: hoy);
      builder.element('Ventas', nest: () {
        for (var v in ventas) {
          builder.element('Venta', nest: () {
            v.forEach((k, val) => builder.element(k, nest: val.toString()));
          });
        }
      });
      builder.element('Detalles', nest: () {
        for (var d in detalles) {
          builder.element('Detalle', nest: () {
            d.forEach((k, v) => builder.element(k, nest: v.toString()));
          });
        }
      });
    });

    final encrypted =
        _encrypter.encrypt(builder.buildDocument().toXmlString(), iv: _iv);
    final directory = await getTemporaryDirectory();
    final fechaStr = hoy.replaceAll('-', '');
    final file =
        File('${directory.path}/cierre_${fechaStr}_$codigoDispositivo.gv');
    await file.writeAsString(encrypted.base64);

    await cerrarTurno();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Cierre $hoy — $codigoDispositivo',
      ),
    );
  }

  // ─── IMPORTAR INVENTARIO DEL ADMIN ─────────────────────────────────────────

  Future<void> importarInventarioAdmin(File archivo) async {
    final db = await database;
    final contenido = await archivo.readAsString();

    final yaImportado = await inventarioYaImportado(contenido);
    if (yaImportado) {
      throw Exception('Este inventario ya fue importado anteriormente.');
    }

    final xmlString =
        _encrypter.decrypt(enc.Encrypted.fromBase64(contenido), iv: _iv);
    final document = XmlDocument.parse(xmlString);

    await db.transaction((txn) async {
      await txn.delete('productos');
      for (var p in document.findAllElements('Producto')) {
        final data = _xmlElementToMap(p);
        await txn.insert(
          'productos',
          {
            'id': data['id'],
            'nombre': data['nombre'],
            'precioVenta': data['precioVenta'],
            'stockActual': data['stockActual'] ?? 0.0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    await _registrarInventarioImportado(contenido);
  }

  Map<String, dynamic> _xmlElementToMap(XmlElement element) {
    final Map<String, dynamic> data = {};
    for (var child in element.children) {
      if (child is XmlElement) {
        final key = child.name.local;
        final val = child.innerText;
        if (['id', 'producto_id'].contains(key)) {
          data[key] = int.tryParse(val);
        } else if (['cantidad', 'precio', 'total', 'precioVenta', 'stockActual']
            .contains(key)) {
          data[key] = double.tryParse(val);
        } else {
          data[key] = val;
        }
      }
    }
    return data;
  }

  // ─── CUENTAS ABIERTAS ──────────────────────────────────────────────────────

  /// Lista todas las cuentas abiertas con sus items.
  Future<List<CuentaAbierta>> obtenerCuentasAbiertas() async {
    final db = await database;
    final cuentas =
        await db.query('cuentas_abiertas', orderBy: 'abierta_en ASC');
    final result = <CuentaAbierta>[];
    for (final c in cuentas) {
      final items = await db.query(
        'items_cuenta',
        where: 'cuenta_id = ?',
        whereArgs: [c['id']],
      );
      result.add(CuentaAbierta.fromMap(c, items));
    }
    return result;
  }

  /// Crea una cuenta vacía. Devuelve la cuenta creada.
  Future<CuentaAbierta> crearCuenta(String nombre) async {
    final db = await database;
    final cuenta = CuentaAbierta(
      id: const Uuid().v4(),
      nombre: nombre,
      items: [],
      abiertaEn: DateTime.now(),
    );
    await db.insert('cuentas_abiertas', cuenta.toMap());
    return cuenta;
  }

  /// Agrega un item a la cuenta y descuenta stock inmediatamente.
  /// Lanza excepción si no hay stock suficiente.
  Future<void> agregarItemCuenta({
    required String cuentaId,
    required int productoId,
    required String nombreProducto,
    required double cantidad,
    required double precio,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Verificar stock disponible
      final stockRes = await txn.query(
        'productos',
        columns: ['stockActual'],
        where: 'id = ?',
        whereArgs: [productoId],
        limit: 1,
      );
      if (stockRes.isEmpty) throw Exception('Producto no encontrado');
      final stock = (stockRes.first['stockActual'] as num).toDouble();
      if (stock < cantidad) {
        throw Exception(
            'Stock insuficiente (disponible: ${stock.toStringAsFixed(0)})');
      }

      // Ver si ya existe ese producto en la cuenta → sumar cantidad
      final existing = await txn.query(
        'items_cuenta',
        where: 'cuenta_id = ? AND producto_id = ?',
        whereArgs: [cuentaId, productoId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final nuevoTotal =
            (existing.first['cantidad'] as num).toDouble() + cantidad;
        await txn.update(
          'items_cuenta',
          {'cantidad': nuevoTotal},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await txn.insert('items_cuenta', {
          'cuenta_id': cuentaId,
          'producto_id': productoId,
          'nombre': nombreProducto,
          'cantidad': cantidad,
          'precio': precio,
        });
      }

      // Descontar stock
      await txn.rawUpdate(
        'UPDATE productos SET stockActual = stockActual - ? WHERE id = ?',
        [cantidad, productoId],
      );
    });
  }

  /// Quita una unidad de un item. Si llega a 0, elimina el item y devuelve stock.
  Future<void> quitarItemCuenta({
    required String cuentaId,
    required int productoId,
    required double cantidad,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'items_cuenta',
        where: 'cuenta_id = ? AND producto_id = ?',
        whereArgs: [cuentaId, productoId],
        limit: 1,
      );
      if (existing.isEmpty) return;

      final cantActual = (existing.first['cantidad'] as num).toDouble();
      final cantQuitar = cantidad.clamp(0, cantActual);

      if (cantActual - cantQuitar <= 0) {
        await txn.delete(
          'items_cuenta',
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await txn.update(
          'items_cuenta',
          {'cantidad': cantActual - cantQuitar},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }

      // Devolver stock
      await txn.rawUpdate(
        'UPDATE productos SET stockActual = stockActual + ? WHERE id = ?',
        [cantQuitar, productoId],
      );
    });
  }

  /// Cobra la cuenta: la convierte en Venta+DetalleVenta y la elimina.
  /// El stock ya fue descontado al agregar — aquí solo se registra la venta.
  Future<void> cobrarCuenta(CuentaAbierta cuenta, String metodoPago) async {
    final db = await database;
    final idVenta = const Uuid().v4();
    final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await db.transaction((txn) async {
      await txn.insert('ventas', {
        'id_venta': idVenta,
        'fecha': fecha,
        'total': cuenta.total,
        'metodo_pago': metodoPago,
      });

      // Stock YA descontado al agregar — solo insertar detalles
      for (final item in cuenta.items) {
        await txn.insert('detalle_venta', {
          'id_detalle': const Uuid().v4(),
          'id_venta': idVenta,
          'producto_id': item.productoId,
          'cantidad': item.cantidad,
          'precio': item.precio,
          'total': item.subtotal,
        });
      }

      await txn.delete(
        'items_cuenta',
        where: 'cuenta_id = ?',
        whereArgs: [cuenta.id],
      );
      await txn.delete(
        'cuentas_abiertas',
        where: 'id = ?',
        whereArgs: [cuenta.id],
      );
    });
  }

  /// Cancela la cuenta y DEVUELVE todo el stock.
  Future<void> cancelarCuenta(CuentaAbierta cuenta) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in cuenta.items) {
        await txn.rawUpdate(
          'UPDATE productos SET stockActual = stockActual + ? WHERE id = ?',
          [item.cantidad, item.productoId],
        );
      }
      await txn.delete(
        'items_cuenta',
        where: 'cuenta_id = ?',
        whereArgs: [cuenta.id],
      );
      await txn.delete(
        'cuentas_abiertas',
        where: 'id = ?',
        whereArgs: [cuenta.id],
      );
    });
  }

  /// Carga una cuenta con sus items actualizados desde la BD.
  Future<CuentaAbierta?> recargarCuenta(String cuentaId) async {
    final db = await database;
    final cuentas = await db.query(
      'cuentas_abiertas',
      where: 'id = ?',
      whereArgs: [cuentaId],
      limit: 1,
    );
    if (cuentas.isEmpty) return null;
    final items = await db.query(
      'items_cuenta',
      where: 'cuenta_id = ?',
      whereArgs: [cuentaId],
    );
    return CuentaAbierta.fromMap(cuentas.first, items);
  }
  // ─── IMPORTAR CIERRE DE TURNO ─────────────────────────────────────────────
  // Permite que el cajero del turno siguiente descuente del stock
  // los productos que vendió el cajero del turno anterior.

// solo para claridad

  Future<bool> cierreTurnoYaImportado(String contenido) async {
    final db = await database;
    final hash = contenido.length > 64 ? contenido.substring(0, 64) : contenido;
    final res = await db.query(
      'cierres_turno_importados',
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<void> _registrarCierreTurnoImportado(String contenido) async {
    final db = await database;
    final hash = contenido.length > 64 ? contenido.substring(0, 64) : contenido;
    final fecha = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    await db.insert(
      'cierres_turno_importados',
      {'hash': hash, 'fecha': fecha},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Importa el cierre `.gv` del turno anterior y descuenta el stock.
  /// Devuelve el número de productos procesados.
  /// Lanza [Exception] si el archivo ya fue importado o tiene formato incorrecto.
  Future<int> importarCierreTurno(File archivo) async {
    final contenido = await archivo.readAsString();

    // ── 1. Verificar duplicado ────────────────────────────────────────────
    if (await cierreTurnoYaImportado(contenido)) {
      throw Exception('Este cierre ya fue importado anteriormente.');
    }

    // ── 2. Desencriptar y parsear XML ─────────────────────────────────────
    final xmlString = _encrypter.decrypt(
      enc.Encrypted.fromBase64(contenido),
      iv: _iv,
    );
    final document = XmlDocument.parse(xmlString);

    // ── 3. Acumular cantidades vendidas por producto ───────────────────────
    final Map<int, double> cantidadesPorProducto = {};

    for (final detalle in document.findAllElements('Detalle')) {
      final data = _xmlElementToMap(detalle);
      final productoId = int.tryParse(data['producto_id'].toString());
      final cantidad = double.tryParse(data['cantidad'].toString());
      if (productoId == null || cantidad == null) continue;
      cantidadesPorProducto[productoId] =
          (cantidadesPorProducto[productoId] ?? 0.0) + cantidad;
    }

    if (cantidadesPorProducto.isEmpty) {
      throw Exception(
        'El archivo no contiene ventas o tiene un formato incorrecto.',
      );
    }

    // ── 4. Descontar stock — productos inexistentes se ignoran ────────────
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in cantidadesPorProducto.entries) {
        await txn.rawUpdate('''
          UPDATE productos
          SET stockActual = MAX(0.0, stockActual - ?)
          WHERE id = ?
        ''', [entry.value, entry.key]);
      }
    });

    // ── 5. Registrar para evitar duplicados ───────────────────────────────
    await _registrarCierreTurnoImportado(contenido);

    return cantidadesPorProducto.length;
  }
  // ─── PAGOS QR ──────────────────────────────────────────────────────────────

  /// Verifica si un ID de transacción QR ya fue registrado (anti-fraude).
  Future<bool> existeTransaccionQR(String idTransaccion) async {
    final db = await database;
    final res = await db.query(
      'pagos_qr',
      where: 'id_transaccion = ?',
      whereArgs: [idTransaccion],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  /// Guarda el detalle del pago QR vinculado a una venta.
  Future<void> guardarPagoQR({
    required String idVenta,
    required String plataforma,
    required String idTransaccion,
    required double monto,
    required String moneda,
    String? fechaSms,
  }) async {
    final db = await database;
    await db.insert('pagos_qr', {
      'id_pago': const Uuid().v4(),
      'id_venta': idVenta,
      'plataforma': plataforma,
      'id_transaccion': idTransaccion,
      'monto': monto,
      'moneda': moneda,
      'fecha_sms': fechaSms,
    });
  }

  /// Realiza la venta y guarda el pago QR en una sola transacción.
  /// Lanza [Exception] si el id_transaccion ya existe.
  Future<void> realizarVentaQR({
    required Venta venta,
    required List<DetalleVenta> detalles,
    required String plataforma,
    required String idTransaccion,
    required double montoQR,
    required String moneda,
    String? fechaSms,
  }) async {
    // Verificar duplicado ANTES de abrir la transacción
    final duplicado = await existeTransaccionQR(idTransaccion);
    if (duplicado) {
      throw Exception('DUPLICADO:$idTransaccion');
      // El caller captura esto para mostrar la alerta de pago duplicado
    }

    final db = await database;
    await db.transaction((txn) async {
      // Insertar venta con método QR
      final ventaMap = venta.toMap();
      ventaMap['metodo_pago'] = 'QR';
      await txn.insert('ventas', ventaMap);

      // Insertar detalles y descontar stock
      for (final d in detalles) {
        await txn.insert('detalle_venta', d.toMap());
        await txn.rawUpdate(
          'UPDATE productos SET stockActual = stockActual - ? WHERE id = ?',
          [d.cantidad, d.productoId],
        );
      }

      // Guardar detalle del pago QR
      await txn.insert('pagos_qr', {
        'id_pago': const Uuid().v4(),
        'id_venta': venta.idVenta,
        'plataforma': plataforma,
        'id_transaccion': idTransaccion,
        'monto': montoQR,
        'moneda': moneda,
        'fecha_sms': fechaSms,
      });
    });
  }
}
