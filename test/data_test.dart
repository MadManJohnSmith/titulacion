import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titulacion/models/models.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vgc;

/// Comprueba que el proyecto no vuelva a empaquetar padrones de personas y que
/// los datos que sí se distribuyen (mapas, catálogo) sigan enteros.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory raiz;

  setUpAll(() {
    raiz = Directory.current;
  });

  /// Los tests no tienen bundle: aqui leemos los archivos del proyecto igual.
  Map<String, dynamic> leerIndice(String ruta) {
    final f = File('${raiz.path}/$ruta');
    expect(f.existsSync(), isTrue, reason: 'falta $ruta');
    return json.decode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  group('Privacidad: ningún padrón de personas viaja en el paquete', () {
    /// El padrón de alumnos (318 mil) y el de trabajadores (43 mil, con
    /// matrícula y correo institucional) se distribuían dentro del APK sin
    /// ninguna forma de dar acceso controlado a esa información. Se quitaron.
    ///
    /// Estas pruebas son la red que evita que vuelvan: si alguien reintroduce
    /// los archivos, la suite falla aquí y no en una auditoría posterior.
    for (final carpeta in ['assets/alumnos', 'assets/trabajadores']) {
      test('$carpeta no existe en el repositorio', () {
        expect(
          Directory('${raiz.path}/$carpeta').existsSync(),
          isFalse,
          reason:
              '$carpeta volvió al proyecto. Son datos personales de personas '
              'que no se pueden consultar sin registro; no se empaquetan.',
        );
      });
    }

    test('ningún asset del paquete es un padrón comprimido de personas', () {
      final pubspec = File('${raiz.path}/pubspec.yaml').readAsStringSync();
      for (final carpeta in ['assets/alumnos/', 'assets/trabajadores/']) {
        expect(
          pubspec,
          isNot(contains(carpeta)),
          reason: 'pubspec.yaml vuelve a declarar $carpeta como asset',
        );
      }
    });

    test('ningún .tsv.gz quedó suelto en assets/', () {
      final encontrados = Directory('${raiz.path}/assets')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.tsv.gz'))
          .map((f) => f.path)
          .toList();
      expect(
        encontrados,
        isEmpty,
        reason: 'Hay padrones en el proyecto: $encontrados',
      );
    });

    test('el código no busca alumnos ni trabajadores por padrón', () {
      final codigo = Directory('${raiz.path}/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      for (final simbolo in [
        'StudentRepository',
        'StaffRepository',
        'Trabajador(',
        'assets/alumnos',
        'assets/trabajadores',
      ]) {
        expect(
          codigo,
          isNot(contains(simbolo)),
          reason: 'lib/ vuelve a usar "$simbolo"',
        );
      }
    });
  });

  group('Detección de matrícula', () {
    final d = DigitosMatricula();

    test('acepta matrículas de 9 dígitos', () {
      expect(d.esMatricula('202145678'), isTrue);
      expect(d.esMatricula(' 202145678 '), isTrue);
    });

    test('rechaza lo que no es una matrícula', () {
      expect(d.esMatricula('20214567'), isFalse); // 8 dígitos
      expect(d.esMatricula('2021456789'), isFalse); // 10
      expect(d.esMatricula('María López'), isFalse);
      expect(d.esMatricula(''), isFalse);
      expect(d.esMatricula('abcdefghi'), isFalse);
      expect(d.esMatricula('189012345'), isFalse); // cohorte imposible
    });

    test('normaliza lo que el alumno teclea con guiones o espacios', () {
      expect(d.normalizar('2021-458-78'), '202145878');
      expect(d.normalizar('2021 458 78'), '202145878');
      expect(d.normalizar('202145678'), '202145678');
    });
  });

  // Defecto (d) del inventario: un asset que el JSON cita pero que no existe,
  // o que existe pero está corrupto, se ve roto en la app sin que nadie lo note
  // hasta que un alumno lo abre. Estas pruebas lo cortan de raíz.
  group('Assets citados por routes.json', () {
    /// Todas las rutas de asset que el JSON menciona, con el campo del que sale.
    Map<String, List<String>> referencias() {
      final data = leerIndice('assets/json/routes.json');
      final out = <String, List<String>>{};

      void anota(String? path, String campo) {
        if (path == null || path.isEmpty) return;
        (out[path] ??= <String>[]).add(campo);
      }

      for (final r in data['rutas'] as List<dynamic>) {
        final ruta = r as Map<String, dynamic>;
        anota(ruta['mascotaInicio'] as String?, '${ruta['id']}.mascotaInicio');
        anota(
          ruta['pergaminoInicio'] as String?,
          '${ruta['id']}.pergaminoInicio',
        );
        anota(ruta['tituloAsset'] as String?, '${ruta['id']}.tituloAsset');
        anota(
          ruta['descripcionAsset'] as String?,
          '${ruta['id']}.descripcionAsset',
        );
        anota(ruta['mapa'] as String?, '${ruta['id']}.mapa');
        for (final n in (ruta['niveles'] as List<dynamic>? ?? [])) {
          final nivel = n as Map<String, dynamic>;
          final id = '${ruta['id']}/${nivel['numero']}';
          anota(nivel['icono'] as String?, '$id.icono');
          anota(nivel['mascota'] as String?, '$id.mascota');
          anota(nivel['fondo'] as String?, '$id.fondo');
        }
      }
      return out;
    }

    test(
      'el JSON cita al menos un asset (si no, la prueba no vigila nada)',
      () {
        final refs = referencias();
        expect(
          refs.length,
          greaterThan(20),
          reason: 'routes.json dejó de citar assets: revisa el esquema',
        );
      },
    );

    test('todo asset citado existe en disco y no está vacío', () {
      final rotos = <String>[];
      referencias().forEach((path, campos) {
        final f = File('${raiz.path}/$path');
        if (!f.existsSync()) {
          rotos.add('$path (lo cita ${campos.join(", ")}): no existe en disco');
        } else if (f.lengthSync() == 0) {
          rotos.add(
            '$path (lo cita ${campos.join(", ")}): el archivo está vacío',
          );
        }
      });
      expect(rotos, isEmpty, reason: 'assets rotos:\n${rotos.join("\n")}');
    });

    test('todo SVG citado se puede parsear como SVG válido', () {
      // Este es el defecto (d): un .svg truncado, renombrado o con XML roto
      // deja la pantalla vacía aunque el archivo "esté ahí". Se parsea de
      // verdad con el mismo compilador que usa flutter_svg en la app.
      final rotos = <String>[];
      var revisados = 0;
      referencias().forEach((path, campos) {
        if (!path.toLowerCase().endsWith('.svg')) return;
        revisados++;
        final texto = File(
          '${raiz.path}/$path',
        ).readAsStringSync(encoding: utf8);
        try {
          final dibujo = vgc.parseWithoutOptimizers(texto, key: path);
          // Un SVG que no dibuja nada es tan roto como uno que no compila:
          // el alumno vería el hueco sin entender por qué.
          if (dibujo.commands.isEmpty) {
            rotos.add(
              '$path (lo cita ${campos.join(", ")}): el SVG no trae '
              'ningún dibujo, así que en pantalla saldría vacío',
            );
          }
        } catch (e) {
          rotos.add(
            '$path (lo cita ${campos.join(", ")}): no se puede parsear '
            'como SVG → $e.\n'
            '    Causa conocida: si el <svg> raíz va con prefijo de espacio '
            'de nombres (por ejemplo <ns0:svg xmlns:ns0=…>), flutter_svg no lo '
            'reconoce y no dibuja nada. El arreglo es reescribir el archivo '
            'con el espacio de nombres por defecto (xmlns="http://www.w3.org/'
            '2000/svg") y los elementos sin prefijo.',
          );
        }
      });
      expect(
        revisados,
        greaterThan(10),
        reason: 'la prueba tiene que revisar los SVG de verdad',
      );
      expect(rotos, isEmpty, reason: 'SVG inválidos:\n${rotos.join("\n")}');
    });

    test('los mapas raster citados son PNG legibles', () {
      final firmaPng = [0x89, 0x50, 0x4E, 0x47];
      final rotos = <String>[];
      referencias().forEach((path, campos) {
        if (!path.toLowerCase().endsWith('.png')) return;
        final bytes = File('${raiz.path}/$path').readAsBytesSync();
        final esPng =
            bytes.length > 8 &&
            List<int>.generate(4, (i) => bytes[i]).join(',') ==
                firmaPng.join(',');
        if (!esPng) {
          rotos.add(
            '$path (lo cita ${campos.join(", ")}): no es un PNG válido',
          );
        }
      });
      expect(rotos, isEmpty, reason: 'mapas rotos:\n${rotos.join("\n")}');
    });

    test('cada ruta declara el mapa que le corresponde, con su nota', () {
      // El inventario vio mapas cruzados: la ruta de CENEVAL navegaba sobre
      // un mapa improvisado mientras el único mapa real del diseño estaba en
      // la ruta de examen profesional. Cada ruta dice cuál usa y por qué.
      final data = leerIndice('assets/json/routes.json');
      final rutas =
          (data['rutas'] as List<dynamic>)
              .map((r) => r as Map<String, dynamic>)
              .toList();

      final esperados = {
        'ceneval': 'assets/images/maps/mapa_agua.png',
        'profesional': 'assets/images/maps/mapa_tierra.png',
        'promedio': 'assets/images/maps/mapa_aire.png',
      };
      for (final r in rutas) {
        final id = r['id'] as String;
        final mapa = r['mapa'] as String? ?? '';
        expect(mapa, isNotEmpty, reason: 'la ruta "$id" navega sin mapa');
        expect(
          (r['mapaNota'] as String? ?? '').isNotEmpty,
          isTrue,
          reason: 'la ruta "$id" usa "$mapa" sin decir de dónde sale',
        );
        if (esperados.containsKey(id)) {
          expect(
            mapa,
            esperados[id],
            reason: 'la ruta "$id" tiene el mapa cruzado',
          );
        }
      }

      // Los tres mapas del proyecto se usan: ninguno quedó de adorno.
      final usados = rutas.map((r) => r['mapa'] as String).toSet();
      for (final archivo
          in Directory(
            '${raiz.path}/assets/images/maps',
          ).listSync().whereType<File>()) {
        final relativo = archivo.path.substring(raiz.path.length + 1);
        expect(
          usados,
          contains(relativo),
          reason: '$relativo está en el APK pero ninguna ruta lo usa',
        );
      }
    });
  });
}
