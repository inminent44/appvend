import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _passwordKey = 'admin_password';
  static const String _loggedInKey = 'is_logged_in';

  // Contraseña por defecto, cámbiala por una más segura
  static const String _defaultPassword = '1234';

  // --- Lógica de Superusuario (GestorV) ---

  // Flag para saber si la sesión actual es de superusuario
  static bool _isGestorV = false;

  /// Devuelve true si el usuario logueado es el superusuario GestorV.
  static bool get esGestorV => _isGestorV;

  // Contraseña secreta para acceder como superusuario. No se guarda ni se cambia.
  static const String _gestorVPassword = 'Gandalf*123';

  // ----------------------------------------

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_passwordKey) == null) {
      await prefs.setString(_passwordKey, _defaultPassword);
    }
  }

  static Future<bool> login(String password) async {
    // Primero, verificar si la contraseña es la del superusuario
    if (password == _gestorVPassword) {
      _isGestorV = true; // Marcar la sesión como superusuario
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInKey, true);
      return true;
    }

    // Si no, es un login normal. Resetear el flag de superusuario.
    _isGestorV = false;

    final prefs = await SharedPreferences.getInstance();
    final storedPassword = prefs.getString(_passwordKey) ?? _defaultPassword;
    if (password == storedPassword) {
      await prefs.setBool(_loggedInKey, true);
      return true;
    }

    return false;
  }

  static Future<void> logout() async {
    _isGestorV = false; // Limpiar el flag de superusuario al salir
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  static Future<void> setPassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey, newPassword);
  }
}
