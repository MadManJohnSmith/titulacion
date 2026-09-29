import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/notes_screen.dart';
import '../theme.dart';

/// Un mosaico de niveles con su nota al lado.
///
/// Escucha a [NotasState] con [ListenableBuilder] porque las notas se guardan
/// fuera de [AppState]: sin escucharla, la pantalla no se repinta al guardar.
class NotesBoard extends StatelessWidget {
  const NotesBoard({
    super.key,
    required this.ruta,
    required this.namespace,
    required this.notas,
    required this.alGuardar,
  });

  final Ruta ruta;

  /// El espacio de nombres donde caen estas notas (modalidad o ruta).
  final String namespace;

  final NotasState notas;
  final Future<void> Function(int nivel, String texto) alGuardar;

  @override
  Widget build(BuildContext context) {
    final niveles = ruta.nivelesJugables;
    return ListenableBuilder(
      listenable: notas,
      builder: (context, _) {
        final conNota =
            niveles.where((n) => notas.textoDe(namespace, n.numero).isNotEmpty).length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              ruta.nombre,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              conNota == 0
                  ? 'Todavía no has escrito nada en estos niveles.'
                  : '$conNota de ${niveles.length} niveles con nota.',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              explicacionNamespace(namespace),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const Divider(height: 24, color: Colors.white12),
            for (final n in niveles)
              _LevelNoteTile(
                nivel: n,
                texto: notas.textoDe(namespace, n.numero),
                alGuardar: alGuardar,
              ),
            if (ruta.citaFuente.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                ruta.citaFuente,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LevelNoteTile extends StatelessWidget {
  const _LevelNoteTile({
    required this.nivel,
    required this.texto,
    required this.alGuardar,
  });

  final Nivel nivel;
  final String texto;
  final Future<void> Function(int nivel, String texto) alGuardar;

  @override
  Widget build(BuildContext context) {
    final tiene = texto.isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              tiene ? LoboColors.gold.withValues(alpha: 0.25) : Colors.white10,
          child: Text(
            '${nivel.numero}',
            style: TextStyle(
              color: tiene ? LoboColors.gold : Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          nivel.titulo,
          style: const TextStyle(fontSize: 15),
        ),
        subtitle:
            tiene
                ? Text(
                  texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                )
                : const Text(
                  'Sin nota',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
        trailing: const Icon(Icons.edit_note, color: Colors.white38),
        onTap: () => _editar(context),
      ),
    );
  }

  Future<void> _editar(BuildContext context) async {
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => _NotaDialog(nivel: nivel, inicial: texto),
    );
    if (resultado == null) return;
    await alGuardar(nivel.numero, resultado);
  }
}

/// El diálogo de la nota.
///
/// Es un `StatefulWidget` a propósito: el `TextEditingController` lo crea y
/// lo destruye el propio diálogo. Si quien lo abre lo destruyera al volver, el
/// `EditableText` que todavía está cerrándose se quedaría sin controlador y
/// Flutter revienta el test con "attached: is not true".
class _NotaDialog extends StatefulWidget {
  const _NotaDialog({required this.nivel, required this.inicial});

  final Nivel nivel;
  final String inicial;

  @override
  State<_NotaDialog> createState() => _NotaDialogState();
}

class _NotaDialogState extends State<_NotaDialog> {
  late final TextEditingController _control =
      TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nivel ${widget.nivel.numero}: ${widget.nivel.titulo}'),
      content: TextField(
        controller: _control,
        autofocus: true,
        maxLines: 6,
        minLines: 3,
        decoration: const InputDecoration(
          hintText: 'Ej.: la cita en la DAE es el 14 de noviembre',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Borrar nota'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _control.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
