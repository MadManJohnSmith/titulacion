import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../state/notas_state.dart';
import '../widgets/notes_board.dart';

export '../state/notas_state.dart';

/// Notas por nivel de la modalidad o ruta que el alumno tiene activa.
///
/// Si no tiene ninguna oferta activa lo dice y no inventa una lista: las notas
/// se escriben sobre un nivel, y sin nivel no hay a qué pegarse.
class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.state,
    required this.notas,
    this.repo,
  });

  final AppState state;
  final NotasState notas;
  final ContentRepository? repo;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final ContentRepository _repo = widget.repo ?? ContentRepository.instance;

  Ruta? _ruta;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final id = widget.state.rutaActiva;
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    final ruta = await _repo.rutaEfectivaPorId(id);
    if (!mounted) return;
    setState(() {
      _ruta = ruta;
      _cargando = false;
    });
  }

  String get _namespace =>
      widget.state.namespaceDe(widget.state.rutaActiva ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis notas por nivel')),
      body:
          _cargando
              ? const Center(child: CircularProgressIndicator())
              : _ruta == null
                  ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        'Elige primero una modalidad: las notas se escriben '
                        'sobre los niveles de tu ruta, y sin ruta no hay niveles '
                        'a los que pegarse.',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  )
                  : NotesBoard(
                    ruta: _ruta!,
                    namespace: _namespace,
                    notas: widget.notas,
                    alGuardar: (nivel, texto) =>
                        widget.notas.guardar(_namespace, nivel, texto),
                  ),
    );
  }
}

/// Texto que explica de dónde sale el espacio de nombres de las notas.
String explicacionNamespace(String namespace) =>
    'Tus notas se guardan aparte del avance y solo se ven en "$namespace".';
