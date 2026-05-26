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
  static const String _aesIV  = 'GestorV2024!IV8#';

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
    final path   = join(dbPath, 'pos_vendedor.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE productos (
            id          INTEGER PRIMARY KEY,
            nombre      TEXT NOT NULL,
            precioVenta REAL NOT NULL,
            stockActual REAL NOT NULL DEFAULT 0
          )
        ''');
        // ventas ahora incluye método de pago y moneda
        await db.execute('''
          CREATE TABLE ventas (
            id_venta       TEXT PRIMARY KEY,
            fecha          TEXT NOT NULL,
            total          REAL NOT NULL,
            metodo_pago    TEXT NOT NULL DEFAULT 'efectivo',
            moneda         TEXT NOT NULL DEFAULT 'CUP',
            monto_moneda   REAL NOT NULL DEFAULT 0,
            tasa_cambio    REAL NOT NULL DEFAULT 1,
            ref_transaccion TEXT,
            plataforma_qr  TEXT
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
        // Tasas de cambio (todas respecto al CUP)
        await db.execute('''
          CREATE TABLE tasas_cambio (
            moneda TEXT PRIMARY KEY,
            tasa   REAL NOT NULL,
            nombre TEXT NOT NULL
          )
        ''');
        // Tasas por defecto
        await db.insert('tasas_cambio', {'moneda': 'CUP', 'tasa': 1.0,    'nombre': 'Peso Cubano'});
        await db.insert('tasas_cambio', {'moneda': 'USD', 'tasa': 300.0,  'nombre': 'Dólar USA'});
        await db.insert('tasas_cambio', {'moneda': 'EUR', 'tasa': 330.0,  'nombre': 'Euro'});
        await db.insert('tasas_cambio', {'moneda': 'CAD', 'tasa': 220.0,  'nombre': 'Dólar Canadiense'});
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
          // Migrar tabla ventas: agregar columnas de pago y moneda
          try { await db.execute("ALTER TABLE ventas ADD COLUMN metodo_pago TEXT NOT NULL DEFAULT 'efectivo'"); } catch (_) {}
          try { await db.execute("ALTER TABLE ventas ADD COLUMN moneda TEXT NOT NULL DEFAULT 'CUP'"); } catch (_) {}
          try { await db.execute("ALTER TABLE ventas ADD COLUMN monto_moneda REAL NOT NULL DEFAULT 0"); } catch (_) {}
          try { await db.execute("ALTER TABLE ventas ADD COLUMN tasa_cambio REAL NOT NULL DEFAULT 1"); } catch (_) {}
          try { await db.execute("ALTER TABLE ventas ADD COLUMN ref_transaccion TEXT"); } catch (_) {}
          try { await db.execute("ALTER TABLE ventas ADD COLUMN plataforma_qr TEXT"); } catch (_) {}
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tasas_cambio (
              moneda TEXT PRIMARY KEY,
              tasa   REAL NOT NULL,
              nombre TEXT NOT NULL
            )
          ''');
          // Insertar tasas solo si no existen
          final existing = await db.query('tasas_cambio');
          if (existing.isEmpty) {
            await db.insert('tasas_cambio', {'moneda': 'CUP', 'tasa': 1.0,    'nombre': 'Peso Cubano'});
            await db.insert('tasas_cambio', {'moneda': 'USD', 'tasa': 300.0,  'nombre': 'Dólar USA'});
            await db.insert('tasas_cambio', {'moneda': 'EUR', 'tasa': 330.0,  'nombre': 'Euro'});
            await db.insert('tasas_cambio', {'moneda': 'CAD', 'tasa': 220.0,  'nombre': 'Dólar Canadiense'});
          }
          // Eliminar tabla cierres_turno si existía (ya no se usa)
          try { await db.execute('DROP TABLE IF EXISTS cierres_turno'); } catch (_) {}
        }
      },
      onOpen: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ─── TASAS DE CAMBIO ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerTasas() async {
    final db = await database;
    return db.query('tasas_cambio', orderBy: 'moneda ASC');
  }

  Future<void> actualizarTasa(String moneda, double tasa) async {
    final db = await database;
    await db.update(
      'tasas_cambio',
      {'tasa': tasa},
      where: 'moneda = ?',
      whereArgs: [moneda],
    );
  }

  /// Retorna la tasa (CUP por unidad de moneda extranjera) de una moneda.
  Future<double> obtenerTasa(String moneda) async {
    if (moneda == 'CUP') return 1.0;
    final db = await database;
    final res = await db.query('tasas_cambio', where: 'moneda = ?', whereArgs: [moneda], limit: 1);
    if (res.isEmpty) return 1.0;
    return (res.first['tasa'] as num).toDouble();
  }

  /// Convierte monto de moneda extranjera a CUP usando la tasa actual.
  Future<double> convertirACup(double monto, String moneda) async {
    final tasa = await obtenerTasa(moneda);
    return monto * tasa;
  }

  // ─── INVENTARIO ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerProductosConStock() async {
    final db = await database;
    return db.query('productos', orderBy: 'nombre ASC');
  }

  Future<bool> inventarioYaImportado(String contenido) async {
    final db   = await database;
    final hash = contenido.length > 64 ? contenido.substring(0, 64) : contenido;
    final res  = await db.query(
      'inventarios_importados',
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<void> _registrarInventarioImportado(String contenido) async {
    final db    = await database;
    final hash  = contenido.length > 64 ? contenido.substring(0, 64) : contenido;
    final fecha = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    await db.insert(
      'inventarios_importados',
      {'hash': hash, 'fecha': fecha},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ─── VENTAS ────────────────────────────────────────────────────────────────

  /// Realiza una venta con soporte de método de pago y moneda.
  Future<void> realizarVenta(Venta venta, List<DetalleVenta> detalles) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('ventas', venta.toMap());
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
      await txn.delete('detalle_venta', where: 'id_venta = ?', whereArgs: [idVenta]);
      await txn.delete('ventas',        where: 'id_venta = ?', whereArgs: [idVenta]);
    });
  }

  Future<List<Map<String, dynamic>>> obtenerDetallesDeVenta(String idVenta) async {
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
    required int    productoIdAnterior,
    required int    cantidadAnterior,
    required int    productoIdNuevo,
    required int    nuevaCantidad,
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

  // ─── RESUMEN CIERRE (con desglose por moneda y método) ────────────────────

  Future<Map<String, dynamic>> obtenerResumenCierre() async {
    final db  = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final totales = await db.rawQuery(
      'SELECT COALESCE(SUM(total),0.0) AS totalVentas, COUNT(*) AS numeroVentas '
      'FROM ventas WHERE fecha = ?',
      [hoy],
    );

    // Desglose por método de pago (total en CUP)
    final porMetodo = await db.rawQuery('''
      SELECT metodo_pago,
             COALESCE(SUM(total), 0) AS totalCUP,
             COUNT(*) AS cantidad
      FROM ventas WHERE fecha = ?
      GROUP BY metodo_pago
    ''', [hoy]);

    // Desglose por moneda (monto en moneda original + equivalente CUP)
    final porMoneda = await db.rawQuery('''
      SELECT moneda,
             COALESCE(SUM(monto_moneda), 0) AS totalMoneda,
             COALESCE(SUM(total), 0) AS totalCUP,
             COUNT(*) AS cantidad,
             MAX(tasa_cambio) AS tasa
      FROM ventas WHERE fecha = ?
      GROUP BY moneda
    ''', [hoy]);

    final detalle = await db.rawQuery('''
      SELECT p.nombre, SUM(dv.cantidad) AS cantidadTotal, SUM(dv.total) AS totalVendido
      FROM detalle_venta dv
      JOIN ventas    v ON v.id_venta = dv.id_venta
      JOIN productos p ON p.id       = dv.producto_id
      WHERE v.fecha = ?
      GROUP BY p.id ORDER BY totalVendido DESC
    ''', [hoy]);

    return {
      'totalVentas':  (totales.first['totalVentas']  as num).toDouble(),
      'numeroVentas': (totales.first['numeroVentas'] as num).toInt(),
      'detalle':      detalle,
      'porMetodo':    porMetodo,
      'porMoneda':    porMoneda,
    };
  }

  // ─── EXPORTAR CIERRE ───────────────────────────────────────────────────────

  Future<void> exportarCierreCaja() async {
    final db  = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final ventas   = await db.query('ventas',   where: 'fecha = ?', whereArgs: [hoy]);
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
      builder.element('Fecha',       nest: hoy);
      builder.element('Ventas', nest: () {
        for (var v in ventas) {
          builder.element('Venta', nest: () {
            v.forEach((k, val) => builder.element(k, nest: val?.toString() ?? ''));
          });
        }
      });
      builder.element('Detalles', nest: () {
        for (var d in detalles) {
          builder.element('Detalle', nest: () {
            d.forEach((k, v) => builder.element(k, nest: v?.toString() ?? ''));
          });
        }
      });
    });

    final encrypted = _encrypter.encrypt(
        builder.buildDocument().toXmlString(), iv: _iv);
    final directory  = await getTemporaryDirectory();
    final fechaStr   = hoy.replaceAll('-', '');
    final file       = File(
        '${directory.path}/cierre_${fechaStr}_$codigoDispositivo.gv');
    await file.writeAsString(encrypted.base64);

    await Share.shareXFiles(
        [XFile(file.path)], text: 'Cierre $hoy — $codigoDispositivo');
  }

  // ─── IMPORTAR INVENTARIO DEL ADMIN ─────────────────────────────────────────

  Future<void> importarInventarioAdmin(File archivo) async {
    final db       = await database;
    final contenido = await archivo.readAsString();

    final yaImportado = await inventarioYaImportado(contenido);
    if (yaImportado) {
      throw Exception('Este inventario ya fue importado anteriormente.');
    }

    final xmlString = _encrypter.decrypt(
        enc.Encrypted.fromBase64(contenido), iv: _iv);
    final document  = XmlDocument.parse(xmlString);

    await db.transaction((txn) async {
      await txn.delete('productos');
      for (var p in document.findAllElements('Producto')) {
        final data = _xmlElementToMap(p);
        await txn.insert(
          'productos',
          {
            'id':          data['id'],
            'nombre':      data['nombre'],
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

  Future<List<CuentaAbierta>> obtenerCuentasAbiertas() async {
    final db      = await database;
    final cuentas = await db.query('cuentas_abiertas', orderBy: 'abierta_en ASC');
    final result  = <CuentaAbierta>[];
    for (final c in cuentas) {
      final items = await db.query(
        'items_cuenta',
        where:     'cuenta_id = ?',
        whereArgs: [c['id']],
      );
      result.add(CuentaAbierta.fromMap(c, items));
    }
    return result;
  }

  Future<CuentaAbierta> crearCuenta(String nombre) async {
    final db     = await database;
    final cuenta = CuentaAbierta(
      id:        const Uuid().v4(),
      nombre:    nombre,
      items:     [],
      abiertaEn: DateTime.now(),
    );
    await db.insert('cuentas_abiertas', cuenta.toMap());
    return cuenta;
  }

  Future<void> agregarItemCuenta({
    required String cuentaId,
    required int    productoId,
    required String nombreProducto,
    required double cantidad,
    required double precio,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final stockRes = await txn.query(
        'productos',
        columns:   ['stockActual'],
        where:     'id = ?',
        whereArgs: [productoId],
        limit:     1,
      );
      if (stockRes.isEmpty) throw Exception('Producto no encontrado');
      final stock = (stockRes.first['stockActual'] as num).toDouble();
      if (stock < cantidad) {
        throw Exception(
            'Stock insuficiente (disponible: ${stock.toStringAsFixed(0)})');
      }

      final existing = await txn.query(
        'items_cuenta',
        where:     'cuenta_id = ? AND producto_id = ?',
        whereArgs: [cuentaId, productoId],
        limit:     1,
      );

      if (existing.isNotEmpty) {
        final nuevoTotal =
            (existing.first['cantidad'] as num).toDouble() + cantidad;
        await txn.update(
          'items_cuenta',
          {'cantidad': nuevoTotal},
          where:     'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await txn.insert('items_cuenta', {
          'cuenta_id':   cuentaId,
          'producto_id': productoId,
          'nombre':      nombreProducto,
          'cantidad':    cantidad,
          'precio':      precio,
        });
      }

      await txn.rawUpdate(
        'UPDATE productos SET stockActual = stockActual - ? WHERE id = ?',
        [cantidad, productoId],
      );
    });
  }

  Future<void> quitarItemCuenta({
    required String cuentaId,
    required int    productoId,
    required double cantidad,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'items_cuenta',
        where:     'cuenta_id = ? AND producto_id = ?',
        whereArgs: [cuentaId, productoId],
        limit:     1,
      );
      if (existing.isEmpty) return;

      final cantActual = (existing.first['cantidad'] as num).toDouble();
      final cantQuitar = cantidad.clamp(0, cantActual);

      if (cantActual - cantQuitar <= 0) {
        await txn.delete(
          'items_cuenta',
          where:     'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await txn.update(
          'items_cuenta',
          {'cantidad': cantActual - cantQuitar},
          where:     'id = ?',
          whereArgs: [existing.first['id']],
        );
      }

      await txn.rawUpdate(
        'UPDATE productos SET stockActual = stockActual + ? WHERE id = ?',
        [cantQuitar, productoId],
      );
    });
  }

  /// Cobra la cuenta con método de pago y moneda.
  Future<void> cobrarCuenta(
    CuentaAbierta cuenta, {
    String metodoPago = 'efectivo',
    String moneda = 'CUP',
    double? montoMoneda,
    double tasaCambio = 1.0,
    String? refTransaccion,
    String? plataformaQr,
  }) async {
    final db      = await database;
    final idVenta = const Uuid().v4();
    final fecha   = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final monto   = montoMoneda ?? cuenta.total;

    await db.transaction((txn) async {
      await txn.insert('ventas', {
        'id_venta':        idVenta,
        'fecha':           fecha,
        'total':           cuenta.total,
        'metodo_pago':     metodoPago,
        'moneda':          moneda,
        'monto_moneda':    monto,
        'tasa_cambio':     tasaCambio,
        'ref_transaccion': refTransaccion,
        'plataforma_qr':   plataformaQr,
      });

      for (final item in cuenta.items) {
        await txn.insert('detalle_venta', {
          'id_detalle':  const Uuid().v4(),
          'id_venta':    idVenta,
          'producto_id': item.productoId,
          'cantidad':    item.cantidad,
          'precio':      item.precio,
          'total':       item.subtotal,
        });
      }

      await txn.delete(
        'items_cuenta',
        where:     'cuenta_id = ?',
        whereArgs: [cuenta.id],
      );
      await txn.delete(
        'cuentas_abiertas',
        where:     'id = ?',
        whereArgs: [cuenta.id],
      );
    });
  }

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
        where:     'cuenta_id = ?',
        whereArgs: [cuenta.id],
      );
      await txn.delete(
        'cuentas_abiertas',
        where:     'id = ?',
        whereArgs: [cuenta.id],
      );
    });
  }

  Future<CuentaAbierta?> recargarCuenta(String cuentaId) async {
    final db = await database;
    final cuentas = await db.query(
      'cuentas_abiertas',
      where:     'id = ?',
      whereArgs: [cuentaId],
      limit:     1,
    );
    if (cuentas.isEmpty) return null;
    final items = await db.query(
      'items_cuenta',
      where:     'cuenta_id = ?',
      whereArgs: [cuentaId],
    );
    return CuentaAbierta.fromMap(cuentas.first, items);
  }

  // ─── IMPORTAR CIERRE DE TURNO (conservado por compatibilidad) ─────────────

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

  Future<int> importarCierreTurno(File archivo) async {
    final contenido = await archivo.readAsString();
    if (await cierreTurnoYaImportado(contenido)) {
      throw Exception('Este cierre ya fue importado anteriormente.');
    }
    final xmlString = _encrypter.decrypt(
      enc.Encrypted.fromBase64(contenido),
      iv: _iv,
    );
    final document = XmlDocument.parse(xmlString);
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
      throw Exception('El archivo no contiene ventas o tiene un formato incorrecto.');
    }
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
    await _registrarCierreTurnoImportado(contenido);
    return cantidadesPorProducto.length;
  }

  esTurnoCerrado() {}
}