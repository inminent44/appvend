import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/license_service.dart';
import 'services/db_helper_admin.dart';
import 'services/db_helper_cajero.dart';
import 'screens/activacion_screen.dart';
import 'admin/screens/login_screen.dart';
import 'cajero/vendedor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);

  final nivel = await LicenseService.obtenerNivelActual();
  ModoApp modo = ModoApp.desconocido;

  if (nivel == NivelApp.basico) {
    modo = await LicenseService.obtenerModoActual();
    if (modo == ModoApp.admin) {
      await DBHelperAdmin.instance.database;
    } else if (modo == ModoApp.cajero) {
      await DBHelperCajero.instance.database;
    }
  }

  runApp(MyApp(nivelInicial: nivel, modoInicial: modo));
}

class MyApp extends StatefulWidget {
  final NivelApp nivelInicial;
  final ModoApp modoInicial;

  const MyApp({
    super.key,
    required this.nivelInicial,
    required this.modoInicial,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late NivelApp _nivel;
  late ModoApp _modo;

  @override
  void initState() {
    super.initState();
    _nivel = widget.nivelInicial;
    _modo = widget.modoInicial;
  }

  Future<void> _onActivada() async {
    final modo = await LicenseService.obtenerModoActual();
    if (modo == ModoApp.admin) {
      await DBHelperAdmin.instance.database;
    } else if (modo == ModoApp.cajero) {
      await DBHelperCajero.instance.database;
    }
    if (!mounted) return;
    setState(() {
      _nivel = NivelApp.basico;
      _modo = modo;
    });
  }

  Widget _getHomeScreen() {
    if (_nivel == NivelApp.bloqueado) {
      return ActivacionScreen(onActivada: _onActivada);
    }
    switch (_modo) {
      case ModoApp.admin:
        return const LoginScreen();
      case ModoApp.cajero:
        return const VendedorScreen();
      case ModoApp.desconocido:
        LicenseService.desactivar();
        return ActivacionScreen(onActivada: _onActivada);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaraNova',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF084B53),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF084B53),
        ),
      ),
      home: _getHomeScreen(),
    );
  }
}
