import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// Busca alumnos en la base de la BUAP empaquetada en la app.
///
/// La base son 318 mil alumnos (~2.9 MB comprimidos) y viene partida por
/// cohorte: si el alumno escribe su matrícula, el prefijo de 4 dígitos dice en
/// qué archivo está, y solo se descompresa ese. Buscar por nombre sí necesita
/// todos, así que esa búsqueda es la lenta.
///
/// Solo se guarda matrícula y nombre: los correos no se empaquetan.
class StudentRepository {
  StudentRepository._();

  static final StudentRepository instance = StudentRepository._();

  Map<String, List<Alumno>>? _cohortes;
  Map<String, String> _rutasPorCohorte = const {};
  bool _cargandoIndice = false;

  /// Carga el índice de archivos (barato). Las cohortes se cargan bajo demanda.
  Future<void> _cargarIndice() async {
    if (_cohortes != null || _cargandoIndice) return;
    _cargandoIndice = true;
    try {
      final raw = await rootBundle.loadString('assets/alumnos/index.json');
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

    final data = await rootBundle.load(ruta);
    final texto = utf8.decode(
      GZipDecoder().decodeBytes(data.buffer.asUint8List()),
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

    // Búsqueda por nombre: recorre todas las cohortes.
    final minuscula = q.toLowerCase();
    for (final cohorte in _rutasPorCohorte.keys) {
      await _cargarCohorte(cohorte);
    }
    for (final lista in _cohortes!.values) {
      for (final a in lista) {
        if (a.nombre.toLowerCase().contains(minuscula)) return a;
      }
    }
    return null;
  }

  /// Devuelve hasta [limite] coincidencias parciales, para el autocompletado.
  Future<List<Alumno>> sugerencias(String query, {int limite = 8}) async {
    final q = query.trim().toLowerCase();
    if (q.length < 3) return const [];
    await _cargarIndice();
    if (_cohortes == null) return const [];

    final encontrados = <Alumno>[];
    for (final cohorte in _rutasPorCohorte.keys) {
      await _cargarCohorte(cohorte);
    }
    for (final lista in _cohortes!.values) {
      for (final a in lista) {
        if (a.nombre.toLowerCase().contains(q)) {
          encontrados.add(a);
          if (encontrados.length >= limite) return encontrados;
        }
      }
    }
    return encontrados;
  }
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
