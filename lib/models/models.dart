/// Modelos de datos de LoboApp.
///
/// El contenido de las rutas y niveles vive en `assets/json/routes.json` para que
/// cambiar un requisito sea editar un JSON, no recompilar Dart.
library;

/// Una modalidad de titulación (promedio, CENEVAL, examen profesional...).
class Ruta {
  const Ruta({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.niveles,
    required this.mascotaInicio,
    required this.pergaminoInicio,
    this.mapa = '',
    this.tituloAsset,
    this.descripcionAsset,
  });

  final String id;
  final String nombre;
  final String descripcion;

  /// Nivel 0 es la pantalla de inicio de la ruta; el resto son niveles de juego.
  final List<Nivel> niveles;

  final String mascotaInicio;
  final String pergaminoInicio;

  /// Fondo del mapa de la ruta. Cada una tiene su propio mapa.
  final String mapa;

  final String? tituloAsset;
  final String? descripcionAsset;

  /// Los niveles jugables, excluyendo la pantalla de inicio.
  List<Nivel> get nivelesJugables =>
      niveles.where((n) => !n.esInicio).toList(growable: false);

  factory Ruta.fromJson(Map<String, dynamic> json) => Ruta(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String? ?? '',
        niveles: (json['niveles'] as List<dynamic>? ?? [])
            .map((n) => Nivel.fromJson(n as Map<String, dynamic>))
            .toList(),
        mascotaInicio: json['mascotaInicio'] as String? ?? '',
        pergaminoInicio: json['pergaminoInicio'] as String? ?? '',
        mapa: json['mapa'] as String? ?? '',
        tituloAsset: json['tituloAsset'] as String?,
        descripcionAsset: json['descripcionAsset'] as String?,
      );
}

/// Un nivel dentro de una ruta.
class Nivel {
  const Nivel({
    required this.numero,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.mascota,
    required this.fondo,
    this.pasos = const [],
    this.documentos = const [],
    this.esInicio = false,
    this.esFinal = false,
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

  /// Documentos que el alumno debe reunir. Cada uno tiene `nombre`, `nota` y
  /// opcionalmente `url`.
  final List<DocumentoRequisito> documentos;

  final bool esInicio;
  final bool esFinal;

  factory Nivel.fromJson(Map<String, dynamic> json) => Nivel(
        numero: json['numero'] as int,
        titulo: json['titulo'] as String? ?? '',
        descripcion: json['descripcion'] as String? ?? '',
        icono: json['icono'] as String? ?? '',
        mascota: json['mascota'] as String? ?? '',
        fondo: json['fondo'] as String? ?? '',
        pasos: (json['pasos'] as List<dynamic>? ?? [])
            .map((p) => Paso.fromJson(p as Map<String, dynamic>))
            .toList(),
        documentos: (json['documentos'] as List<dynamic>? ?? [])
            .map((d) => DocumentoRequisito.fromJson(d as Map<String, dynamic>))
            .toList(),
        esInicio: json['esInicio'] as bool? ?? false,
        esFinal: json['esFinal'] as bool? ?? false,
      );
}

/// Un paso dentro de un nivel.
class Paso {
  const Paso({required this.titulo, this.detalle = ''});

  final String titulo;
  final String detalle;

  factory Paso.fromJson(Map<String, dynamic> json) => Paso(
        titulo: json['titulo'] as String? ?? '',
        detalle: json['detalle'] as String? ?? '',
      );
}

/// Un documento que hay que presentar.
class DocumentoRequisito {
  const DocumentoRequisito({
    required this.nombre,
    this.nota = '',
    this.url,
  });

  final String nombre;
  final String nota;
  final String? url;

  factory DocumentoRequisito.fromJson(Map<String, dynamic> json) =>
      DocumentoRequisito(
        nombre: json['nombre'] as String? ?? '',
        nota: json['nota'] as String? ?? '',
        url: json['url'] as String?,
      );
}

/// Una unidad académica de la BUAP.
class Facultad {
  const Facultad({
    required this.nombre,
    required this.clave,
    this.coordinacion = '',
    this.correo = '',
    this.telefono = '',
    this.responsable = '',
    this.notas = '',
  });

  final String nombre;

  /// Clave corta y estable, usada como clave de guardado del progreso.
  final String clave;

  final String coordinacion;
  final String correo;
  final String telefono;
  final String responsable;
  final String notas;

  /// Un contato está completo solo si tiene correo.
  bool get tieneContacto => correo.isNotEmpty;

  factory Facultad.fromJson(Map<String, dynamic> json) => Facultad(
        nombre: json['nombre'] as String,
        clave: json['clave'] as String? ?? json['nombre'] as String,
        coordinacion: json['coordinacion'] as String? ?? '',
        correo: json['correo'] as String? ?? '',
        telefono: json['telefono'] as String? ?? '',
        responsable: json['responsable'] as String? ?? '',
        notas: json['notas'] as String? ?? '',
      );
}

/// Un alumno registrado en el dispositivo.
class Alumno {
  const Alumno({required this.nombre, required this.matricula, this.facultad});

  final String nombre;
  final String matricula;
  final String? facultad;

  factory Alumno.fromJson(Map<String, dynamic> json) => Alumno(
        nombre: json['nombre'] as String? ?? '',
        matricula: json['matricula'] as String? ?? '',
        facultad: json['facultad'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'matricula': matricula,
        'facultad': facultad,
      };
}

/// Un enlace útil de la BUAP.
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
