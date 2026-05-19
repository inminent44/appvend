import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NivelApp { basico, bloqueado }

class LicenseService {
  static const String _keyActivado = 'app_activada';
  static const String _keyLicencia = 'app_licencia';
  static const String _claveSecreta = 'MITHRA22';

  // ── Cambia solo esta línea entre la app Admin (BA) y Vendedor (BV) ────────
  static const String _prefijoPropio = 'BA'; // ← 'BV' en App Vendedor

  // ─── ID de dispositivo (igual que tenías) ─────────────────────────────────
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

  // ─── Fecha → token 6 chars base36 (igual que el HTML) ────────────────────

  static DateTime _tokenAFecha(String token) {
    final n = int.parse(token, radix: 36);
    final d = n % 100;
    final m = (n ~/ 100) % 100;
    final y = n ~/ 10000;
    return DateTime(y, m, d);
  }

  // ─── Reconstruye la licencia esperada ─────────────────────────────────────
  static String _crearLicencia(String codigoDispositivo, String tokFecha) {
    final input = _prefijoPropio +
        codigoDispositivo.replaceAll('-', '') +
        tokFecha +
        _claveSecreta;
    final hash = sha256.convert(utf8.encode(input)).toString().toUpperCase();
    return '$_prefijoPropio-$tokFecha-${hash.substring(0, 10)}';
  }

  // ─── Validar y activar ────────────────────────────────────────────────────
  static Future<bool> validarYActivar(String licenciaIngresada) async {
    try {
      final entrada = licenciaIngresada.trim().toUpperCase();
      final partes = entrada.split('-');
      if (partes.length != 3) return false;

      final prefijo = partes[0];
      final tokFecha = partes[1];

      if (prefijo != _prefijoPropio) return false;

      final expiracion = _tokenAFecha(tokFecha);
      if (DateTime.now().isAfter(expiracion)) return false;

      final codigoDisp = await generarCodigoDispositivo();
      final licenciaEsperada = _crearLicencia(codigoDisp, tokFecha);

      if (entrada == licenciaEsperada.toUpperCase()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyActivado, true);
        await prefs.setString(_keyLicencia, entrada);
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  // ─── Nivel actual (re-valida fecha en cada arranque) ──────────────────────
  static Future<NivelApp> obtenerNivelActual() async {
    final prefs = await SharedPreferences.getInstance();
    final activado = prefs.getBool(_keyActivado) ?? false;
    if (!activado) return NivelApp.bloqueado;

    final lic = prefs.getString(_keyLicencia) ?? '';
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

  // ─── Desactivar ───────────────────────────────────────────────────────────
  static Future<void> desactivar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActivado);
    await prefs.remove(_keyLicencia);
  }
}
