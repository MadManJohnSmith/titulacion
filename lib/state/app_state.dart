import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'notas_state.dart';

/// Estado global de la app: quién es el alumno, en qué unidad está, qué
/// modalidad eligió y hasta dónde llegó.
///
/// ## Esquema de guardado
///
/// Versión 1 (la app anterior): cuatro claves, `alumno`, `facultad`, `ruta` y
/// `progreso`, con el progreso indexado por `rutaId`.
///
/// Versión 2 (esta): las cuatro claves anteriores **se leen tal cual y nunca se
/// borran**. Se agregan `estadoSchema`, `modalidadActiva`, `rutaActivaBase`,
/// `contextoAlumno` y `migraciones`. El progreso nuevo se guarda bajo
/// `modalidad:<modalidadId>`; el viejo sigue bajo su `rutaId`, intacto.
///
/// Eso evita dos cosas a la vez: que un alumno que ya avanzó pierde su avance,
/// y que el avance de una modalidad aparezca como si fuera de otra.
///
/// La única excepción es [cerrarSesion]: esa sí borra, porque es la operación
/// destructiva que el aviso de privacidad promete y solo ocurre cuando la
/// persona la pide explícitamente.
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _cargar();
  }

  final SharedPreferences _prefs;

  /// Las notas que el alumno escribe en cada nivel.
  ///
  /// Vive aquí y no en las pantallas para que ambas compartan la misma
  /// instancia: una nota escrita en el nivel se ve en el listado y sale en el
  /// respaldo sin tener que releer las preferencias.
  late final NotasState notas = NotasState(_prefs);

  // Claves de la versión 1. No se tocan.
  static const _kAlumno = 'alumno';
  static const _kFacultad = 'facultad';
  static const _kRuta = 'ruta';
  static const _kProgreso = 'progreso';

  // Claves de la versión 2.
  static const _kEsquema = 'estadoSchema';
  static const _kModalidadActiva = 'modalidadActiva';
  static const _kRutaActivaBase = 'rutaActivaBase';
  static const _kContexto = 'contextoAlumno';
  static const _kMigraciones = 'migracionesProgreso';

  /// Prefijo del espacio de nombres del progreso de una modalidad.
  static const String prefijoModalidad = 'modalidad:';

  static const int esquemaActual = 2;

  /// Progreso: `espacioDeNombres -> [niveles completados]`, y
  /// `docs -> "espacioDeNombres:nivel:indice"`.
  Map<String, List<int>> _completados = {};
  Set<String> _documentosMarcados = {};

  /// `modalidadId -> rutaIdBase` de las migraciones ya ofrecidas y aceptadas.
  Map<String, String> _migraciones = {};

  Alumno? _alumno;
  String? _facultadClave;
  String? _rutaActiva;
  String? _modalidadActiva;
  String? _rutaActivaBase;
  int _anioIngreso = 0;
  String _carreraId = '';
  String _planId = '';

  Alumno? get alumno => _alumno;
  String? get facultadClave => _facultadClave;

  /// Id con el que se guarda el avance: el de la modalidad si la hay, si no el
  /// de la ruta global. Es el id que mapa y detalle usan.
  String? get rutaActiva => _rutaActiva;

  /// La modalidad elegida, o `null` si el alumno va por una ruta global.
  String? get modalidadActiva => _modalidadActiva;

  /// La ruta base de la que partiese la modalidad elegida.
  String? get rutaActivaBase => _rutaActivaBase;

  bool get estaRegistrado => _alumno != null;

  /// La versión del esquema con la que se escribió el estado.
  int get esquema => int.tryParse(_prefs.getString(_kEsquema) ?? '') ?? 1;

  /// Contexto académico opcional. Vacío = la unidad no publica ese dato, o el
  /// alumno no lo capturó: en ambos casos la app pide confirmar con la unidad.
  String get carreraId => _carreraId;
  String get planId => _planId;
  int get anioIngreso => _anioIngreso;

  bool get tieneContexto =>
      _carreraId.isNotEmpty || _planId.isNotEmpty || _anioIngreso > 0;

  // -------------------------------------------------------------- migración

  void _cargar() {
    final alumnoJson = _prefs.getString(_kAlumno);
    if (alumnoJson != null) {
      try {
        _alumno = Alumno.fromJson(
          json.decode(alumnoJson) as Map<String, dynamic>,
        );
        _carreraId = _alumno!.carrera;
        _planId = _alumno!.plan;
        _anioIngreso = _alumno!.anioIngreso ?? 0;
      } catch (_) {
        _alumno = null;
      }
    }
    _facultadClave = _prefs.getString(_kFacultad);
    _rutaActiva = _prefs.getString(_kRuta);
    _modalidadActiva = _prefs.getString(_kModalidadActiva);
    _rutaActivaBase = _prefs.getString(_kRutaActivaBase);

    final contexto = _prefs.getString(_kContexto);
    if (contexto != null) {
      try {
        final m = json.decode(contexto) as Map<String, dynamic>;
        _carreraId = m['carreraId'] as String? ?? _carreraId;
        _planId = m['planId'] as String? ?? _planId;
        _anioIngreso = (m['anioIngreso'] as num?)?.toInt() ?? _anioIngreso;
      } catch (_) {
        // Contexto corrupto: se sigue con lo que haya en el alumno.
      }
    }

    final migraciones = _prefs.getString(_kMigraciones);
    if (migraciones != null) {
      try {
        _migraciones = (json.decode(migraciones) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v?.toString() ?? ''),
        );
      } catch (_) {
        _migraciones = {};
      }
    }

    final progJson = _prefs.getString(_kProgreso);
    if (progJson != null) {
      try {
        final map = json.decode(progJson) as Map<String, dynamic>;
        _completados =
            map['completados'] == null
                ? <String, List<int>>{}
                : (map['completados'] as Map<String, dynamic>).map(
                  (k, v) => MapEntry(k, (v as List<dynamic>).cast<int>()),
                );
        _documentosMarcados =
            ((map['documentos'] as List<dynamic>?) ?? [])
                .cast<String>()
                .toSet();
      } catch (_) {
        // Progreso corrupto: la app arranca en cero en vez de no arrancar.
        _completados = {};
        _documentosMarcados = {};
      }
    }
  }

  /// Escribe el bloque `progreso` una sola vez, siempre con las tres claves.
  Future<void> _guardarProgreso() async {
    await _prefs.setString(
      _kProgreso,
      json.encode({
        'completados': _completados,
        'documentos': _documentosMarcados.toList(),
      }),
    );
  }

  /// Marca el estado como versión 2.
  ///
  /// Se llama **al final** de la migración, nunca antes: mientras no esté
  /// escrito, la app sigue leyendo las claves de la versión 1 tal cual, así que
  /// una migración a medias no pierde nada.
  Future<void> _marcarEsquema2() async {
    if (esquema >= esquemaActual) return;
    await _prefs.setString(_kEsquema, '$esquemaActual');
  }

  /// El espacio de nombres donde vive el avance de una ruta o modalidad.
  ///
  /// Las modalidades quedan aisladas entre sí: completar una no aparece en
  /// otra, aunque las dos se apoyen en la misma ruta base.
  String namespaceDe(String idDeRuta) {
    if (_modalidadActiva != null && idDeRuta == _modalidadActiva) {
      return '$prefijoModalidad$idDeRuta';
    }
    return idDeRuta;
  }

  // ---------------------------------------------------------------- alumno

  /// Registra o actualiza al alumno.
  ///
  /// [facultadClave] es obligatoria: sin unidad no hay catálogo ni oferta. Si
  /// la unidad cambia, la modalidad y la ruta activa se deselccionan, pero el
  /// avance ya guardado no se borra: queda aislado en su propio espacio de
  /// nombres y sigue ahí si el alumno vuelve a esa unidad.
  Future<void> registrar(Alumno alumno, {required String facultadClave}) async {
    final unidadPrevia = _facultadClave;
    final cambioDeAlumno =
        _alumno != null &&
        (_alumno!.matricula != alumno.matricula ||
            _alumno!.nombre != alumno.nombre);

    _alumno = alumno;
    _carreraId = alumno.carrera;
    _planId = alumno.plan;
    _anioIngreso = alumno.anioIngreso ?? 0;
    _facultadClave = facultadClave;

    await _prefs.setString(_kAlumno, json.encode(alumno.toJson()));
    await _prefs.setString(_kFacultad, facultadClave);
    await _prefs.setString(
      _kContexto,
      json.encode({
        'carreraId': _carreraId,
        'planId': _planId,
        'anioIngreso': _anioIngreso,
      }),
    );

    if (unidadPrevia != null && unidadPrevia != facultadClave) {
      await _deseleccionarOferta();
    } else if (cambioDeAlumno) {
      // Otra persona en el mismo dispositivo: no ve el avance de la anterior.
      await _deseleccionarOferta();
    } else {
      await _marcarEsquema2();
    }
    notifyListeners();
  }

  /// Cambia de unidad académica aplicando la misma invalidación.
  Future<void> elegirFacultad(String clave) async {
    if (_facultadClave == clave) return;
    _facultadClave = clave;
    await _prefs.setString(_kFacultad, clave);
    await _deseleccionarOferta();
    notifyListeners();
  }

  /// Quita la modalidad y la ruta activa sin tocar el avance ya guardado.
  Future<void> _deseleccionarOferta() async {
    _modalidadActiva = null;
    _rutaActivaBase = null;
    _rutaActiva = null;
    await _prefs.remove(_kModalidadActiva);
    await _prefs.remove(_kRutaActivaBase);
    await _prefs.remove(_kRuta);
    await _marcarEsquema2();
  }

  /// Cierra la sesión: borra del dispositivo **todo** lo que la app guardó de
  /// esta persona.
  ///
  /// Es la única operación que destruye datos: el resto del esquema (cambiar de
  /// unidad, elegir otra modalidad) **aísla** el avance, nunca lo borra. Se van
  /// el registro (`alumno`), la unidad académica, el contexto, la oferta
  /// activa, el avance de todos sus espacios de nombres (`progreso`) y las
  /// notas, y la app queda como recién instalada: quien entre después en esta
  /// unidad empieza en cero y no ve nada de quien estuvo antes.
  Future<void> cerrarSesion() async {
    _alumno = null;
    _facultadClave = null;
    _carreraId = '';
    _planId = '';
    _anioIngreso = 0;
    _completados = {};
    _documentosMarcados = {};
    _migraciones = {};
    // Primero se deselecciona la oferta: `_marcarEsquema2` se ejecuta dentro y
    // dejaría la marca de esquema puesta si se borrara antes.
    await _deseleccionarOferta();
    await _prefs.remove(_kAlumno);
    await _prefs.remove(_kFacultad);
    await _prefs.remove(_kContexto);
    await _prefs.remove(_kMigraciones);
    await _prefs.remove(_kProgreso);
    await _prefs.remove(_kEsquema);
    // Las notas viven en su propia clave, pero son datos de esta misma persona.
    await notas.borrarTodo();
    notifyListeners();
  }

  /// Guarda el contexto académico. Todo opcional: si no se captura, la
  /// elegibilidad de cada modalidad sale como "confirma con la unidad".
  Future<void> guardarContexto({
    String? carreraId,
    String? planId,
    int? anioIngreso,
  }) async {
    if (carreraId != null) _carreraId = carreraId.trim();
    if (planId != null) _planId = planId.trim();
    if (anioIngreso != null) _anioIngreso = anioIngreso;
    final a = _alumno;
    if (a != null) {
      _alumno = Alumno(
        nombre: a.nombre,
        matricula: a.matricula,
        facultad: a.facultad,
        carrera: _carreraId,
        plan: _planId,
        anioIngreso: _anioIngreso > 0 ? _anioIngreso : null,
      );
      await _prefs.setString(_kAlumno, json.encode(_alumno!.toJson()));
    }
    await _prefs.setString(
      _kContexto,
      json.encode({
        'carreraId': _carreraId,
        'planId': _planId,
        'anioIngreso': _anioIngreso,
      }),
    );
    await _marcarEsquema2();
    notifyListeners();
  }

  // ----------------------------------------------------------------- rutas

  /// Elige una modalidad de una unidad y la deja como ruta activa.
  ///
  /// El avance de esta modalidad arranca en cero: no hereda el de la ruta base.
  /// Lo que sí puede es repetir el que el alumno ya traía, pero solo con su
  /// confirmación (ver [migracionDisponible]).
  Future<void> elegirModalidad(String modalidadId, String rutaIdBase) async {
    _modalidadActiva = modalidadId;
    _rutaActivaBase = rutaIdBase;
    _rutaActiva = modalidadId;
    await _prefs.setString(_kModalidadActiva, modalidadId);
    await _prefs.setString(_kRutaActivaBase, rutaIdBase);
    await _prefs.setString(_kRuta, modalidadId);
    await _marcarEsquema2();
    notifyListeners();
  }

  /// Elige una ruta global (el adaptador legado de la versión 1).
  Future<void> elegirRuta(String rutaId) async {
    _modalidadActiva = null;
    _rutaActivaBase = null;
    _rutaActiva = rutaId;
    await _prefs.remove(_kModalidadActiva);
    await _prefs.remove(_kRutaActivaBase);
    await _prefs.setString(_kRuta, rutaId);
    await _marcarEsquema2();
    notifyListeners();
  }

  /// Deselecciona la oferta sin borrar el avance: deja al alumno en la lista
  /// de su unidad. Útil cuando la modalidad que tenía ya no está publicada.
  Future<void> limpiarOfertaActiva() async {
    await _deseleccionarOferta();
    notifyListeners();
  }

  // ------------------------------------------------- migración de progreso

  /// ¿Hay avance de la versión 1 que este alumno podría trasladar a esta
  /// modalidad?
  ///
  /// Solo se ofrece si la modalidad no tiene avance propio todavía, si nunca se
  /// le Pidió migrar y si el avance de la ruta base existe de verdad. El
  /// alumno decide: nada se copia a sus espaldas.
  bool migracionDisponible(String modalidadId, String rutaIdBase) {
    if (_migraciones.containsKey(modalidadId)) return false;
    final destino = '$prefijoModalidad$modalidadId';
    if ((_completados[destino]?.isNotEmpty ?? false)) return false;
    if (_documentosMarcados.any((d) => d.startsWith('$destino:'))) return false;
    return (_completados[rutaIdBase]?.isNotEmpty ?? false) ||
        _documentosMarcados.any((d) => d.startsWith('$rutaIdBase:'));
  }

  /// Cuántos niveles tiene el avance que se puede trasladar.
  int nivelesAMigrar(String rutaIdBase) =>
      _completados[rutaIdBase]?.length ?? 0;

  /// Copia el avance de la ruta base al espacio de la modalidad.
  ///
  /// No borra el original: si el alumno se arrepiente, sigue ahí. Y no se
  /// vuelve a ofrecer, porque queda registrado en [migraciones].
  Future<void> migrarProgreso(String modalidadId, String rutaIdBase) async {
    if (!migracionDisponible(modalidadId, rutaIdBase)) return;
    final destino = '$prefijoModalidad$modalidadId';
    final niveles = List<int>.from(_completados[rutaIdBase] ?? const <int>[])
      ..sort();
    _completados[destino] = niveles;
    // La lista se copia antes de modificar el conjunto: iterar y agregar sobre
    // el mismo `Set` lanza "concurrent modification" en cuanto hay un elemento.
    final heredados =
        _documentosMarcados.where((d) => d.startsWith('$rutaIdBase:')).toList();
    for (final d in heredados) {
      _documentosMarcados.add('$destino${d.substring(rutaIdBase.length)}');
    }
    _migraciones[modalidadId] = rutaIdBase;
    await _prefs.setString(_kMigraciones, json.encode(_migraciones));
    await _guardarProgreso();
    await _marcarEsquema2();
    notifyListeners();
  }

  // -------------------------------------------------------------- progreso

  List<int> completadosDe(String rutaId) =>
      _completados[namespaceDe(rutaId)] ?? const [];

  bool estaCompletado(String rutaId, int nivel) =>
      completadosDe(rutaId).contains(nivel);

  /// El siguiente nivel por hacer: el menor número que no esté completado.
  int siguienteNivel(String rutaId, int totalNiveles) {
    final hechos = completadosDe(rutaId).toSet();
    for (var i = 1; i <= totalNiveles; i++) {
      if (!hechos.contains(i)) return i;
    }
    return totalNiveles;
  }

  bool nivelDesbloqueado(String rutaId, int nivel) {
    if (nivel <= 1) return true;
    return estaCompletado(rutaId, nivel - 1);
  }

  Future<void> completarNivel(String rutaId, int nivel) async {
    final ns = namespaceDe(rutaId);
    final lista = _completados.putIfAbsent(ns, () => <int>[]);
    if (!lista.contains(nivel)) {
      lista.add(nivel);
      lista.sort();
      await _guardarProgreso();
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- documentos

  String _docKey(String rutaId, int nivel, int indice) =>
      '${namespaceDe(rutaId)}:$nivel:$indice';

  bool documentoMarcado(String rutaId, int nivel, int indice) =>
      _documentosMarcados.contains(_docKey(rutaId, nivel, indice));

  void alternarDocumento(String rutaId, int nivel, int indice) {
    final key = _docKey(rutaId, nivel, indice);
    if (!_documentosMarcados.remove(key)) {
      _documentosMarcados.add(key);
    }
    _guardarProgreso();
    notifyListeners();
  }

  /// Progreso 0..1 de una ruta, para la barra del mapa.
  double progresoDe(String rutaId, int totalNiveles) {
    if (totalNiveles == 0) return 0;
    final hechos = completadosDe(rutaId).where((n) => n <= totalNiveles).length;
    return (hechos / totalNiveles).clamp(0.0, 1.0);
  }
}
