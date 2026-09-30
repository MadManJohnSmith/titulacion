import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../demo.dart';

/// Un trabajador de la BUAP, del directorio empacado en la app.
class Trabajador {
  const Trabajador({
    required this.matricula,
    required this.nombre,
    this.correo = '',
  });

  final String matricula;
  final String nombre;

  /// Vacío si la persona no tiene correo institucional publicado.
  final String correo;

  bool get tieneCorreo => correo.isNotEmpty;
}

/// Busca en el directorio de trabajadores de la BUAP (43 mil personas).
///
/// La base no trae la unidad académica de cada persona, así que **no se puede
/// filtrar por facultad**: la búsqueda es por nombre o matrícula. Solo se
/// empaquetan los correos institucionales (`@correo.buap.mx`); los personales
/// quedan fuera.
class StaffRepository {
  StaffRepository._();

  static final StaffRepository instance = StaffRepository._();

  List<Trabajador>? _lista;
  bool _cargando = false;

  /// false solo en la demo web, que no trae el directorio dentro del bundle.
  static bool get busquedaDisponible => !kDemoWeb;

  /// Assets que las pruebas hacen fallar a propósito. Vacío = ninguno.
  ///
  /// Reproduce el directorio que no llega a estar en el bundle: la pantalla
  /// tiene que decirlo y dejar de buscar, no quedarse girando.
  @visibleForTesting
  static Set<String> assetsRotosDePrueba = const {};

  /// Olvida la lista en memoria, para que cada prueba parta de cero.
  @visibleForTesting
  void invalidarCacheEnMemoria() {
    _lista = null;
    _cargando = false;
  }

  Future<List<Trabajador>> _cargar() async {
    if (_lista != null) return _lista!;
    if (_cargando) return const [];
    _cargando = true;
    try {
      const indiceAsset = 'assets/trabajadores/index.json';
      if (assetsRotosDePrueba.contains(indiceAsset)) {
        throw StateError('No se pudo leer el asset "$indiceAsset"');
      }
      final indice = json.decode(
        await rootBundle.loadString(indiceAsset),
      ) as Map<String, dynamic>;
      final ruta = indice['archivo'] as String;

      final data = await rootBundle.load(ruta);
      final texto = utf8.decode(
        GZipDecoder().decodeBytes(data.buffer.asUint8List()),
        allowMalformed: true,
      );

      final lista = <Trabajador>[];
      for (final linea in texto.split('\n')) {
        if (linea.isEmpty) continue;
        final p = linea.split('\t');
        if (p.length < 2) continue;
        lista.add(Trabajador(
          matricula: p[0],
          nombre: p[1].trim(),
          correo: p.length > 2 ? p[2].trim() : '',
        ));
      }
      return _lista = lista;
    } finally {
      _cargando = false;
    }
  }

  /// Busca por matrícula exacta, o por nombre si no parece una matrícula.
  Future<List<Trabajador>> buscar(String query, {int limite = 30}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    if (kDemoWeb) return const [];
    final lista = await _cargar();
    if (lista.isEmpty) return const [];

    // Matrícula de 9 dígitos: coincidencia exacta, rápida.
    if (RegExp(r'^\d{9}$').hasMatch(q)) {
      for (final t in lista) {
        if (t.matricula == q) return [t];
      }
      return const [];
    }

    final minuscula = q.toLowerCase();
    final encontrados = <Trabajador>[];
    for (final t in lista) {
      if (t.nombre.toLowerCase().contains(minuscula)) {
        encontrados.add(t);
        if (encontrados.length >= limite) break;
      }
    }
    return encontrados;
  }
}
