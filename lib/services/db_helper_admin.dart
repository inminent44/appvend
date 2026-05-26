// ════════════════════════════════════════════════════════════════════════════
// lib/services/db_helper_admin.dart
// VaraNova POS — DB Admin v4
//
// Versiones:
//   v1 → tablas base
//   v2 → metodo_pago en ventas_importadas
//   v3 → categoria + tipo_producto en productos
//   v4 → es_favorito · combo_items · modificadores · tasas_cambio · stats_productos
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xml/xml.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../admin/models/producto.dart';
import '../admin/models/movimiento.dart';
import '../models/modificador.dart';
import '../models/tasa_cambio.dart';
import '../models/combo_item.dart';

class DBHelperAdmin {
  static final DBHelperAdmin instance = DBHelperAdmin._internal();
  factory DBHelperAdmin() => instance;
  DBHelperAdmin._internal();

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

  // ═══════════════════════════════════════════════════════════════════════════
  // INIT / MIGRATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'pos_admin.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Productos ────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE productos (
        id             INTEGER PRIMARY KEY,
        nombre         TEXT    NOT NULL,
        precioVenta    REAL    NOT NULL,
        categoria      TEXT,
        tipo_producto  TEXT,
        es_favorito    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── Movimientos de stock ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE movimientos (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        cantidad    REAL    NOT NULL,
        fecha       TEXT    NOT NULL,
        tipo        TEXT    NOT NULL,
        nota        TEXT,
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');

    // ── Cierres de caja importados ───────────────────────────────────────────
    await db.execute('''
      CREATE TABLE cierres_importados (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        archivo   TEXT NOT NULL UNIQUE,
        fecha_imp TEXT NOT NULL
      )
    ''');

    // ── Ventas importadas ────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE ventas_importadas (
        id_venta    TEXT    NOT NULL PRIMARY KEY,
        fecha       TEXT    NOT NULL,
        total       REAL    NOT NULL,
        cierre_id   INTEGER NOT NULL,
        metodo_pago TEXT    NOT NULL DEFAULT 'Efectivo',
        FOREIGN KEY (cierre_id) REFERENCES cierres_importados(id)
      )
    ''');

    // ── Detalle de ventas importadas ─────────────────────────────────────────
    await db.execute('''
      CREATE TABLE detalle_venta_importada (
        id_detalle  TEXT    NOT NULL,
        id_venta    TEXT    NOT NULL,
        producto_id INTEGER NOT NULL,
        cantidad    REAL    NOT NULL,
        precio      REAL    NOT NULL,
        total       REAL    NOT NULL,
        FOREIGN KEY (id_venta) REFERENCES ventas_importadas(id_venta)
      )
    ''');

    // ── Combo items ──────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE combo_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        combo_id    INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        cantidad    REAL    NOT NULL DEFAULT 1,
        FOREIGN KEY (combo_id)    REFERENCES productos(id),
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');

    // ── Modificadores ────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE modificadores (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre       TEXT    NOT NULL,
        precio_extra REAL    NOT NULL DEFAULT 0,
        afecta_stock INTEGER NOT NULL DEFAULT 0,
        producto_id  INTEGER,
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');

    // ── Tasas de cambio (manual, offline-first) ──────────────────────────────
    await db.execute('''
      CREATE TABLE tasas_cambio (
        moneda      TEXT PRIMARY KEY,
        tasa_a_cup  REAL NOT NULL,
        actualizado TEXT NOT NULL
      )
    ''');

    // ── Stats de productos (resumen precalculado, se actualiza al importar cierre)
    await db.execute('''
      CREATE TABLE stats_productos (
        producto_id    INTEGER PRIMARY KEY,
        veces_vendido  INTEGER NOT NULL DEFAULT 0,
        unidades_total REAL    NOT NULL DEFAULT 0,
        ingresos_total REAL    NOT NULL DEFAULT 0,
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');

    // ── Tasas por defecto ────────────────────────────────────────────────────
    await _insertarTasasPorDefecto(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE ventas_importadas ADD COLUMN metodo_pago TEXT NOT NULL DEFAULT 'Efectivo'",
      );
    }

    // v2 → v3: soporte restaurante/cafetería
    if (oldVersion < 3) {
      try { await db.execute('ALTER TABLE productos ADD COLUMN categoria TEXT'); }
      catch (_) {}
      try { await db.execute('ALTER TABLE productos ADD COLUMN tipo_producto TEXT'); }
      catch (_) {}
    }

    // v3 → v4: favoritos · combos · modificadores · tasas · stats
    if (oldVersion < 4) {
      // es_favorito en productos
      try {
        await db.execute(
          'ALTER TABLE productos ADD COLUMN es_favorito INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}

      // combo_items
      await db.execute('''
        CREATE TABLE IF NOT EXISTS combo_items (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          combo_id    INTEGER NOT NULL,
          producto_id INTEGER NOT NULL,
          cantidad    REAL    NOT NULL DEFAULT 1,
          FOREIGN KEY (combo_id)    REFERENCES productos(id),
          FOREIGN KEY (producto_id) REFERENCES productos(id)
        )
      ''');

      // modificadores
      await db.execute('''
        CREATE TABLE IF NOT EXISTS modificadores (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre       TEXT    NOT NULL,
          precio_extra REAL    NOT NULL DEFAULT 0,
          afecta_stock INTEGER NOT NULL DEFAULT 0,
          producto_id  INTEGER,
          FOREIGN KEY (producto_id) REFERENCES productos(id)
        )
      ''');

      // tasas_cambio
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tasas_cambio (
          moneda      TEXT PRIMARY KEY,
          tasa_a_cup  REAL NOT NULL,
          actualizado TEXT NOT NULL
        )
      ''');

      // stats_productos
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stats_productos (
          producto_id    INTEGER PRIMARY KEY,
          veces_vendido  INTEGER NOT NULL DEFAULT 0,
          unidades_total REAL    NOT NULL DEFAULT 0,
          ingresos_total REAL    NOT NULL DEFAULT 0,
          FOREIGN KEY (producto_id) REFERENCES productos(id)
        )
      ''');

      await _insertarTasasPorDefecto(db);
    }
  }

  /// Tasas iniciales conservadoras — el admin las edita desde la UI.
  Future<void> _insertarTasasPorDefecto(Database db) async {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    const defaults = {'USD': 300.0, 'EUR': 330.0, 'CAD': 220.0};
    for (final entry in defaults.entries) {
      await db.insert(
        'tasas_cambio',
        {'moneda': entry.key, 'tasa_a_cup': entry.value, 'actualizado': hoy},
        conflictAlgorithm: ConflictAlgorithm.ignore, // no sobreescribe si ya existe
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCTOS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> obtenerProductosConStock() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        p.id,
        p.nombre,
        p.precioVenta,
        p.categoria,
        p.tipo_producto,
        p.es_favorito,
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
      await txn.delete('movimientos',    where: 'producto_id = ?', whereArgs: [id]);
      await txn.delete('combo_items',    where: 'combo_id = ?',    whereArgs: [id]);
      await txn.delete('combo_items',    where: 'producto_id = ?', whereArgs: [id]);
      await txn.delete('modificadores',  where: 'producto_id = ?', whereArgs: [id]);
      await txn.delete('stats_productos',where: 'producto_id = ?', whereArgs: [id]);
      await txn.delete('productos',      where: 'id = ?',          whereArgs: [id]);
    });
  }

  Future<void> editarProducto({
    required int    id,
    required String nombre,
    required double precioVenta,
    String? categoria,
    String? tipoProducto,
    bool    esFavorito = false,
  }) async {
    final db = await database;
    await db.update(
      'productos',
      {
        'nombre':        nombre,
        'precioVenta':   precioVenta,
        'categoria':     categoria,
        'tipo_producto': tipoProducto,
        'es_favorito':   esFavorito ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Favoritos ────────────────────────────────────────────────────────────

  /// Activa o desactiva el flag favorito de un producto.
  Future<void> toggleFavorito(int productoId, {required bool esFavorito}) async {
    final db = await database;
    await db.update(
      'productos',
      {'es_favorito': esFavorito ? 1 : 0},
      where: 'id = ?',
      whereArgs: [productoId],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOVIMIENTOS DE STOCK
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> insertarMovimiento(Movimiento movimiento) async {
    final db = await database;
    await db.insert('movimientos', movimiento.toMap());
  }

  Future<void> ajustarStock({
    required int    productoId,
    required double cantidad,
    required String nota,
  }) async {
    final db  = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await db.insert('movimientos', {
      'producto_id': productoId,
      'cantidad':    cantidad,
      'fecha':       hoy,
      'tipo':        Movimiento.tipoAjuste,
      'nota':        nota,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMBOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve los componentes de un combo con nombre y precio de cada uno.
  Future<List<ComboItem>> obtenerItemsCombo(int comboId) async {
    final db   = await database;
    final rows = await db.rawQuery('''
      SELECT ci.id, ci.combo_id, ci.producto_id, ci.cantidad,
             p.nombre, p.precioVenta
      FROM combo_items ci
      JOIN productos p ON p.id = ci.producto_id
      WHERE ci.combo_id = ?
      ORDER BY p.nombre ASC
    ''', [comboId]);
    return rows.map(ComboItem.fromMap).toList();
  }

  /// Reemplaza todos los items de un combo en una transacción atómica.
  Future<void> guardarItemsCombo(int comboId, List<ComboItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('combo_items', where: 'combo_id = ?', whereArgs: [comboId]);
      for (final item in items) {
        await txn.insert('combo_items', {
          'combo_id':    comboId,
          'producto_id': item.productoId,
          'cantidad':    item.cantidad,
        });
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODIFICADORES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve modificadores globales (producto_id IS NULL) y, opcionalmente,
  /// los específicos del [productoId] indicado.
  Future<List<Modificador>> obtenerModificadores({int? productoId}) async {
    final db = await database;
    final List<Map<String, dynamic>> rows;

    if (productoId != null) {
      rows = await db.rawQuery('''
        SELECT * FROM modificadores
        WHERE producto_id IS NULL OR producto_id = ?
        ORDER BY nombre ASC
      ''', [productoId]);
    } else {
      rows = await db.query('modificadores', orderBy: 'nombre ASC');
    }

    return rows.map(Modificador.fromMap).toList();
  }

  Future<void> guardarModificador(Modificador mod) async {
    final db = await database;
    await db.insert(
      'modificadores',
      mod.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> eliminarModificador(int id) async {
    final db = await database;
    await db.delete('modificadores', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TASAS DE CAMBIO
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<TasaCambio>> obtenerTasasCambio() async {
    final db   = await database;
    final rows = await db.query('tasas_cambio', orderBy: 'moneda ASC');
    return rows.map(TasaCambio.fromMap).toList();
  }

  /// Actualiza (o inserta) la tasa para una moneda. Registra la fecha/hora.
  Future<void> actualizarTasa(String moneda, double tasaACup) async {
    final db  = await database;
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    await db.insert(
      'tasas_cambio',
      {'moneda': moneda, 'tasa_a_cup': tasaACup, 'actualizado': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATS DE PRODUCTOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Top N productos más vendidos por unidades.
  Future<List<Map<String, dynamic>>> topProductos({int limit = 10}) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        p.nombre,
        p.categoria,
        p.tipo_producto,
        p.es_favorito,
        s.veces_vendido,
        s.unidades_total,
        s.ingresos_total
      FROM stats_productos s
      JOIN productos p ON p.id = s.producto_id
      ORDER BY s.unidades_total DESC
      LIMIT ?
    ''', [limit]);
  }

  /// Actualiza stats de un producto en una transacción ya abierta.
  /// Se llama desde [importarCierreCaja].
  Future<void> _actualizarStats(
    Transaction txn, {
    required int    productoId,
    required double cantidad,
    required double precio,
  }) async {
    await txn.rawInsert('''
      INSERT INTO stats_productos (producto_id, veces_vendido, unidades_total, ingresos_total)
      VALUES (?, 1, ?, ?)
      ON CONFLICT(producto_id) DO UPDATE SET
        veces_vendido  = veces_vendido  + 1,
        unidades_total = unidades_total + excluded.unidades_total,
        ingresos_total = ingresos_total + excluded.ingresos_total
    ''', [productoId, cantidad, cantidad * precio]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORTAR INVENTARIO AL CAJERO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Exporta productos + tasas de cambio al cajero en un único .inv encriptado.
  Future<void> exportarInventario() async {
    final db       = await database;
    final productos = await obtenerProductosConStock();
    final tasas     = await db.query('tasas_cambio');

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('Inventario', nest: () {
      // ── Productos ──────────────────────────────────────────────────────────
      for (final p in productos) {
        builder.element('Producto', nest: () {
          builder.element('id',            nest: p['id'].toString());
          builder.element('nombre',        nest: p['nombre'].toString());
          builder.element('precioVenta',   nest: p['precioVenta'].toString());
          builder.element('stockActual',   nest: p['stockActual'].toString());
          builder.element('categoria',     nest: (p['categoria']     ?? '').toString());
          builder.element('tipo_producto', nest: (p['tipo_producto'] ?? '').toString());
          builder.element('es_favorito',   nest: (p['es_favorito']   ?? 0).toString());
        });
      }

      // ── Tasas de cambio ────────────────────────────────────────────────────
      builder.element('Tasas', nest: () {
        for (final t in tasas) {
          builder.element('Tasa', nest: () {
            t.forEach((k, v) => builder.element(k, nest: v?.toString() ?? ''));
          });
        }
      });
    });

    final xmlStr    = builder.buildDocument().toXmlString();
    final encrypted = _encrypter.encrypt(xmlStr, iv: _iv);
    final dir       = await getTemporaryDirectory();
    final hoy       = DateFormat('yyyyMMdd').format(DateTime.now());
    final file      = File('${dir.path}/inventario_$hoy.inv');
    await file.writeAsString(encrypted.base64);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Inventario $hoy',
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CIERRES DE CAJA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> obtenerHistorialCierres() async {
    final db = await database;
    return db.query('cierres_importados', orderBy: 'id DESC');
  }

  Future<bool> cierreYaImportado(String nombreArchivo) async {
    final db  = await database;
    final res = await db.query(
      'cierres_importados',
      where:     'archivo = ?',
      whereArgs: [nombreArchivo],
      limit:     1,
    );
    return res.isNotEmpty;
  }

  Future<void> importarCierreCaja(File archivo) async {
    final db        = await database;
    final contenido = await archivo.readAsString();
    final xmlString = _encrypter.decrypt(
      enc.Encrypted.fromBase64(contenido),
      iv: _iv,
    );
    final document      = XmlDocument.parse(xmlString);
    final nombreArchivo = archivo.path.split('/').last;
    final fechaImp      = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    await db.transaction((txn) async {
      final cierreId = await txn.insert(
        'cierres_importados',
        {'archivo': nombreArchivo, 'fecha_imp': fechaImp},
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      // ── Ventas ──────────────────────────────────────────────────────────────
      for (final v in document.findAllElements('Venta')) {
        final data = _xmlToMap(v);
        await txn.insert(
          'ventas_importadas',
          {
            'id_venta':   data['id_venta'],
            'fecha':      data['fecha'],
            'total':      double.tryParse(data['total'].toString()) ?? 0.0,
            'cierre_id':  cierreId,
            'metodo_pago': (data['metodo_pago']?.toString().isNotEmpty == true)
                ? data['metodo_pago'].toString()
                : 'Efectivo',
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // ── Detalles + descontar stock + actualizar stats ─────────────────────
      for (final d in document.findAllElements('Detalle')) {
        final data     = _xmlToMap(d);
        final cantidad = double.tryParse(data['cantidad'].toString()) ?? 0.0;
        final precio   = double.tryParse(data['precio'].toString())   ?? 0.0;
        final prodId   = int.tryParse(data['producto_id'].toString()) ?? 0;

        await txn.insert(
          'detalle_venta_importada',
          {
            'id_detalle':  data['id_detalle'],
            'id_venta':    data['id_venta'],
            'producto_id': prodId,
            'cantidad':    cantidad,
            'precio':      precio,
            'total':       double.tryParse(data['total'].toString()) ?? 0.0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // Descontar stock solo si el producto existe
        final productoExiste = await txn.query(
          'productos',
          where:     'id = ?',
          whereArgs: [prodId],
          limit:     1,
        );
        if (productoExiste.isNotEmpty) {
          final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
          await txn.insert('movimientos', {
            'producto_id': prodId,
            'cantidad':    -cantidad,
            'fecha':       hoy,
            'tipo':        'venta_cajero',
            'nota':        'Cierre importado: $nombreArchivo',
          });

          // Actualizar stats
          await _actualizarStats(txn,
            productoId: prodId,
            cantidad:   cantidad,
            precio:     precio,
          );
        }
      }
    });
  }

  Future<Map<String, dynamic>> obtenerResumenPorFecha(String fechaImp) async {
    final db = await database;
    final cierres = await db.query(
      'cierres_importados',
      where:     'fecha_imp = ?',
      whereArgs: [fechaImp],
      limit:     1,
    );
    if (cierres.isEmpty) {
      return {
        'totalVentas':      0.0,
        'numeroVentas':     0,
        'detalle':          [],
        'totalesPorMetodo': <String, double>{},
      };
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
      JOIN ventas_importadas vi ON vi.id_venta  = dvi.id_venta
      LEFT JOIN productos p     ON p.id         = dvi.producto_id
      WHERE vi.cierre_id = ?
      GROUP BY dvi.producto_id
      ORDER BY totalVendido DESC
    ''', [cierreId]);

    final porMetodo = await db.rawQuery('''
      SELECT metodo_pago, COALESCE(SUM(total), 0.0) AS subtotal
      FROM ventas_importadas
      WHERE cierre_id = ?
      GROUP BY metodo_pago
    ''', [cierreId]);

    return {
      'totalVentas':      (totales.first['totalVentas']  as num).toDouble(),
      'numeroVentas':     (totales.first['numeroVentas'] as num).toInt(),
      'detalle':          detalle,
      'totalesPorMetodo': {
        for (final row in porMetodo)
          row['metodo_pago'] as String: (row['subtotal'] as num).toDouble()
      },
    };
  }

  Future<double> obtenerTotalVentasHoy() async {
    final db  = await database;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(vi.total), 0.0) AS totalHoy
      FROM ventas_importadas vi
      JOIN cierres_importados ci ON ci.id = vi.cierre_id
      WHERE ci.fecha_imp LIKE ?
    ''', ['$hoy%']);
    return (res.first['totalHoy'] as num).toDouble();
  }

  // ─── Reportes ─────────────────────────────────────────────────────────────

  /// Ingresos agrupados por método de pago para un cierre específico.
  Future<Map<String, double>> ingresosPorMetodo(int cierreId) async {
    final db   = await database;
    final rows = await db.rawQuery('''
      SELECT metodo_pago, COALESCE(SUM(total), 0) AS subtotal
      FROM ventas_importadas
      WHERE cierre_id = ?
      GROUP BY metodo_pago
    ''', [cierreId]);
    return {
      for (final r in rows)
        r['metodo_pago'] as String: (r['subtotal'] as num).toDouble()
    };
  }

  /// Ventas agrupadas por día (últimos [dias] días).
  Future<List<Map<String, dynamic>>> ventasPorDia({int dias = 30}) async {
    final db    = await database;
    final desde = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(Duration(days: dias)));
    return db.rawQuery('''
      SELECT
        vi.fecha,
        COUNT(*)                     AS numero_ventas,
        COALESCE(SUM(vi.total), 0.0) AS total_dia
      FROM ventas_importadas vi
      WHERE vi.fecha >= ?
      GROUP BY vi.fecha
      ORDER BY vi.fecha ASC
    ''', [desde]);
  }

  /// Categoría con más ventas por ingresos.
  Future<List<Map<String, dynamic>>> topCategorias({int limit = 5}) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        COALESCE(p.categoria, 'Sin categoría') AS categoria,
        SUM(s.unidades_total)                  AS unidades,
        SUM(s.ingresos_total)                  AS ingresos
      FROM stats_productos s
      JOIN productos p ON p.id = s.producto_id
      GROUP BY p.categoria
      ORDER BY ingresos DESC
      LIMIT ?
    ''', [limit]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKUP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> exportarBackup() async {
    final db = await database;

    final productos    = await db.query('productos');
    final movimientos  = await db.query('movimientos');
    final cierres      = await db.query('cierres_importados');
    final ventas       = await db.query('ventas_importadas');
    final detalles     = await db.query('detalle_venta_importada');
    final combos       = await db.query('combo_items');
    final modificadores = await db.query('modificadores');
    final tasas        = await db.query('tasas_cambio');
    final stats        = await db.query('stats_productos');

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('Backup', nest: () {
      _escribirTabla(builder, 'Productos',     'Producto',    productos);
      _escribirTabla(builder, 'Movimientos',   'Movimiento',  movimientos);
      _escribirTabla(builder, 'Cierres',       'Cierre',      cierres);
      _escribirTabla(builder, 'Ventas',        'Venta',       ventas);
      _escribirTabla(builder, 'Detalles',      'Detalle',     detalles);
      _escribirTabla(builder, 'ComboItems',    'ComboItem',   combos);
      _escribirTabla(builder, 'Modificadores', 'Modificador', modificadores);
      _escribirTabla(builder, 'Tasas',         'Tasa',        tasas);
      _escribirTabla(builder, 'Stats',         'Stat',        stats);
    });

    final xmlStr    = builder.buildDocument().toXmlString();
    final encrypted = _encrypter.encrypt(xmlStr, iv: _iv);
    final hoy       = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final dir       = await getTemporaryDirectory();
    final file      = File('${dir.path}/backup_admin_$hoy.bkp');
    await file.writeAsString(encrypted.base64);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Backup VaraNova Admin — $hoy',
      ),
    );
  }

  Future<void> restaurarBackup(File archivo) async {
    final db        = await database;
    final contenido = await archivo.readAsString();
    final xmlString = _encrypter.decrypt(
      enc.Encrypted.fromBase64(contenido),
      iv: _iv,
    );
    final document = XmlDocument.parse(xmlString);

    await db.transaction((txn) async {
      // Borrar en orden para respetar FK
      await txn.delete('stats_productos');
      await txn.delete('detalle_venta_importada');
      await txn.delete('ventas_importadas');
      await txn.delete('cierres_importados');
      await txn.delete('combo_items');
      await txn.delete('modificadores');
      await txn.delete('movimientos');
      await txn.delete('productos');
      await txn.delete('tasas_cambio');

      // Productos
      for (final el in document.findAllElements('Producto')) {
        final m = _xmlToMap(el);
        await txn.insert('productos', {
          'id':            int.tryParse(m['id'].toString()) ?? 0,
          'nombre':        m['nombre'],
          'precioVenta':   double.tryParse(m['precioVenta'].toString()) ?? 0.0,
          'categoria':     _emptyToNull(m['categoria']),
          'tipo_producto': _emptyToNull(m['tipo_producto']),
          'es_favorito':   int.tryParse(m['es_favorito']?.toString() ?? '0') ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Movimientos
      for (final el in document.findAllElements('Movimiento')) {
        final m = _xmlToMap(el);
        await txn.insert('movimientos', {
          'id':          int.tryParse(m['id'].toString()),
          'producto_id': int.tryParse(m['producto_id'].toString()) ?? 0,
          'cantidad':    double.tryParse(m['cantidad'].toString()) ?? 0.0,
          'fecha':       m['fecha'],
          'tipo':        m['tipo'],
          'nota':        m['nota'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Cierres
      for (final el in document.findAllElements('Cierre')) {
        final m = _xmlToMap(el);
        await txn.insert('cierres_importados', {
          'id':        int.tryParse(m['id'].toString()),
          'archivo':   m['archivo'],
          'fecha_imp': m['fecha_imp'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Ventas
      for (final el in document.findAllElements('Venta')) {
        final m = _xmlToMap(el);
        await txn.insert('ventas_importadas', {
          'id_venta':   m['id_venta'],
          'fecha':      m['fecha'],
          'total':      double.tryParse(m['total'].toString()) ?? 0.0,
          'cierre_id':  int.tryParse(m['cierre_id'].toString()) ?? 0,
          'metodo_pago': (m['metodo_pago']?.toString().isNotEmpty == true)
              ? m['metodo_pago'].toString()
              : 'Efectivo',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Detalles
      for (final el in document.findAllElements('Detalle')) {
        final m = _xmlToMap(el);
        await txn.insert('detalle_venta_importada', {
          'id_detalle':  m['id_detalle'],
          'id_venta':    m['id_venta'],
          'producto_id': int.tryParse(m['producto_id'].toString()) ?? 0,
          'cantidad':    double.tryParse(m['cantidad'].toString()) ?? 0.0,
          'precio':      double.tryParse(m['precio'].toString())   ?? 0.0,
          'total':       double.tryParse(m['total'].toString())    ?? 0.0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Combo items
      for (final el in document.findAllElements('ComboItem')) {
        final m = _xmlToMap(el);
        await txn.insert('combo_items', {
          'id':          int.tryParse(m['id'].toString()),
          'combo_id':    int.tryParse(m['combo_id'].toString()) ?? 0,
          'producto_id': int.tryParse(m['producto_id'].toString()) ?? 0,
          'cantidad':    double.tryParse(m['cantidad'].toString()) ?? 1.0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Modificadores
      for (final el in document.findAllElements('Modificador')) {
        final m = _xmlToMap(el);
        await txn.insert('modificadores', {
          'id':           int.tryParse(m['id'].toString()),
          'nombre':       m['nombre'],
          'precio_extra': double.tryParse(m['precio_extra'].toString()) ?? 0.0,
          'afecta_stock': int.tryParse(m['afecta_stock'].toString()) ?? 0,
          'producto_id':  int.tryParse(m['producto_id']?.toString() ?? ''),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Tasas
      for (final el in document.findAllElements('Tasa')) {
        final m = _xmlToMap(el);
        await txn.insert('tasas_cambio', {
          'moneda':      m['moneda'],
          'tasa_a_cup':  double.tryParse(m['tasa_a_cup'].toString()) ?? 1.0,
          'actualizado': m['actualizado'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Stats
      for (final el in document.findAllElements('Stat')) {
        final m = _xmlToMap(el);
        await txn.insert('stats_productos', {
          'producto_id':    int.tryParse(m['producto_id'].toString()) ?? 0,
          'veces_vendido':  int.tryParse(m['veces_vendido'].toString()) ?? 0,
          'unidades_total': double.tryParse(m['unidades_total'].toString()) ?? 0.0,
          'ingresos_total': double.tryParse(m['ingresos_total'].toString()) ?? 0.0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS PRIVADOS
  // ═══════════════════════════════════════════════════════════════════════════

  void _escribirTabla(
    XmlBuilder builder,
    String tagPadre,
    String tagHijo,
    List<Map<String, dynamic>> rows,
  ) {
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

  /// Devuelve null si el valor es null o cadena vacía. Útil para campos opcionales.
  String? _emptyToNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : s;
  }
}