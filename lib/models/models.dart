/// Modelos de datos de LoboApp.
///
/// El contenido de las rutas y niveles vive en `assets/json/routes.json` y la
/// relación unidad académica → modalidad de titulación vive en
/// `assets/json/catalogo_modalidades.json`, para que cambiar un requisito sea
/// editar un JSON, no recompilar Dart.
///
/// Regla de la casa: ningún dato entra sin su fuente y su fecha. Un campo que
/// la unidad no publica se queda en `null` y la UI dice "no publicado"; nunca
/// se rellena con un valor por omisión ni con `false`/`0` para "quedar bien".
library;

/// Convierte un valor numérico del JSON (int o double) a `double?`.
double? _doble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool? _bool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  return null;
}

/// Lee un campo de texto que en el JSON aparece a veces como cadena y a veces
/// como lista de párrafos (así viene `salvedad` en cuatro unidades). Se junta
/// con saltos de línea; nunca se descarta contenido por una diferencia de tipo.
String _texto(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is List) return v.map((e) => e?.toString() ?? '').join('\n');
  return v.toString();
}

// ---------------------------------------------------------------------------
// Trazabilidad
// ---------------------------------------------------------------------------

/// La norma que enmarca todo el catálogo: el Reglamento General de Titulación.
class NormaMarco {
  const NormaMarco({
    this.titulo = '',
    this.organo = '',
    this.fechaAprobacion = '',
    this.articuloModalidades = '',
    this.consultadoEn = '',
    this.fuente = '',
  });

  final String titulo;
  final String organo;

  /// Fecha de aprobación del reglamento (`YYYY-MM-DD`).
  final String fechaAprobacion;

  /// Artículo que reconoce las modalidades, tal como lo cita el JSON.
  final String articuloModalidades;

  /// Momento de la consulta (`YYYY-MM-DDTHH:MM:SSZ`).
  final String consultadoEn;
  final String fuente;

  bool get estaVacia => titulo.isEmpty;

  /// "Reglamento General de Titulación de la BUAP · H. Consejo Universitario
  /// 2015-11-23 · art. 7"
  String get cita =>
      '$titulo · $organo $fechaAprobacion · art. $articuloModalidades';

  factory NormaMarco.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NormaMarco();
    return NormaMarco(
      titulo: json['titulo'] as String? ?? '',
      organo: json['organo'] as String? ?? '',
      fechaAprobacion: json['fechaAprobacion'] as String? ?? '',
      articuloModalidades: json['articuloModalidades'] as String? ?? '',
      consultadoEn: json['consultadoEn'] as String? ?? '',
      fuente: json['fuente'] as String? ?? '',
    );
  }
}

/// Una publicación oficial que respalda un dato. Sin `url` no hay dato.
class Fuente {
  const Fuente({
    this.id = '',
    this.titulo = '',
    this.url = '',
    this.fechaPublicacion = '',
    this.consultadoEn = '',
  });

  final String id;
  final String titulo;
  final String url;
  final String fechaPublicacion;
  final String consultadoEn;

  /// Una fuente es acreditable solo si trae la URL que la respalda.
  bool get esAcreditable => url.trim().isNotEmpty;

  /// "Fuente · fecha" para la UI. Nunca devuelve texto vacío si hay URL.
  String get etiqueta {
    final t = titulo.isEmpty ? 'Fuente oficial' : titulo;
    final fecha = _fechaVisible;
    return fecha.isEmpty ? '$t · $url' : '$t · $fecha';
  }

  String get _fechaVisible =>
      fechaPublicacion.isNotEmpty ? fechaPublicacion : consultadoEn;

  factory Fuente.fromJson(Map<String, dynamic> json) => Fuente(
    id: json['id'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    url: json['url'] as String? ?? '',
    fechaPublicacion: json['fechaPublicacion'] as String? ?? '',
    consultadoEn: json['consultadoEn'] as String? ?? '',
  );
}

/// Una URL que se consultó y su resultado. Es el rastro que la app enseña cuando
/// una unidad no publica catálogo: "no lo encontramos" también se documenta.
class RastroConsulta {
  const RastroConsulta({
    this.url = '',
    this.consultadoEn = '',
    this.resultado = '',
    this.evidencia = '',
  });

  final String url;
  final String consultadoEn;
  final String resultado;
  final String evidencia;

  factory RastroConsulta.fromJson(Map<String, dynamic> json) => RastroConsulta(
    url: json['url'] as String? ?? '',
    consultadoEn: json['consultadoEn'] as String? ?? '',
    resultado: json['resultado'] as String? ?? '',
    evidencia: json['evidencia'] as String? ?? '',
  );
}

// ---------------------------------------------------------------------------
// Requisitos legibles por máquina
// ---------------------------------------------------------------------------

/// Un requisito con su valor, su estado y la evidencia que lo respalda.
///
/// [valor] es `null` cuando la unidad **no publica** ese dato. `null` nunca
/// significa "cumple": la UI lo muestra como "no publicado" y la evaluación
/// devuelve `cumple == null` (desconocido).
class FilaRequisito {
  const FilaRequisito({
    required this.clave,
    required this.etiqueta,
    required this.valor,
    this.evidencia = '',
  });

  /// Clave estable para las pruebas y para lógica de negocio.
  final String clave;
  final String etiqueta;
  final String valor;

  /// Cita de la fuente que sustenta el valor, si el catálogo la trae.
  final String evidencia;

  /// false cuando la unidad no publica el dato.
  bool get conocido => valor.isNotEmpty;
}

/// Requisitos de una modalidad, en forma que la app puede comparar.
///
/// Se fusionan en dos capas: `base` (lo que declara la ruta genérica, que suele
/// ser `null` porque la ruta no lo publica) y `unidad` (lo que publica la
/// unidad). La unidad manda; la base solo rellena huecos.
class Requisitos {
  const Requisitos({
    this.promedioMinimo,
    this.permiteRecursar,
    this.porcentajeCreditosMinimo,
    this.exigeServicioSocial,
    this.exigeEgelCeneval,
    this.exigeTrabajoEscrito,
    this.exigeExperienciaProfesional,
    this.nota = '',
    this.evidencia = const {},
  });

  final double? promedioMinimo;
  final bool? permiteRecursar;
  final double? porcentajeCreditosMinimo;
  final bool? exigeServicioSocial;
  final bool? exigeEgelCeneval;
  final bool? exigeTrabajoEscrito;
  final bool? exigeExperienciaProfesional;

  /// Por qué faltan datos, si la fuente lo explica.
  final String nota;

  /// `campo -> cita` con la frase de la fuente que sustenta el valor.
  final Map<String, String> evidencia;

  /// [evidencia] son las citas textuales de la fuente, que el catálogo guarda
  /// aparte de los valores en `evidenciaCalculadora`.
  factory Requisitos.fromJson(
    Map<String, dynamic>? json, {
    Map<String, dynamic>? evidencia,
  }) {
    if (json == null) return const Requisitos();
    return Requisitos(
      promedioMinimo: _doble(json['promedioMinimo']),
      permiteRecursar: _bool(json['permiteRecursar']),
      porcentajeCreditosMinimo: _doble(json['porcentajeCreditosMinimo']),
      exigeServicioSocial: _bool(json['exigeServicioSocial']),
      exigeEgelCeneval: _bool(json['exigeEgelCeneval']),
      exigeTrabajoEscrito: _bool(json['exigeTrabajoEscrito']),
      exigeExperienciaProfesional: _bool(json['exigeExperienciaProfesional']),
      nota: json['nota'] as String? ?? '',
      evidencia:
          evidencia == null
              ? const {}
              : {
                for (final e in evidencia.entries)
                  e.key: e.value?.toString() ?? '',
              },
    );
  }

  /// Une otra capa encima: los valores no nulos de [otra] ganan.
  Requisitos fusionar(Requisitos otra) => Requisitos(
    promedioMinimo: otra.promedioMinimo ?? promedioMinimo,
    permiteRecursar: otra.permiteRecursar ?? permiteRecursar,
    porcentajeCreditosMinimo:
        otra.porcentajeCreditosMinimo ?? porcentajeCreditosMinimo,
    exigeServicioSocial: otra.exigeServicioSocial ?? exigeServicioSocial,
    exigeEgelCeneval: otra.exigeEgelCeneval ?? exigeEgelCeneval,
    exigeTrabajoEscrito: otra.exigeTrabajoEscrito ?? exigeTrabajoEscrito,
    exigeExperienciaProfesional:
        otra.exigeExperienciaProfesional ?? exigeExperienciaProfesional,
    nota: otra.nota.isNotEmpty ? otra.nota : nota,
    evidencia: {...evidencia, ...otra.evidencia},
  );

  /// true cuando ningún campo trae valor: la unidad no publica requisitos.
  bool get sinDatos => filas.every((f) => !f.conocido);

  /// Las filas de la tabla de requisitos, en el orden en que se explican.
  List<FilaRequisito> get filas => [
    FilaRequisito(
      clave: 'promedioMinimo',
      etiqueta: 'Promedio general mínimo',
      valor: promedioMinimo == null ? '' : promedioMinimo!.toStringAsFixed(2),
      evidencia: evidencia['promedioMinimo'] ?? '',
    ),
    FilaRequisito(
      clave: 'permiteRecursar',
      etiqueta: 'Permite recursar',
      valor: _siNo(permiteRecursar),
      evidencia: evidencia['permiteRecursar'] ?? '',
    ),
    FilaRequisito(
      clave: 'porcentajeCreditosMinimo',
      etiqueta: 'Créditos mínimo',
      valor:
          porcentajeCreditosMinimo == null
              ? ''
              : '${porcentajeCreditosMinimo!.toStringAsFixed(0)}%',
      evidencia: evidencia['porcentajeCreditosMinimo'] ?? '',
    ),
    FilaRequisito(
      clave: 'exigeServicioSocial',
      etiqueta: 'Exige servicio social',
      valor: _siNo(exigeServicioSocial),
      evidencia: evidencia['exigeServicioSocial'] ?? '',
    ),
    FilaRequisito(
      clave: 'exigeEgelCeneval',
      etiqueta: 'Exige EGEL-CENEVAL',
      valor: _siNo(exigeEgelCeneval),
      evidencia: evidencia['exigeEgelCeneval'] ?? '',
    ),
    FilaRequisito(
      clave: 'exigeTrabajoEscrito',
      etiqueta: 'Exige trabajo escrito',
      valor: _siNo(exigeTrabajoEscrito),
      evidencia: evidencia['exigeTrabajoEscrito'] ?? '',
    ),
    FilaRequisito(
      clave: 'exigeExperienciaProfesional',
      etiqueta: 'Exige experiencia profesional',
      valor: _siNo(exigeExperienciaProfesional),
      evidencia: evidencia['exigeExperienciaProfesional'] ?? '',
    ),
  ];

  static String _siNo(bool? v) {
    if (v == null) return '';
    return v ? 'Sí' : 'No';
  }
}

/// Resultado de comparar los datos del alumno contra lo que publica la unidad.
///
/// [desconocido] nunca cuenta como aprobado: la app pide confirmar con la unidad.
enum EstadoElegibilidad {
  /// La unidad publica el dato y el alumno coincide.
  coincide,

  /// La unidad publica el dato y el alumno queda fuera del rango.
  fueraDeRango,

  /// La unidad publica el dato pero el alumno no lo registró.
  faltaDatoAlumno,

  /// La unidad no publica el dato: no se puede calcular.
  unidadNoPublica,
}

class Elegibilidad {
  const Elegibilidad(this.estado, {this.explicacion = ''});

  final EstadoElegibilidad estado;
  final String explicacion;

  bool get sePuedeConfirmar => estado != EstadoElegibilidad.coincide;

  /// Texto corto para la UI.
  String get etiqueta {
    switch (estado) {
      case EstadoElegibilidad.coincide:
        return 'Coincide con lo que publica tu unidad';
      case EstadoElegibilidad.fueraDeRango:
        return 'Tu perfil queda fuera de lo publicado';
      case EstadoElegibilidad.faltaDatoAlumno:
        return 'Registra tu carrera o tu cohorte para compararlo';
      case EstadoElegibilidad.unidadNoPublica:
        return 'La unidad no publica el perfil al que aplica: confirma con ella';
    }
  }
}

/// A qué carreras, planes y cohortes aplica una modalidad.
///
/// Todos los campos son opcionales porque casi ninguna unidad los publica; un
/// `null` significa "no lo publica", no "aplica a todos".
class PerfilAplicacion {
  const PerfilAplicacion({
    this.carreraIds,
    this.planes,
    this.cohortesDesde,
    this.cohortesHasta,
  });

  final List<String>? carreraIds;
  final List<String>? planes;
  final int? cohortesDesde;
  final int? cohortesHasta;

  /// true cuando la unidad publica al menos un criterio de aplicación.
  bool get publicado =>
      carreraIds != null || planes != null || cohortesDesde != null;

  factory PerfilAplicacion.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PerfilAplicacion();
    final cohortes = json['cohortes'];
    return PerfilAplicacion(
      carreraIds: _listaDeTextos(json['carreraIds']),
      planes: _listaDeTextos(json['planes']),
      cohortesDesde: switch (cohortes) {
        final Map<dynamic, dynamic> m =>
          m['desde'] == null ? null : int.tryParse(m['desde'].toString()),
        _ => null,
      },
      cohortesHasta: switch (cohortes) {
        final Map<dynamic, dynamic> m =>
          m['hasta'] == null ? null : int.tryParse(m['hasta'].toString()),
        _ => null,
      },
    );
  }

  /// null = la unidad no publica la lista; nunca se convierte en lista vacía
  /// porque "no lo publica" y "no aplica a nada" son cosas distintas.
  static List<String>? _listaDeTextos(dynamic v) {
    if (v is! List) return null;
    return v.map((e) => e.toString()).toList();
  }

  /// Compara lo que registró el alumno contra lo publicado.
  ///
  /// Devuelve [EstadoElegibilidad.unidadNoPublica] en cuanto un criterio no está
  /// publicado: no se puede afirmar que el alumno aplica sin ese dato.
  Elegibilidad comprobar({
    String? carreraId,
    String? planId,
    int? anioIngreso,
  }) {
    if (!publicado) {
      return const Elegibilidad(EstadoElegibilidad.unidadNoPublica);
    }
    if (carreraIds != null && carreraIds!.isNotEmpty) {
      if (carreraId == null || carreraId.isEmpty) {
        return const Elegibilidad(
          EstadoElegibilidad.faltaDatoAlumno,
          explicacion: 'La unidad publica la carrera a la que aplica.',
        );
      }
      if (!carreraIds!.contains(carreraId)) {
        return const Elegibilidad(
          EstadoElegibilidad.fueraDeRango,
          explicacion: 'Tu carrera no está entre las que publica la unidad.',
        );
      }
    }
    if (planes != null && planes!.isNotEmpty) {
      if (planId == null || planId.isEmpty) {
        return const Elegibilidad(
          EstadoElegibilidad.faltaDatoAlumno,
          explicacion:
              'La unidad publica los planes de estudio a los que aplica.',
        );
      }
      if (!planes!.contains(planId)) {
        return const Elegibilidad(
          EstadoElegibilidad.fueraDeRango,
          explicacion: 'Tu plan de estudios no está entre los publicados.',
        );
      }
    }
    if (cohortesDesde != null || cohortesHasta != null) {
      if (anioIngreso == null) {
        return const Elegibilidad(
          EstadoElegibilidad.faltaDatoAlumno,
          explicacion: 'La unidad publica el rango de cohorte al que aplica.',
        );
      }
      if (cohortesDesde != null && anioIngreso < cohortesDesde!) {
        return const Elegibilidad(
          EstadoElegibilidad.fueraDeRango,
          explicacion: 'Tu año de ingreso es anterior al rango publicado.',
        );
      }
      if (cohortesHasta != null && anioIngreso > cohortesHasta!) {
        return const Elegibilidad(
          EstadoElegibilidad.fueraDeRango,
          explicacion: 'Tu año de ingreso es posterior al rango publicado.',
        );
      }
    }
    return const Elegibilidad(EstadoElegibilidad.coincide);
  }
}

// ---------------------------------------------------------------------------
// Catálogo de modalidades por unidad
// ---------------------------------------------------------------------------

/// Una modalidad de titulación tal como la publica una unidad concreta.
///
/// `rutaId` apunta a la ruta base de `routes.json` que le da los niveles. Si
/// viene en `null`, la unidad publica la modalidad pero no hay ruta base
/// acreditada: la app la muestra como información, no como algo jugable.
class ModalidadUnidad {
  const ModalidadUnidad({
    required this.modalidadId,
    required this.unidadClave,
    required this.unidadNombre,
    this.rutaId,
    this.rutaIdMapeo = '',
    this.nombreOficial = '',
    this.nombreNormativo,
    this.nombreArticulo7,
    this.estado = '',
    this.confirmada = false,
    this.vigenteDesde = '',
    this.vigenteHasta = '',
    this.consultadoEn = '',
    this.fuente = '',
    this.fecha = '',
    this.requisitosTexto = '',
    this.requisitos = const Requisitos(),
    this.perfil = const PerfilAplicacion(),
    this.seleccionable = false,
    this.pendiente = '',
    this.fuentes = const [],
  });

  final String modalidadId;
  final String unidadClave;
  final String unidadNombre;

  /// Ruta base de `routes.json`; `null` cuando la unidad no tiene ruta acreditada.
  final String? rutaId;

  /// Cómo se decidió el mapeo (`nombreNormativo`, `sin_base`...).
  final String rutaIdMapeo;

  /// El nombre con el que la unidad la publica.
  final String nombreOficial;

  /// El nombre del art. 7, si la unidad lo declara o si el catálogo lo норма.
  final String? nombreNormativo;
  final String? nombreArticulo7;

  final String estado;
  final bool confirmada;
  final String vigenteDesde;
  final String vigenteHasta;
  final String consultadoEn;

  /// URL de la publicación que la respalda.
  final String fuente;

  /// Qué se sabe de la publicación, con su fecha.
  final String fecha;

  /// Texto íntegro de los requisitos tal como lo publica la unidad.
  final String requisitosTexto;

  final Requisitos requisitos;
  final PerfilAplicacion perfil;

  /// true solo si hay ruta base acreditada y se puede jugar.
  final bool seleccionable;

  /// Lo que falta para poder mostrarla como acreditada.
  final String pendiente;

  /// Publicaciones con su fecha, cuando el catálogo las desglosa.
  final List<Fuente> fuentes;

  /// Indica "Vigente hasta [fecha]" si el catálogo dice que dejó de estar
  /// vigente.
  bool get vencida =>
      vigenteHasta.isNotEmpty && vigenteHasta.compareTo(_hoy) < 0;

  bool get tieneFuente => fuente.trim().isNotEmpty;

  /// Rótulo para la UI: nombre de la unidad primero, норма entre paréntesis.
  String get nombreMostrado {
    final n = nombreNormativo;
    if (n == null || n.isEmpty || n == nombreOficial) return nombreOficial;
    return '$nombreOficial ($n)';
  }

  factory ModalidadUnidad.fromJson(
    Map<String, dynamic> json, {
    required String unidadClave,
    required String unidadNombre,
  }) {
    final fuentes = <Fuente>[];
    final crudas = json['fuentes'];
    if (crudas is List) {
      for (final f in crudas) {
        if (f is Map) fuentes.add(Fuente.fromJson(f.cast<String, dynamic>()));
      }
    }
    return ModalidadUnidad(
      modalidadId: json['modalidadId'] as String? ?? '',
      unidadClave: unidadClave,
      unidadNombre: unidadNombre,
      rutaId: json['rutaId'] as String?,
      rutaIdMapeo: json['rutaIdMapeo'] as String? ?? '',
      nombreOficial: json['nombreOficial'] as String? ?? '',
      nombreNormativo: json['nombreNormativo'] as String?,
      nombreArticulo7: json['nombreArticulo7'] as String?,
      estado: json['estado'] as String? ?? '',
      confirmada: json['confirmada'] as bool? ?? false,
      vigenteDesde: json['vigenteDesde'] as String? ?? '',
      vigenteHasta: json['vigenteHasta'] as String? ?? '',
      consultadoEn: json['consultadoEn'] as String? ?? '',
      fuente: json['fuente'] as String? ?? '',
      fecha: json['fecha'] as String? ?? '',
      requisitosTexto: json['requisitosTexto'] as String? ?? '',
      requisitos: Requisitos.fromJson(
        (json['requisitos'] as Map?)?.cast<String, dynamic>(),
        evidencia:
            (json['evidenciaCalculadora'] as Map?)?.cast<String, dynamic>(),
      ),
      perfil: PerfilAplicacion.fromJson(
        (json['perfilAplicacion'] as Map?)?.cast<String, dynamic>(),
      ),
      seleccionable: json['seleccionable'] as bool? ?? false,
      pendiente: json['pendiente'] as String? ?? '',
      fuentes: fuentes,
    );
  }
}

/// Fecha de corte local, solo para comparar `vigenteHasta`. El contenido real
/// trae su propia fecha en cada modalidad; esta no inventa vigencia.
final DateTime _ahora = DateTime.now();
String get _hoy =>
    '${_ahora.year.toString().padLeft(4, '0')}-'
    '${_ahora.month.toString().padLeft(2, '0')}-'
    '${_ahora.day.toString().padLeft(2, '0')}';

/// Una unidad académica con su catálogo (o con la constancia de que no lo tiene).
class UnidadCatalogo {
  const UnidadCatalogo({
    required this.clave,
    required this.nombreOficial,
    this.nombreCatalogo = '',
    this.estadoCatalogo = '',
    this.resultadoBusqueda = '',
    this.publicaCatalogo,
    this.salvedad = '',
    this.veredictoConfirmacion = '',
    this.veredictoDetalle = '',
    this.fuentes = const [],
    this.fuentesConsulta = const [],
    this.modalidades = const [],
    this.contacto = const ContactoUnidad(),
  });

  final String clave;
  final String nombreOficial;

  /// El nombre con el que la unidad titula su catálogo, si es distinto.
  final String nombreCatalogo;

  /// `publicado`, `publicacion_parcial_no_exhaustiva`,
  /// `publicacion_sin_fuente_registrada`, `unidad_no_publica_catalogo`,
  /// `no_aplica_nivel_medio_superior`.
  final String estadoCatalogo;
  final String resultadoBusqueda;
  final bool? publicaCatalogo;
  final String salvedad;
  final String veredictoConfirmacion;
  final String veredictoDetalle;

  final List<Fuente> fuentes;

  /// URLs consultadas con su resultado. Es el rastro que se muestra cuando no
  /// se encontró catálogo.
  final List<RastroConsulta> fuentesConsulta;

  final List<ModalidadUnidad> modalidades;
  final ContactoUnidad contacto;

  /// Nombre a mostrar en la UI: el del catálogo si existe, si no el oficial.
  String get nombre =>
      nombreCatalogo.isNotEmpty ? nombreCatalogo : nombreOficial;

  /// true cuando la unidad tiene alguna modalidad con ruta base acreditada.
  bool get tieneOferta =>
      modalidades.any((m) => m.seleccionable && m.rutaId != null);

  /// true cuando la unidad declaró que no publica catálogo.
  bool get noPublicaCatalogo => estadoCatalogo == 'unidad_no_publica_catalogo';

  /// Mensaje único para la pantalla cuando no hay nada que ofrecer.
  String get mensajeSinCatalogo {
    switch (estadoCatalogo) {
      case 'unidad_no_publica_catalogo':
        return 'Esta unidad no publica catálogo de modalidades de titulación. '
            'Se consultaron sus sitios oficiales el ${_fechaCorta()} sin '
            'encontrar uno; abajo queda el rastro de las URLs revisadas.';
      case 'no_aplica_nivel_medio_superior':
        return 'Esta unidad no imparte educación superior, así que no le aplica '
            'el Reglamento General de Titulación.';
      case 'publicacion_sin_fuente_registrada':
        return 'El registro de evidencia anota modalidades para esta unidad, '
            'pero sin una publicación oficial que las respalde. Por eso no se '
            'muestran como oferta acreditada.';
      default:
        return 'Esta unidad todavía no tiene modalidades con ruta acreditada en '
            'el catálogo con fecha de corte $_fechaCorta.';
    }
  }

  String _fechaCorta() {
    for (final f in fuentesConsulta) {
      if (f.consultadoEn.isNotEmpty) return f.consultadoEn.split('T').first;
    }
    return 'sin fecha registrada';
  }

  factory UnidadCatalogo.fromJson(Map<String, dynamic> json) {
    final fuentes = <Fuente>[];
    final crudas = json['fuentes'];
    if (crudas is List) {
      for (final f in crudas) {
        if (f is Map) {
          // El catálogo a veces separa `url` y `urlCompleta`; gana la completa.
          final m = f.cast<String, dynamic>();
          final u = m['url'] as String? ?? '';
          final uc = m['urlCompleta'] as String? ?? '';
          fuentes.add(Fuente.fromJson({...m, 'url': uc.isNotEmpty ? uc : u}));
        }
      }
    }
    final consulta = <RastroConsulta>[];
    final crudasC = json['fuentesConsulta'];
    if (crudasC is List) {
      for (final f in crudasC) {
        if (f is Map) {
          consulta.add(RastroConsulta.fromJson(f.cast<String, dynamic>()));
        }
      }
    }
    final clave = json['clave'] as String? ?? '';
    final nombre = json['nombreOficial'] as String? ?? '';
    final modalidades = <ModalidadUnidad>[];
    final crudasM = json['modalidades'];
    if (crudasM is List) {
      for (final m in crudasM) {
        if (m is Map) {
          modalidades.add(
            ModalidadUnidad.fromJson(
              m.cast<String, dynamic>(),
              unidadClave: clave,
              unidadNombre: nombre,
            ),
          );
        }
      }
    }
    return UnidadCatalogo(
      clave: clave,
      nombreOficial: nombre,
      nombreCatalogo: _texto(json['nombreCatalogo']),
      estadoCatalogo: _texto(json['estadoCatalogo']),
      resultadoBusqueda: _texto(json['resultadoBusqueda']),
      publicaCatalogo: _bool(json['publicaCatalogo']),
      salvedad: _texto(json['salvedad']),
      veredictoConfirmacion: _texto(json['veredictoConfirmacion']),
      veredictoDetalle: _texto(json['veredictoDetalle']),
      fuentes: fuentes,
      fuentesConsulta: consulta,
      modalidades: modalidades,
      contacto: ContactoUnidad.fromJson(
        (json['contacto'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

/// Contacto de titulación de una unidad, para el respaldo cuando no hay oferta.
class ContactoUnidad {
  const ContactoUnidad({
    this.coordinacion = '',
    this.correo = '',
    this.telefono = '',
    this.responsable = '',
    this.notas = '',
  });

  final String coordinacion;
  final String correo;
  final String telefono;
  final String responsable;
  final String notas;

  bool get tieneAlguno =>
      correo.isNotEmpty || telefono.isNotEmpty || coordinacion.isNotEmpty;

  factory ContactoUnidad.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ContactoUnidad();
    return ContactoUnidad(
      coordinacion: json['coordinacion'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      responsable: json['responsable'] as String? ?? '',
      notas: json['notas'] as String? ?? '',
    );
  }
}

/// El catálogo completo: la única fuente de la relación unidad → modalidad.
class CatalogoModalidades {
  const CatalogoModalidades({
    this.catalogoVersion = '',
    this.fechaCorte = '',
    this.generadoEn = '',
    this.norma = const NormaMarco(),
    this.estadosCatalogo = const {},
    this.unidades = const [],
    this.origen = origenEmbi,
  });

  /// Versión del catálogo; sube cuando cambia el contenido.
  final String catalogoVersion;

  /// Fecha de corte del contenido, `YYYY-MM-DD`.
  final String fechaCorte;
  final String generadoEn;
  final NormaMarco norma;

  /// `estado -> explicación`, para que la UI pueda decir qué significa.
  final Map<String, String> estadosCatalogo;

  final List<UnidadCatalogo> unidades;

  /// De dónde salió este catálogo: el asset embebido o la caché descargada.
  final String origen;

  static const String origenEmbi = 'asset embebido';
  static const String origenCache = 'caché descargada';

  UnidadCatalogo? porClave(String clave) {
    for (final u in unidades) {
      if (u.clave == clave) return u;
    }
    return null;
  }

  factory CatalogoModalidades.fromJson(
    Map<String, dynamic> json, {
    String origen = origenEmbi,
  }) {
    final estados = <String, String>{};
    final crudosE = json['estadosCatalogo'];
    if (crudosE is Map) {
      crudosE.forEach((k, v) => estados[k.toString()] = v?.toString() ?? '');
    }
    final unidades = <UnidadCatalogo>[];
    final crudas = json['unidades'];
    if (crudas is List) {
      for (final u in crudas) {
        if (u is Map) {
          unidades.add(UnidadCatalogo.fromJson(u.cast<String, dynamic>()));
        }
      }
    }
    return CatalogoModalidades(
      catalogoVersion: json['catalogoVersion'] as String? ?? '',
      fechaCorte: json['fechaCorte'] as String? ?? '',
      generadoEn: json['generadoEn'] as String? ?? '',
      norma: NormaMarco.fromJson(
        (json['normaMarco'] as Map?)?.cast<String, dynamic>(),
      ),
      estadosCatalogo: estados,
      unidades: unidades,
      origen: origen,
    );
  }
}

// ---------------------------------------------------------------------------
// Rutas
// ---------------------------------------------------------------------------

/// Lo que una unidad publica de una modalidad concreta, tal como está en
/// `routes.json → particularidadesPorUnidad`.
class ParticularidadUnidad {
  const ParticularidadUnidad({
    this.unidadClave = '',
    this.nombreOficial = '',
    this.modalidadId = '',
    this.nombreEnUnidad = '',
    this.estadoCatalogoUnidad = '',
    this.detalle = '',
    this.fuente = '',
    this.fecha = '',
    this.textoCompletoEnCatalogo = '',
  });

  final String unidadClave;
  final String nombreOficial;
  final String modalidadId;

  /// El nombre de la modalidad tal como lo escribe la unidad.
  final String nombreEnUnidad;
  final String estadoCatalogoUnidad;

  /// Resumen de lo que exige la unidad, en sus términos.
  final String detalle;
  final String fuente;
  final String fecha;

  /// Dónde está el texto íntegro de los requisitos.
  final String textoCompletoEnCatalogo;

  factory ParticularidadUnidad.fromJson(Map<String, dynamic> json) =>
      ParticularidadUnidad(
        unidadClave: json['unidadClave'] as String? ?? '',
        nombreOficial: json['nombreOficial'] as String? ?? '',
        modalidadId: json['modalidadId'] as String? ?? '',
        nombreEnUnidad: json['nombreEnUnidad'] as String? ?? '',
        estadoCatalogoUnidad: json['estadoCatalogoUnidad'] as String? ?? '',
        detalle: json['detalle'] as String? ?? '',
        fuente: json['fuente'] as String? ?? '',
        fecha: json['fecha'] as String? ?? '',
        textoCompletoEnCatalogo:
            json['textoCompletoEnCatalogo'] as String? ?? '',
      );
}

/// Una publicación de otra unidad citada dentro de una ruta.
class PublicacionRelacionada {
  const PublicacionRelacionada({
    this.unidadClave = '',
    this.nombreOficial = '',
    this.titulo = '',
    this.url = '',
    this.fecha = '',
    this.nota = '',
  });

  final String unidadClave;
  final String nombreOficial;
  final String titulo;
  final String url;
  final String fecha;
  final String nota;

  factory PublicacionRelacionada.fromJson(Map<String, dynamic> json) =>
      PublicacionRelacionada(
        unidadClave: json['unidadClave'] as String? ?? '',
        nombreOficial: json['nombreOficial'] as String? ?? '',
        titulo: json['titulo'] as String? ?? '',
        url: json['url'] as String? ?? '',
        fecha: json['fecha'] as String? ?? '',
        nota: json['nota'] as String? ?? '',
      );
}

/// Una modalidad de titulación (promedio, CENEVAL, examen profesional...).
///
/// `id` es estable: los tres ids legados (`promedio`, `ceneval`, `profesional`)
/// no se cambian nunca, porque son la clave con la que el progreso guardado en
/// el dispositivo queda amarrado a una ruta.
class Ruta {
  const Ruta({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.niveles,
    this.mascotaInicio = '',
    this.pergaminoInicio = '',
    this.mapa = '',
    this.tituloAsset = '',
    this.descripcionAsset = '',
    this.esRutaNueva = false,
    this.rutaReservada = false,
    this.alcance = '',
    this.fuenteBase = '',
    this.fechaBase = '',
    this.fechaCorte = '',
    this.fuente = '',
    this.fechaFuente = '',
    this.notaFuente = '',
    this.requisitosBase = const Requisitos(),
    this.norma = const NormaMarco(),
    this.particularidades = const [],
    this.publicacionesRelacionadas = const [],
  });

  final String id;
  final String nombre;
  final String descripcion;

  final String mascotaInicio;
  final String pergaminoInicio;

  /// Fondo del mapa de la ruta. Cada una tiene su propio mapa.
  final String mapa;

  /// Título y descriptor de la pantalla de selección, tal como los entrega el
  /// diseño. Si vienen vacíos la UI dibuja texto.
  final String tituloAsset;
  final String descripcionAsset;

  /// true para las rutas cuya base viene de una fuente oficial verificada;
  /// false para las tres rutas heredadas de la app anterior.
  final bool esRutaNueva;
  final bool rutaReservada;

  /// Qué cubre esta ruta y qué no. Se muestra en la UI para no sobreprometer.
  final String alcance;

  final String fuenteBase;
  final String fechaBase;
  final String fechaCorte;
  final String fuente;
  final String fechaFuente;

  /// Por qué esta ruta no trae fuente (típicamente: contenido heredado).
  final String notaFuente;

  final Requisitos requisitosBase;
  final NormaMarco norma;

  /// Qué exige cada unidad cuando la unidad publica esa modalidad.
  final List<ParticularidadUnidad> particularidades;
  final List<PublicacionRelacionada> publicacionesRelacionadas;

  /// Nivel 0 es la pantalla de inicio de la ruta; el resto son niveles de juego.
  final List<Nivel> niveles;

  /// Los niveles jugables, excluyendo la pantalla de inicio.
  List<Nivel> get nivelesJugables =>
      niveles.where((n) => !n.esInicio).toList(growable: false);

  /// Cita corta de la fuente de esta ruta, o la explicación de por qué no hay.
  String get citaFuente {
    if (fuenteBase.isNotEmpty) {
      final f = fechaBase.isEmpty ? '' : ' · $fechaBase';
      return '$fuenteBase$f';
    }
    if (fuente.isNotEmpty) {
      final f = fechaFuente.isNotEmpty ? ' · $fechaFuente' : '';
      return '$fuente$f';
    }
    return notaFuente;
  }

  /// ¿Esta ruta trae contenido verificado por una fuente oficial?
  bool get tieneFuenteVerificada => fuenteBase.isNotEmpty || fuente.isNotEmpty;

  ParticularidadUnidad? particularidadDe(String unidadClave) {
    for (final p in particularidades) {
      if (p.unidadClave == unidadClave) return p;
    }
    return null;
  }

  /// Copia la ruta cambiando lo que la variante de una unidad necesita.
  ///
  /// La base nunca se modifica: la composición devuelve una ruta nueva.
  Ruta copiarCon({
    String? id,
    String? nombre,
    String? descripcion,
    List<Nivel>? niveles,
  }) => Ruta(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    niveles: niveles ?? this.niveles,
    mascotaInicio: mascotaInicio,
    pergaminoInicio: pergaminoInicio,
    mapa: mapa,
    tituloAsset: tituloAsset,
    descripcionAsset: descripcionAsset,
    esRutaNueva: esRutaNueva,
    rutaReservada: rutaReservada,
    alcance: alcance,
    fuenteBase: fuenteBase,
    fechaBase: fechaBase,
    fechaCorte: fechaCorte,
    fuente: fuente,
    fechaFuente: fechaFuente,
    notaFuente: notaFuente,
    requisitosBase: requisitosBase,
    norma: norma,
    particularidades: particularidades,
    publicacionesRelacionadas: publicacionesRelacionadas,
  );

  factory Ruta.fromJson(Map<String, dynamic> json) => Ruta(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    descripcion: json['descripcion'] as String? ?? '',
    niveles:
        (json['niveles'] as List<dynamic>? ?? [])
            .map((n) => Nivel.fromJson(n as Map<String, dynamic>))
            .toList(),
    mascotaInicio: json['mascotaInicio'] as String? ?? '',
    pergaminoInicio: json['pergaminoInicio'] as String? ?? '',
    mapa: json['mapa'] as String? ?? '',
    tituloAsset: json['tituloAsset'] as String? ?? '',
    descripcionAsset: json['descripcionAsset'] as String? ?? '',
    esRutaNueva: json['esRutaNueva'] as bool? ?? false,
    rutaReservada: json['rutaReservada'] as bool? ?? false,
    alcance: json['alcance'] as String? ?? '',
    fuenteBase: json['fuenteBase'] as String? ?? '',
    fechaBase: json['fechaBase'] as String? ?? '',
    fechaCorte: json['fechaCorte'] as String? ?? '',
    fuente: json['fuente'] as String? ?? '',
    fechaFuente: json['fechaFuente'] as String? ?? '',
    notaFuente: json['notaFuente'] as String? ?? '',
    requisitosBase: Requisitos.fromJson(
      (json['requisitosCalculadoraBase'] as Map?)?.cast<String, dynamic>(),
    ),
    norma: NormaMarco.fromJson(
      (json['norma'] as Map?)?.cast<String, dynamic>(),
    ),
    particularidades:
        (json['particularidadesPorUnidad'] as List<dynamic>? ?? [])
            .map(
              (p) => ParticularidadUnidad.fromJson(p as Map<String, dynamic>),
            )
            .toList(),
    publicacionesRelacionadas:
        (json['publicacionesRelacionadas'] as List<dynamic>? ?? [])
            .map(
              (p) => PublicacionRelacionada.fromJson(p as Map<String, dynamic>),
            )
            .toList(),
  );
}

/// Un nivel dentro de una ruta.
class Nivel {
  const Nivel({
    required this.numero,
    required this.titulo,
    required this.descripcion,
    this.icono = '',
    this.mascota = '',
    this.fondo = '',
    this.pasos = const [],
    this.documentos = const [],
    this.esInicio = false,
    this.esFinal = false,
    this.fuente = '',
    this.fecha = '',
  });

  /// 0 para la pantalla de inicio; 1..n para los niveles jugables.
  final int numero;
  final String titulo;
  final String descripcion;

  final String icono;
  final String mascota;
  final String fondo;

  /// Pasos a seguir, en orden. Cada uno es un objeto con `titulo` y `detalle`.
  final List<Paso> pasos;

  /// Documentos que el alumno debe reunir.
  final List<DocumentoRequisito> documentos;

  final bool esInicio;
  final bool esFinal;

  /// Publicación de la que viene el nivel, y cuándo se consultó.
  final String fuente;
  final String fecha;

  factory Nivel.fromJson(Map<String, dynamic> json) => Nivel(
    numero: json['numero'] as int,
    titulo: json['titulo'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    icono: json['icono'] as String? ?? '',
    mascota: json['mascota'] as String? ?? '',
    fondo: json['fondo'] as String? ?? '',
    pasos:
        (json['pasos'] as List<dynamic>? ?? [])
            .map((p) => Paso.fromJson(p as Map<String, dynamic>))
            .toList(),
    documentos:
        (json['documentos'] as List<dynamic>? ?? [])
            .map((d) => DocumentoRequisito.fromJson(d as Map<String, dynamic>))
            .toList(),
    esInicio: json['esInicio'] as bool? ?? false,
    esFinal: json['esFinal'] as bool? ?? false,
    fuente: json['fuente'] as String? ?? '',
    fecha: json['fecha'] as String? ?? '',
  );
}

/// Un paso dentro de un nivel.
class Paso {
  const Paso({required this.titulo, this.detalle = '', this.fuente = ''});

  final String titulo;
  final String detalle;
  final String fuente;

  factory Paso.fromJson(Map<String, dynamic> json) => Paso(
    titulo: json['titulo'] as String? ?? '',
    detalle: json['detalle'] as String? ?? '',
    fuente: json['fuente'] as String? ?? '',
  );
}

/// Un documento que hay que presentar.
class DocumentoRequisito {
  const DocumentoRequisito({
    required this.nombre,
    this.nota = '',
    this.url,
    this.fuente = '',
    this.fecha = '',
  });

  final String nombre;
  final String nota;
  final String? url;
  final String fuente;
  final String fecha;

  factory DocumentoRequisito.fromJson(Map<String, dynamic> json) =>
      DocumentoRequisito(
        nombre: json['nombre'] as String? ?? '',
        nota: json['nota'] as String? ?? '',
        url: json['url'] as String?,
        fuente: json['fuente'] as String? ?? '',
        fecha: json['fecha'] as String? ?? '',
      );
}

/// Una unidad académica de la BUAP, tal como está en `facultades.json`.
///
/// El catálogo de modalidades no vive aquí: está en
/// `assets/json/catalogo_modalidades.json`, que es la única fuente normativa.
class Facultad {
  const Facultad({
    required this.nombre,
    required this.clave,
    this.coordinacion = '',
    this.correo = '',
    this.telefono = '',
    this.responsable = '',
    this.notas = '',
    this.confianza = '',
    this.estadoCatalogo = '',
    this.resultadoBusqueda = '',
    this.fechaConsultaCatalogo = '',
  });

  final String nombre;

  /// Clave corta y estable, usada como clave de guardado del progreso.
  final String clave;

  final String coordinacion;
  final String correo;
  final String telefono;
  final String responsable;
  final String notas;

  /// `alta`, `media` o `baja`: qué tan firme es la fuente del contacto.
  final String confianza;

  final String estadoCatalogo;
  final String resultadoBusqueda;
  final String fechaConsultaCatalogo;

  /// Un contacto está completo solo si tiene correo.
  bool get tieneContacto => correo.isNotEmpty;

  factory Facultad.fromJson(Map<String, dynamic> json) => Facultad(
    nombre: json['nombre'] as String,
    clave: json['clave'] as String? ?? json['nombre'] as String,
    coordinacion: json['coordinacion'] as String? ?? '',
    correo: json['correo'] as String? ?? '',
    telefono: json['telefono'] as String? ?? '',
    responsable: json['responsable'] as String? ?? '',
    notas: json['notas'] as String? ?? '',
    confianza: json['confianza'] as String? ?? '',
    estadoCatalogo: json['estadoCatalogo'] as String? ?? '',
    resultadoBusqueda: json['resultadoBusqueda'] as String? ?? '',
    fechaConsultaCatalogo: json['fechaConsultaCatalogo'] as String? ?? '',
  );
}

/// Un alumno registrado en el dispositivo.
class Alumno {
  const Alumno({
    required this.nombre,
    required this.matricula,
    this.facultad,
    this.carrera = '',
    this.plan = '',
    this.anioIngreso,
  });

  final String nombre;
  final String matricula;
  final String? facultad;

  /// Contexto académico opcional. Nunca se exige ni se inventa: sin él, la
  /// elegibilidad de cada modalidad sale como "confirmar con la unidad".
  final String carrera;
  final String plan;
  final int? anioIngreso;

  factory Alumno.fromJson(Map<String, dynamic> json) => Alumno(
    nombre: json['nombre'] as String? ?? '',
    matricula: json['matricula'] as String? ?? '',
    facultad: json['facultad'] as String?,
    carrera: json['carrera'] as String? ?? '',
    plan: json['plan'] as String? ?? '',
    anioIngreso:
        json['anioIngreso'] == null
            ? null
            : int.tryParse(json['anioIngreso'].toString()),
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'matricula': matricula,
    'facultad': facultad,
    'carrera': carrera,
    'plan': plan,
    'anioIngreso': anioIngreso,
  };
}

/// Una entrada de `links.json`.
class LinkBuap {
  const LinkBuap({
    required this.titulo,
    required this.url,
    this.categoria = '',
  });

  final String titulo;
  final String url;
  final String categoria;

  factory LinkBuap.fromJson(Map<String, dynamic> json) => LinkBuap(
    titulo: json['titulo'] as String? ?? '',
    url: json['url'] as String? ?? '',
    categoria: json['categoria'] as String? ?? '',
  );
}

/// Un contacto de la BUAP.
class Contacto {
  const Contacto({
    required this.nombre,
    required this.area,
    this.telefono = '',
    this.correo = '',
    this.redes = '',
    this.ambito = 'general',
  });

  final String nombre;
  final String area;
  final String telefono;
  final String correo;
  final String redes;

  /// `general` (BUAP completa) o `facultad` (de una unidad concreta).
  final String ambito;

  factory Contacto.fromJson(Map<String, dynamic> json) => Contacto(
    nombre: json['nombre'] as String? ?? '',
    area: json['area'] as String? ?? '',
    telefono: json['telefono'] as String? ?? '',
    correo: json['correo'] as String? ?? '',
    redes: json['redes'] as String? ?? '',
    ambito: json['ambito'] as String? ?? 'general',
  );
}

// ---------------------------------------------------------------------------
// Ruta compuesta: la variante de una unidad fusionada sobre la ruta genérica
// ---------------------------------------------------------------------------

/// La ruta que ve el alumno: la ruta genérica con lo que publica su unidad.
///
/// Es una vista inmutable. La [Ruta] base nunca se modifica: aquí vive la copia
/// con un nivel extra (lo que exige la unidad) y el nombre que usa la unidad.
class RutaCompuesta {
  /// La calcula el repositorio. La base nunca se toca: aquí vive la copia con
  /// la variante de la unidad encima.
  const RutaCompuesta({
    required this.rutaBase,
    required this.ruta,
    required this.modalidad,
    required this.particularidad,
    required this.requisitos,
    required this.estadoCatalogoUnidad,
  });

  /// Ruta base tal como vino de `routes.json`, sin tocar.
  final Ruta rutaBase;

  /// La ruta efectiva que consumen mapa y detalle.
  final Ruta ruta;

  /// La modalidad de la unidad, o `null` en el adaptador legado.
  final ModalidadUnidad? modalidad;

  /// Lo que la unidad publica de esa modalidad, o `null`.
  final ParticularidadUnidad? particularidad;

  /// Requisitos fusionados: los de la unidad sobre los de la ruta base.
  final Requisitos requisitos;

  final String estadoCatalogoUnidad;

  /// Id con el que se guarda el progreso. Es el id de la modalidad cuando la
  /// ruta viene de una unidad, y el id legado cuando es la ruta global.
  String get id => ruta.id;

  /// Composición de una ruta global sin unidad: el adaptador legado.
  factory RutaCompuesta.legacy(Ruta base) => RutaCompuesta(
    rutaBase: base,
    ruta: base,
    modalidad: null,
    particularidad: null,
    requisitos: base.requisitosBase,
    estadoCatalogoUnidad: '',
  );

  /// Número de niveles jugables de la ruta efectiva.
  int get totalNiveles => ruta.nivelesJugables.length;

  /// ¿Trae la variante de alguna unidad?
  bool get tieneParticularidad => particularidad != null;

  /// Fuentes que respaldan lo que se está mostrando, con su fecha.
  ///
  /// Siempre incluye la fuente base de la ruta; si la unidad tiene fuente
  /// propia, se suma.
  List<Fuente> get fuentes {
    final out = <Fuente>[];
    if (rutaBase.fuenteBase.isNotEmpty || rutaBase.fuente.isNotEmpty) {
      out.add(
        Fuente(
          titulo:
              rutaBase.fuenteBase.isNotEmpty
                  ? rutaBase.fuenteBase
                  : 'Fuente de la ruta',
          url: rutaBase.fuente,
          fechaPublicacion: rutaBase.fechaBase,
          consultadoEn: rutaBase.fechaCorte,
        ),
      );
    }
    final m = modalidad;
    if (m != null) {
      if (m.fuente.isNotEmpty) {
        out.add(
          Fuente(
            titulo: '${m.unidadNombre} — ${m.nombreOficial}',
            url: m.fuente,
            fechaPublicacion: m.vigenteDesde,
            consultadoEn: m.consultadoEn,
          ),
        );
      }
      out.addAll(m.fuentes);
    }
    return out;
  }

  /// "Fuente · fecha" de la unidad, o la de la ruta si la unidad no trae.
  String get citaFuente {
    final m = modalidad;
    if (m != null && m.fuente.isNotEmpty) {
      final fecha = m.fecha.isNotEmpty ? m.fecha : m.consultadoEn;
      return fecha.isEmpty ? m.fuente : '${m.fuente} — $fecha';
    }
    return rutaBase.citaFuente;
  }
}
