import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(LoboApp(state: AppState(prefs)));
}

class LoboApp extends StatelessWidget {
  const LoboApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoboApp',
      debugShowCheckedModeBanner: false,
      theme: buildLoboTheme(),
      home: _Root(state: state),
    );
  }
}

/// Decide por dónde entra: si el alumno ya se registró, va directo a su casa;
/// si no, pasa por bienvenida y registro.
///
/// Escucha a [AppState] porque el registro ocurre en otra pantalla: sin
/// escucharlo, la app se quedaría en bienvenida después de registrarse.
class _Root extends StatefulWidget {
  const _Root({required this.state});

  final AppState state;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onCambio);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onCambio);
    super.dispose();
  }

  void _onCambio() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.estaRegistrado) {
      return HomeScreen(state: state);
    }
    return WelcomeScreen(
      onContinuar: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RegisterScreen(state: state)),
      ),
    );
  }
}
