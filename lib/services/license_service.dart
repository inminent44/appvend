import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Nivel de activación ──────────────────────────────────────────────────────
enum NivelApp { basico, bloqueado }

// ─── Modo de la app según la licencia activada ────────────────────────────────
enum ModoApp { admin, cajero, desconocido }

class LicenseService {
  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const String _keyActivado  = 'app_activada';
  static const String _keyLicencia  = 'app_licencia';
  static const String _keyModo      = 'app_modo';   // 'admin' | 'cajero'

  // ── Constantes de firma ────────────────────────────────────────────────────
  static const String _claveSecreta = 'MITHRA22';
  static const String _prefijoAdmin = 'BA';
  static const String _prefijoCajero = 'BV';

  // ─── ID de dispositivo ────────────────────────────────────────────────────
  static Future<String> obtenerIdDispositivo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      final serial = info.serialNumber;
      if (serial.isNotEmpty && serial != 'unknown') return serial;
      return '${info.brand}-${info.model}-${info.hardware}';
    }
    return 'unknown-device';
  }

  // ─── Código visible para el cliente (XXXX-XXXX-XXXX) ─────────────────────
  static Future<String> generarCodigoDispositivo() async {
    final id = await obtenerIdDispositivo();
    final hash = sha256.convert(utf8.encode(id)).toString().toUpperCase();
    return '${hash.substring(0, 4)}-'
        '${hash.substring(4, 8)}-'
        '${hash.substring(8, 12)}';
  }

  // ─── Token de fecha → DateTime ────────────────────────────────────────────
  static DateTime _tokenAFecha(String token) {
    final n = int.parse(token, radix: 36);
    final d = n % 100;
    final m = (n ~/ 100) % 100;
    final y = n ~/ 10000;
    return DateTime(y, m, d);
  }

  // ─── Reconstruye la licencia esperada para un prefijo dado ───────────────
  static String _crearLicencia(
      String prefijo, String codigoDispositivo, String tokFecha) {
    final input =
        prefijo + codigoDispositivo.replaceAll('-', '') + tokFecha + _claveSecreta;
    final hash = sha256.convert(utf8.encode(input)).toString().toUpperCase();
    return '$prefijo-$tokFecha-${hash.substring(0, 10)}';
  }

  // ─── Valida y activa — acepta BA o BV ─────────────────────────────────────
  /// Devuelve true si la licencia es válida y se activó correctamente.
  /// Internamente guarda el modo ('admin' o 'cajero') en SharedPreferences.
  static Future<bool> validarYActivar(String licenciaIngresada) async {
    try {
      final entrada = licenciaIngresada.trim().toUpperCase();
      final partes = entrada.split('-');
      if (partes.length != 3) return false;

      final prefijo   = partes[0];
      final tokFecha  = partes[1];

      // Solo aceptamos prefijos conocidos
      if (prefijo != _prefijoAdmin && prefijo != _prefijoCajero) return false;

      // Verificar fecha de expiración
      final expiracion = _tokenAFecha(tokFecha);
      if (DateTime.now().isAfter(expiracion)) return false;

      // Verificar firma contra el dispositivo actual
      final codigoDisp      = await generarCodigoDispositivo();
      final licenciaEsperada = _crearLicencia(prefijo, codigoDisp, tokFecha);

      if (entrada == licenciaEsperada.toUpperCase()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyActivado, true);
        await prefs.setString(_keyLicencia, entrada);
        await prefs.setString(
            _keyModo, prefijo == _prefijoAdmin ? 'admin' : 'cajero');
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  // ─── Nivel actual (re-valida fecha en cada arranque) ─────────────────────
  static Future<NivelApp> obtenerNivelActual() async {
    final prefs    = await SharedPreferences.getInstance();
    final activado = prefs.getBool(_keyActivado) ?? false;
    if (!activado) return NivelApp.bloqueado;

    final lic    = prefs.getString(_keyLicencia) ?? '';
    final partes = lic.split('-');
    if (partes.length != 3) return NivelApp.bloqueado;

    try {
      final expiracion = _tokenAFecha(partes[1]);
      if (DateTime.now().isAfter(expiracion)) {
        await desactivar();
        return NivelApp.bloqueado;
      }
    } catch (_) {
      return NivelApp.bloqueado;
    }

    return NivelApp.basico;
  }

  // ─── Modo guardado ────────────────────────────────────────────────────────
  /// Devuelve el modo activo sin re-validar la licencia.
  /// Llamar solo si `obtenerNivelActual()` ya devolvió `basico`.
  static Future<ModoApp> obtenerModoActual() async {
    final prefs = await SharedPreferences.getInstance();
    final modo  = prefs.getString(_keyModo);
    if (modo == 'admin')  return ModoApp.admin;
    if (modo == 'cajero') return ModoApp.cajero;
    return ModoApp.desconocido;
  }

  // ─── Desactivar ───────────────────────────────────────────────────────────
  static Future<void> desactivar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActivado);
    await prefs.remove(_keyLicencia);
    await prefs.remove(_keyModo);
  }
}