import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NivelApp { basico, bloqueado }

class LicenseService {
  static const String _keyActivado = 'app_activada';

  // ─── Prefijo exclusivo para la App Admin ──────────────────────────────────
  static const String _prefijoAdmin = 'BA';
  static const String _claveSecreta = 'MITHRA22';

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

  static Future<String> generarCodigoDispositivo() async {
    final id = await obtenerIdDispositivo();
    final hash = sha256.convert(utf8.encode(id)).toString().toUpperCase();
    return '${hash.substring(0, 4)}-'
        '${hash.substring(4, 8)}-'
        '${hash.substring(8, 12)}';
  }

  /// Genera la licencia esperada para este dispositivo con prefijo BA.
  static String _crearLicencia(String codigoDispositivo) {
    final input =
        _prefijoAdmin + codigoDispositivo.replaceAll('-', '') + _claveSecreta;
    final hash = sha256.convert(utf8.encode(input)).toString().toUpperCase();
    return '$_prefijoAdmin-${hash.substring(0, 12)}';
  }

  /// Valida que la licencia ingresada sea válida Y sea de tipo Admin (BA-...).
  static Future<bool> validarYActivar(String licenciaIngresada) async {
    try {
      final entrada = licenciaIngresada.trim().toUpperCase();

      // Solo acepta licencias que empiecen con BA-
      if (!entrada.startsWith('$_prefijoAdmin-')) return false;

      final codigoDisp = await generarCodigoDispositivo();
      final licenciaEsperada = _crearLicencia(codigoDisp);

      if (entrada == licenciaEsperada.toUpperCase()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyActivado, true);
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  static Future<NivelApp> obtenerNivelActual() async {
    final prefs = await SharedPreferences.getInstance();
    final activado = prefs.getBool(_keyActivado) ?? false;
    return activado ? NivelApp.basico : NivelApp.bloqueado;
  }

  static Future<void> desactivar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActivado);
  }
}
