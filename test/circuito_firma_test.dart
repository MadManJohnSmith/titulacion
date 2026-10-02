import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titulacion/services/content_repository.dart';

/// Comprueba el contrato entre el que publica y el que verifica.
///
/// `tools/publicar_contenido.sh` firma con OpenSSL y la app verifica con Dart.
/// Los dos tienen que construir **la misma cadena canónica**: si uno pone un
/// salto de línea final y el otro no, ninguna firma cuadra y la app nunca
/// instala contenido. Esta prueba genera una clave temporal, publica con el
/// script y pasa el manifiesto por el verificador real.
///
/// La clave que la app lleva embebida se comprueba aparte, abajo: lo que no
/// se puede comprobar aquí es que esa clave en concreto sea la buena, porque
/// la privada no está en el repositorio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String publicaB64;
  late ManifiestoContenido manifiesto;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('circuito');
    final raiz = Directory.current.path;

    // Clave temporal: el circuito se prueba sin la clave de publicación.
    final gen = await Process.run(
      'openssl',
      ['genpkey', '-algorithm', 'ed25519', '-out', '${dir.path}/c.pem'],
    );
    expect(gen.exitCode, 0, reason: 'openssl no generó la clave');

    // A archivo: la salida DER son bytes binarios y Process.run los
    // decodificaría como texto, con lo que se pierde.
    final pub = await Process.run('openssl', [
      'pkey',
      '-in',
      '${dir.path}/c.pem',
      '-pubout',
      '-outform',
      'DER',
      '-out',
      '${dir.path}/pub.der',
    ]);
    expect(pub.exitCode, 0, reason: 'openssl no exportó la pública');
    // Los 32 bytes crudos de la pública: el script y la app no usan PEM.
    final der = File('${dir.path}/pub.der').readAsBytesSync();
    publicaB64 = base64Encode(der.sublist(der.length - 32));

    final res = await Process.run('bash', [
      '$raiz/tools/publicar_contenido.sh',
      '${dir.path}/c.pem',
      'https://ejemplo.invalid/loboapp',
      dir.path,
    ]);
    expect(res.exitCode, 0, reason: 'el publicador falló: ${res.stderr}');

    final bytes =
        File('${dir.path}/contenido/manifiesto.json').readAsBytesSync();
    manifiesto = ManifiestoContenido.fromJson(
      json.decode(utf8.decode(bytes)) as Map<String, dynamic>,
    );

    // Lo que el manifiesto describe tiene que ser lo que se publica.
    final servido = File('${dir.path}/contenido/catalogo_modalidades.json')
        .readAsBytesSync();
    expect(
      sha256.convert(servido).toString(),
      manifiesto.sha256,
      reason: 'el hash del manifiesto no cuadra con el archivo publicado',
    );
    expect(
      json.decode(utf8.decode(servido))['catalogoVersion'],
      manifiesto.catalogoVersion,
    );
  });

  tearDownAll(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Map<String, String> clavesFirmadas() => {
    'loboapp-contenido-v1': publicaB64,
  };

  test('la app acepta el manifiesto que firma el publicador', () async {
    expect(manifiesto.algoritmo, 'Ed25519');
    expect(manifiesto.claveId, 'loboapp-contenido-v1');
    expect(
      await manifiesto.problemaDeFirma(clavesFirmadas()),
      isNull,
      reason: 'el script y la app no construyen la misma cadena firmada',
    );
  });

  test('cambiar cualquier campo del manifiesto rompe la firma', () async {
    final base = <String, dynamic>{
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
    };
    for (final campo in [
      'sha256',
      'expiraEn',
      'urlContenido',
      'catalogoVersion',
      'generadoEn',
    ]) {
      final copia = Map<String, dynamic>.from(base);
      copia[campo] = 'alterado';
      expect(
        await ManifiestoContenido.fromJson(copia).problemaDeFirma(clavesFirmadas()),
        isNotNull,
        reason: 'cambiar "$campo" no rompió la firma',
      );
    }
  });

  test('la firma no sirve con otra clave', () async {
    expect(
      await manifiesto.problemaDeFirma(const {
        'loboapp-contenido-v1':
            'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      }),
      isNotNull,
      reason: 'una clave distinta tambien debe rechazar el manifiesto',
    );
  });

  group('La clave que la app lleva embebida', () {
    test('es una Ed25519 pública válida', () {
      final clave = ContentRepository.clavesPublicasConfiables[
        'loboapp-contenido-v1'
      ];
      expect(clave, isNotNull, reason: 'la app no trae clave de confianza');
      final bytes = base64Decode(clave!);
      expect(bytes.length, 32, reason: 'una Ed25519 pública son 32 bytes');
    });

    test('el host de publicación está declarado y es el que se usa', () {
      expect(
        ContentRepository.hostsPermitidos,
        contains('madmanjohnsmith.github.io'),
      );
      expect(
        ContentRepository.manifiestoPorDefecto,
        startsWith('https://madmanjohnsmith.github.io/'),
        reason: 'la URL por defecto tiene que estar en la lista de hosts',
      );
      expect(
        Uri.parse(ContentRepository.manifiestoPorDefecto).host,
        ContentRepository.hostsPermitidos.first,
        reason: 'si el manifiesto fuera a otro host, se rechazaría siempre',
      );
    });
  });
}