import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titulacion/services/content_repository.dart';

/// Prueba de extremo a extremo con la clave real de publicación.
///
/// Genera el manifiesto con `tools/publicar_contenido.sh` (OpenSSL firma) y lo
/// pasa por el mismo verificador que usa la app. Si el script y el Dart no
/// construyen la misma cadena canónica, esto falla.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const claveId = 'loboapp-contenido-v1';
  late ManifiestoContenido manifiesto;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('circuito');
    final raiz = Directory.current.path;
    final res = await Process.run(
      'bash',
      ['$raiz/tools/publicar_contenido.sh',
       '/home/alan/Documents/LoboApp-signing-backup/contenido-loboapp/loboapp-contenido-v1.pem',
       'https://madmanjohnsmith.github.io/LoboApp',
       dir.path],
    );
    expect(res.exitCode, 0, reason: 'el publicador falló: ${res.stderr}');
    final bytes = File('${dir.path}/contenido/manifiesto.json').readAsBytesSync();
    manifiesto = ManifiestoContenido.fromJson(
      json.decode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
    // El contenido firmado debe ser el mismo que se publica.
    final servido = File('${dir.path}/contenido/catalogo_modalidades.json')
        .readAsBytesSync();
    expect(
      sha256.convert(servido).toString(),
      manifiesto.sha256,
      reason: 'el hash del manifiesto no cuadra con el archivo publicado',
    );
  });

  test('la app acepta el manifiesto firmado con la clave real', () async {
    final problema = await manifiesto.problemaDeFirma(
      ContentRepository.clavesPublicasConfiables,
    );
    expect(problema, isNull);
    expect(manifiesto.claveId, claveId);
    expect(manifiesto.sha256, isNotEmpty);
    expect(manifiesto.urlContenido,
        'https://madmanjohnsmith.github.io/LoboApp/contenido/catalogo_modalidades.json');
  });

  test('cambiar cualquier campo rompe la firma', () async {
    for (final campo in ['sha256', 'expiraEn', 'urlContenido', 'catalogoVersion']) {
      final copia = Map<String, dynamic>.from({
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
      });
      copia[campo] = 'alterado';
      final problema = await ManifiestoContenido.fromJson(copia)
          .problemaDeFirma(ContentRepository.clavesPublicasConfiables);
      expect(problema, isNotNull, reason: 'cambiar "$campo" no rompió la firma');
    }
  });
}
