import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/producto.dart';
import '../models/movimiento.dart';
import '../../services/db_helper_admin.dart';

class AgregarProductoScreen extends StatefulWidget {
  final Producto? producto;
  const AgregarProductoScreen({super.key, this.producto});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  static const Color primaryDark = Color(0xFF084B53);
  static const Color primaryMid = Color(0xFF0A6B77);
  static const Color bgPage = Color(0xFFF4F6F8);

  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  final _cantidadController = TextEditingController();
  // Restaurante: valores temporales para los selectors
  String? _categoriaSeleccionada;
  TipoProducto _tipoSeleccionado = TipoProducto.ninguno;

  final _nombreFocus = FocusNode();
  final _precioFocus = FocusNode();
  final _cantidadFocus = FocusNode();

  bool _cargando = false;
  bool _idDuplicado = false;
  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _idController.text = widget.producto!.id.toString();
      _nombreController.text = widget.producto!.nombre;
      _precioController.text = widget.producto!.precioVenta.toString();
    } else {
      _idController.addListener(_buscarProductoPorId);
      _categoriaSeleccionada = widget.producto!.categoria;
      _tipoSeleccionado = widget.producto!.tipoProducto;
    }
  }

  @override
  void dispose() {
    if (!_esEdicion) _idController.removeListener(_buscarProductoPorId);
    _idController.dispose();
    _nombreController.dispose();
    _precioController.dispose();
    _cantidadController.dispose();
    _nombreFocus.dispose();
    _precioFocus.dispose();
    _cantidadFocus.dispose();
    super.dispose();
  }

  Future<void> _buscarProductoPorId() async {
    final id = int.tryParse(_idController.text.trim());
    if (id == null) {
      if (_idDuplicado) setState(() => _idDuplicado = false);
      return;
    }
    final productos = await DBHelperAdmin.instance.obtenerProductosConStock();
    if (!mounted) return;
    final existe = productos.any((p) => p['id'] == id);
    if (existe != _idDuplicado) setState(() => _idDuplicado = existe);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idDuplicado) return;
    setState(() => _cargando = true);

    try {
      final nombre = _nombreController.text.trim();
      final precio = double.parse(_precioController.text.replaceAll(',', '.'));

      if (_esEdicion) {
        await DBHelperAdmin.instance.editarProducto(
          id: widget.producto!.id,
          nombre: nombre,
          precioVenta: precio,
          categoria: _categoriaSeleccionada,
          tipoProducto: _tipoSeleccionado.toDb(),
        );
        final cant = double.tryParse(
                _cantidadController.text.trim().replaceAll(',', '.')) ??
            0;
        if (cant != 0) {
          await DBHelperAdmin.instance.insertarMovimiento(Movimiento(
            productoId: widget.producto!.id,
            cantidad: cant,
            fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            tipo: Movimiento.tipoAjuste,
            nota: 'Ajuste desde edición',
          ));
        }
      } else {
        final idNuevo = int.parse(_idController.text);
        final actuales =
            await DBHelperAdmin.instance.obtenerProductosConStock();

        if (actuales.any((p) => p['id'] == idNuevo)) {
          setState(() {
            _cargando = false;
            _idDuplicado = true;
          });
          return;
        }
        if (actuales.length >= 300) {
          setState(() => _cargando = false);
          if (!mounted) return;
          _mostrarAlertaLimite();
          return;
        }

        final producto = Producto(
          id: idNuevo,
          nombre: nombre,
          precioVenta: precio,
          categoria: _categoriaSeleccionada,
          tipoProducto: _tipoSeleccionado,
        );
        await DBHelperAdmin.instance.insertarProducto(producto);

        final cant = double.tryParse(
                _cantidadController.text.trim().replaceAll(',', '.')) ??
            0;
        if (cant != 0) {
          await DBHelperAdmin.instance.insertarMovimiento(Movimiento(
            productoId: producto.id,
            cantidad: cant,
            fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            tipo: Movimiento.tipoAjuste,
            nota: 'Carga inicial',
          ));
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al guardar: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _eliminarProducto() async {
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),

          // Ícono
          Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.delete_outline,
                  color: Colors.red.shade600, size: 28)),
          const SizedBox(height: 12),

          const Text('Eliminar producto',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text(
            '¿Eliminar "${widget.producto!.nombre}" y todos sus movimientos?\n'
            'Esta acción no se puede deshacer.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey.shade500, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Eliminar',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ]),
        ]),
      ),
    );

    if (confirmar != true) return;
    await DBHelperAdmin.instance.eliminarProducto(widget.producto!.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _mostrarAlertaLimite() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child:
                  const Icon(Icons.lock_outline, color: Colors.red, size: 18)),
          const SizedBox(width: 12),
          const Text('Límite alcanzado', style: TextStyle(fontSize: 17)),
        ]),
        content: const Text('Has alcanzado el límite de 300 productos.\n'
            'Contacta a VaraNova para obtener más capacidad.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: Column(
        children: [
          // ── Header gradiente ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryDark, primaryMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 4,
              right: 16,
              bottom: 20,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _esEdicion ? 'Editar Producto' : 'Nuevo Producto',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _esEdicion
                            ? 'Modifica nombre, precio o stock'
                            : 'Agrega un producto al inventario',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Botón eliminar solo en edición
                if (_esEdicion)
                  GestureDetector(
                    onTap: _eliminarProducto,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(64),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),

          // ── Formulario ────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Sección identificación ────────────────────────
                    _seccionLabel('Identificación'),
                    const SizedBox(height: 10),

                    // Campo ID
                    _buildCard(
                      child: TextFormField(
                        controller: _idController,
                        enabled: !_esEdicion,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'Código / ID',
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            _esEdicion ? Icons.lock_outline : Icons.tag,
                            color: _idDuplicado ? Colors.red : primaryDark,
                            size: 20,
                          ),
                          errorText: _idDuplicado ? 'Este ID ya existe' : null,
                          helperText:
                              _esEdicion ? 'El ID no se puede modificar' : null,
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      error: _idDuplicado,
                    ),

                    const SizedBox(height: 10),

                    // Campo nombre
                    _buildCard(
                      child: TextFormField(
                        controller: _nombreController,
                        focusNode: _nombreFocus,
                        enabled: !_idDuplicado,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del producto',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.inventory_2_outlined,
                              color: primaryDark, size: 20),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                        onEditingComplete: () => _precioFocus.requestFocus(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const SizedBox(height: 24),
                    _seccionLabel('Tipo de producto (opcional)'),
                    const SizedBox(height: 10),
                    _buildCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Selector de TipoProducto
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: TipoProducto.values.map((tipo) {
                                final seleccionado = _tipoSeleccionado == tipo;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _tipoSeleccionado = tipo),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: seleccionado
                                          ? primaryDark
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: seleccionado
                                            ? primaryDark
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(tipo.emoji,
                                            style:
                                                const TextStyle(fontSize: 14)),
                                        const SizedBox(width: 5),
                                        Text(
                                          tipo.label,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: seleccionado
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            // Campo categoría libre
                            TextFormField(
                              initialValue: _categoriaSeleccionada,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Categoría (opcional)',
                                hintText:
                                    'Ej: Bebidas frías, Del día, Entradas…',
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.label_outline,
                                    color: primaryDark, size: 20),
                              ),
                              onChanged: (v) => _categoriaSeleccionada =
                                  v.trim().isEmpty ? null : v.trim(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Sección precio ────────────────────────────────
                    _seccionLabel('Precio'),
                    const SizedBox(height: 10),

                    _buildCard(
                      child: TextFormField(
                        controller: _precioController,
                        focusNode: _precioFocus,
                        enabled: !_idDuplicado,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Precio de venta',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.attach_money,
                              color: primaryDark, size: 20),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                        onEditingComplete: () => _cantidadFocus.requestFocus(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Sección stock ─────────────────────────────────
                    _seccionLabel(
                        _esEdicion ? 'Ajuste de Stock' : 'Stock Inicial'),
                    const SizedBox(height: 10),

                    _buildCard(
                      child: TextFormField(
                        controller: _cantidadController,
                        focusNode: _cantidadFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*[,.]?\d*'))
                        ],
                        decoration: InputDecoration(
                          labelText: _esEdicion
                              ? 'Ajuste (+ agregar / - quitar)'
                              : 'Cantidad inicial en stock',
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.layers_outlined,
                              color: primaryDark, size: 20),
                          helperText: _esEdicion
                              ? 'Usa negativo para reducir stock. Deja en 0 para no ajustar.'
                              : 'La cantidad inicial no puede ser cero.',
                        ),
                        validator: (v) {
                          if (_esEdicion) {
                            return null;
                          }
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa la cantidad inicial';
                          }
                          final valor =
                              double.tryParse(v.trim().replaceAll(',', '.'));
                          if (valor == null) {
                            return 'Número inválido';
                          }
                          if (valor == 0) {
                            return 'La cantidad no puede ser cero';
                          }
                          return null;
                        },
                      ),
                    ),

                    // Info edición
                    if (_esEdicion) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue.shade400, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'El ajuste se suma al stock actual. '
                                'Deja en 0 si no quieres modificar el stock.',
                                style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 11,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 36),

                    // ── Botón guardar ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_cargando || _idDuplicado)
                              ? Colors.grey.shade300
                              : primaryDark,
                          foregroundColor: Colors.white,
                          elevation: (_cargando || _idDuplicado) ? 0 : 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed:
                            (_cargando || _idDuplicado) ? null : _guardar,
                        child: _cargando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      _esEdicion
                                          ? Icons.check_circle_outline
                                          : Icons.add_circle_outline,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _esEdicion ? 'ACTUALIZAR' : 'GUARDAR',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _seccionLabel(String label) {
    return Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 0.8));
  }

  Widget _buildCard({required Widget child, bool error = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            error ? Border.all(color: Colors.red.shade300, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: child,
    );
  }
}
