import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'contacts_screen.dart';
import 'register_screen.dart';

/// Perfil del alumno: sus datos, su facultad, su progreso y su progreso total.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final alumno = state.alumno;
    final repo = ContentRepository.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: FutureBuilder<List<Ruta>>(
        future: repo.rutas(),
        builder: (context, snapshot) {
          final rutas = snapshot.data ?? const <Ruta>[];
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
              if (rutas.isEmpty)
                const Text('Cargando rutas…', style: TextStyle(color: Colors.white70))
              else
                ...rutas.map((r) {
                  final total = r.nivelesJugables.length;
                  final p = state.progresoDe(r.id, total);
                  final hechos = state.completadosDe(r.id).length;
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
                                Text(
                                  '$hechos/$total',
                                  style: const TextStyle(
                                    color: LoboColors.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: p,
                                minHeight: 7,
                                backgroundColor: Colors.white24,
                                valueColor:
                                    const AlwaysStoppedAnimation(LoboColors.gold),
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
                        'Se borrarán tu registro y tu progreso en este dispositivo.',
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
