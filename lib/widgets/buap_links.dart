import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// Un enlace que la app abre fuera, en el navegador del teléfono.
///
/// Regla de la casa: un enlace sin URL de fuente y fecha de consulta no se abre.
/// Por eso [puedeAbrirse] es una propiedad, no una decisión de la pantalla: si
/// alguien mete una URL sin comprobarla, el botón ni aparece.
class EnlaceOficial {
  const EnlaceOficial({
    required this.clave,
    required this.titulo,
    required this.queAbre,
    required this.url,
    required this.fuente,
    required this.consultadoEn,
    this.icono = Icons.open_in_new,
    this.pendiente = false,
    this.motivoPendiente = '',
  });

  /// Id estable para pruebas y para agregar entradas nuevas sin romper nada.
  final String clave;

  final String titulo;

  /// Qué encuentra el alumno al abrirlo. Sin esto el enlace es un adorno.
  final String queAbre;

  final String url;

  /// La publicación oficial de la que sale la URL.
  final String fuente;

  /// Fecha en que se comprobó que la URL existe, `YYYY-MM-DD`.
  final String consultadoEn;

  final IconData icono;

  /// Entrada conocida pero todavía sin comprobar: se muestra, no se abre.
  final bool pendiente;

  /// Por qué sigue pendiente, para no dejar un hueco mudo.
  final String motivoPendiente;

  /// Solo abre si hay HTTPS, fuente y fecha. Sin excepción.
  bool get verificado =>
      !pendiente &&
      url.startsWith('https://') &&
      fuente.trim().isNotEmpty &&
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(consultadoEn.trim());

  bool get puedeAbrirse => verificado;

  /// "Fuente · fecha", como el resto de la app cita sus datos.
  String get cita => 'Fuente: $fuente · consultado el $consultadoEn';
}

/// Los enlaces profundos que el encargo pidió abrir.
///
/// Cada entrada trae su fuente y la fecha en que se comprobó, y ninguna entra
/// sin las dos. El orden va de lo más general a lo más específico.
const List<EnlaceOficial> enlacesTitulacionBUAP = <EnlaceOficial>[
  EnlaceOficial(
    clave: 'dae-titulacion',
    titulo: 'Portal de Titulación de la DAE',
    queAbre:
        'El sitio de la Dirección de Administración Escolar donde se publican '
        'los requisitos, el trámite completo de titulación y las preguntas '
        'frecuentes.',
    url: 'https://titulacion.buap.mx/',
    fuente: 'https://titulacion.buap.mx/',
    consultadoEn: '2026-09-29',
    icono: Icons.account_balance,
  ),
  EnlaceOficial(
    clave: 'calendario-titulacion',
    titulo: 'Calendario de titulación BUAP 2026',
    queAbre:
        'Los calendarios institucionales de la BUAP para 2026, donde salen las '
        'fechas de exámenes, juntas y actas.',
    url:
        'https://titulacion.buap.mx/content/calendarios-institucionales-buap-2026',
    fuente:
        'https://titulacion.buap.mx/content/calendarios-institucionales-buap-2026',
    consultadoEn: '2026-09-29',
    icono: Icons.calendar_month,
  ),
  // Un tercer enlace (el "RVO" del encargo) quedó descartado: no existe ningún
  // sistema de la BUAP verificable con ese nombre (búsqueda del 2026-09-29 en
  // el sitio de la DAE, en DNS y en la web, sin resultados). No entra un
  // enlace sin fuente. Lo que sí hace falta —consultar lo que la DAE exige— lo
  // cubre el portal de arriba.
];

/// Busca un enlace por su clave. `null` si no existe.
EnlaceOficial? enlacePorClave(List<EnlaceOficial> enlaces, String clave) {
  for (final e in enlaces) {
    if (e.clave == clave) return e;
  }
  return null;
}

/// Una fila de enlace: título, qué abre y la cita de la fuente.
///
/// Si al enlace le falta la fuente o la fecha, se dibuja igual pero con candado
/// y sin abrir: la guarda es visual, no una excepción en tiempo de ejecución.
class EnlaceOficialTile extends StatelessWidget {
  const EnlaceOficialTile({super.key, required this.enlace});

  final EnlaceOficial enlace;

  @override
  Widget build(BuildContext context) {
    final abierto = enlace.puedeAbrirse;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            abierto
                ? () => abrirUrl(context, enlace.url)
                : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                abierto ? enlace.icono : Icons.lock_outline,
                color: abierto ? LoboColors.gold : Colors.white38,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enlace.titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: abierto ? Colors.white : Colors.white54,
                        decoration:
                            abierto ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      abierto
                          ? enlace.queAbre
                          : (enlace.motivoPendiente.isEmpty
                              ? enlace.queAbre
                              : enlace.motivoPendiente),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (abierto) ...[
                      const SizedBox(height: 6),
                      Text(
                        enlace.cita,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enlace.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (abierto)
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La sección completa de enlaces profundos, lista para incrustar.
class EnlacesTitulacion extends StatelessWidget {
  const EnlacesTitulacion({
    super.key,
    this.titulo = 'Enlaces para tu trámite fuera de la app',
    this.enlaces = enlacesTitulacionBUAP,
  });

  final String titulo;
  final List<EnlaceOficial> enlaces;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        for (final e in enlaces) EnlaceOficialTile(enlace: e),
      ],
    );
  }
}
