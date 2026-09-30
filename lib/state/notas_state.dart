import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las notas que el alumno escribe en cada nivel.
///
/// ## Dónde viven
///
/// En su propia clave de preferencias, [clavePref], que **no** es ninguna de las
/// del esquema de estado de [AppState] (versión 1: `alumno`, `facultad`,
/// `ruta`, `progreso`; versión 2: `estadoSchema`, `modalidadActiva`,
/// `rutaActivaBase`, `contextoAlumno`, `migracionesProgreso`). Por eso el
/// esquema de avance no se entera y no se rompe si este archivo falta.
///
/// ## Cómo se nombran
///
/// Por espacio de nombres y número de nivel, igual que el avance:
/// `modalidad:ceneval-fcc` → `3` → "el examen es el 14 de noviembre". La nota
/// de una modalidad nunca aparece en otra, aunque compartan ruta base.
class NotasState extends ChangeNotifier {
  NotasState(this._prefs) {
    _cargar();
  }

  final SharedPreferences _prefs;

  /// Clave propia de las notas. Namespace `notasTitulacion`.
  static const String clavePref = 'notasTitulacionV1';

  /// Versión del formato de notas, por si algún día hay que migrarlo.
  static const int versionNotas = 1;

  Map<String, Map<int, String>> _notas = {};

  // ------------------------------------------------------------------ lectura

  /// La nota de un nivel, o cadena vacía si no hay.
  String textoDe(String namespace, int nivel) =>
      _notas[namespace]?[nivel] ?? '';

  /// Cuántas notas tiene el alumno en un espacio de nombres.
  int totalDe(String namespace) => _notas[namespace]?.length ?? 0;

  /// Todos los niveles con nota, para los listados y para el respaldo.
  Map<int, String> nivelesDe(String namespace) =>
      Map<int, String>.from(_notas[namespace] ?? const {});

  /// Copia de todo, para exportar.
  Map<String, Map<int, String>> todas() => {
    for (final e in _notas.entries) e.key: Map<int, String>.from(e.value),
  };

  // ------------------------------------------------------------------ escritura

  /// Guarda o borra la nota de un nivel. Texto vacío = borrar.
  Future<void> guardar(String namespace, int nivel, String texto) async {
    final limpio = texto.trim();
    final actual = Map<int, String>.from(_notas[namespace] ?? const {});
    if (limpio.isEmpty) {
      if (actual.remove(nivel) == null) return;
    } else {
      if (actual[nivel] == limpio) return;
      actual[nivel] = limpio;
    }
    _notas = {..._notas};
    if (actual.isEmpty) {
      _notas.remove(namespace);
    } else {
      _notas[namespace] = actual;
    }
    await _persistir();
    notifyListeners();
  }

  Future<void> _persistir() async {
    await _prefs.setString(
      clavePref,
      json.encode({'version': versionNotas, 'notas': _serializar(_notas)}),
    );
  }

  void _cargar() {
    final crudo = _prefs.getString(clavePref);
    if (crudo == null) return;
    try {
      final m = json.decode(crudo);
      if (m is! Map) return;
      final notas = m['notas'];
      if (notas is! Map) return;
      _notas = _deserializar(notas);
    } catch (_) {
      // Notas corruptas: se arrancan en cero en vez de no arrancar.
      _notas = {};
    }
  }

  // -------------------------------------------------------------- serialización

  /// `"ns": {"3": "texto"}` — JSON no admite claves numéricas, por eso el
  /// nivel va como texto.
  static Map<String, dynamic> _serializar(Map<String, Map<int, String>> notas) => {
    for (final e in notas.entries)
      e.key: {for (final n in e.value.entries) '${n.key}': n.value},
  };

  static Map<String, Map<int, String>> _deserializar(Map<dynamic, dynamic> crudo) {
    final salida = <String, Map<int, String>>{};
    for (final e in crudo.entries) {
      final ns = e.key?.toString() ?? '';
      if (ns.isEmpty || e.value is! Map) continue;
      final niveles = <int, String>{};
      for (final n in (e.value as Map).entries) {
        final numero = int.tryParse(n.key.toString());
        final texto = n.value?.toString() ?? '';
        if (numero == null || numero < 0 || texto.trim().isEmpty) continue;
        niveles[numero] = texto;
      }
      if (niveles.isNotEmpty) salida[ns] = niveles;
    }
    return salida;
  }

  /// Parte de un respaldo. `null` si el bloque no trae la forma esperada: el
  /// que llama decide si eso es un error o solo una nota que no venía.
  static Map<String, Map<int, String>>? desdeRespaldo(dynamic jsonNotas) {
    if (jsonNotas is! Map) return null;
    return _deserializar(jsonNotas);
  }

  /// Escribe un bloque de respaldo encima de lo que hay.
  ///
  /// `reemplazar` deja las notas que no venían intactas; es lo mismo que hace
  /// la restauración del avance.
  Future<int> aplicarDesdeRespaldo(
    Map<String, Map<int, String>> notas, {
    bool reemplazar = false,
  }) async {
    if (reemplazar) _notas = {};
    var escritas = 0;
    for (final e in notas.entries) {
      final destino = Map<int, String>.from(_notas[e.key] ?? const {});
      for (final n in e.value.entries) {
        if (destino[n.key] == n.value) continue;
        destino[n.key] = n.value;
        escritas++;
      }
      if (destino.isEmpty) {
        _notas = {..._notas}..remove(e.key);
      } else {
        _notas = {..._notas, e.key: destino};
      }
    }
    if (escritas == 0) return 0;
    await _persistir();
    notifyListeners();
    return escritas;
  }
}
