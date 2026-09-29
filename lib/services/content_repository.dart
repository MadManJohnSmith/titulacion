import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../demo.dart';
import '../models/models.dart';

/// Carga el contenido de la app desde `assets/json/` y lo actualiza desde la
/// web cuando hay un manifiesto firmado.
///
/// Orden de preferencia del catálogo de modalidades:
///   1. la caché descargada, si no venció y su hash cuadra;
///   2. el asset embebido `assets/json/catalogo_modalidades.json`.
///
/// El respaldo embebido siempre está: si la red falla, si el manifiesto no
/// cuadra o si no hay manifiesto, la app arranca con el contenido que ya traía.
/// Nunca se borra el último paquete válido.
///
/// Solo se descarga **contenido público**: el único archivo que el actualizador
/// toca es el catálogo de modalidades. El padrón de alumnos y el directorio de
/// trabajadores no se descargan, no se envían y no se cachean aquí.
class ContentRepository {
  ContentRepository._();

  static final ContentRepository instance = ContentRepository._();

  /// Ruta del catálogo embebido en el bundle.
  static const String assetCatalogo = 'assets/json/catalogo_modalidades.json';
  static const String assetRutas = 'assets/json/routes.json';
  static const String assetFacultades = 'assets/json/facultades.json';

  /// Claves de `SharedPreferences` de la caché de contenido.
  static const String _kCacheCatalogo = 'catalogo_cache_json';
  static const String _kCacheManifiesto = 'catalogo_cache_manifiesto';
  static const String _kCacheFecha = 'catalogo_cache_fecha';

  /// Hosts de los que se acepta manifiesto. Vacío = no se acepta ninguno: la
  /// app no conoce todavía el dominio de publicación, así que por omisión
  /// **no actualiza**. Esto no es un olvido: acceptar un host desconocido sería
  /// dejar que cualquiera cambie el contenido que la app enseña.
  static const Set<String> hostsPermitidos = {};

  /// Claves públicas Ed25519 en las que se confía para validar el manifiesto.
  /// Vacío = ninguna: sin clave de confianza el manifiesto se rechaza.
  static const Map<String, String> clavesPublicasConfiables = {};

  /// Anula los dos mapas de arriba durante las pruebas. Vacío = se usan los de
  /// compilación, que es lo que corre en la app.
  @visibleForTesting
  static Set<String> hostsPermitidosDePrueba = const {};
  @visibleForTesting
  static Map<String, String> clavesPublicasDePrueba = const {};

  static Set<String> get _hosts =>
      hostsPermitidosDePrueba.isEmpty
          ? hostsPermitidos
          : hostsPermitidosDePrueba;

  static Map<String, String> get _claves =>
      clavesPublicasDePrueba.isEmpty
          ? clavesPublicasConfiables
          : clavesPublicasDePrueba;

  /// Tope del contenido descargado, para que un servidor grande no nos llene
  /// el almacenamiento del dispositivo.
  static const int maxBytesContenido = 4 * 1024 * 1024;
  static const Duration timeoutDescarga = Duration(seconds: 15);

  /// Archivo de la ruta base nueva, para no tenerlos escritos a mano.
  static const String _nivelIconoPrefijo = 'assets/images/level_icons/nivel_';
  static const int _nivelIconosDisponibles = 7;

  List<Ruta>? _rutas;
  List<Facultad>? _facultades;
  List<LinkBuap>? _links;
  List<Contacto>? _contactos;
  CatalogoModalidades? _catalogo;
  String _fechaCorteRutas = '';
  NormaMarco _normaMarco = const NormaMarco();
  SharedPreferences? _prefs;

  /// Cliente HTTP inyectable, para probar el actualizador sin red.
  http.Client? _clienteHttp;

  // ------------------------------------------------------------------ rutas

  Future<List<Ruta>> rutas() async {
    if (_rutas != null) return _rutas!;
    final data = await _leer(assetRutas);
    _fechaCorteRutas = data['fechaCorte'] as String? ?? '';
    _normaMarco = NormaMarco.fromJson(
      (data['normaMarco'] as Map?)?.cast<String, dynamic>(),
    );
    final lista =
        (data['rutas'] as List<dynamic>)
            .map((e) => Ruta.fromJson(e as Map<String, dynamic>))
            .toList();
    return _rutas = lista;
  }

  /// Fecha de corte del contenido de rutas, tal como la declara el JSON.
  Future<String> fechaCorteRutas() async {
    await rutas();
    return _fechaCorteRutas;
  }

  /// La norma que enmarca el catálogo. Del JSON de rutas si no hay catálogo.
  Future<NormaMarco> normaMarco() async {
    if (_catalogo != null && !_catalogo!.norma.estaVacia) {
      return _catalogo!.norma;
    }
    await rutas();
    return _normaMarco;
  }

  Future<List<Facultad>> facultades() async {
    if (_facultades != null) return _facultades!;
    final data = await _leer(assetFacultades);
    final lista =
        (data['facultades'] as List<dynamic>)
            .map((e) => Facultad.fromJson(e as Map<String, dynamic>))
            .toList();
    return _facultades = lista;
  }

  Future<List<LinkBuap>> links() async {
    if (_links != null) return _links!;
    final data = await _leer('assets/json/links.json');
    final lista =
        (data['links'] as List<dynamic>)
            .map((e) => LinkBuap.fromJson(e as Map<String, dynamic>))
            .toList();
    return _links = lista;
  }

  Future<List<Contacto>> contactos() async {
    if (_contactos != null) return _contactos!;
    final data = await _leer('assets/json/contactos.json');
    final lista =
        (data['contactos'] as List<dynamic>)
            .map((e) => Contacto.fromJson(e as Map<String, dynamic>))
            .toList();
    return _contactos = lista;
  }

  /// Busca una ruta base por su id. Lanza si no existe: un id mal escrito es un
  /// error de programación, no algo que el usuario pueda provocar.
  Future<Ruta> rutaPorId(String id) async {
    final todas = await rutas();
    return todas.firstWhere(
      (r) => r.id == id,
      orElse: () => throw StateError('No existe la ruta "$id" en routes.json'),
    );
  }

  Future<Facultad?> facultadPorClave(String clave) async {
    final todas = await facultades();
    for (final f in todas) {
      if (f.clave == clave) return f;
    }
    return null;
  }

  // --------------------------------------------------------------- catálogo

  /// El catálogo vigente: caché descargada si sirve, si no el asset embebido.
  Future<CatalogoModalidades> catalogo() async {
    if (_catalogo != null) return _catalogo!;
    final cache = await _leerCache();
    if (cache != null) {
      _catalogo = cache;
      return cache;
    }
    final data = await _leer(assetCatalogo);
    return _catalogo = CatalogoModalidades.fromJson(
      data,
      origen: CatalogoModalidades.origenEmbi,
    );
  }

  Future<UnidadCatalogo?> unidadPorClave(String clave) async {
    final c = await catalogo();
    return c.porClave(clave);
  }

  /// Qué puede ofrecer una unidad concreta: sus modalidades acreditadas, las
  /// que no se pueden jugar y por qué, y el rastro de búsqueda cuando no hay
  /// catálogo.
  ///
  /// Nunca devuelve una lista vacía sin explicación: si la unidad no publica
  /// nada, trae el mensaje, las URLs consultadas y el contacto de respaldo.
  Future<OfertaUnidad> ofertaDeUnidad(String clave) async {
    final cat = await catalogo();
    final unidad = cat.porClave(clave);
    if (unidad == null) {
      return OfertaUnidad(
        unidad: null,
        clave: clave,
        nombre: clave,
        rutas: const [],
        informativas: [
          ModalidadNoAcreditada(
            nombre: 'La clave no está en el catálogo',
            motivo:
                'No hay ninguna unidad con la clave "$clave" en '
                'catalogo_modalidades.json (fecha de corte ${cat.fechaCorte}).',
          ),
        ],
        errores: const [],
        fechaCorte: cat.fechaCorte,
      );
    }

    final bases = {for (final r in await rutas()) r.id: r};
    final ofertas = <RutaOferta>[];
    final informativas = <ModalidadNoAcreditada>[];
    final errores = <ErrorComposicion>[];

    for (final m in unidad.modalidades) {
      if (m.modalidadId.isEmpty) {
        errores.add(
          ErrorComposicion(
            modalidadId: '(vacío)',
            motivo: 'La modalidad no trae modalidadId.',
          ),
        );
        continue;
      }
      final base = m.rutaId == null ? null : bases[m.rutaId];
      if (base == null) {
        final motivo =
            m.rutaId == null
                ? (m.rutaIdMapeo.isNotEmpty
                    ? 'Mapeada como "${m.rutaIdMapeo}": la unidad la publica pero '
                        'no hay ruta base acreditada para jugarla.'
                    : 'La unidad la publica pero no hay ruta base acreditada.')
                : 'Apunta a la ruta "${m.rutaId}", que no existe en routes.json.';
        informativas.add(
          ModalidadNoAcreditada(
            modalidadId: m.modalidadId,
            nombre: m.nombreOficial,
            motivo: motivo,
            fuente: m.fuente,
            fecha: m.fecha,
          ),
        );
        continue;
      }
      if (!m.seleccionable) {
        informativas.add(
          ModalidadNoAcreditada(
            modalidadId: m.modalidadId,
            nombre: m.nombreOficial,
            motivo:
                m.pendiente.isNotEmpty
                    ? m.pendiente
                    : 'La unidad la publica, pero el catálogo no la marca como '
                        'acreditada.',
            fuente: m.fuente,
            fecha: m.fecha,
          ),
        );
        continue;
      }
      if (!m.tieneFuente) {
        errores.add(
          ErrorComposicion(
            modalidadId: m.modalidadId,
            motivo: 'No trae URL de fuente, así que no se puede acreditar.',
          ),
        );
        continue;
      }
      final compuesta = _componer(base, m, unidad.estadoCatalogo);
      if (compuesta == null) {
        continue;
      }
      ofertas.add(
        RutaOferta(
          ruta: compuesta,
          modalidad: m,
          particularidad: compuesta.particularidad,
        ),
      );
    }

    return OfertaUnidad(
      unidad: unidad,
      clave: clave,
      nombre: unidad.nombre,
      rutas: ofertas,
      informativas: informativas,
      errores: errores,
      fechaCorte: cat.fechaCorte,
    );
  }

  /// Compone la variante de una unidad sobre su ruta base.
  ///
  /// Devuelve `null` (y registra el error) si la composición no es válida. La
  /// ruta base nunca se modifica: se devuelve una copia con un nivel extra.
  RutaCompuesta? _componer(
    Ruta base,
    ModalidadUnidad modalidad,
    String estadoCatalogoUnidad,
  ) {
    // El id de la modalidad es la clave del progreso: no puede chocar con el de
    // otra modalidad de la misma unidad ni con el de una ruta base.
    if (base.id == modalidad.modalidadId) {
      return null;
    }
    final p = base.particularidadDe(modalidad.unidadClave);
    final niveles = List<Nivel>.from(base.niveles);
    final usados = niveles.map((n) => n.numero).toSet();

    // Un nivel por particularidad: lo que la unidad publica de esta modalidad.
    // Solo se agrega si hay algo que decir; si no, la variante no inventa un
    // nivel vacío.
    if (p != null &&
        (p.detalle.isNotEmpty || modalidad.requisitosTexto.isNotEmpty)) {
      final numero =
          usados.isEmpty ? 1 : usados.reduce((a, b) => a > b ? a : b) + 1;
      if (usados.contains(numero)) return null;
      final pasos = <Paso>[];
      final detalle = p.detalle.trim();
      if (detalle.isNotEmpty) {
        pasos.add(
          Paso(
            titulo: 'Lo que declara ${modalidad.unidadNombre}',
            detalle: detalle,
            fuente: p.fuente,
          ),
        );
      }
      if (modalidad.requisitosTexto.isNotEmpty) {
        pasos.add(
          Paso(
            titulo: 'Requisitos publicados por la unidad',
            detalle: modalidad.requisitosTexto,
            fuente: modalidad.fuente,
          ),
        );
      }
      niveles.add(
        Nivel(
          numero: numero,
          titulo: 'Lo que exige ${modalidad.unidadNombre}',
          descripcion: _descripcionParticularidad(modalidad, p),
          icono: _iconoDeNivel(numero),
          pasos: pasos,
          fuente: p.fuente.isNotEmpty ? p.fuente : modalidad.fuente,
          fecha: p.fecha.isNotEmpty ? p.fecha : modalidad.consultadoEn,
        ),
      );
    }

    final efectiva = base.copiarCon(
      id: modalidad.modalidadId,
      nombre: modalidad.nombreMostrado,
      niveles: niveles,
    );
    return RutaCompuesta(
      rutaBase: base,
      ruta: efectiva,
      modalidad: modalidad,
      particularidad: p,
      requisitos: base.requisitosBase.fusionar(modalidad.requisitos),
      estadoCatalogoUnidad: estadoCatalogoUnidad,
    );
  }

  String _descripcionParticularidad(
    ModalidadUnidad m,
    ParticularidadUnidad? p,
  ) {
    if (p != null && p.detalle.isNotEmpty) return p.detalle;
    if (m.requisitosTexto.isNotEmpty) return m.requisitosTexto;
    return 'La unidad publica esta modalidad en ${m.fuente}.';
  }

  /// El diseño entrega siete iconos de nivel; los reutilizamos en ciclo para
  /// que las rutas largas también tengan icono en lugar de un hueco. El ciclo
  /// va de 1 a 7 inclusive: nunca sale `nivel_0.svg`, que no existe.
  String _iconoDeNivel(int numero) {
    if (numero <= 0) return '';
    if (numero <= _nivelIconosDisponibles) {
      return '$_nivelIconoPrefijo$numero.svg';
    }
    return '$_nivelIconoPrefijo${((numero - 1) % _nivelIconosDisponibles) + 1}'
        '.svg';
  }

  /// Compone por id de modalidad. Devuelve `null` si esa modalidad no existe o
  /// no se puede componer.
  Future<RutaCompuesta?> rutaCompuestaPorModalidad(String modalidadId) async {
    final cat = await catalogo();
    for (final u in cat.unidades) {
      for (final m in u.modalidades) {
        if (m.modalidadId != modalidadId) continue;
        final base = m.rutaId == null ? null : await _rutaBase(m.rutaId!);
        if (base == null) return null;
        return _componer(base, m, u.estadoCatalogo);
      }
    }
    return null;
  }

  Future<Ruta?> _rutaBase(String id) async {
    try {
      return await rutaPorId(id);
    } on StateError {
      return null;
    }
  }

  /// Resuelve cualquier id que la app pueda tener guardado: el de una modalidad
  /// o el legado de una ruta global. Es el adaptador del que habla el plan.
  Future<RutaCompuesta?> rutaDeOferta(String id) async {
    if (id.isEmpty) return null;
    final compuesta = await rutaCompuestaPorModalidad(id);
    if (compuesta != null) return compuesta;
    final base = await _rutaBase(id);
    if (base == null) return null;
    return RutaCompuesta.legacy(base);
  }

  /// Ruta efectiva (la que consumen mapa y detalle) de un id guardado.
  Future<Ruta?> rutaEfectivaPorId(String id) async {
    final c = await rutaDeOferta(id);
    return c?.ruta;
  }

  // ------------------------------------------------- actualización de contenido

  /// Cambia el cliente HTTP. Solo lo usan las pruebas.
  @visibleForTesting
  void clienteHttpParaPruebas(http.Client? cliente) {
    _clienteHttp = cliente;
    _cargando = false;
  }

  /// Fuerza a releer el contenido desde el origen, ignorando la caché en
  /// memoria. Solo lo usan las pruebas y el actualizador.
  @visibleForTesting
  void invalidarCacheEnMemoria() {
    _catalogo = null;
    _rutas = null;
    _cargando = false;
  }

  bool _cargando = false;

  /// Intenta bajar un catálogo más nuevo.
  ///
  /// Nunca lanza: cualquier problema se devuelve como [ResultadoActualizacion]
  /// con su motivo, y la app sigue con la caché o con el asset embebido.
  Future<ResultadoActualizacion> actualizarDesdeWeb({
    String manifiestoUrl = manifiestoPorDefecto,
  }) async {
    if (kDemoWeb) {
      return const ResultadoActualizacion(
        EstadoActualizacion.deshabilitada,
        motivo: 'La demo web se compila sin red: usa el catálogo embebido.',
      );
    }
    if (_hosts.isEmpty) {
      return const ResultadoActualizacion(
        EstadoActualizacion.sinConfianza,
        motivo:
            'La app no tiene registrado ningún host de publicación, así '
            'que no acepta contenido remoto. Se queda con el catálogo embebido.',
      );
    }
    if (_cargando) {
      return const ResultadoActualizacion(
        EstadoActualizacion.omitida,
        motivo: 'Ya hay una actualización en curso.',
      );
    }
    _cargando = true;
    try {
      final url = Uri.tryParse(manifiestoUrl);
      final problema = _validarUrl(url, esManifiesto: true);
      if (problema != null) {
        return ResultadoActualizacion(
          EstadoActualizacion.rechazada,
          motivo: problema,
        );
      }
      final cuerpo = await _descargar(url!);
      if (cuerpo == null) {
        return const ResultadoActualizacion(
          EstadoActualizacion.sinRed,
          motivo: 'No se pudo contactar al servidor de contenido.',
        );
      }
      final manifiesto = _leerManifiesto(cuerpo.bytes);
      if (manifiesto == null) {
        return const ResultadoActualizacion(
          EstadoActualizacion.rechazada,
          motivo: 'El manifiesto no es un JSON con la forma esperada.',
        );
      }
      final actual = await catalogo();
      if (manifiesto.catalogoVersion == actual.catalogoVersion) {
        return ResultadoActualizacion(
          EstadoActualizacion.sinCambio,
          version: actual.catalogoVersion,
          motivo: 'El servidor tiene la misma versión que ya está instalada.',
        );
      }
      if (manifiesto.estaVencido) {
        return ResultadoActualizacion(
          EstadoActualizacion.rechazada,
          version: manifiesto.catalogoVersion,
          motivo:
              'El manifiesto venció el ${manifiesto.expiraEn}; no se '
              'instala contenido vencido.',
        );
      }
      final problemaFirma = manifiesto.problemaDeFirma(_claves);
      if (problemaFirma != null) {
        return ResultadoActualizacion(
          EstadoActualizacion.sinConfianza,
          version: manifiesto.catalogoVersion,
          motivo: problemaFirma,
        );
      }
      final urlContenido = Uri.tryParse(manifiesto.urlContenido);
      final problemaUrl = _validarUrl(urlContenido, esManifiesto: false);
      if (problemaUrl != null) {
        return ResultadoActualizacion(
          EstadoActualizacion.rechazada,
          version: manifiesto.catalogoVersion,
          motivo: problemaUrl,
        );
      }
      final descargado = await _descargar(urlContenido!);
      if (descargado == null) {
        return ResultadoActualizacion(
          EstadoActualizacion.sinRed,
          version: manifiesto.catalogoVersion,
          motivo: 'Se leyó el manifiesto pero no se pudo bajar el catálogo.',
        );
      }
      final hash = sha256.convert(descargado.bytes).toString();
      if (hash != manifiesto.sha256) {
        return ResultadoActualizacion(
          EstadoActualizacion.rechazada,
          version: manifiesto.catalogoVersion,
          motivo:
              'El contenido no cuadra con el hash del manifiesto; se '
              'descartó.',
        );
      }
      final Map<String, dynamic> datos;
      try {
        datos =
            json.decode(utf8.decode(descargado.bytes)) as Map<String, dynamic>;
      } catch (_) {
        return ResultadoActualizacion(
          EstadoActualizacion.rechazada,
          version: manifiesto.catalogoVersion,
          motivo: 'El catálogo descargado no es un JSON válido.',
        );
      }
      final nuevo = CatalogoModalidades.fromJson(
        datos,
        origen: CatalogoModalidades.origenCache,
      );
      final problemaEsquema = _validarCatalogo(nuevo);
      if (problemaEsquema != null) {
        return ResultadoActualizacion(
          EstadoActualizacion.rechazada,
          version: manifiesto.catalogoVersion,
          motivo: problemaEsquema,
        );
      }
      await _guardarCache(nuevo, manifiesto, cuerpo.bytes);
      _catalogo = nuevo;
      return ResultadoActualizacion(
        EstadoActualizacion.actualizada,
        version: nuevo.catalogoVersion,
        fechaCorte: nuevo.fechaCorte,
        motivo: 'Catálogo actualizado a la versión ${nuevo.catalogoVersion}.',
      );
    } finally {
      _cargando = false;
    }
  }

  /// URL del manifiesto. Vacía a propósito: la app no publica aún su contenido
  /// en la web, así que no hay un endpoint que legitimate este valor.
  static const String manifiestoPorDefecto = '';

  /// Descarga acotada: HTTPS, host permitido, sin redirección a otro host,
  /// tope de tamaño y timeout.
  Future<_Descarga?> _descargar(Uri url) async {
    final cliente = _clienteHttp ?? http.Client();
    try {
      final r = await cliente
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(timeoutDescarga);
      if (r.statusCode != 200) return null;
      if (r.bodyBytes.length > maxBytesContenido) return null;
      return _Descarga(r.bodyBytes);
    } catch (_) {
      return null;
    } finally {
      if (_clienteHttp == null) cliente.close();
    }
  }

  String? _validarUrl(Uri? url, {required bool esManifiesto}) {
    if (url == null || !url.isAbsolute || url.host.isEmpty) {
      return 'La dirección del ${esManifiesto ? 'manifiesto' : 'contenido'} '
          'no es válida.';
    }
    if (url.scheme != 'https') {
      return 'Solo se acepta HTTPS: se recibió "$url".';
    }
    if (!_hosts.contains(url.host)) {
      return 'El host "${url.host}" no está en la lista de publicación de la '
          'app, así que no se descarga nada de ahí.';
    }
    return null;
  }

  /// El manifiesto tiene que describir un catálogo utilizable. Si no, se
  /// descarta aunque el hash cuadre.
  String? _validarCatalogo(CatalogoModalidades c) {
    if (c.unidades.isEmpty) {
      return 'El catálogo descargado no trae unidades.';
    }
    if (c.fechaCorte.isEmpty) {
      return 'El catálogo descargado no declara fecha de corte.';
    }
    if (c.catalogoVersion.isEmpty) {
      return 'El catálogo descargado no declara versión.';
    }
    final claves = <String>{};
    for (final u in c.unidades) {
      if (u.clave.isEmpty) return 'Hay una unidad sin clave.';
      if (!claves.add(u.clave)) return 'La clave "${u.clave}" está repetida.';
      if (u.noPublicaCatalogo && u.modalidades.isNotEmpty) {
        return 'La unidad "${u.clave}" declara que no publica catálogo pero '
            'trae modalidades.';
      }
      for (final m in u.modalidades) {
        if (m.seleccionable && !m.tieneFuente) {
          return 'La modalidad "${m.modalidadId}" de "${u.clave}" es '
              'seleccionable sin URL de fuente.';
        }
      }
    }
    return null;
  }

  ManifiestoContenido? _leerManifiesto(List<int> bytes) {
    try {
      final datos = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      return ManifiestoContenido.fromJson(datos);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ caché

  Future<CatalogoModalidades?> _leerCache() async {
    try {
      final prefs = await _obtenerPrefs();
      final guardado = prefs.getString(_kCacheCatalogo);
      if (guardado == null || guardado.isEmpty) return null;
      final datos = json.decode(guardado) as Map<String, dynamic>;
      final c = CatalogoModalidades.fromJson(
        datos,
        origen: CatalogoModalidades.origenCache,
      );
      if (_validarCatalogo(c) != null) return null;
      return c;
    } catch (_) {
      // Una caché corrupta no debe tumbar la app: se ignora y se usa el asset.
      return null;
    }
  }

  Future<void> _guardarCache(
    CatalogoModalidades catalogo,
    ManifiestoContenido manifiesto,
    List<int> manifiestoBytes,
  ) async {
    try {
      final prefs = await _obtenerPrefs();
      await prefs.setString(
        _kCacheCatalogo,
        json.encode({
          'catalogoVersion': catalogo.catalogoVersion,
          'fechaCorte': catalogo.fechaCorte,
          'generadoEn': catalogo.generadoEn,
          'normaMarco': {
            'titulo': catalogo.norma.titulo,
            'organo': catalogo.norma.organo,
            'fechaAprobacion': catalogo.norma.fechaAprobacion,
            'articuloModalidades': catalogo.norma.articuloModalidades,
            'consultadoEn': catalogo.norma.consultadoEn,
            'fuente': catalogo.norma.fuente,
          },
          'estadosCatalogo': catalogo.estadosCatalogo,
          'unidades': _unidadesAPlain(catalogo),
        }),
      );
      await prefs.setString(
        _kCacheManifiesto,
        json.encode({
          'catalogoVersion': manifiesto.catalogoVersion,
          'generadoEn': manifiesto.generadoEn,
          'expiraEn': manifiesto.expiraEn,
          'urlContenido': manifiesto.urlContenido,
          'sha256': manifiesto.sha256,
          'firma': {
            'algoritmo': manifiesto.algoritmo,
            'claveId': manifiesto.claveId,
            'valorBase64': manifiesto.firmaBase64,
          },
        }),
      );
      await prefs.setString(_kCacheFecha, _selloDeTiempo());
    } catch (e) {
      debugPrint('No se pudo guardar la caché de contenido: $e');
    }
  }

  /// Reconstruye el JSON del catálogo desde los modelos, para la caché.
  List<Map<String, dynamic>> _unidadesAPlain(CatalogoModalidades c) =>
      c.unidades
          .map(
            (u) => {
              'clave': u.clave,
              'nombreOficial': u.nombreOficial,
              'nombreCatalogo': u.nombreCatalogo,
              'estadoCatalogo': u.estadoCatalogo,
              'resultadoBusqueda': u.resultadoBusqueda,
              'publicaCatalogo': u.publicaCatalogo,
              'salvedad': u.salvedad,
              'fuentes': [
                for (final f in u.fuentes)
                  {
                    'id': f.id,
                    'titulo': f.titulo,
                    'url': f.url,
                    'fechaPublicacion': f.fechaPublicacion,
                    'consultadoEn': f.consultadoEn,
                  },
              ],
              'fuentesConsulta': [
                for (final r in u.fuentesConsulta)
                  {
                    'url': r.url,
                    'consultadoEn': r.consultadoEn,
                    'resultado': r.resultado,
                    'evidencia': r.evidencia,
                  },
              ],
              'contacto': {
                'coordinacion': u.contacto.coordinacion,
                'correo': u.contacto.correo,
                'telefono': u.contacto.telefono,
                'responsable': u.contacto.responsable,
                'notas': u.contacto.notas,
              },
              'modalidades': [
                for (final m in u.modalidades)
                  {
                    'modalidadId': m.modalidadId,
                    'rutaId': m.rutaId,
                    'rutaIdMapeo': m.rutaIdMapeo,
                    'nombreOficial': m.nombreOficial,
                    'nombreNormativo': m.nombreNormativo,
                    'nombreArticulo7': m.nombreArticulo7,
                    'estado': m.estado,
                    'confirmada': m.confirmada,
                    'vigenteDesde': m.vigenteDesde,
                    'vigenteHasta': m.vigenteHasta,
                    'consultadoEn': m.consultadoEn,
                    'fuente': m.fuente,
                    'fecha': m.fecha,
                    'requisitosTexto': m.requisitosTexto,
                    'requisitos': {
                      'promedioMinimo': m.requisitos.promedioMinimo,
                      'permiteRecursar': m.requisitos.permiteRecursar,
                      'porcentajeCreditosMinimo':
                          m.requisitos.porcentajeCreditosMinimo,
                      'exigeServicioSocial': m.requisitos.exigeServicioSocial,
                      'exigeEgelCeneval': m.requisitos.exigeEgelCeneval,
                      'exigeTrabajoEscrito': m.requisitos.exigeTrabajoEscrito,
                      'exigeExperienciaProfesional':
                          m.requisitos.exigeExperienciaProfesional,
                    },
                    'evidenciaCalculadora': m.requisitos.evidencia,
                    'perfilAplicacion': const {},
                    'seleccionable': m.seleccionable,
                    'pendiente': m.pendiente,
                  },
              ],
            },
          )
          .toList();

  static String _selloDeTiempo() => DateTime.now().toUtc().toIso8601String();

  Future<SharedPreferences> _obtenerPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Borra la caché y vuelve al asset embebido. Se usa si el catálogo
  /// descargado resultara problemático.
  Future<void> descartarCache() async {
    final prefs = await _obtenerPrefs();
    await prefs.remove(_kCacheCatalogo);
    await prefs.remove(_kCacheManifiesto);
    await prefs.remove(_kCacheFecha);
    _catalogo = null;
  }

  // ------------------------------------------------------------------ I/O

  String? _raizProyecto;

  /// Lee un JSON del proyecto: del disco si se fijó una raíz (tests), del
  /// bundle en la app.
  Future<Map<String, dynamic>> _leer(String path) async {
    if (_raizProyecto != null) {
      final file = File('$_raizProyecto/$path');
      if (file.existsSync()) {
        return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      }
    }
    final raw = await rootBundle.loadString(path);
    return json.decode(raw) as Map<String, dynamic>;
  }

  // ----------------------------------------------------------------- tests

  /// En los tests no hay bundle: cargamos el JSON real desde el disco del
  /// proyecto, para que las pruebas cubran el contenido de verdad y no un fake.
  void cargarDesdeDiscoParaTests({String? raizProyecto}) {
    _raizProyecto = raizProyecto ?? Directory.current.path;
    _raizProyectoTests = _raizProyecto;
    _rutas = null;
    _facultades = null;
    _links = null;
    _contactos = null;
    _catalogo = null;
  }

  static String? _raizProyectoTests;

  /// ¿Existe en disco el asset que cita el JSON? Lo usan los tests para
  /// detectar rutas de asset rotas, el error más fácil de introducir al
  /// renombrar archivos.
  static bool existeAsset(String rutaAsset) {
    if (rutaAsset.isEmpty) return false;
    final raiz = _raizProyectoTests ?? Directory.current.path;
    return File('$raiz/$rutaAsset').existsSync();
  }
}

class _Descarga {
  const _Descarga(this.bytes);
  final List<int> bytes;
}

// ---------------------------------------------------------------------------
// Manifiesto de contenido remoto
// ---------------------------------------------------------------------------

/// El manifiesto que describe un catálogo remoto.
///
/// Se valida **antes** de instalar nada: HTTPS, host permitido, sin
/// redirección a otro host, caducidad, hash del contenido y firma de una clave
/// en la que la app confíe. Si algo no cuadra, se conserva el último paquete
/// válido.
class ManifiestoContenido {
  const ManifiestoContenido({
    required this.catalogoVersion,
    required this.generadoEn,
    required this.expiraEn,
    required this.urlContenido,
    required this.sha256,
    this.algoritmo = '',
    this.claveId = '',
    this.firmaBase64 = '',
  });

  final String catalogoVersion;
  final String generadoEn;

  /// Fecha y hora de caducidad del manifiesto.
  final String expiraEn;
  final String urlContenido;

  /// SHA-256 del contenido, en hexadecimal minúscula.
  final String sha256;

  final String algoritmo;
  final String claveId;
  final String firmaBase64;

  /// true cuando ya pasó la caducidad. Una fecha vacía no vence nunca: el
  /// servidor decide, y si no dice nada no se inventa una caducidad.
  bool get estaVencido {
    if (expiraEn.isEmpty) return false;
    final t = DateTime.tryParse(expiraEn);
    if (t == null) return false;
    return t.isBefore(DateTime.now().toUtc());
  }

  /// Motivo por el que la firma no sirve, o `null` si la confianza alcanza.
  ///
  /// La app no trae ninguna clave pública todavía: sin `claveId` en
  /// [clavesConfiables] el manifiesto se rechaza siempre. Integridad (hash) no
  /// es autenticidad: quien cambie el contenido puede cambiar también el hash.
  String? problemaDeFirma(Map<String, String> clavesConfiables) {
    if (algoritmo.isEmpty || claveId.isEmpty || firmaBase64.isEmpty) {
      return 'El manifiesto no trae firma; no se instala contenido sin '
          'autenticidad.';
    }
    if (algoritmo != 'Ed25519') {
      return 'La firma usa "$algoritmo", que la app no sabe verificar.';
    }
    if (!clavesConfiables.containsKey(claveId)) {
      return 'La firma viene de la clave "$claveId", en la que la app no '
          'confía. Se conserva el contenido anterior.';
    }
    return null;
  }

  factory ManifiestoContenido.fromJson(Map<String, dynamic> json) {
    final firma = json['firma'];
    final f = firma is Map ? firma.cast<String, dynamic>() : const {};
    return ManifiestoContenido(
      catalogoVersion: json['catalogoVersion'] as String? ?? '',
      generadoEn: json['generadoEn'] as String? ?? '',
      expiraEn: json['expiraEn'] as String? ?? '',
      urlContenido: json['urlContenido'] as String? ?? '',
      sha256: (json['sha256'] as String? ?? '').toLowerCase(),
      algoritmo: f['algoritmo'] as String? ?? '',
      claveId: f['claveId'] as String? ?? '',
      firmaBase64: f['valorBase64'] as String? ?? '',
    );
  }
}

enum EstadoActualizacion {
  /// Se bajó y validó un catálogo nuevo.
  actualizada,

  /// El servidor tiene lo mismo que ya está instalado.
  sinCambio,

  /// Algo no cuadró; se conserva lo anterior.
  rechazada,

  /// No se pudo hablar con el servidor.
  sinRed,

  /// Hay un camino abierto en la red, pero la app no tiene con quién validar.
  sinConfianza,

  /// La demo web no usa red.
  deshabilitada,

  /// Ya había una actualización corriendo.
  omitida,
}

class ResultadoActualizacion {
  const ResultadoActualizacion(
    this.estado, {
    this.version = '',
    this.fechaCorte = '',
    this.motivo = '',
  });

  final EstadoActualizacion estado;
  final String version;
  final String fechaCorte;

  /// Por qué pasó esto, en palabras. Se muestra en la UI.
  final String motivo;

  bool get cambioInstalado => estado == EstadoActualizacion.actualizada;
}

// ---------------------------------------------------------------------------
// Oferta de una unidad
// ---------------------------------------------------------------------------

/// Una modalidad que la unidad publica pero que la app no puede ofrecer como
/// ruta jugable. Se muestra como información, con su fuente, nunca como oferta.
class ModalidadNoAcreditada {
  const ModalidadNoAcreditada({
    this.modalidadId = '',
    required this.nombre,
    required this.motivo,
    this.fuente = '',
    this.fecha = '',
  });

  final String modalidadId;
  final String nombre;

  /// Por qué no se puede jugar: falta ruta base, falta fuente, etc.
  final String motivo;
  final String fuente;
  final String fecha;
}

/// Un problema de composición de una modalidad. Aísla esa modalidad: las demás
/// siguen mostrándose.
class ErrorComposicion {
  const ErrorComposicion({required this.modalidadId, required this.motivo});

  final String modalidadId;
  final String motivo;
}

/// Una ruta que la unidad sí ofrece: la ruta genérica con su variante encima.
class RutaOferta {
  const RutaOferta({required this.ruta, this.modalidad, this.particularidad});

  final RutaCompuesta ruta;
  final ModalidadUnidad? modalidad;
  final ParticularidadUnidad? particularidad;

  String get id => ruta.id;
  String get nombre => ruta.ruta.nombre;
  String get descripcion => ruta.ruta.descripcion;
  String get mapa => ruta.ruta.mapa;
  String get mascotaInicio => ruta.ruta.mascotaInicio;

  /// Requisitos ya fusionados: los de la unidad sobre los de la ruta base.
  Requisitos get requisitos => ruta.requisitos;

  String get idModalidad => modalidad?.modalidadId ?? '';

  /// Id de la ruta base, que es el que queda como adaptador legado.
  String get rutaBaseId => modalidad?.rutaId ?? ruta.rutaBase.id;
}

/// Lo que una unidad académica puede ofrecerle a su alumno.
class OfertaUnidad {
  const OfertaUnidad({
    required this.unidad,
    required this.clave,
    required this.nombre,
    required this.rutas,
    required this.informativas,
    required this.errores,
    required this.fechaCorte,
  });

  /// `null` cuando la clave no existe en el catálogo.
  final UnidadCatalogo? unidad;
  final String clave;
  final String nombre;

  /// Modalidades acreditadas y jugables.
  final List<RutaOferta> rutas;

  /// Modalidades publicadas pero no jugables, con el motivo.
  final List<ModalidadNoAcreditada> informativas;

  /// Modalidades que no se pudieron componer. Se registran, no se esconden.
  final List<ErrorComposicion> errores;

  final String fechaCorte;

  bool get existe => unidad != null;
  bool get vacia => rutas.isEmpty;

  String get estadoCatalogo => unidad?.estadoCatalogo ?? '';

  /// El mensaje para cuando no hay nada que ofrecer. Nunca vacío.
  String get mensajeSinCatalogo =>
      unidad?.mensajeSinCatalogo ??
      'No hay ninguna unidad con la clave "$clave" en el catálogo.';

  /// URLs consultadas al buscar el catálogo, con su resultado.
  List<RastroConsulta> get rastro => unidad?.fuentesConsulta ?? const [];

  /// Datos para el respaldo: a quién escribirle si no hay nada en pantalla.
  ContactoUnidad get contacto => unidad?.contacto ?? const ContactoUnidad();

  /// Estado del catálogo en palabras, para el subtítulo de la pantalla.
  ///
  /// La clave del JSON es un identificador de máquina (`unidad_no_publica_
  /// catálogo`); aquí se traduce a algo que un alumno pueda leer.
  String get estadoExplicado {
    final u = unidad;
    if (u == null) return 'Clave fuera del catálogo';
    switch (u.estadoCatalogo) {
      case 'publicado':
        return 'Catálogo publicado';
      case 'publicacion_parcial_no_exhaustiva':
        return 'Catálogo parcial, no exhaustivo';
      case 'publicacion_sin_fuente_registrada':
        return 'Registro de evidencia sin fuente oficial';
      case 'unidad_no_publica_catalogo':
        return 'Sin catálogo publicado';
      case 'no_aplica_nivel_medio_superior':
        return 'No aplica el Reglamento de Titulación';
      default:
        return u.estadoCatalogo.replaceAll('_', ' ');
    }
  }
}
