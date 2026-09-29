import 'package:flutter/material.dart';

import '../theme.dart';
import 'eligibility_result.dart';

/// Tarjeta de una modalidad con su veredicto de elegibilidad.
///
/// Muestra el nombre oficial de la unidad, el nombre del art. 7 cuando el
/// catálogo lo trae, el veredicto de la calculadora y la cita de la fuente.
/// Toca para desplegar el detalle requisito por requisito.
class ModalityCard extends StatelessWidget {
  const ModalityCard({
    super.key,
    required this.veredicto,
    this.inicial = false,
    this.abierta = false,
    this.onTap,
  });

  final VeredictoModalidad veredicto;

  /// Marca la modalidad que el alumno tiene activa ahora mismo.
  final bool inicial;

  /// Si el detalle viene desplegado.
  final bool abierta;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = veredicto;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      v.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (inicial)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: LoboColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'tu modalidad',
                        style: TextStyle(
                          color: LoboColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (v.nombreArticulo7.isNotEmpty &&
                  v.nombreArticulo7 != v.nombre) ...[
                const SizedBox(height: 2),
                Text(
                  'Reglamento General de Titulación, art. 7: ${v.nombreArticulo7}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              EligibilityBadge(estado: v.estado),
              const SizedBox(height: 4),
              Text(
                v.etiqueta,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (abierta) ...[
                const Divider(height: 24, color: Colors.white12),
                EligibilityResultView(veredicto: v),
              ],
              const SizedBox(height: 8),
              Text(
                v.citaFuente,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
