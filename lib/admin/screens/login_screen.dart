import 'package:flutter/material.dart';
import 'package:pos_caja/app_theme.dart';
import '../auth_service.dart';
import 'main_admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    if (!mounted) return;
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

    try {
      if (!_estaRegistrado) {
        await AuthService.instance.registrarAdminInicial(
          _passController.text,
          _preguntaController.text,
          _respuestaController.text,
        );
        if (!mounted) return;
        await _chequearEstado();
      } else if (_olvidoPass) {
        final ok = await AuthService.instance.validarRecuperacion(_respuestaController.text);
        if (!mounted) return;
        if (ok) {
          await AuthService.instance.actualizarPassword('1234');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contraseña temporal: 1234 — cámbiala pronto')),
          );
          setState(() => _olvidoPass = false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Respuesta incorrecta')),
          );
        }
      } else {
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
        }
      }
    } catch (e) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if(mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    String title = !_estaRegistrado ? 'Configurar Admin' : (_olvidoPass ? 'Recuperar Acceso' : 'VaraNova Admin');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.shield_moon_outlined, size: 80, color: AppTheme.primary),
                    const SizedBox(height: 20),
                    Text(title, style: textTheme.headlineLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 30),
                    ..._buildFormFields(),
                    const SizedBox(height: 30),
                    _buildActionButton(textTheme),
                    _buildTextButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    if (!_estaRegistrado) {
      return [
        _buildField(_passController, 'Crea tu contraseña', isPass: true),
        _buildField(_preguntaController, 'Pregunta de seguridad'),
        _buildField(_respuestaController, 'Respuesta a la pregunta'),
      ];
    } else if (_olvidoPass) {
      return [
        Text(_preguntaRecuperacion, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 15),
        _buildField(_respuestaController, 'Tu respuesta'),
      ];
    } else {
      return [
        _buildField(_passController, 'Contraseña', isPass: true),
      ];
    }
  }

  Widget _buildField(TextEditingController controller, String label, {bool isPass = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPass && !_verPassword,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: isPass
              ? IconButton(
                  icon: Icon(_verPassword ? Icons.visibility : Icons.visibility_off, color: AppTheme.textSecondary),
                  onPressed: () => setState(() => _verPassword = !_verPassword),
                )
              : null,
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
      ),
    );
  }

  Widget _buildActionButton(TextTheme textTheme) {
    String buttonText = !_estaRegistrado ? 'REGISTRAR ADMIN' : (_olvidoPass ? 'VALIDAR' : 'ENTRAR');
    return ElevatedButton(
      onPressed: _cargando ? null : _ejecutarAccion,
      child: _cargando
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
          : Text(buttonText, style: textTheme.labelLarge?.copyWith(color: Colors.white)),
    );
  }
  
  Widget _buildTextButton() {
    if (_estaRegistrado && !_olvidoPass) {
      return TextButton(
        onPressed: () => setState(() => _olvidoPass = true),
        child: const Text('Olvidé mi contraseña'),
      );
    }
    if (_olvidoPass) {
      return TextButton(
        onPressed: () => setState(() => _olvidoPass = false),
        child: const Text('Volver al Login'),
      );
    }
    return const SizedBox.shrink(); 
  }
}
