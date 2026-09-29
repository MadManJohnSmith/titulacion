import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'contacts_screen.dart';
import 'directory_screen.dart';
import 'menu_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'route_selection_screen.dart';

/// Pantalla principal: muestra el progreso y deja entrar a las rutas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = ContentRepository.instance;
  List<Ruta> _rutas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final rutas = await _repo.rutas();
    if (!mounted) return;
    setState(() {
      _rutas = rutas;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final alumno = state.alumno;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [LoboColors.navy, LoboColors.steelBlue],
                ),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: -40,
            child: Opacity(
              opacity: 0.12,
              child: AssetImageSafe(
                'assets/images/lobo_deportivo.svg',
                height: 220,
              ),
            ),
          ),
          SafeArea(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _saludo(alumno?.nombre),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (alumno != null)
                                  Text(
                                    alumno.matricula.isEmpty
                                        ? 'Sesión de invitado'
                                        : 'Matrícula ${alumno.matricula}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Menú',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MenuScreen(state: state),
                              ),
                            ),
                            icon: const Icon(Icons.menu, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Mi perfil',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(state: state),
                              ),
                            ),
                            icon: const CircleAvatar(
                              radius: 18,
                              backgroundColor: LoboColors.gold,
                              child: Icon(Icons.person, color: LoboColors.deepBlue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Elige tu ruta',
                        style: loboDisplay.copyWith(
                          fontSize: 19,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tu camino hacia el título comienza ahora.',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      ..._rutas.map((r) => _buildRutaCard(context, r)),
                      const SizedBox(height: 20),
                      _buildFooter(context),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _saludo(String? nombre) {
    if (nombre == null || nombre.isEmpty) return '¡Hola, viajero!';
    final primero = nombre.split(' ').first;
    return '¡Hola, $primero!';
  }

  Widget _buildRutaCard(BuildContext context, Ruta ruta) {
    final state = widget.state;
    final total = ruta.nivelesJugables.length;
    final progreso = state.progresoDe(ruta.id, total);
    final siguiente = state.siguienteNivel(ruta.id, total);
    final nivelActual = ruta.nivelesJugables
        .where((n) => n.numero == siguiente)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await state.elegirRuta(ruta.id);
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RouteSelectionScreen(
                  ruta: ruta,
                  state: state,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AssetImageSafe(ruta.mascotaInicio, height: 64, fallbackIcon: Icons.pets),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ruta.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progreso > 0
                            ? (nivelActual == null
                                ? '¡Ruta completada! 🎉'
                                : 'Siguiente: ${nivelActual.titulo}')
                            : '${ruta.nivelesJugables.length} niveles por superar',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progreso,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(LoboColors.gold),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContactsScreen(state: widget.state),
              ),
            ),
            icon: const Icon(Icons.support_agent, size: 18),
            label: const Text('Contactos'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DirectoryScreen()),
            ),
            icon: const Icon(Icons.badge_outlined, size: 18),
            label: const Text('Directorio'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              final rutaActiva = widget.state.rutaActiva;
              if (rutaActiva == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Primero elige una ruta para ver su mapa')),
                );
                return;
              }
              final ruta = await _repo.rutaPorId(rutaActiva);
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MapScreen(ruta: ruta, state: widget.state),
                ),
              );
            },
            icon: const Icon(Icons.map, size: 18),
            label: const Text('Mapa'),
          ),
        ),
      ],
    );
  }
}
