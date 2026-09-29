import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titulacion/services/staff_repository.dart';
import 'package:titulacion/services/student_repository.dart';

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
      expect(total, greaterThan(300000), reason: 'la BUAP envió 318 mil alumnos');
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
      final info = (idx['cohorts'] as Map<String, dynamic>)['2023']
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
      expect(total, lessThan(6 * 1024 * 1024), reason: 'la app no debe pesar MB');
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
        expect(l[2], endsWith('@correo.buap.mx'),
            reason: 'solo correos institucionales: ${l[2]}');
      }
    });

    test('no se empaquetan correos personales', () {
      final idx = leerIndice('assets/trabajadores/index.json');
      final texto = File('${raiz.path}/${idx['archivo']}').existsSync()
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
        const Trabajador(matricula: '1', nombre: 'X', correo: 'a@correo.buap.mx')
            .tieneCorreo,
        isTrue,
      );
      expect(
        const Trabajador(matricula: '1', nombre: 'X').tieneCorreo,
        isFalse,
      );
    });
  });
}
