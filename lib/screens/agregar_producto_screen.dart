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
  bool _productoExistente = false;
  bool get _esEdicion => widget.producto != null;
  late int _idOriginal;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _idController.text = widget.producto!.id.toString();
      _nombreController.text = widget.producto!.nombre;
      _precioController.text = widget.producto!.precioVenta.toString();
      _idOriginal = widget.producto!.id;
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

  Future<void> _buscarProductoPorId() async {
    final id = int.tryParse(_idController.text.trim());
    if (id == null) return;

    final productos = await DBHelper.instance.obtenerProductosConStock();
    if (!mounted) return;

    final encontrado =
        productos.firstWhere((p) => p['id'] == id, orElse: () => {});

    if (encontrado.isNotEmpty) {
      setState(() => _productoExistente = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Ese ID ya está en uso. Elimínalo primero si deseas reutilizarlo.'),
          backgroundColor: Colors.red,
        ),
      );
      _idController.clear();
      _nombreFocus.requestFocus();
      return;
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

    if (!_esEdicion) {
      final idNuevoTemp = int.tryParse(_idController.text);
      if (idNuevoTemp != null) {
        final actuales = await DBHelper.instance.obtenerProductosConStock();
        final idOcupado = actuales.any((p) => p['id'] == idNuevoTemp);
        if (idOcupado) {
          setState(() => _cargando = false);
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ese ID ya está en uso. Elimínalo primero.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    if (!_esEdicion) {
      final actuales = await DBHelper.instance.obtenerProductosConStock();
      if (!mounted) return;
      if (actuales.length >= 50) {
        setState(() => _cargando = false);
        _mostrarAlertaLimite();
        return;
      }
    }

    try {
      final idNuevo = int.parse(_idController.text);
      final nombre = _nombreController.text.trim();
      final precio = double.parse(_precioController.text.replaceAll(',', '.'));

      if (_esEdicion) {
        // Edición: usa el método que maneja cambio de ID
        await DBHelper.instance.editarProducto(
          idAnterior: _idOriginal,
          idNuevo: idNuevo,
          nombre: nombre,
          precioVenta: precio,
        );
        final cantTexto = _cantidadController.text.trim().replaceAll(',', '.');
        final cant = double.tryParse(cantTexto) ?? 0;
        if (cant != 0) {
          await DBHelper.instance.insertarMovimiento(Movimiento(
            productoId: idNuevo,
            cantidad: cant,
            fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            tipo: Movimiento.tipoAjuste,
            nota: 'Ajuste desde edición',
          ));
        }
      } else {
        // Nuevo producto — lógica existente sin cambios
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
            nota: _productoExistente ? 'Entrada de stock' : 'Carga inicial',
          ));
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
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
        content: const Text('Has alcanzado el límite de 50 productos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'))
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
              if (_productoExistente && !_esEdicion)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Producto existente. Solo se agregará la cantidad al stock.',
                          style: TextStyle(color: Colors.blue, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: TextFormField(
                  controller: _idController,
                  enabled: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Código / ID',
                    border: const OutlineInputBorder(),
                    filled: _esEdicion,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                  onEditingComplete: _buscarProductoPorId,
                ),
              ),
              _buildTextField(_nombreController, 'Nombre del producto',
                  focusNode: _nombreFocus, nextFocus: _precioFocus),
              _buildTextField(_precioController, 'Precio de Venta',
                  isNumber: true,
                  focusNode: _precioFocus,
                  nextFocus: _cantidadFocus),
              if (!_esEdicion)
                _buildTextField(
                  _cantidadController,
                  _productoExistente ? 'Cantidad a ingresar' : 'Stock Inicial',
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

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, FocusNode? focusNode, FocusNode? nextFocus}) {
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
