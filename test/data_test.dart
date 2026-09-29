import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titulacion/services/staff_repository.dart';
import 'package:titulacion/services/student_repository.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vgc;

/// Comprueba la base de alumnos y el directorio de trabajadores empaquetados:
/// que los archivos estén, que se descompriman y que el contenido sea el que
/// la BUAP envió.
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

  List<List<String>> leerCohorte(String rutaGz) {
    final f = File('${raiz.path}/$rutaGz');
    expect(f.existsSync(), isTrue, reason: 'falta $rutaGz');
    final texto = utf8.decode(
      GZipDecoder().decodeBytes(f.readAsBytesSync()),
      allowMalformed: true,
    );
    return texto
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.split('\t'))
        .toList();
  }

  group('Base de alumnos', () {
    test('el índice declara las cohortes y los archivos existen', () {
      final idx = leerIndice('assets/alumnos/index.json');
      final cohortes = idx['cohorts'] as Map<String, dynamic>;
      expect(cohortes, isNotEmpty);

      var total = 0;
      cohortes.forEach((anio, v) {
        final info = v as Map<String, dynamic>;
        final archivo = info['archivo'] as String;
        expect(
          File('${raiz.path}/$archivo').existsSync(),
          isTrue,
          reason: 'falta el archivo de la cohorte $anio',
        );
        expect(anio, matches(RegExp(r'^\d{4}$')));
        total += info['registros'] as int;
      });
      expect(total, idx['total']);
      expect(
        total,
        greaterThan(300000),
        reason: 'la BUAP envió 318 mil alumnos',
      );
    });

    test('cada línea es matrícula + nombre, sin correos', () {
      final idx = leerIndice('assets/alumnos/index.json');
      final cohortes = idx['cohorts'] as Map<String, dynamic>;
      // Muestreo: la primera y la última cohorte.
      for (final anio in ['2020', '2025']) {
        final info = cohortes[anio] as Map<String, dynamic>;
        final lineas = leerCohorte(info['archivo'] as String);
        expect(lineas.length, info['registros']);

        for (final l in lineas.take(50)) {
          expect(l.length, 2, reason: 'más de 2 campos: ${l.length}');
          expect(l[0], matches(RegExp(r'^\d{9}$')));
          expect(l[0].startsWith(anio), isTrue);
          expect(l[1].trim(), isNotEmpty);
          // El correo del alumno no debe estar en la app.
          expect(l[1], isNot(contains('@')));
        }
      }
    });

    test('las matrículas no están duplicadas dentro de una cohorte', () {
      final idx = leerIndice('assets/alumnos/index.json');
      final info =
          (idx['cohorts'] as Map<String, dynamic>)['2023']
              as Map<String, dynamic>;
      final matriculas =
          leerCohorte(info['archivo'] as String).map((l) => l[0]).toSet();
      expect(matriculas.length, info['registros']);
    });

    test('el tamaño total cabe en lo razonable para una app', () {
      final idx = leerIndice('assets/alumnos/index.json');
      final cohortes = idx['cohorts'] as Map<String, dynamic>;
      var total = 0;
      cohortes.forEach((_, v) {
        total += (v as Map<String, dynamic>)['gz_bytes'] as int;
      });
      expect(
        total,
        lessThan(6 * 1024 * 1024),
        reason: 'la app no debe pesar MB',
      );
    });
  });

  group('Directorio de trabajadores', () {
    test('el archivo existe y trae nombre y correo institucional', () {
      final idx = leerIndice('assets/trabajadores/index.json');
      final lineas = leerCohorte(idx['archivo'] as String);
      expect(lineas.length, idx['total']);
      expect(lineas.length, greaterThan(40000));

      final conCorreo = lineas.where((l) => l.length > 2 && l[2].isNotEmpty);
      expect(conCorreo.length, idx['con_correo_institucional']);
      for (final l in conCorreo.take(50)) {
        expect(
          l[2],
          endsWith('@correo.buap.mx'),
          reason: 'solo correos institucionales: ${l[2]}',
        );
      }
    });

    test('no se empaquetan correos personales', () {
      final idx = leerIndice('assets/trabajadores/index.json');
      final texto =
          File('${raiz.path}/${idx['archivo']}').existsSync()
              ? leerCohorte(idx['archivo'] as String)
              : <List<String>>[];
      for (final l in texto) {
        if (l.length > 2 && l[2].isNotEmpty) {
          expect(l[2], isNot(contains('gmail')));
          expect(l[2], isNot(contains('hotmail')));
        }
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

  group('Trabajador', () {
    test('sabe si tiene correo', () {
      expect(
        const Trabajador(
          matricula: '1',
          nombre: 'X',
          correo: 'a@correo.buap.mx',
        ).tieneCorreo,
        isTrue,
      );
      expect(
        const Trabajador(matricula: '1', nombre: 'X').tieneCorreo,
        isFalse,
      );
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
