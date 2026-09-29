import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/models.dart';

/// Carga el contenido de la app desde `assets/json/`.
///
/// Los archivos se cachean en memoria: la app carga las rutas una vez al
/// arrancar y no vuelve a leer el disco.
class ContentRepository {
  ContentRepository._();

  static final ContentRepository instance = ContentRepository._();

  List<Ruta>? _rutas;
  List<Facultad>? _facultades;
  List<LinkBuap>? _links;
  List<Contacto>? _contactos;

  Future<List<Ruta>> rutas() async {
    if (_rutas != null) return _rutas!;
    final data = await _leer('assets/json/routes.json');
    final lista = (data['rutas'] as List<dynamic>)
        .map((e) => Ruta.fromJson(e as Map<String, dynamic>))
        .toList();
    return _rutas = lista;
  }

  Future<List<Facultad>> facultades() async {
    if (_facultades != null) return _facultades!;
    final data = await _leer('assets/json/facultades.json');
    final lista = (data['facultades'] as List<dynamic>)
        .map((e) => Facultad.fromJson(e as Map<String, dynamic>))
        .toList();
    return _facultades = lista;
  }

  Future<List<LinkBuap>> links() async {
    if (_links != null) return _links!;
    final data = await _leer('assets/json/links.json');
    final lista = (data['links'] as List<dynamic>)
        .map((e) => LinkBuap.fromJson(e as Map<String, dynamic>))
        .toList();
    return _links = lista;
  }

  Future<List<Contacto>> contactos() async {
    if (_contactos != null) return _contactos!;
    final data = await _leer('assets/json/contactos.json');
    final lista = (data['contactos'] as List<dynamic>)
        .map((e) => Contacto.fromJson(e as Map<String, dynamic>))
        .toList();
    return _contactos = lista;
  }

  /// Busca una ruta por su id. Lanza si no existe: un id mal escrito es un
  /// error de programación, no algo que el usuario pueda provoke.
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
