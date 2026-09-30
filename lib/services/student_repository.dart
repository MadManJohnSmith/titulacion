import 'dart:convert';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../demo.dart';
import '../models/models.dart';

/// Busca alumnos en la base de la BUAP empaquetada en la app.
///
/// La base son 318 mil alumnos (~2.9 MB comprimidos) y viene partida por
/// cohorte: si el alumno escribe su matrícula, el prefijo de 4 dígitos dice en
/// qué archivo está, y solo se descomprime ese. Buscar por nombre sí necesita
/// todos, así que esa búsqueda se hace **fuera del isolate de la interfaz**:
/// descomprimir y recorrer 318 mil nombres es CPU y memoria, y en el isolate de
/// la UI congelaba la pantalla al teclear.
///
/// Solo se guarda matrícula y nombre: los correos no se empaquetan.
class StudentRepository {
  StudentRepository._();

  static final StudentRepository instance = StudentRepository._();

  Map<String, List<Alumno>>? _cohortes;
  Map<String, String> _rutasPorCohorte = const {};
  bool _cargandoIndice = false;

  /// Etiqueta del isolate donde corre la búsqueda por nombre.
  ///
  /// Es lo que permite distinguir, incluso en las pruebas, si el trabajo pesado
  /// salió del isolate de la interfaz o no.
  static const String etiquetaIsolateDeBusqueda = 'loboapp-busqueda-nombre';

  /// Etiqueta del isolate en el que corrió la última búsqueda por nombre.
  /// Vacío = todavía no se ha buscado por nombre.
  @visibleForTesting
  static String? ultimoIsolateDeBusqueda;

  /// Assets que las pruebas hacen fallar a propósito. Vacío = ninguno.
  ///
  /// Es la base que no llegó a empaquetarse: la pantalla que la consulta tiene
  /// que decirlo y dejar de girar.
  @visibleForTesting
  static Set<String> assetsRotosDePrueba = const {};

  /// Cohortes que quedaron residentes en memoria. 0 = no se cargó ninguna.
  @visibleForTesting
  int get cohortesEnMemoria => _cohortes?.length ?? 0;

  /// Olvida el índice y las cohortes en memoria, para que cada prueba parta de
  /// cero.
  @visibleForTesting
  void invalidarCacheEnMemoria() {
    _cohortes = null;
    _rutasPorCohorte = const {};
    _cargandoIndice = false;
  }

  /// false solo en la demo web, que no trae la base dentro del bundle.
  static bool get busquedaDisponible => !kDemoWeb;

  /// Lee los bytes de un asset del padrón, o falla como fallaría en la app.
  Future<Uint8List> _bytesDeCohorte(String ruta) async {
    if (assetsRotosDePrueba.contains(ruta)) {
      throw StateError('No se pudo leer el asset "$ruta"');
    }
    final data = await rootBundle.load(ruta);
    return data.buffer.asUint8List();
  }

  /// Carga el índice de archivos (barato). Las cohortes se cargan bajo demanda.
  Future<void> _cargarIndice() async {
    if (_cohortes != null || _cargandoIndice) return;
    _cargandoIndice = true;
    try {
      const indiceAsset = 'assets/alumnos/index.json';
      if (assetsRotosDePrueba.contains(indiceAsset)) {
        throw StateError('No se pudo leer el asset "$indiceAsset"');
      }
      final raw = await rootBundle.loadString(indiceAsset);
      final data = json.decode(raw) as Map<String, dynamic>;
      final cohortes = data['cohorts'] as Map<String, dynamic>;
      _rutasPorCohorte = {
        for (final entry in cohortes.entries)
          entry.key: (entry.value as Map<String, dynamic>)['archivo'] as String,
      };
      _cohortes = {};
    } catch (e) {
      _cohortes = {};
      _rutasPorCohorte = const {};
      rethrow;
    } finally {
      _cargandoIndice = false;
    }
  }

  Future<void> _cargarCohorte(String cohorte) async {
    if (_cohortes == null) await _cargarIndice();
    if (_cohortes!.containsKey(cohorte)) return;

    final ruta = _rutasPorCohorte[cohorte];
    if (ruta == null) return;

    final bytes = await _bytesDeCohorte(ruta);
    final texto = utf8.decode(
      GZipDecoder().decodeBytes(bytes),
      allowMalformed: true,
    );

    final lista = <Alumno>[];
    for (final linea in texto.split('\n')) {
      if (linea.isEmpty) continue;
      final corte = linea.indexOf('\t');
      if (corte <= 0) continue;
      final matricula = linea.substring(0, corte);
      final nombre = linea.substring(corte + 1).trim();
      if (nombre.isEmpty) continue;
      lista.add(Alumno(nombre: nombre, matricula: matricula));
    }
    _cohortes![cohorte] = lista;
  }

  /// Busca por matrícula exacta, o por nombre si no parece una matrícula.
  ///
  /// Devuelve null si no encuentra nada. Si hay varios con el mismo nombre
  /// devuelve el primero: el alumno confirma luego con su matrícula.
  Future<Alumno?> buscar(String query, {int limite = 20}) async {
    final q = query.trim();
    if (q.length < 3) return null;
    if (kDemoWeb) return null;
    await _cargarIndice();
    if (_cohortes == null) return null;

    final esMatricula = DigitosMatricula().esMatricula(q);

    if (esMatricula && q.length >= 4) {
      final cohorte = q.substring(0, 4);
      if (_rutasPorCohorte.containsKey(cohorte)) {
        await _cargarCohorte(cohorte);
        for (final a in _cohortes![cohorte]!) {
          if (a.matricula == q) return a;
        }
        // Matrícula no encontrada en su cohorte: no existe en la base.
        return null;
      }
    }

    // Búsqueda por nombre: recorre todas las cohortes, pero en otro isolate.
    return _buscarPorNombreLejosDeLaInterfaz(q);
  }

  /// Búsqueda por nombre sin tocar el isolate de la interfaz.
  ///
  /// Leer los ~3 MB comprimidos es E/S y puede quedar aquí; descomprimir y
  /// recorrer 318 mil nombres es CPU y memoria, y eso va a [_primerAlumnoPorNombre]
  /// en un isolate aparte. El padrón tampoco se queda guardado en memoria: solo
  /// vuelve la coincidencia.
  Future<Alumno?> _buscarPorNombreLejosDeLaInterfaz(String query) async {
    final minuscula = query.trim().toLowerCase();
    final cohortes = <Uint8List>[];
    for (final ruta in _rutasPorCohorte.values) {
      cohortes.add(await _bytesDeCohorte(ruta));
    }
    if (cohortes.isEmpty) return null;

    final resultado = await compute(
      _primerAlumnoPorNombre,
      _PeticionBusqueda(cohortes, minuscula),
      debugLabel: etiquetaIsolateDeBusqueda,
    );
    ultimoIsolateDeBusqueda = resultado.isolate;
    return resultado.alumno;
  }
}

/// Lo que viaja al isolate: los bytes ya leídos y el texto que se busca.
class _PeticionBusqueda {
  const _PeticionBusqueda(this.cohortes, this.minuscula);

  final List<Uint8List> cohortes;
  final String minuscula;
}

/// Lo que vuelve del isolate: la coincidencia y dónde se ejecutó.
class _ResultadoBusqueda {
  const _ResultadoBusqueda(this.alumno, this.isolate);

  final Alumno? alumno;
  final String isolate;
}

/// Corre en un isolate aparte (`compute`), nunca en el de la interfaz.
///
/// No construye la lista completa de alumnos: solo el que coincide, para no
/// retener los 318 mil en memoria mientras la persona escribe.
_ResultadoBusqueda _primerAlumnoPorNombre(_PeticionBusqueda peticion) {
  final isolate = Isolate.current.debugName ?? '';
  for (final bytes in peticion.cohortes) {
    final texto = utf8.decode(
      GZipDecoder().decodeBytes(bytes),
      allowMalformed: true,
    );
    for (final linea in texto.split('\n')) {
      if (linea.isEmpty) continue;
      final corte = linea.indexOf('\t');
      if (corte <= 0) continue;
      final nombre = linea.substring(corte + 1).trim();
      if (nombre.isEmpty) continue;
      if (nombre.toLowerCase().contains(peticion.minuscula)) {
        return _ResultadoBusqueda(
          Alumno(nombre: nombre, matricula: linea.substring(0, corte)),
          isolate,
        );
      }
    }
  }
  return _ResultadoBusqueda(null, isolate);
}

/// Detecta si un texto parece una matrícula de la BUAP (9 dígitos, cohorte 2020+).
class DigitosMatricula {
  bool esMatricula(String texto) {
    final t = texto.trim();
    if (t.length != 9) return false;
    if (!RegExp(r'^\d{9}$').hasMatch(t)) return false;
    final cohorte = int.tryParse(t.substring(0, 4));
    return cohorte != null && cohorte >= 1990 && cohorte <= 2100;
  }

  /// Deja solo dígitos, para tolerar que el alumno teclee espacios o guiones.
  String normalizar(String texto) => texto.replaceAll(RegExp(r'\D'), '');
}
