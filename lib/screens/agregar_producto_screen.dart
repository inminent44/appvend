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
  // ignore: unused_field
  bool _productoExistente = false;
  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _idController.text = widget.producto!.id.toString();
      _nombreController.text = widget.producto!.nombre;
      _precioController.text = widget.producto!.precioVenta.toString();
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nombreController.dispose();
    _precioController.dispose();
    _cantidadController.dispose();
    _nombreFocus.dispose();
    _precioFocus.dispose();
    _cantidadFocus.dispose();
    super.dispose();
  }

  // Solo se usa al crear un producto nuevo
  Future<void> _buscarProductoPorId() async {
    final id = int.tryParse(_idController.text.trim());
    if (id == null) return;

    final productos = await DBHelper.instance.obtenerProductosConStock();
    if (!mounted) return;

    final encontrado =
        productos.firstWhere((p) => p['id'] == id, orElse: () => {});

    if (encontrado.isNotEmpty) {
      setState(() => _productoExistente = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Ese ID ya está en uso. Elimínalo primero si deseas reutilizarlo.'),
          backgroundColor: Colors.red,
        ),
      );
      _idController.clear();
      _nombreFocus.requestFocus();
    } else {
      setState(() {
        _productoExistente = false;
        _nombreController.clear();
        _precioController.clear();
      });
      _nombreFocus.requestFocus();
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      final nombre = _nombreController.text.trim();
      final precio = double.parse(_precioController.text.replaceAll(',', '.'));

      if (_esEdicion) {
        // ── Edición: solo nombre y precio, el ID no cambia ────────────────
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
        // ── Nuevo producto ────────────────────────────────────────────────
        final idNuevo = int.parse(_idController.text);

        // Verificar ID duplicado
        final actuales = await DBHelper.instance.obtenerProductosConStock();
        final idOcupado = actuales.any((p) => p['id'] == idNuevo);
        if (idOcupado) {
          setState(() => _cargando = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ese ID ya está en uso. Elimínalo primero.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Verificar límite
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
              // ── Campo ID: editable solo al crear, bloqueado al editar ────
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: TextFormField(
                  controller: _idController,
                  enabled: !_esEdicion, // ← bloqueado en edición
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Código / ID',
                    border: const OutlineInputBorder(),
                    filled: _esEdicion,
                    fillColor: Colors.grey[200],
                    // Candado visual cuando está bloqueado
                    suffixIcon: _esEdicion
                        ? const Icon(Icons.lock_outline,
                            color: Colors.grey, size: 18)
                        : null,
                    helperText:
                        _esEdicion ? 'El ID no se puede modificar' : null,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                  onEditingComplete: _esEdicion ? null : _buscarProductoPorId,
                ),
              ),

              _buildTextField(_nombreController, 'Nombre del producto',
                  focusNode: _nombreFocus, nextFocus: _precioFocus),

              _buildTextField(_precioController, 'Precio de Venta',
                  isNumber: true,
                  focusNode: _precioFocus,
                  nextFocus: _cantidadFocus),

              // Stock inicial solo al crear
              if (!_esEdicion)
                _buildTextField(
                  _cantidadController,
                  'Stock Inicial',
                  isNumber: true,
                  focusNode: _cantidadFocus,
                ),

              // Ajuste de stock al editar
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
                  onPressed: _cargando ? null : _guardar,
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
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
        onEditingComplete:
            nextFocus != null ? () => nextFocus.requestFocus() : null,
      ),
    );
  }
}
