import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'notes_screen.dart';

/// Respaldo y restauración del avance del alumno, en JSON y por el portapapeles.
///
/// ## Por qué el portapapeles
///
/// Es la vía que funciona igual en Android, iOS, web y escritorio sin
/// permisos ni dependencias: `Clipboard` viene en la biblioteca estándar de
/// Flutter (`package:flutter/services.dart`). El alumno copia el bloque, lo
/// pega en un correo o en una nota, y en el otro teléfono lo pega de vuelta.
///
/// ## Qué viaja y qué no
///
/// Viaja el estado legible del alumno (quién es, de qué unidad, qué contexto
/// académico), la oferta que tenía activa, el avance de **esa** oferta y sus
/// notas.
///
/// No viaja el avance de modalidades que ya no tiene activas: `AppState` no
/// expone una forma de enumerar sus espacios de nombres, solo de leer el
/// activo ([AppState.completadosDe]). Por eso el propio bloque dice qué se
/// quedó fuera, en [RespaldoAlumno.alcance]. Ver `problemas` del informe de
/// este frente.
const String tipoRespaldo = 'loboapp-respaldo';
const int versionRespaldo = 1;

/// El bloque JSON del respaldo, ya validado.
class RespaldoAlumno {
  const RespaldoAlumno({
    required this.generadoEn,
    required this.esquemaEstado,
    required this.alumno,
    required this.facultadClave,
    required this.modalidadActiva,
    required this.rutaActiva,
    required this.rutaActivaBase,
    required this.carreraId,
    required this.planId,
    required this.anioIngreso,
    required this.namespace,
    required this.nivelesCompletados,
    required this.documentosMarcados,
    required this.notas,
    required this.alcance,
  });

  final String generadoEn;
  final int esquemaEstado;
  final Alumno? alumno;
  final String? facultadClave;
  final String? modalidadActiva;
  final String? rutaActiva;
  final String? rutaActivaBase;
  final String? carreraId;
  final String? planId;
  final int? anioIngreso;

  /// El espacio de nombres del que viene el avance, `modalidad:<id>` o `rutaId`.
  final String? namespace;
  final List<int> nivelesCompletados;
  final List<String> documentosMarcados;
  final Map<String, Map<int, String>> notas;

  /// Lo que este respaldo **no** lleva, dicho con palabras.
  final List<String> alcance;

  Map<String, dynamic> toJson() => {
    'tipo': tipoRespaldo,
    'version': versionRespaldo,
    'generadoEn': generadoEn,
    'esquemaEstado': esquemaEstado,
    'alumno': alumno?.toJson(),
    'facultadClave': facultadClave,
    'contexto': {
      'carreraId': carreraId,
      'planId': planId,
      'anioIngreso': anioIngreso,
    },
    'oferta': {
      'modalidadActiva': modalidadActiva,
      'rutaActiva': rutaActiva,
      'rutaActivaBase': rutaActivaBase,
    },
    'progreso': {
      'namespace': namespace,
      'nivelesCompletados': nivelesCompletados,
      'documentosMarcados': documentosMarcados,
    },
    'notas': {
      for (final e in notas.entries)
        e.key: {for (final n in e.value.entries) '${n.key}': n.value},
    },
    'alcance': alcance,
  };

  String serializar() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  /// Lee un respaldo. Devuelve `null` si el texto no es un respaldo válido; los
  /// motivos van en [errores], nunca se tragan.
  static RespaldoAlumno? analizar(String texto, List<String> errores) {
    Object? crudo;
    try {
      crudo = json.decode(texto);
    } catch (e) {
      errores.add('El texto no es JSON válido: $e');
      return null;
    }
    if (crudo is! Map) {
      errores.add('El respaldo no es un objeto JSON.');
      return null;
    }
    final m = Map<String, dynamic>.from(crudo);
    if (m['tipo'] != tipoRespaldo) {
      errores.add(
        'El bloque no es un respaldo de LoboApp (tipo: ${m['tipo']}).',
      );
      return null;
    }
    final version = (m['version'] as num?)?.toInt() ?? 0;
    if (version > versionRespaldo) {
      errores.add(
        'El respaldo es de una versión más nueva de la app ($version > '
        '$versionRespaldo): esta versión no sabe leerlo.',
      );
      return null;
    }

    final alumnoJson = m['alumno'];
    Alumno? alumno;
    if (alumnoJson is Map) {
      try {
        alumno = Alumno.fromJson(Map<String, dynamic>.from(alumnoJson));
      } catch (e) {
        errores.add('El alumno del respaldo no se pudo leer: $e');
      }
    }

    final contexto = m['contexto'] is Map
        ? Map<String, dynamic>.from(m['contexto'] as Map)
        : const <String, dynamic>{};
    final oferta = m['oferta'] is Map
        ? Map<String, dynamic>.from(m['oferta'] as Map)
        : const <String, dynamic>{};
    final progreso = m['progreso'] is Map
        ? Map<String, dynamic>.from(m['progreso'] as Map)
        : const <String, dynamic>{};

    return RespaldoAlumno(
      generadoEn: m['generadoEn']?.toString() ?? '',
      esquemaEstado: (m['esquemaEstado'] as num?)?.toInt() ?? 0,
      alumno: alumno,
      facultadClave: _texto(m['facultadClave']),
      modalidadActiva: _texto(oferta['modalidadActiva']),
      rutaActiva: _texto(oferta['rutaActiva']),
      rutaActivaBase: _texto(oferta['rutaActivaBase']),
      carreraId: _texto(contexto['carreraId']),
      planId: _texto(contexto['planId']),
      anioIngreso: (contexto['anioIngreso'] as num?)?.toInt(),
      namespace: _texto(progreso['namespace']),
      nivelesCompletados: _enteros(progreso['nivelesCompletados']),
      documentosMarcados: _textos(progreso['documentosMarcados']),
      notas: NotasState.desdeRespaldo(m['notas']) ?? const {},
      alcance: _textos(m['alcance']),
    );
  }

  static String? _texto(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static List<int> _enteros(dynamic v) {
    if (v is! List) return const [];
    final salida = <int>[];
    for (final e in v) {
      final n = e is num ? e.toInt() : int.tryParse(e.toString());
      if (n != null && !salida.contains(n)) salida.add(n);
    }
    salida.sort();
    return salida;
  }

  static List<String> _textos(dynamic v) {
    if (v is! List) return const [];
    return [for (final e in v) e.toString()].where((e) => e.isNotEmpty).toList();
  }
}

/// Arma el respaldo del estado actual.
///
/// [niveles] son los niveles de la oferta activa; hacen falta para enumerar los
/// documentos marcados. Si son `null`, el avance de niveles sí viaja y el de
/// documentos no, y el respaldo lo dice en [alcance].
String construirRespaldo({
  required AppState state,
  required NotasState notas,
  List<Nivel>? niveles,
  DateTime? ahora,
}) {
  final rutaActiva = state.rutaActiva;
  final ns = rutaActiva == null ? null : state.namespaceDe(rutaActiva);

  final completados = rutaActiva == null ? <int>[] : state.completadosDe(rutaActiva);

  final docs = <String>[];
  if (rutaActiva != null && niveles != null) {
    for (final n in niveles) {
      for (var i = 0; i < n.documentos.length; i++) {
        if (state.documentoMarcado(rutaActiva, n.numero, i)) {
          docs.add('$ns:${n.numero}:$i');
        }
      }
    }
  }

  final alcance = <String>[
    'El avance de modalidades que ya no están activas no viaja: AppState solo '
        'expone el espacio de nombres activo.',
    if (niveles == null && rutaActiva != null)
      'Los documentos marcados no viajan: sin los niveles de la ruta no se '
          'pueden enumerar.',
  ];

  final respaldo = RespaldoAlumno(
    generadoEn:
        '${(ahora ?? DateTime.now()).toUtc().toIso8601String().split('.').first}Z',
    esquemaEstado: state.esquema,
    alumno: state.alumno,
    facultadClave: state.facultadClave,
    modalidadActiva: state.modalidadActiva,
    rutaActiva: rutaActiva,
    rutaActivaBase: state.rutaActivaBase,
    carreraId: _oVacio(state.carreraId),
    planId: _oVacio(state.planId),
    anioIngreso: state.anioIngreso > 0 ? state.anioIngreso : null,
    namespace: ns,
    nivelesCompletados: List<int>.from(completados)..sort(),
    documentosMarcados: docs,
    notas: notas.todas(),
    alcance: alcance,
  );
  return respaldo.serializar();
}

String? _oVacio(String v) => v.trim().isEmpty ? null : v.trim();

/// Lo que una restauración hizo y lo que no pudo hacer.
class InformeRespaldo {
  InformeRespaldo({
    this.respaldo,
    List<String>? errores,
    List<String>? avisos,
    List<String>? aplicados,
  }) : errores = errores ?? <String>[],
       avisos = avisos ?? <String>[],
       aplicados = aplicados ?? <String>[];

  final RespaldoAlumno? respaldo;
  final List<String> errores;
  final List<String> avisos;
  final List<String> aplicados;

  bool get sePuedeRestaurar => respaldo != null && errores.isEmpty;
}

/// Aplica un respaldo sobre el estado del teléfono.
///
/// Solo usa la API pública de [AppState]: registrar, guardar contexto, elegir
/// modalidad, completar nivel y alternar documento. **No** puede borrar: la
/// API no expone esa operación, así que la restauración **suma** lo que falta y
/// deja lo que ya estaba. El informe lo dice, para que nadie lo descubra
/// después.
Future<InformeRespaldo> restaurarRespaldo({
  required AppState state,
  required NotasState notas,
  required RespaldoAlumno respaldo,
  required ContentRepository repo,
}) async {
  final informe = InformeRespaldo(respaldo: respaldo);

  // 1. Alumno y unidad. Sin unidad válida no se toca nada más.
  final a = respaldo.alumno;
  final clave = respaldo.facultadClave;
  if (a == null || a.nombre.trim().isEmpty || a.matricula.trim().isEmpty) {
    informe.avisos.add('El respaldo no trae un alumno completo: no se registró.');
  } else if (clave == null) {
    informe.avisos.add('El respaldo no trae unidad académica: no se registró.');
  } else {
    final facultad = await repo.facultadPorClave(clave);
    if (facultad == null) {
      informe.avisos.add(
        'La unidad "$clave" no existe en el catálogo de esta app: no se '
        'registró el alumno.',
      );
    } else {
      await state.registrar(
        Alumno(
          nombre: a.nombre,
          matricula: a.matricula,
          carrera: a.carrera,
          plan: a.plan,
          anioIngreso: a.anioIngreso,
        ),
        facultadClave: clave,
      );
      informe.aplicados.add('Alumno ${a.matricula} en la unidad $clave.');
    }
  }

  // 2. Contexto académico, si viene.
  if (respaldo.carreraId != null ||
      respaldo.planId != null ||
      respaldo.anioIngreso != null) {
    await state.guardarContexto(
      carreraId: respaldo.carreraId,
      planId: respaldo.planId,
      anioIngreso: respaldo.anioIngreso,
    );
    informe.aplicados.add('Contexto académico (carrera, plan, cohorte).');
  }

  // 3. Oferta activa, solo si la modalidad sigue existiendo en el catálogo.
  final modalidad = respaldo.modalidadActiva;
  if (modalidad != null) {
    final base = respaldo.rutaActivaBase;
    final existe = await _modalidadExiste(repo, modalidad);
    if (!existe) {
      informe.avisos.add(
        'La modalidad "$modalidad" ya no está en el catálogo de esta app: no se '
        'seleccionó.',
      );
    } else if (base == null) {
      informe.avisos.add(
        'La modalidad "$modalidad" no trae ruta base en el respaldo: no se '
        'seleccionó.',
      );
    } else {
      await state.elegirModalidad(modalidad, base);
      informe.aplicados.add('Modalidad $modalidad sobre la ruta $base.');
    }
  }

  // 4. Avance de la oferta activa. Solo suma: la API pública no permite quitar.
  final rutaActiva = state.rutaActiva;
  if (rutaActiva == null) {
    if (respaldo.nivelesCompletados.isNotEmpty ||
        respaldo.documentosMarcados.isNotEmpty) {
      informe.avisos.add(
        'El respaldo trae avance pero no hay oferta activa: elige una '
        'modalidad y vuelve a pegar el respaldo.',
      );
    }
  } else {
    var niveles = 0;
    for (final n in respaldo.nivelesCompletados) {
      if (n <= 0 || state.estaCompletado(rutaActiva, n)) continue;
      await state.completarNivel(rutaActiva, n);
      niveles++;
    }
    var docs = 0;
    for (final claveDoc in respaldo.documentosMarcados) {
      final partes = claveDoc.split(':');
      if (partes.length < 3) continue;
      final n = int.tryParse(partes[partes.length - 2]);
      final i = int.tryParse(partes[partes.length - 1]);
      if (n == null || i == null || n <= 0 || i < 0) continue;
      if (state.documentoMarcado(rutaActiva, n, i)) continue;
      // `alternarDocumento` es síncrono en AppState: no se espera.
      state.alternarDocumento(rutaActiva, n, i);
      docs++;
    }
    informe.aplicados.add(
      'Avance: $niveles ${niveles == 1 ? 'nivel' : 'niveles'} y $docs '
      '${docs == 1 ? 'documento' : 'documentos'} nuevos.',
    );
    informe.avisos.add(
      'La restauración suma avance; no borra el que ya estaba en el teléfono.',
    );
  }

  // 5. Notas.
  final escritas = await notas.aplicarDesdeRespaldo(respaldo.notas);
  if (escritas > 0) {
    informe.aplicados.add('$escritas notas escritas.');
  } else if (respaldo.notas.isNotEmpty) {
    informe.avisos.add('Las notas del respaldo ya estaban todas en el teléfono.');
  }

  if (respaldo.alcance.isNotEmpty) {
    for (final a2 in respaldo.alcance) {
      informe.avisos.add('El respaldo de origen avisa: $a2');
    }
  }
  return informe;
}

Future<bool> _modalidadExiste(ContentRepository repo, String modalidadId) async {
  final cat = await repo.catalogo();
  for (final u in cat.unidades) {
    for (final m in u.modalidades) {
      if (m.modalidadId == modalidadId) return true;
    }
  }
  return false;
}

/// Pantalla de respaldo: copia el estado al portapapeles y lo restaura desde
/// ahí.
///
/// Los dosPorts puede inyectarse para probar sin canal de plataforma.
class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.state,
    required this.notas,
    this.repo,
    this.escribirPortapapeles,
    this.leerPortapapeles,
  });

  final AppState state;
  final NotasState notas;
  final ContentRepository? repo;

  /// Por defecto, `Clipboard.setData`. Se inyecta en las pruebas.
  final Future<void> Function(String texto)? escribirPortapapeles;

  /// Por defecto, `Clipboard.getData('text/plain')`. Se inyecta en las pruebas.
  final Future<String?> Function()? leerPortapapeles;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final ContentRepository _repo = widget.repo ?? ContentRepository.instance;

  String _json = '';
  List<Nivel>? _niveles;
  InformeRespaldo? _informe;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargarRuta();
  }

  Future<void> _cargarRuta() async {
    final id = widget.state.rutaActiva;
    if (id == null) {
      if (mounted) setState(() => _niveles = null);
      return;
    }
    final ruta = await _repo.rutaEfectivaPorId(id);
    if (!mounted) return;
    setState(() => _niveles = ruta?.niveles);
  }

  String _construir() => construirRespaldo(
    state: widget.state,
    notas: widget.notas,
    niveles: _niveles,
  );

  Future<void> _exportar() async {
    setState(() => _ocupado = true);
    final texto = _construir();
    await (widget.escribirPortapapeles ?? _copiar)(texto);
    if (!mounted) return;
    setState(() {
      _json = texto;
      _informe = null;
      _ocupado = false;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Respaldo copiado al portapapeles.')),
    );
  }

  static Future<void> _copiar(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
  }

  static Future<String?> _pegar() async {
    final d = await Clipboard.getData('text/plain');
    return d?.text;
  }

  Future<void> _revisar() async {
    final texto =
        await (widget.leerPortapapeles ?? _pegar)();
    if (!mounted) return;
    if (texto == null || texto.trim().isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('El portapapeles está vacío.')),
      );
      return;
    }
    final errores = <String>[];
    final r = RespaldoAlumno.analizar(texto, errores);
    setState(() => _informe = InformeRespaldo(respaldo: r, errores: errores));
  }

  Future<void> _restaurar() async {
    final informe = _informe;
    if (informe == null || !informe.sePuedeRestaurar) return;
    setState(() => _ocupado = true);
    final nuevo = await restaurarRespaldo(
      state: widget.state,
      notas: widget.notas,
      respaldo: informe.respaldo!,
      repo: _repo,
    );
    if (!mounted) return;
    setState(() {
      _informe = nuevo;
      _ocupado = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo de mi avance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Qué sale y qué entra',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'El respaldo lleva quién eres, de qué unidad vienes, la modalidad '
            'que tienes activa, los niveles que ya completaste, los documentos '
            'que marcaste y tus notas. Se copia como texto JSON al portapapeles, '
            'sin enviarlo a ningún servidor.',
            style: TextStyle(height: 1.5, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _ocupado ? null : _exportar,
            icon: const Icon(Icons.copy),
            label: const Text('Copiar mi respaldo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _ocupado ? null : _revisar,
            icon: const Icon(Icons.content_paste),
            label: const Text('Pegar un respaldo y revisarlo'),
          ),
          if (_json.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Así quedó el respaldo:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _json,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
          if (_informe != null) ...[
            const Divider(height: 32, color: Colors.white12),
            _seccion('Revisión', _informe!),
            if (_informe!.sePuedeRestaurar &&
                _informe!.aplicados.isEmpty) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _ocupado ? null : _restaurar,
                icon: const Icon(Icons.restore),
                label: const Text('Restaurar este respaldo'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _seccion(String titulo, InformeRespaldo informe) {
    final vacio =
        informe.errores.isEmpty &&
        informe.avisos.isEmpty &&
        informe.aplicados.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (vacio)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Sin novedades.'),
          ),
        for (final e in informe.errores)
          Text(
            '· $e',
            style: const TextStyle(color: Color(0xFFE5735D), fontSize: 13),
          ),
        for (final a in informe.avisos)
          Text(
            '· $a',
            style: const TextStyle(color: LoboColors.gold, fontSize: 13),
          ),
        for (final a in informe.aplicados)
          Text(
            '· $a',
            style: const TextStyle(color: Color(0xFF5BD07E), fontSize: 13),
          ),
      ],
    );
  }
}
