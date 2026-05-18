import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xml/xml.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../models/producto.dart';
import '../models/movimiento.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._internal();
  factory DBHelper() => instance;
  DBHelper._internal();

  // ─── Claves AES-256 — deben coincidir con la app Vendedor ─────────────────
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
    final path = join(dbPath, 'pos_admin.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE productos (
            id          INTEGER PRIMARY KEY,
            nombre      TEXT    NOT NULL,
            precioVenta REAL    NOT NULL,
            stockActual REAL    NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE movimientos (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            producto_id INTEGER NOT NULL,
            cantidad    REAL    NOT NULL,
            fecha       TEXT    NOT NULL,
            tipo        TEXT    NOT NULL,
            nota        TEXT,
            FOREIGN KEY (producto_id) REFERENCES productos (id)
          )
        ''');

        // Historial de archivos .gv importados desde los vendedores
        await db.execute('''
          CREATE TABLE cierres_importados (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            archivo   TEXT NOT NULL,
            fecha_imp TEXT NOT NULL
          )
        ''');

        // Ventas y detalles reconstruidos a partir de los cierres importados
        await db.execute('''
          CREATE TABLE ventas_importadas (
            id_venta  TEXT    NOT NULL PRIMARY KEY,
            fecha     TEXT    NOT NULL,
            total     REAL    NOT NULL,
            cierre_id INTEGER NOT NULL,
            FOREIGN KEY (cierre_id) REFERENCES cierres_importados (id)
          )
        ''');

        await db.execute('''
          CREATE TABLE detalle_venta_importada (
            id_detalle  TEXT    NOT NULL,
            id_venta    TEXT    NOT NULL,
            producto_id INTEGER NOT NULL,
            cantidad    REAL    NOT NULL,
            precio      REAL    NOT NULL,
            total       REAL    NOT NULL,
            FOREIGN KEY (id_venta) REFERENCES ventas_importadas (id_venta)
          )
        ''');
      },
      onOpen: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ─── PRODUCTOS ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerProductosConStock() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        p.id,
        p.nombre,
        p.precioVenta,
        COALESCE(
          (SELECT SUM(m.cantidad) FROM movimientos m WHERE m.producto_id = p.id),
          0
        ) AS stockActual
      FROM productos p
      ORDER BY p.nombre ASC
    ''');
  }

  Future<void> insertarProducto(Producto producto) async {
    final db = await database;
    await db.insert(
      'productos',
      producto.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> eliminarProducto(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn
          .delete('movimientos', where: 'producto_id = ?', whereArgs: [id]);
      await txn.delete('productos', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> editarProducto({
    required int idAnterior,
    required int idNuevo,
    required String nombre,
    required double precioVenta,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      if (idAnterior != idNuevo) {
        // Insertar con nuevo ID
        await txn.insert(
            'productos',
            {
              'id': idNuevo,
              'nombre': nombre,
              'precioVenta': precioVenta,
              'stockActual': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
        // Reasignar movimientos al nuevo ID
        await txn.rawUpdate(
          'UPDATE movimientos SET producto_id = ? WHERE producto_id = ?',
          [idNuevo, idAnterior],
        );
        // Borrar el viejo
        await txn.delete('productos', where: 'id = ?', whereArgs: [idAnterior]);
      } else {
        await txn.update(
          'productos',
          {'nombre': nombre, 'precioVenta': precioVenta},
          where: 'id = ?',
          whereArgs: [idAnterior],
        );
      }
    });
  }

  // ─── MOVIMIENTOS ───────────────────────────────────────────────────────────

  Future<void> insertarMovimiento(Movimiento movimiento) async {
    final db = await database;
    await db.insert('movimientos', movimiento.toMap());
  }

  Future<void> ajustarStock({
    required int productoId,
    required double cantidad,
    required String nota,
  }) async {
    final db = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await db.insert('movimientos', {
      'producto_id': productoId,
      'cantidad': cantidad,
      'fecha': hoy,
      'tipo': Movimiento.tipoAjuste,
      'nota': nota,
    });
  }

  // ─── EXPORTAR INVENTARIO AL VENDEDOR ──────────────────────────────────────

  /// Genera un archivo .inv cifrado con todos los productos y su stock actual,
  /// listo para importar desde la app Vendedor.
  Future<void> exportarInventario() async {
    final productos = await obtenerProductosConStock();

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('Inventario', nest: () {
      for (final p in productos) {
        builder.element('Producto', nest: () {
          builder.element('id', nest: p['id'].toString());
          builder.element('nombre', nest: p['nombre'].toString());
          builder.element('precioVenta', nest: p['precioVenta'].toString());
          builder.element('stockActual', nest: p['stockActual'].toString());
        });
      }
    });

    final xmlStr = builder.buildDocument().toXmlString();
    final encrypted = _encrypter.encrypt(xmlStr, iv: _iv);

    final dir = await getTemporaryDirectory();
    final hoy = DateFormat('yyyyMMdd').format(DateTime.now());
    final file = File('${dir.path}/inventario_$hoy.inv');
    await file.writeAsString(encrypted.base64);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Inventario exportado $hoy',
    );
  }

  // ─── CIERRES DE CAJA (importados desde el Vendedor) ───────────────────────

  Future<List<Map<String, dynamic>>> obtenerHistorialCierres() async {
    final db = await database;
    return db.query(
      'cierres_importados',
      orderBy: 'id DESC',
    );
  }

  /// Importa un archivo .gv del vendedor, descifra el XML,
  /// persiste ventas y detalles, y descuenta el stock.
  Future<void> importarCierreCaja(File archivo) async {
    final db = await database;
    final contenido = await archivo.readAsString();
    final xmlString =
        _encrypter.decrypt(enc.Encrypted.fromBase64(contenido), iv: _iv);
    final document = XmlDocument.parse(xmlString);

    final nombreArchivo = archivo.path.split('/').last;
    final fechaImp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    await db.transaction((txn) async {
      // Registrar el cierre
      final cierreId = await txn.insert('cierres_importados', {
        'archivo': nombreArchivo,
        'fecha_imp': fechaImp,
      });

      // Ventas
      for (final v in document.findAllElements('Venta')) {
        final data = _xmlToMap(v);
        await txn.insert(
          'ventas_importadas',
          {
            'id_venta': data['id_venta'],
            'fecha': data['fecha'],
            'total': double.tryParse(data['total'].toString()) ?? 0.0,
            'cierre_id': cierreId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // Detalles + descuento de stock
      for (final d in document.findAllElements('Detalle')) {
        final data = _xmlToMap(d);
        final cantidad = double.tryParse(data['cantidad'].toString()) ?? 0.0;
        final precio = double.tryParse(data['precio'].toString()) ?? 0.0;
        final prodId = int.tryParse(data['producto_id'].toString()) ?? 0;

        await txn.insert(
          'detalle_venta_importada',
          {
            'id_detalle': data['id_detalle'],
            'id_venta': data['id_venta'],
            'producto_id': prodId,
            'cantidad': cantidad,
            'precio': precio,
            'total': double.tryParse(data['total'].toString()) ?? 0.0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // Descontar del inventario del Admin mediante un movimiento negativo
        final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await txn.insert('movimientos', {
          'producto_id': prodId,
          'cantidad': -cantidad,
          'fecha': hoy,
          'tipo': 'venta_vendedor',
          'nota': 'Cierre importado: $nombreArchivo',
        });
      }
    });
  }

  /// Devuelve totales y detalle por producto de UN cierre (fecha_imp).
  Future<Map<String, dynamic>> obtenerResumenPorFecha(String fechaImp) async {
    final db = await database;

    // Obtener el id del cierre que corresponde a esa fecha_imp
    final cierres = await db.query(
      'cierres_importados',
      where: 'fecha_imp = ?',
      whereArgs: [fechaImp],
      limit: 1,
    );
    if (cierres.isEmpty) {
      return {'totalVentas': 0.0, 'numeroVentas': 0, 'detalle': []};
    }
    final cierreId = cierres.first['id'] as int;

    final totales = await db.rawQuery('''
      SELECT
        COALESCE(SUM(vi.total), 0.0) AS totalVentas,
        COUNT(*)                     AS numeroVentas
      FROM ventas_importadas vi
      WHERE vi.cierre_id = ?
    ''', [cierreId]);

    final detalle = await db.rawQuery('''
      SELECT
        COALESCE(p.nombre, 'ID ' || dvi.producto_id) AS nombre,
        SUM(dvi.cantidad)                             AS cantidadTotal,
        SUM(dvi.total)                                AS totalVendido
      FROM detalle_venta_importada dvi
      JOIN ventas_importadas vi ON vi.id_venta = dvi.id_venta
      LEFT JOIN productos p     ON p.id = dvi.producto_id
      WHERE vi.cierre_id = ?
      GROUP BY dvi.producto_id
      ORDER BY totalVendido DESC
    ''', [cierreId]);

    return {
      'totalVentas': (totales.first['totalVentas'] as num).toDouble(),
      'numeroVentas': (totales.first['numeroVentas'] as num).toInt(),
      'detalle': detalle,
    };
  }

  /// Suma el total de todas las ventas importadas HOY (por fecha_imp).
  Future<double> obtenerTotalVentasHoy() async {
    final db = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final result = await db.rawQuery('''
    SELECT COALESCE(SUM(vi.total), 0.0) AS totalHoy
    FROM ventas_importadas vi
    JOIN cierres_importados ci ON ci.id = vi.cierre_id
    WHERE ci.fecha_imp LIKE ?
  ''', ['$hoy%']);

    return (result.first['totalHoy'] as num).toDouble();
  }

  // ─── BACKUP ────────────────────────────────────────────────────────────────

  /// Exporta toda la base de datos como XML cifrado (.bkp).
  Future<void> exportarBackup() async {
    final db = await database;
    final productos = await db.query('productos');
    final movimientos = await db.query('movimientos');
    final cierres = await db.query('cierres_importados');
    final ventas = await db.query('ventas_importadas');
    final detalles = await db.query('detalle_venta_importada');

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('Backup', nest: () {
      _escribirTabla(builder, 'Productos', 'Producto', productos);
      _escribirTabla(builder, 'Movimientos', 'Movimiento', movimientos);
      _escribirTabla(builder, 'Cierres', 'Cierre', cierres);
      _escribirTabla(builder, 'Ventas', 'Venta', ventas);
      _escribirTabla(builder, 'Detalles', 'Detalle', detalles);
    });

    final xmlStr = builder.buildDocument().toXmlString();
    final encrypted = _encrypter.encrypt(xmlStr, iv: _iv);

    final dir = await getTemporaryDirectory();
    final hoy = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/backup_admin_$hoy.bkp');
    await file.writeAsString(encrypted.base64);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Backup VaraNova Admin — $hoy',
    );
  }

  /// Restaura la base de datos desde un archivo .bkp cifrado.
  Future<void> restaurarBackup(File archivo) async {
    final db = await database;
    final contenido = await archivo.readAsString();
    final xmlString =
        _encrypter.decrypt(enc.Encrypted.fromBase64(contenido), iv: _iv);
    final document = XmlDocument.parse(xmlString);

    await db.transaction((txn) async {
      // Limpiar todo
      await txn.delete('detalle_venta_importada');
      await txn.delete('ventas_importadas');
      await txn.delete('cierres_importados');
      await txn.delete('movimientos');
      await txn.delete('productos');

      // Restaurar productos
      for (final el in document.findAllElements('Producto')) {
        final m = _xmlToMap(el);
        await txn.insert(
            'productos',
            {
              'id': int.tryParse(m['id'].toString()) ?? 0,
              'nombre': m['nombre'],
              'precioVenta':
                  double.tryParse(m['precioVenta'].toString()) ?? 0.0,
              'stockActual':
                  double.tryParse(m['stockActual'].toString()) ?? 0.0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Restaurar movimientos
      for (final el in document.findAllElements('Movimiento')) {
        final m = _xmlToMap(el);
        await txn.insert(
            'movimientos',
            {
              'id': int.tryParse(m['id'].toString()),
              'producto_id': int.tryParse(m['producto_id'].toString()) ?? 0,
              'cantidad': double.tryParse(m['cantidad'].toString()) ?? 0.0,
              'fecha': m['fecha'],
              'tipo': m['tipo'],
              'nota': m['nota'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Restaurar cierres
      for (final el in document.findAllElements('Cierre')) {
        final m = _xmlToMap(el);
        await txn.insert(
            'cierres_importados',
            {
              'id': int.tryParse(m['id'].toString()),
              'archivo': m['archivo'],
              'fecha_imp': m['fecha_imp'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Restaurar ventas importadas
      for (final el in document.findAllElements('Venta')) {
        final m = _xmlToMap(el);
        await txn.insert(
            'ventas_importadas',
            {
              'id_venta': m['id_venta'],
              'fecha': m['fecha'],
              'total': double.tryParse(m['total'].toString()) ?? 0.0,
              'cierre_id': int.tryParse(m['cierre_id'].toString()) ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Restaurar detalles
      for (final el in document.findAllElements('Detalle')) {
        final m = _xmlToMap(el);
        await txn.insert(
            'detalle_venta_importada',
            {
              'id_detalle': m['id_detalle'],
              'id_venta': m['id_venta'],
              'producto_id': int.tryParse(m['producto_id'].toString()) ?? 0,
              'cantidad': double.tryParse(m['cantidad'].toString()) ?? 0.0,
              'precio': double.tryParse(m['precio'].toString()) ?? 0.0,
              'total': double.tryParse(m['total'].toString()) ?? 0.0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  void _escribirTabla(XmlBuilder builder, String tagPadre, String tagHijo,
      List<Map<String, dynamic>> rows) {
    builder.element(tagPadre, nest: () {
      for (final row in rows) {
        builder.element(tagHijo, nest: () {
          row.forEach((k, v) => builder.element(k, nest: v?.toString() ?? ''));
        });
      }
    });
  }

  Map<String, dynamic> _xmlToMap(XmlElement element) {
    final map = <String, dynamic>{};
    for (final child in element.children) {
      if (child is XmlElement) {
        map[child.name.local] = child.innerText;
      }
    }
    return map;
  }
}
