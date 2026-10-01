import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../theme.dart';

/// Qué pasa con un requisito, con la lógica de tres valores de la casa.
///
/// Nunca se colapsa "desconocido" en "cumple": si la unidad no publica el dato
/// o el alumno no lo capturó, el veredicto no puede ser favorable.
enum EstadoRequisito {
  /// La unidad publica el dato y el alumno lo cumple.
  cumple,

  /// La unidad publica el dato y el alumno no llega.
  noCumple,

  /// La unidad no publica ese dato: no se puede calcular.
  unidadNoPublica,

  /// La unidad sí publica el dato, pero el alumno no lo capturó.
  faltaDatoAlumno,
}

/// Lo que el alumno declara, tal como lo escribió.
///
/// Estos datos **no se guardan**: el promedio y los créditos están en el
/// expediente del alumno, no en la app. Solo se comparan mientras la
/// calculadora está abierta.
class DatosAlumno {
  const DatosAlumno({
    this.promedio,
    this.porcentajeCreditos,
    this.repitioMateria,
    this.servicioSocial,
    this.egelCeneval,
    this.trabajoEscrito,
    this.experienciaProfesional,
  });

  final double? promedio;
  final double? porcentajeCreditos;

  /// `true` si ha repetido alguna materia; `null` si no lo ha dicho.
  final bool? repitioMateria;
  final bool? servicioSocial;
  final bool? egelCeneval;
  final bool? trabajoEscrito;
  final bool? experienciaProfesional;

  /// Copia con los campos cambiados. Un argumento en `null` sí limpia el dato:
  /// por eso el centinela, en vez de `?? this`.
  static const Object _sinCambio = Object();

  DatosAlumno copyWith({
    Object? promedio = _sinCambio,
    Object? porcentajeCreditos = _sinCambio,
    Object? repitioMateria = _sinCambio,
    Object? servicioSocial = _sinCambio,
    Object? egelCeneval = _sinCambio,
    Object? trabajoEscrito = _sinCambio,
    Object? experienciaProfesional = _sinCambio,
  }) => DatosAlumno(
    promedio: identical(promedio, _sinCambio) ? this.promedio : promedio as double?,
    porcentajeCreditos:
        identical(porcentajeCreditos, _sinCambio)
            ? this.porcentajeCreditos
            : porcentajeCreditos as double?,
    repitioMateria:
        identical(repitioMateria, _sinCambio)
            ? this.repitioMateria
            : repitioMateria as bool?,
    servicioSocial:
        identical(servicioSocial, _sinCambio)
            ? this.servicioSocial
            : servicioSocial as bool?,
    egelCeneval:
        identical(egelCeneval, _sinCambio)
            ? this.egelCeneval
            : egelCeneval as bool?,
    trabajoEscrito:
        identical(trabajoEscrito, _sinCambio)
            ? this.trabajoEscrito
            : trabajoEscrito as bool?,
    experienciaProfesional:
        identical(experienciaProfesional, _sinCambio)
            ? this.experienciaProfesional
            : experienciaProfesional as bool?,
  );
}

/// Un requisito ya comparado: lo que publica la unidad, lo que declaró el
/// alumno y por qué quedó como quedó.
class VeredictoRequisito {
  const VeredictoRequisito({
    required this.clave,
    required this.etiqueta,
    required this.estado,
    required this.publicado,
    required this.declarado,
    required this.explicacion,
    this.evidencia = '',
  });

  /// La clave del JSON: `promedioMinimo`, `permiteRecursar`, etc.
  final String clave;

  final String etiqueta;
  final EstadoRequisito estado;

  /// Lo que publica la unidad, o `null` si no lo publica.
  final String? publicado;

  /// Lo que declaró el alumno, o `null` si no lo dijo.
  final String? declarado;

  final String explicacion;

  /// La frase de la fuente que sustenta el valor, cuando el catálogo la trae.
  final String evidencia;

  bool get esFavorable => estado == EstadoRequisito.cumple;
  bool get esDesconocido => estado != EstadoRequisito.cumple && estado != EstadoRequisito.noCumple;
}

/// Veredicto final de una modalidad.
enum EstadoModalidad {
  /// Cumple todo lo que la unidad publica y el alumno sí declaró.
  puedeAspirar,

  /// No se puede afirmar: la unidad no publica algo, o falta un dato del alumno.
  confirmarConUnidad,

  /// Hay al menos un requisito publicado que el alumno no cumple.
  noCumple,
}

/// La respuesta de la calculadora para una modalidad de la unidad del alumno.
class VeredictoModalidad {
  const VeredictoModalidad({
    required this.modalidadId,
    required this.nombre,
    required this.nombreArticulo7,
    required this.estado,
    required this.requisitos,
    required this.perfil,
    required this.avisoPerfil,
    required this.citaFuente,
    required this.rutaBaseId,
    this.textoPublicacion = '',
  });

  final String modalidadId;
  final String nombre;

  /// El nombre que le da el art. 7 del Reglamento, cuando el catálogo lo trae.
  final String nombreArticulo7;
  final EstadoModalidad estado;
  final List<VeredictoRequisito> requisitos;

  /// Lo que dice el núcleo sobre carrera, plan y cohorte ([PerfilAplicacion]).
  final Elegibilidad perfil;

  /// Aviso aparte del perfil: no baja el veredicto, pero se muestra siempre
  /// porque "cumple lo que publica la unidad" no es "cumple para tu carrera".
  final String avisoPerfil;

  /// "Fuente · fecha" de donde sale este veredicto.
  final String citaFuente;

  final String rutaBaseId;

  /// Los requisitos de ingreso en el texto de la unidad. 39 modalidades lo
  /// publican y no se mostraba: el alumno comparaba un perfil estructurado sin
  /// ver las condiciones que la unidad escribe.
  final String textoPublicacion;

  bool get puedeAspirar => estado == EstadoModalidad.puedeAspirar;

  int get incumplidos =>
      requisitos.where((r) => r.estado == EstadoRequisito.noCumple).length;

  int get sinDefinir =>
      requisitos
          .where(
            (r) =>
                r.estado == EstadoRequisito.unidadNoPublica ||
                r.estado == EstadoRequisito.faltaDatoAlumno,
          )
          .length;

  /// Texto del botón/resultado, sin decir nunca más de lo que se sabe.
  String get etiqueta {
    switch (estado) {
      case EstadoModalidad.puedeAspirar:
        return 'Cumple lo que publica tu unidad';
      case EstadoModalidad.confirmarConUnidad:
        return 'Hay $sinDefinir ${sinDefinir == 1 ? 'punto' : 'puntos'} que solo tu unidad puede confirmar';
      case EstadoModalidad.noCumple:
        return 'No cumples $incumplidos ${incumplidos == 1 ? 'requisito publicado' : 'requisitos publicados'}';
    }
  }
}

/// Compara lo que el alumno declaró contra lo que publica la unidad.
///
/// Los valores salen de `catalogo_modalidades.json` (vía `RutaOferta`), nunca
/// de una constante escrita aquí. Si la unidad no publica un requisito, el
/// veredicto lo dice; no lo rellena.
class CalculadoraElegibilidad {
  const CalculadoraElegibilidad._();

  /// Orden en que se explican los requisitos: el mismo que la tabla del
  /// catálogo, para que la app y el JSON se lean igual.
  static const List<String> orden = <String>[
    'promedioMinimo',
    'permiteRecursar',
    'porcentajeCreditosMinimo',
    'exigeServicioSocial',
    'exigeEgelCeneval',
    'exigeTrabajoEscrito',
    'exigeExperienciaProfesional',
  ];

  /// Evalúa una modalidad ya compuesta.
  static VeredictoModalidad evaluar(
    RutaOferta oferta, {
    required DatosAlumno datos,
    String? carreraId,
    String? planId,
    int? anioIngreso,
  }) {
    final m = oferta.modalidad;
    final req = oferta.requisitos;
    final etiquetas = <String, String>{
      for (final f in req.filas) f.clave: f.etiqueta,
    };
    final evidencias = <String, String>{
      for (final f in req.filas) f.clave: f.evidencia,
    };

    final veredictos = <VeredictoRequisito>[];
    for (final clave in orden) {
      veredictos.add(
        _comparar(
          clave: clave,
          etiqueta: etiquetas[clave] ?? clave,
          evidencia: evidencias[clave] ?? '',
          req: req,
          datos: datos,
        ),
      );
    }

    final perfil =
        (m?.perfil ?? const PerfilAplicacion()).comprobar(
          carreraId: carreraId,
          planId: planId,
          anioIngreso: anioIngreso,
        );

    var estado = EstadoModalidad.puedeAspirar;
    for (final v in veredictos) {
      if (v.estado == EstadoRequisito.noCumple) {
        estado = EstadoModalidad.noCumple;
        break;
      }
      if (v.estado == EstadoRequisito.unidadNoPublica ||
          v.estado == EstadoRequisito.faltaDatoAlumno) {
        estado = EstadoModalidad.confirmarConUnidad;
      }
    }
    // El perfil es un eje aparte: si la unidad publica carreras y la del
    // alumno no está, eso sí es un no.
    if (estado != EstadoModalidad.noCumple &&
        perfil.estado == EstadoElegibilidad.fueraDeRango) {
      estado = EstadoModalidad.noCumple;
    }

    return VeredictoModalidad(
      modalidadId: oferta.idModalidad,
      nombre: oferta.modalidad?.nombreMostrado ?? oferta.nombre,
      nombreArticulo7: m?.nombreArticulo7 ?? '',
      estado: estado,
      requisitos: veredictos,
      perfil: perfil,
      avisoPerfil: _avisoPerfil(m, perfil),
      textoPublicacion: m?.perfil.textoPublicacion ?? '',
      citaFuente: oferta.ruta.citaFuente,
      rutaBaseId: oferta.rutaBaseId,
    );
  }

  /// Evalúa todas las modalidades acreditadas de la unidad, de la que mejor le
  /// va al alumno a la que peor le va. Nunca devuelve una lista vacía sin
  /// explicación: si no hay nada, quien llama lo dice.
  static List<VeredictoModalidad> evaluarOferta(
    OfertaUnidad oferta, {
    required DatosAlumno datos,
    String? carreraId,
    String? planId,
    int? anioIngreso,
  }) {
    final lista = <VeredictoModalidad>[
      for (final r in oferta.rutas)
        evaluar(
          r,
          datos: datos,
          carreraId: carreraId,
          planId: planId,
          anioIngreso: anioIngreso,
        ),
    ];
    lista.sort((a, b) {
      final ea = a.estado.index, eb = b.estado.index;
      if (ea != eb) return ea.compareTo(eb);
      return a.nombre.compareTo(b.nombre);
    });
    return lista;
  }

  static String _avisoPerfil(ModalidadUnidad? m, Elegibilidad perfil) {
    if (perfil.estado == EstadoElegibilidad.fueraDeRango) {
      return perfil.explicacion.isEmpty
          ? 'Tu perfil queda fuera de lo que publica la unidad.'
          : perfil.explicacion;
    }
    if (perfil.estado == EstadoElegibilidad.coincide) {
      return 'Tu carrera, plan y cohorte están entre los que publica la unidad.';
    }
    final publica = m?.perfil.publicado ?? false;
    return publica
        ? (perfil.explicacion.isEmpty
            ? 'Falta tu carrera, tu plan o tu cohorte para comparar el perfil.'
            : perfil.explicacion)
        : 'La unidad no publica a qué carreras, planes o cohortes aplica esta '
            'modalidad: confírmalo con ella.';
  }

  static VeredictoRequisito _comparar({
    required String clave,
    required String etiqueta,
    required String evidencia,
    required Requisitos req,
    required DatosAlumno datos,
  }) {
    switch (clave) {
      case 'promedioMinimo':
        final min = req.promedioMinimo;
        if (min == null) return _sinPublicar(clave, etiqueta, evidencia);
        final p = datos.promedio;
        if (p == null) {
          return VeredictoRequisito(
            clave: clave,
            etiqueta: etiqueta,
            estado: EstadoRequisito.faltaDatoAlumno,
            publicado: min.toStringAsFixed(2),
            declarado: null,
            explicacion: 'Captura tu promedio para compararlo.',
            evidencia: evidencia,
          );
        }
        return VeredictoRequisito(
          clave: clave,
          etiqueta: etiqueta,
          estado: p >= min ? EstadoRequisito.cumple : EstadoRequisito.noCumple,
          publicado: min.toStringAsFixed(2),
          declarado: p.toStringAsFixed(2),
          explicacion:
              p >= min
                  ? 'Tu promedio llega al mínimo que publica tu unidad.'
                  : 'Tu promedio queda por debajo del mínimo publicado.',
          evidencia: evidencia,
        );

      case 'porcentajeCreditosMinimo':
        final min = req.porcentajeCreditosMinimo;
        if (min == null) return _sinPublicar(clave, etiqueta, evidencia);
        final c = datos.porcentajeCreditos;
        if (c == null) {
          return VeredictoRequisito(
            clave: clave,
            etiqueta: etiqueta,
            estado: EstadoRequisito.faltaDatoAlumno,
            publicado: '${min.toStringAsFixed(0)}%',
            declarado: null,
            explicacion: 'Captura cuántos créditos llevas para compararlo.',
            evidencia: evidencia,
          );
        }
        return VeredictoRequisito(
          clave: clave,
          etiqueta: etiqueta,
          estado: c >= min ? EstadoRequisito.cumple : EstadoRequisito.noCumple,
          publicado: '${min.toStringAsFixed(0)}%',
          declarado: '${c.toStringAsFixed(0)}%',
          explicacion:
              c >= min
                  ? 'Tus créditos llegan al mínimo publicado.'
                  : 'Te faltan créditos para el mínimo publicado.',
          evidencia: evidencia,
        );

      case 'permiteRecursar':
        final permite = req.permiteRecursar;
        if (permite == null) return _sinPublicar(clave, etiqueta, evidencia);
        final r = datos.repitioMateria;
        if (r == null) {
          return VeredictoRequisito(
            clave: clave,
            etiqueta: etiqueta,
            estado: EstadoRequisito.faltaDatoAlumno,
            publicado: permite ? 'Sí' : 'No',
            declarado: null,
            explicacion: 'Dinos si has repetido alguna materia.',
            evidencia: evidencia,
          );
        }
        if (!r) {
          return VeredictoRequisito(
            clave: clave,
            etiqueta: etiqueta,
            estado: EstadoRequisito.cumple,
            publicado: permite ? 'Sí' : 'No',
            declarado: 'No',
            explicacion: 'No has repetido materia: nada que comprobar.',
            evidencia: evidencia,
          );
        }
        return VeredictoRequisito(
          clave: clave,
          etiqueta: etiqueta,
          estado: permite ? EstadoRequisito.cumple : EstadoRequisito.noCumple,
          publicado: permite ? 'Sí' : 'No',
          declarado: 'Sí',
          explicacion:
              permite
                  ? 'Tu unidad sí admite recursar.'
                  : 'Tu unidad no admite recursar.',
          evidencia: evidencia,
        );

      case 'exigeServicioSocial':
        return _exigido(
          clave: clave,
          etiqueta: etiqueta,
          evidencia: evidencia,
          exige: req.exigeServicioSocial,
          declarado: datos.servicioSocial,
          nombre: 'servicio social',
        );

      case 'exigeEgelCeneval':
        return _exigido(
          clave: clave,
          etiqueta: etiqueta,
          evidencia: evidencia,
          exige: req.exigeEgelCeneval,
          declarado: datos.egelCeneval,
          nombre: 'EGEL-CENEVAL',
        );

      case 'exigeTrabajoEscrito':
        return _exigido(
          clave: clave,
          etiqueta: etiqueta,
          evidencia: evidencia,
          exige: req.exigeTrabajoEscrito,
          declarado: datos.trabajoEscrito,
          nombre: 'trabajo escrito',
        );

      case 'exigeExperienciaProfesional':
        return _exigido(
          clave: clave,
          etiqueta: etiqueta,
          evidencia: evidencia,
          exige: req.exigeExperienciaProfesional,
          declarado: datos.experienciaProfesional,
          nombre: 'experiencia profesional',
        );
    }
    return _sinPublicar(clave, etiqueta, evidencia);
  }

  static VeredictoRequisito _sinPublicar(
    String clave,
    String etiqueta,
    String evidencia,
  ) => VeredictoRequisito(
    clave: clave,
    etiqueta: etiqueta,
    estado: EstadoRequisito.unidadNoPublica,
    publicado: null,
    declarado: null,
    explicacion: 'Tu unidad no publica este dato: solo ella puede confirmarlo.',
    evidencia: evidencia,
  );

  /// Regla común de los requisitos "exige X": si la unidad no lo exige, el
  /// alumno cumple igual; si lo exige, depende de lo que él declare.
  static VeredictoRequisito _exigido({
    required String clave,
    required String etiqueta,
    required String evidencia,
    required bool? exige,
    required bool? declarado,
    required String nombre,
  }) {
    if (exige == null) return _sinPublicar(clave, etiqueta, evidencia);
    if (!exige) {
      return VeredictoRequisito(
        clave: clave,
        etiqueta: etiqueta,
        estado: EstadoRequisito.cumple,
        publicado: 'No',
        declarado: declarado == null ? null : (declarado ? 'Sí' : 'No'),
        explicacion: 'Tu unidad no lo exige.',
        evidencia: evidencia,
      );
    }
    if (declarado == null) {
      return VeredictoRequisito(
        clave: clave,
        etiqueta: etiqueta,
        estado: EstadoRequisito.faltaDatoAlumno,
        publicado: 'Sí',
        declarado: null,
        explicacion: 'Dinos si ya lo tienes para compararlo.',
        evidencia: evidencia,
      );
    }
    return VeredictoRequisito(
      clave: clave,
      etiqueta: etiqueta,
      estado: declarado ? EstadoRequisito.cumple : EstadoRequisito.noCumple,
      publicado: 'Sí',
      declarado: 'Sí',
      explicacion:
          declarado
              ? 'Lo tienes y tu unidad lo exige.'
              : 'Todavía no lo tienes y tu unidad lo exige.',
      evidencia: evidencia,
    );
  }
}

/// La tabla de requisitos de un veredicto, con su color y su evidencia.
class EligibilityResultView extends StatelessWidget {
  const EligibilityResultView({
    super.key,
    required this.veredicto,
    this.mostrarPerfil = true,
  });

  final VeredictoModalidad veredicto;
  final bool mostrarPerfil;

  static Color _color(EstadoRequisito e) {
    switch (e) {
      case EstadoRequisito.cumple:
        return const Color(0xFF5BD07E);
      case EstadoRequisito.noCumple:
        return const Color(0xFFE5735D);
      case EstadoRequisito.unidadNoPublica:
      case EstadoRequisito.faltaDatoAlumno:
        return LoboColors.gold;
    }
  }

  static IconData _icono(EstadoRequisito e) {
    switch (e) {
      case EstadoRequisito.cumple:
        return Icons.check_circle_outline;
      case EstadoRequisito.noCumple:
        return Icons.cancel_outlined;
      case EstadoRequisito.unidadNoPublica:
        return Icons.help_outline;
      case EstadoRequisito.faltaDatoAlumno:
        return Icons.edit_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in veredicto.requisitos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icono(r.estado), color: _color(r.estado), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.etiqueta,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        r.explicacion,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (r.publicado != null)
                        Text(
                          'publicado: ${r.publicado}'
                          '${r.declarado == null ? '' : ' · tú: ${r.declarado}'}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      if (r.evidencia.trim().isNotEmpty)
                        Text(
                          '«${r.evidencia.trim()}»',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (mostrarPerfil && veredicto.avisoPerfil.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            veredicto.avisoPerfil,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
        if (veredicto.textoPublicacion.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lo que publica la unidad como requisito de ingreso',
                  style: TextStyle(
                    color: LoboColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  veredicto.textoPublicacion,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          veredicto.citaFuente,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

/// Etiqueta de color del veredicto, reutilizada por la tarjeta de modalidad.
class EligibilityBadge extends StatelessWidget {
  const EligibilityBadge({super.key, required this.estado});

  final EstadoModalidad estado;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (estado) {
      EstadoModalidad.puedeAspirar => (
        const Color(0xFF5BD07E),
        Icons.check_circle,
      ),
      EstadoModalidad.confirmarConUnidad => (LoboColors.gold, Icons.help),
      EstadoModalidad.noCumple => (
        const Color(0xFFE5735D),
        Icons.cancel,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            switch (estado) {
              EstadoModalidad.puedeAspirar => 'Cumple lo publicado',
              EstadoModalidad.confirmarConUnidad => 'Por confirmar',
              EstadoModalidad.noCumple => 'No cumple',
            },
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
