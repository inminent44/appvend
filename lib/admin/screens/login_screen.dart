import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'main_admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color primaryDark = Color(0xFF084B53);

  final _formKey = GlobalKey<FormState>();
  final _passController = TextEditingController();
  final _preguntaController = TextEditingController();
  final _respuestaController = TextEditingController();

  bool _estaRegistrado = false;
  bool _olvidoPass = false;
  bool _verPassword = false;
  bool _cargando = false;
  String _preguntaRecuperacion = '';

  @override
  void initState() {
    super.initState();
    _chequearEstado();
  }

  @override
  void dispose() {
    _passController.dispose();
    _preguntaController.dispose();
    _respuestaController.dispose();
    super.dispose();
  }

  Future<void> _chequearEstado() async {
    final registrado = await AuthService.instance.estaRegistrado();
    final pregunta = await AuthService.instance.obtenerPregunta();
    if (!mounted) return;
    setState(() {
      _estaRegistrado = registrado;
      _preguntaRecuperacion = pregunta ?? '';
    });
  }

  Future<void> _ejecutarAccion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    if (!_estaRegistrado) {
      await AuthService.instance.registrarAdminInicial(
        _passController.text,
        _preguntaController.text,
        _respuestaController.text,
      );
      if (!mounted) return;
      await _chequearEstado();
      setState(() => _cargando = false);
      return;
    }

    if (_olvidoPass) {
      final ok = await AuthService.instance
          .validarRecuperacion(_respuestaController.text);
      if (!mounted) return;
      if (ok) {
        await AuthService.instance.actualizarPassword('1234');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Contraseña temporal: 1234 — cámbiala pronto')),
        );
        setState(() => _olvidoPass = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respuesta incorrecta')),
        );
      }
      if (mounted) setState(() => _cargando = false);
      return;
    }

    final ok = await AuthService.instance.login(_passController.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainAdminScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña incorrecta')),
      );
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.shield_moon_outlined,
                    size: 80, color: primaryDark),
                const SizedBox(height: 20),
                Text(
                  !_estaRegistrado
                      ? 'Configurar Admin'
                      : (_olvidoPass ? 'Recuperar Acceso' : 'VaraNova Admin'),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primaryDark),
                ),
                const SizedBox(height: 30),
                if (!_estaRegistrado) ...[
                  _buildField(_passController, 'Crea tu contraseña',
                      isPass: true),
                  _buildField(
                      _preguntaController, '¿Pregunta de seguridad?'),
                  _buildField(
                      _respuestaController, 'Respuesta a la pregunta'),
                ] else if (_olvidoPass) ...[
                  Text(_preguntaRecuperacion,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildField(_respuestaController, 'Tu respuesta'),
                ] else ...[
                  _buildField(_passController, 'Contraseña',
                      isPass: true),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white),
                    onPressed: _cargando ? null : _ejecutarAccion,
                    child: _cargando
                        ? const CircularProgressIndicator(
                            color: Colors.white)
                        : Text(!_estaRegistrado
                            ? 'REGISTRAR ADMIN'
                            : (_olvidoPass ? 'VALIDAR' : 'ENTRAR')),
                  ),
                ),
                if (_estaRegistrado && !_olvidoPass)
                  TextButton(
                    onPressed: () =>
                        setState(() => _olvidoPass = true),
                    child: const Text('Olvidé mi contraseña'),
                  ),
                if (_olvidoPass)
                  TextButton(
                    onPressed: () =>
                        setState(() => _olvidoPass = false),
                    child: const Text('Volver al Login'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label,
      {bool isPass = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPass && !_verPassword,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: isPass
              ? IconButton(
                  icon: Icon(_verPassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _verPassword = !_verPassword),
                )
              : null,
        ),
        validator: (v) =>
            (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
      ),
    );
  }
}
