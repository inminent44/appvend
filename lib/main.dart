import 'package:flutter/material.dart';
import 'services/license_service.dart';
import 'services/auth_service.dart';
import 'services/db_helper.dart';
import 'screens/activacion_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.instance.database;

  final nivel = await LicenseService.obtenerNivelActual();
  final sesionActiva = await AuthService.instance.verificarSesion();

  runApp(AdminApp(nivelInicial: nivel, sesionActiva: sesionActiva));
}

class AdminApp extends StatefulWidget {
  final NivelApp nivelInicial;
  final bool sesionActiva;

  const AdminApp({
    super.key,
    required this.nivelInicial,
    required this.sesionActiva,
  });

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late NivelApp _nivel;

  @override
  void initState() {
    super.initState();
    _nivel = widget.nivelInicial;
  }

  void _onActivada() => setState(() => _nivel = NivelApp.basico);

  Widget _getHome() {
    if (_nivel == NivelApp.bloqueado) {
      return ActivacionScreen(onActivada: _onActivada);
    }
    if (widget.sesionActiva) return const MainAdminScreen();
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaraNova Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF084B53)),
      ),
      home: _getHome(),
    );
  }
}
