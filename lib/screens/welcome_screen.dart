import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Pantalla de bienvenida, antes de que el alumno se registre.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinuar});

  final VoidCallback onContinuar;

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
                  colors: [LoboColors.navy, LoboColors.deepBlue],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  AssetImageSafe(
                    'assets/images/isotipo.svg',
                    height: 130,
                    fallbackIcon: Icons.pets,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¡Bienvenido, futuro titulado!',
                    textAlign: TextAlign.center,
                    style: loboDisplay.copyWith(
                      fontSize: 23,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Has llegado al camino a la titulación y aquí te vamos a guiar '
                    'en cada etapa de tu proceso. Encontrarás herramientas, '
                    'recursos y orientación que te ayudarán a avanzar de forma '
                    'clara y organizada.\n\n¡Comienza tu camino hacia la obtención '
                    'de tu título profesional!',
                    textAlign: TextAlign.center,
                    style: loboCuerpo.copyWith(
                      fontSize: 17,
                      color: Colors.white70,
                      height: 1.55,
                    ),
                  ),
                  const Spacer(flex: 3),
                  Center(
                    child: CloudButton(
                      label: 'Comenzar',
                      onTap: onContinuar,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
