import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos_caja/app_theme.dart';
import '../models/producto.dart';
import '../models/movimiento.dart';
import '../../../services/db_helper_admin.dart';

class AgregarProductoScreen extends StatefulWidget {
  final Producto? producto;
  const AgregarProductoScreen({super.key, this.producto});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  final _cantidadController = TextEditingController();

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
    if (!_esEdicion) _idController.removeListener(_buscarProductoPorId);
    _idController.dispose();
    _nombreController.dispose();
    _precioController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _buscarProductoPorId() async {
    final id = int.tryParse(_idController.text.trim());
    if (id == null) {
      if (_idDuplicado) setState(() => _idDuplicado = false);
      return;
    }
    final existe = await DBHelperAdmin.instance.existeProducto(id);
    if (mounted && existe != _idDuplicado) {
      setState(() => _idDuplicado = existe);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _idDuplicado) return;
    setState(() => _cargando = true);

    try {
      final nombre = _nombreController.text.trim();
      final precio = double.parse(_precioController.text.replaceAll(',', '.'));
      final cantidad = double.tryParse(_cantidadController.text.trim().replaceAll(',', '.')) ?? 0;

      if (_esEdicion) {
        await DBHelperAdmin.instance.editarProducto(
            id: widget.producto!.id, nombre: nombre, precioVenta: precio);
        if (cantidad != 0) {
          await _registrarMovimiento(widget.producto!.id, cantidad, 'Ajuste desde edición');
        }
      } else {
        final idNuevo = int.parse(_idController.text);
        final producto = Producto(id: idNuevo, nombre: nombre, precioVenta: precio);
        await DBHelperAdmin.instance.insertarProducto(producto);
        if (cantidad != 0) {
          await _registrarMovimiento(idNuevo, cantidad, 'Carga inicial');
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _registrarMovimiento(int productoId, double cantidad, String nota) {
     return DBHelperAdmin.instance.insertarMovimiento(Movimiento(
        productoId: productoId,
        cantidad: cantidad,
        fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        tipo: Movimiento.tipoAjuste,
        nota: nota,
      ));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar Producto' : 'Nuevo Producto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionCard(
                'Información Básica', 
                [
                  _buildIdField(),
                  const SizedBox(height: 16),
                  _buildTextField(_nombreController, 'Nombre del producto'),
                ]
              ),
              _buildSectionCard(
                'Precios y Stock', 
                [
                  _buildTextField(_precioController, 'Precio de Venta', isNumber: true),
                  const SizedBox(height: 16),
                  _buildStockField(),
                ]
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _cargando ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt_outlined),
                label: Text(_esEdicion ? 'ACTUALIZAR' : 'GUARDAR'),
                onPressed: _cargando || _idDuplicado ? null : _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primary)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildIdField() {
    return TextFormField(
      controller: _idController,
      enabled: !_esEdicion,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Código / ID',
        filled: _esEdicion || _idDuplicado,
        fillColor: _idDuplicado ? Colors.red.withOpacity(0.1) : (_esEdicion ? Colors.grey.shade200 : null),
        errorText: _idDuplicado ? 'Este ID ya existe' : null,
        helperText: _esEdicion ? 'El ID no se puede modificar' : null,
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*'))] : [],
      decoration: InputDecoration(labelText: label),
      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
    );
  }
  
  Widget _buildStockField() {
    return TextFormField(
      controller: _cantidadController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[-]?\d*[,.]?\d*'))],
      decoration: InputDecoration(
        labelText: _esEdicion ? 'Ajuste de stock (+/-)' : 'Stock Inicial',
        helperText: _esEdicion ? 'Positivo para agregar, negativo para quitar' : null,
      ),
    );
  }
}
