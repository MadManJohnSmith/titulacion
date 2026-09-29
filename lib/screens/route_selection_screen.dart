import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'map_screen.dart';

/// Pantalla de selección de titulación: el pergamino con la ruta elegida,
/// antes de entrar al mapa.
class RouteSelectionScreen extends StatelessWidget {
  const RouteSelectionScreen({
    super.key,
    required this.ruta,
    required this.state,
  });

  final Ruta ruta;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [LoboColors.steelBlue, LoboColors.navy],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Volver',
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: LoboColors.parchment,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                ruta.nombre.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Bungee',
                                  fontSize: 18,
                                  height: 1.2,
                                  letterSpacing: 0.5,
                                  color: LoboColors.ink,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Divider(color: LoboColors.teal, thickness: 2),
                              const SizedBox(height: 14),
                              Text(
                                ruta.descripcion,
                                textAlign: TextAlign.center,
                                style: loboCuerpo.copyWith(
                                  fontSize: 16,
                                  height: 1.55,
                                  color: LoboColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        AssetImageSafe(
                          ruta.mascotaInicio,
                          height: 170,
                          fallbackIcon: Icons.pets,
                        ),
                        const SizedBox(height: 20),
                        CloudButton(
                          label: 'Ver mapa',
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapScreen(ruta: ruta, state: state),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
