import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/producto.dart';
import '../models/movimiento.dart';
import '../services/db_helper.dart';

class AgregarProductoScreen extends StatefulWidget {
  final Producto? producto;
  const AgregarProductoScreen({super.key, this.producto});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  static const Color primaryDark = Color(0xFF084B53);

  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  final _cantidadController = TextEditingController();

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
    }
  }

  @override
  void dispose() {
    if (!_esEdicion) {
      _idController.removeListener(_buscarProductoPorId);
    }
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

    final productos = await DBHelper.instance.obtenerProductosConStock();
    if (!mounted) return;

    final existe = productos.any((p) => p['id'] == id);
    if (existe != _idDuplicado) {
      setState(() => _idDuplicado = existe);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idDuplicado) return;
    setState(() => _cargando = true);

    try {
      final nombre = _nombreController.text.trim();
      final precio = double.parse(_precioController.text.replaceAll(',', '.'));

      if (_esEdicion) {
        await DBHelper.instance.editarProducto(
          id: widget.producto!.id,
          nombre: nombre,
          precioVenta: precio,
        );
        final cantTexto = _cantidadController.text.trim().replaceAll(',', '.');
        final cant = double.tryParse(cantTexto) ?? 0;
        if (cant != 0) {
          await DBHelper.instance.insertarMovimiento(Movimiento(
            productoId: widget.producto!.id,
            cantidad: cant,
            fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            tipo: Movimiento.tipoAjuste,
            nota: 'Ajuste desde edición',
          ));
        }
      } else {
        final idNuevo = int.parse(_idController.text);

        final actuales = await DBHelper.instance.obtenerProductosConStock();
        final idOcupado = actuales.any((p) => p['id'] == idNuevo);
        if (idOcupado) {
          setState(() {
            _cargando = false;
            _idDuplicado = true;
          });
          return;
        }

        if (actuales.length >= 150) {
          setState(() => _cargando = false);
          if (!mounted) return;
          _mostrarAlertaLimite();
          return;
        }

        final producto =
            Producto(id: idNuevo, nombre: nombre, precioVenta: precio);
        await DBHelper.instance.insertarProducto(producto);

        final cantTexto = _cantidadController.text.trim().replaceAll(',', '.');
        final cant = double.tryParse(cantTexto) ?? 0;
        if (cant != 0) {
          await DBHelper.instance.insertarMovimiento(Movimiento(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  Future<void> _eliminarProducto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
            '¿Eliminar "${widget.producto!.nombre}" y todos sus movimientos?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await DBHelper.instance.eliminarProducto(widget.producto!.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _mostrarAlertaLimite() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Límite de Productos'),
        content: const Text('Has alcanzado el límite de 150 productos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Producto' : 'Nuevo Producto'),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        actions: _esEdicion
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _eliminarProducto,
                )
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Campo ID ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: TextFormField(
                  controller: _idController,
                  enabled: !_esEdicion,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Código / ID',
                    border: const OutlineInputBorder(),
                    filled: _esEdicion || _idDuplicado,
                    fillColor: _idDuplicado ? Colors.red[50] : Colors.grey[200],
                    errorText: _idDuplicado
                        ? 'Este ID ya existe — bórralo o elige otro'
                        : null,
                    errorStyle: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w500),
                    enabledBorder: _idDuplicado
                        ? const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.red, width: 1.5))
                        : const OutlineInputBorder(),
                    focusedBorder: _idDuplicado
                        ? const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2))
                        : const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Color(0xFF084B53), width: 2)),
                    suffixIcon: _idDuplicado
                        ? const Icon(Icons.error_outline, color: Colors.red)
                        : _esEdicion
                            ? const Icon(Icons.lock_outline,
                                color: Colors.grey, size: 18)
                            : null,
                    helperText:
                        _esEdicion ? 'El ID no se puede modificar' : null,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              ),

              _buildTextField(
                _nombreController,
                'Nombre del producto',
                enabled: !_idDuplicado,
                focusNode: _nombreFocus,
                nextFocus: _precioFocus,
              ),

              _buildTextField(
                _precioController,
                'Precio de Venta',
                enabled: !_idDuplicado,
                isNumber: true,
                focusNode: _precioFocus,
                nextFocus: _cantidadFocus,
              ),

              if (!_esEdicion)
                _buildTextField(
                  _cantidadController,
                  'Stock Inicial',
                  enabled: !_idDuplicado,
                  isNumber: true,
                  focusNode: _cantidadFocus,
                ),

              if (_esEdicion)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: TextFormField(
                    controller: _cantidadController,
                    focusNode: _cantidadFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[-\d,.]'))
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Ajuste de stock (+ entrada / - salida)',
                      border: OutlineInputBorder(),
                      helperText:
                          'Negativo para reducir, positivo para agregar',
                    ),
                  ),
                ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryDark,
                      foregroundColor: Colors.white),
                  onPressed: (_cargando || _idDuplicado) ? null : _guardar,
                  child: _cargando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_esEdicion ? 'ACTUALIZAR' : 'GUARDAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    bool enabled = true,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: !enabled,
          fillColor: Colors.grey[100],
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
        onEditingComplete:
            nextFocus != null ? () => nextFocus.requestFocus() : null,
      ),
    );
  }
}
