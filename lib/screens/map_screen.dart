import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'level_detail_screen.dart';

/// Una isla del mapa. Cada una representa un nivel de la ruta.
class LevelIsland extends StatelessWidget {
  const LevelIsland({
    super.key,
    required this.nivel,
    required this.estado,
    required this.onTap,
    required this.fraccion,
  });

  final Nivel nivel;
  final LevelState estado;
  final VoidCallback onTap;

  /// Posición vertical relativa dentro del mapa, 0 = arriba, 1 = abajo.
  final double fraccion;

  @override
  Widget build(BuildContext context) {
    final bloqueado = estado == LevelState.bloqueado;
    final colorBoton = switch (estado) {
      LevelState.bloqueado => Colors.white24,
      LevelState.actual => LoboColors.gold,
      LevelState.hecho => Colors.white,
    };

    return Semantics(
      button: true,
      enabled: !bloqueado,
      label: 'Nivel ${nivel.numero}: ${nivel.titulo}'
          '${bloqueado ? ', bloqueado' : estado == LevelState.hecho ? ', completado' : ''}',
      child: GestureDetector(
        onTap: bloqueado ? null : onTap,
        child: Opacity(
          opacity: bloqueado ? 0.55 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colorBoton,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (estado == LevelState.hecho)
                      const Icon(Icons.check, color: LoboColors.deepBlue, size: 34)
                    else
                      Text(
                        '${nivel.numero}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: estado == LevelState.bloqueado
                              ? Colors.white38
                              : LoboColors.deepBlue,
                        ),
                      ),
                    if (estado == LevelState.actual)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  nivel.titulo,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: bloqueado ? Colors.white38 : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum LevelState { bloqueado, actual, hecho }

/// El mapa de la ruta: el fondo con las islas de cada nivel.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.ruta, required this.state});

  final Ruta ruta;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final niveles = ruta.nivelesJugables;
    final numeros = ruta.numerosJugables;
    final total = numeros.length;
    final siguiente = state.siguienteNivel(ruta.id, numeros);

    // Cada isla se coloca a lo largo del mapa en zigzag, como en el diseño.
    final posiciones = <Alignment>[];
    for (var i = 0; i < total; i++) {
      final t = total == 1 ? 0.5 : i / (total - 1);
      final x = (i.isEven ? -0.62 : 0.62);
      posiciones.add(Alignment(x, -0.82 + (t * 1.64)));
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              ruta.mapa.isEmpty ? 'assets/images/maps/mapa_agua.png' : ruta.mapa,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [LoboColors.steelBlue, Color(0xFF2E7D9E)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, numeros, siguiente),
                Expanded(
                  child: Stack(
                    children: [
                      for (var i = 0; i < total; i++)
                        Align(
                          alignment: posiciones[i],
                          child: LevelIsland(
                            fraccion: posiciones[i].y,
                            nivel: niveles[i],
                            estado: _estadoDe(niveles[i].numero, siguiente, numeros),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LevelDetailScreen(
                                  ruta: ruta,
                                  nivel: niveles[i],
                                  state: state,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LevelState _estadoDe(int numero, int siguiente, List<int> numeros) {
    if (state.estaCompletado(ruta.id, numero)) return LevelState.hecho;
    if (numero == siguiente) return LevelState.actual;
    if (state.nivelDesbloqueado(ruta.id, numero, numeros)) {
      return LevelState.actual;
    }
    return LevelState.bloqueado;
  }

  Widget _buildHeader(BuildContext context, List<int> numeros, int siguiente) {
    final progreso = state.progresoDe(ruta.id, numeros);
    final nivelActual = ruta.nivelesJugables
        .where((n) => n.numero == siguiente)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            LoboColors.navy.withValues(alpha: 0.9),
            LoboColors.navy.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Volver',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ruta.nombre,
                  style: loboDisplay.copyWith(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                if (nivelActual != null)
                  Text(
                    'Siguiente: ${nivelActual.titulo}',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progreso,
                  strokeWidth: 4,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(LoboColors.gold),
                ),
                Text(
                  '${(progreso * 100).round()}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
