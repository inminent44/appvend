import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  static const String _keyUsuario = 'sesion_usuario';
  static const String _keyPassword = 'admin_password';
  static const String _keyPregunta = 'recup_pregunta';
  static const String _keyRespuesta = 'recup_respuesta';

  bool _sesionActiva = false;
  bool get sesionActiva => _sesionActiva;
  bool _esGestorV = false;
  bool get esGestorV => _esGestorV;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<bool> verificarSesion() async {
  final prefs = await SharedPreferences.getInstance();
  final usuario = prefs.getString(_keyUsuario);
  _sesionActiva = usuario != null;
  _esGestorV = usuario == 'gestorv';
  return _sesionActiva;
}

  /// Login simplificado — la app Admin solo tiene UN admin.
  Future<bool> login(String password) async {
    // Superusuario de emergencia
    if (password == 'Gandalf*123') {
      _sesionActiva = true;
      _esGestorV = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUsuario, 'gestorv');
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final hashGuardado = prefs.getString(_keyPassword);
    if (hashGuardado == null) return false;

    if (_hashPassword(password) == hashGuardado) {
      _sesionActiva = true;
      await prefs.setString(_keyUsuario, 'admin');
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _sesionActiva = false;
    _esGestorV = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsuario);
  }

  Future<bool> estaRegistrado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPassword) != null;
  }

  Future<void> registrarAdminInicial(
      String password, String pregunta, String respuesta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPassword, _hashPassword(password));
    await prefs.setString(_keyPregunta, pregunta);
    await prefs.setString(
        _keyRespuesta, _hashPassword(respuesta.toLowerCase().trim()));
  }

  Future<String?> obtenerPregunta() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPregunta);
  }

  Future<bool> validarRecuperacion(String respuesta) async {
    final prefs = await SharedPreferences.getInstance();
    final resGuardada = prefs.getString(_keyRespuesta);
    return resGuardada == _hashPassword(respuesta.toLowerCase().trim());
  }

  Future<void> actualizarPassword(String nuevaPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPassword, _hashPassword(nuevaPassword));
  }
}
