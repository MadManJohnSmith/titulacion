import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F-08: la demo web que publica `.github/workflows/pages.yml` no debe salir
/// con los metadatos de la plantilla de Flutter.
///
/// La prueba lee los archivos reales que `flutter build web` copia a la demo
/// (`web/manifest.json` y `web/index.html`) y falla si conservan el nombre, la
/// descripción o el color de la plantilla, y si no publican los valores reales
/// de LoboApp. No hay build de web ni copia: los mismos archivos del producto.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Sin acentos ni mayúsculas, para que "titulación" cuente como
  /// "titulacion": la plantilla no se esconde con una tilde.
  String plano(String s) {
    const mapa = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
      'Á': 'a',
      'É': 'e',
      'Í': 'i',
      'Ó': 'o',
      'Ú': 'u',
      'Ü': 'u',
      'Ñ': 'n',
    };
    final buffer = StringBuffer();
    for (final rune in s.runes) {
      final c = String.fromCharCode(rune);
      buffer.write(mapa[c] ?? c);
    }
    return buffer.toString().toLowerCase();
  }

  late String manifest;
  late String index;

  setUpAll(() {
    final raiz = Directory.current.path;
    for (final relativo in const ['web/manifest.json', 'web/index.html']) {
      expect(
        File('$raiz/$relativo').existsSync(),
        isTrue,
        reason: 'la demo web publica $relativo y la prueba debe leerlo real',
      );
    }
    manifest = File('$raiz/web/manifest.json').readAsStringSync();
    index = File('$raiz/web/index.html').readAsStringSync();
  });

  group('F-08: la demo web sale con la identidad de LoboApp', () {
    test('ni el manifiesto ni la portada conservan el nombre de la plantilla', () {
      const publicados = ['web/manifest.json', 'web/index.html'];
      for (final archivo in publicados) {
        final texto = archivo.endsWith('.json') ? manifest : index;
        expect(
          plano(texto).contains('titulacion'),
          isFalse,
          reason:
              '$archivo todavía dice "titulacion": la pestaña, la PWA y la '
              'ficha de la web se publican con el nombre de la plantilla',
        );
        expect(
          plano(texto).contains('a new flutter project'),
          isFalse,
          reason: '$archivo todavía trae la descripción de la plantilla',
        );
        expect(
          plano(texto).contains('#0175c2'),
          isFalse,
          reason:
              '$archivo todavía trae el color de la plantilla en lugar del '
              'azul marino de LoboApp',
        );
      }
    });

    test('el manifiesto publica el nombre, la descripción y el color reales', () {
      final datos =
          json.decode(manifest) as Map<String, dynamic>;

      expect(datos['name'], 'LoboApp');
      expect(datos['short_name'], 'LoboApp');
      expect(datos['description'], isA<String>());
      expect((datos['description'] as String).trim(), isNotEmpty);
      // LoboColors.navy: el fondo con el que arranca la app.
      expect(datos['theme_color'], '#0B233A');
      expect(datos['background_color'], '#0B233A');
    });

    test('la portada repite el título y la descripción de LoboApp', () {
      final datos = json.decode(manifest) as Map<String, dynamic>;

      expect(index, contains('<title>LoboApp</title>'));
      expect(
        index,
        contains('<meta name="apple-mobile-web-app-title" content="LoboApp">'),
      );
      expect(
        index,
        contains('content="${datos['description']}"'),
        reason: 'la pestaña del navegador y la ficha PWA deben decir lo mismo',
      );
    });

    test('la descripción del paquete tampoco es la de la plantilla', () {
      final pubspec = File('${Directory.current.path}/pubspec.yaml')
          .readAsStringSync();
      final descripcion = pubspec
          .split('\n')
          .firstWhere((l) => l.startsWith('description:'));

      expect(plano(descripcion).contains('a new flutter project'), isFalse);
    });
  });
}
