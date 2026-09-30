import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'contacts_screen.dart';
import 'register_screen.dart';

/// Una fila de "Mi progreso".
///
/// El [id] es el que guardó el avance, no el de la ruta base global: si no,
/// el perfil marcaría cero en todo lo que el alumno sí completó.
class _FilaProgreso {
  const _FilaProgreso({
    required this.id,
    required this.nombre,
    required this.numeros,
    this.nota = '',
  });

  final String id;
  final String nombre;

  /// Los números de los niveles jugables: el avance se cuenta sobre ellos, no
  /// sobre su cantidad.
  final List<int> numeros;

  /// Por qué esta modalidad no se puede jugar, cuando es el caso.
  final String nota;
}

/// Lo que el alumno ve en "Mi progreso", ya resuelto contra su unidad.
class _Progreso {
  const _Progreso({required this.filas, required this.mensaje});

  final List<_FilaProgreso> filas;
  final String mensaje;
}

/// Perfil del alumno: sus datos, su facultad, su progreso y su progreso total.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

  /// Arma las filas con las modalidades que publica la unidad del alumno.
  ///
  /// Sin unidad elegida se cae al catálogo global, que es lo único honesto que
  /// hay que mostrar: rutas de otras unidades no se atribuyen a este alumno.
  Future<_Progreso> _progreso(ContentRepository repo) async {
    final clave = state.facultadClave;
    if (clave != null && clave.isNotEmpty) {
      final oferta = await repo.ofertaDeUnidad(clave);
      return _Progreso(
        filas: [
          for (final r in oferta.rutas)
            _FilaProgreso(
              id: r.id,
              nombre: r.nombre,
              numeros: r.ruta.ruta.numerosJugables,
            ),
          for (final m in oferta.informativas)
            _FilaProgreso(
              id: '',
              nombre: m.nombre,
              numeros: const [],
              nota: 'Publicada por tu unidad, sin ruta jugable: ${m.motivo}',
            ),
        ],
        mensaje: oferta.vacia
            ? (oferta.existe
                  ? oferta.mensajeSinCatalogo
                  : 'No encontramos el catálogo de $clave en el catálogo de la BUAP.')
            : '',
      );
    }
    final rutas = await repo.rutas();
    return _Progreso(
      filas: [
        for (final r in rutas)
          _FilaProgreso(
            id: r.id,
            nombre: r.nombre,
            numeros: r.numerosJugables,
          ),
      ],
      mensaje: rutas.isEmpty
          ? 'Elige tu unidad académica para ver las modalidades que publica.'
          : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final alumno = state.alumno;
    final repo = ContentRepository.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: FutureBuilder<_Progreso>(
        future: _progreso(repo),
        builder: (context, snapshot) {
          final progreso = snapshot.data;
          final filas = progreso?.filas ?? const <_FilaProgreso>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            backgroundColor: LoboColors.gold,
                            child: Icon(Icons.person, color: LoboColors.deepBlue, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (alumno == null || alumno.nombre.isEmpty)
                                      ? 'Invitado'
                                      : alumno.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                if (alumno != null)
                                  Text(
                                    alumno.matricula.isEmpty
                                        ? 'Entraste como invitado'
                                        : 'Matrícula: ${alumno.matricula}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Facultad?>(
                        future: state.facultadClave == null
                            ? Future.value(null)
                            : repo.facultadPorClave(state.facultadClave!),
                        builder: (context, f) {
                          final facultad = f.data;
                          return OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            onPressed: () async {
                              await state.elegirFacultad('');
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RegisterScreen(state: state),
                                ),
                              );
                            },
                            icon: const Icon(Icons.school, size: 18),
                            label: Text(
                              facultad?.nombre ?? 'Elegir unidad académica',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mi progreso',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Text('Cargando rutas…', style: TextStyle(color: Colors.white70))
              else if (filas.isEmpty)
                Text(
                  progreso?.mensaje.isNotEmpty == true
                      ? progreso!.mensaje
                      : 'Tu unidad no publica modalidades todavía.',
                  style: const TextStyle(color: Colors.white70),
                )
              else
                ...filas.map((r) {
                  final p = state.progresoDe(r.id, r.numeros);
                  final hechos =
                      r.numeros.where((n) => state.estaCompletado(r.id, n)).length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (r.numeros.isNotEmpty)
                                  Text(
                                    '$hechos/${r.numeros.length}',
                                    style: const TextStyle(
                                      color: LoboColors.gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (r.numeros.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: p,
                                  minHeight: 7,
                                  backgroundColor: Colors.white24,
                                  valueColor:
                                      const AlwaysStoppedAnimation(LoboColors.gold),
                                ),
                              )
                            else
                              Text(
                                r.nota,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactsScreen(state: state),
                  ),
                ),
                icon: const Icon(Icons.support_agent, size: 18),
                label: const Text('Contactos y links'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: LoboColors.deepBlue,
                      title: const Text('¿Cerrar sesión?'),
                      content: const Text(
                        'Se borrarán de este dispositivo tu registro, tu unidad '
                        'académica, la modalidad que elegiste, tu avance y tus '
                        'notas. La app y su catálogo no se tocan.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Salir'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await state.cerrarSesion();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      ),
    );
  }
}
