import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Estado global de la app: quién es el alumno, en qué facultad está, qué ruta
/// eligió y hasta dónde llegó.
///
/// Se guarda en `SharedPreferences` en cada cambio, así que cerrar la app no
/// pierde el progreso.
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _cargar();
  }

  final SharedPreferences _prefs;

  static const _kAlumno = 'alumno';
  static const _kFacultad = 'facultad';
  static const _kRuta = 'ruta';
  static const _kProgreso = 'progreso';

  /// Progreso: `rutaId -> [niveles completados]`, y `docs -> "rutaId:nivel:indice"`.
  Map<String, List<int>> _completados = {};
  Set<String> _documentosMarcados = {};

  Alumno? _alumno;
  String? _facultadClave;
  String? _rutaActiva;

  Alumno? get alumno => _alumno;
  String? get facultadClave => _facultadClave;
  String? get rutaActiva => _rutaActiva;
  bool get estaRegistrado => _alumno != null;

  void _cargar() {
    final alumnoJson = _prefs.getString(_kAlumno);
    if (alumnoJson != null) {
      _alumno = Alumno.fromJson(json.decode(alumnoJson) as Map<String, dynamic>);
    }
    _facultadClave = _prefs.getString(_kFacultad);
    _rutaActiva = _prefs.getString(_kRuta);

    final progJson = _prefs.getString(_kProgreso);
    if (progJson != null) {
      final map = json.decode(progJson) as Map<String, dynamic>;
      _completados = map['completados'] == null
          ? <String, List<int>>{}
          : (map['completados'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, (v as List<dynamic>).cast<int>()),
            );
      _documentosMarcados =
          ((map['documentos'] as List<dynamic>?) ?? []).cast<String>().toSet();
    }
  }

  void _guardar() {
    _prefs.setString(
      _kProgreso,
      json.encode({
        'completados': _completados,
        'documentos': _documentosMarcados.toList(),
      }),
    );
  }

  // ---------------------------------------------------------------- alumno

  Future<void> registrar(Alumno alumno, {String? facultadClave}) async {
    _alumno = alumno;
    if (facultadClave != null) _facultadClave = facultadClave;
    await _prefs.setString(_kAlumno, json.encode(alumno.toJson()));
    if (facultadClave != null) {
      await _prefs.setString(_kFacultad, facultadClave);
    }
    notifyListeners();
  }

  Future<void> elegirFacultad(String clave) async {
    _facultadClave = clave;
    await _prefs.setString(_kFacultad, clave);
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    _alumno = null;
    await _prefs.remove(_kAlumno);
    notifyListeners();
  }

  // ----------------------------------------------------------------- rutas

  Future<void> elegirRuta(String rutaId) async {
    _rutaActiva = rutaId;
    await _prefs.setString(_kRuta, rutaId);
    notifyListeners();
  }

  // -------------------------------------------------------------- progreso

  List<int> completadosDe(String rutaId) => _completados[rutaId] ?? const [];

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
    final lista = _completados.putIfAbsent(rutaId, () => <int>[]);
    if (!lista.contains(nivel)) {
      lista.add(nivel);
      lista.sort();
      _guardar();
      await _prefs.setString(_kProgreso, json.encode({
        'completados': _completados,
        'documentos': _documentosMarcados.toList(),
      }));
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- documentos

  String _docKey(String rutaId, int nivel, int indice) => '$rutaId:$nivel:$indice';

  bool documentoMarcado(String rutaId, int nivel, int indice) =>
      _documentosMarcados.contains(_docKey(rutaId, nivel, indice));

  void alternarDocumento(String rutaId, int nivel, int indice) {
    final key = _docKey(rutaId, nivel, indice);
    if (!_documentosMarcados.remove(key)) {
      _documentosMarcados.add(key);
    }
    _prefs.setString(_kProgreso, json.encode({
      'completados': _completados,
      'documentos': _documentosMarcados.toList(),
    }));
    notifyListeners();
  }

  /// Progreso 0..1 de una ruta, para la barra del mapa.
  double progresoDe(String rutaId, int totalNiveles) {
    if (totalNiveles == 0) return 0;
    final hechos = completadosDe(rutaId).where((n) => n <= totalNiveles).length;
    return (hechos / totalNiveles).clamp(0.0, 1.0);
  }
}
