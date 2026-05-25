import 'package:flutter/material.dart';
import 'services/license_service.dart';
import 'services/db_helper.dart';
import 'screens/activacion_screen.dart';
import 'screens/vendedor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.instance.database;

  final nivel = await LicenseService.obtenerNivelActual();

  runApp(MyApp(nivelInicial: nivel));
}

class MyApp extends StatefulWidget {
  final NivelApp nivelInicial;

  const MyApp({super.key, required this.nivelInicial});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late NivelApp _nivel;

  @override
  void initState() {
    super.initState();
    _nivel = widget.nivelInicial;
  }

  void _onActivada() {
    setState(() => _nivel = NivelApp.basico);
  }

  Widget _getHomeScreen() {
    if (_nivel == NivelApp.bloqueado) {
      return ActivacionScreen(onActivada: _onActivada);
    }
    return const VendedorScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaraNova Vendedor',
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