import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titulacion/models/models.dart';

/// Pruebas de lo corregido el 2026-09-30: el pergamino, la numeración, el
/// enlace de los documentos y el flujo de deshacer progreso.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> routes;
  late List<dynamic> facultades;

  setUpAll(() {
    routes = json.decode(
      File('assets/json/routes.json').readAsStringSync(encoding: utf8),
    ) as Map<String, dynamic>;
    facultades =
        (json.decode(
              File('assets/json/facultades.json').readAsStringSync(
                encoding: utf8,
              ),
            )
            as Map<String, dynamic>)['facultades'] as List<dynamic>;
  });

  group('Pergamino', () {
    test('las rutas con marco declaran un SVG que existe en disco', () {
      for (final r in (routes['rutas'] as List).cast<Map<String, dynamic>>()) {
        final p = r['pergaminoInicio'] as String? ?? '';
        if (p.isEmpty) continue;
        expect(File(p).existsSync(), isTrue, reason: '${r['id']}: $p');
      }
    });

    test('cada SVG de pergamino trae el marco del diseño', () {
      final marcados = <String>[];
      for (final r in (routes['rutas'] as List).cast<Map<String, dynamic>>()) {
        final p = r['pergaminoInicio'] as String? ?? '';
        if (p.isEmpty) continue;
        final svg = File(p).readAsStringSync(encoding: utf8);
        // El marco del diseño son trazados vectoriales con curvas. Lo que
        // faltaba en pantalla no era el archivo, sino que un Container opaco
        // se pintaba encima; aquí se comprueba que el dibujo sigue en el SVG.
        final paths = '<path'.allMatches(svg).length +
            '<polygon'.allMatches(svg).length;
        expect(paths, greaterThanOrEqualTo(1),
            reason: '$p no trae ningún trazado: el marco se vería plano');
        expect(svg, contains('viewBox'),
            reason: '$p sin viewBox no escala y se ve deformado');
        // El marco es una silueta irregular; si fuera un rectángulo liso,
        // el detalle del diseño se habría perdido al exportar.
        expect(RegExp('d="[^"]*[CcSsQqTtAa]').hasMatch(svg), isTrue,
            reason: '$p parece un rectángulo sin curvas: perdió el diseño');
        marcados.add(p);
      }
      expect(marcados, isNotEmpty);
    });
  });

  group('Numeración de niveles', () {
    test('el icono de nivel ya trae el número en el SVG', () {
      // Si el icono lo dibuja, la pantalla no lo repite en texto.
      final rutas = (routes['rutas'] as List).cast<Map<String, dynamic>>();
      final conIcono = rutas
          .expand((r) => (r['niveles'] as List).cast<Map<String, dynamic>>())
          .where((n) => (n['icono'] as String? ?? '').isNotEmpty);
      expect(conIcono, isNotEmpty);
      for (final n in conIcono.take(3)) {
        expect(n['icono'], startsWith('assets/'));
      }
    });

    test('el SVG del icono dibuja la cifra que le toca', () {
      // De esto depende la decisión de diseño: si el número no está dibujado
      // en el SVG, entonces en «Tu ruta» sí hay que ponerlo en texto.
      final rutas = (routes['rutas'] as List).cast<Map<String, dynamic>>();
      final conIcono = rutas
          .expand((r) => (r['niveles'] as List).cast<Map<String, dynamic>>())
          .where((n) => (n['icono'] as String? ?? '').isNotEmpty);
      for (final n in conIcono) {
        final svg = File(n['icono'] as String).readAsStringSync(encoding: utf8);
        final titulo = RegExp(r'<title>([^<]*)</title>').firstMatch(svg);
        expect(titulo, isNotNull, reason: '${n['icono']} no trae título');
        expect(
          titulo!.group(1)!.toLowerCase(),
          contains('${n['numero']}'),
          reason:
              '${n['icono']} se titula «${titulo.group(1)}» pero es el nivel '
              '${n['numero']}: el icono no dibujaría la cifra y quitar el '
              'número de la pantalla dejaría al alumno sin él',
        );
      }
    });
  });

  group('Documentos con enlace oficial', () {
    test('ningún enlace apunta a una URL rota o a un ejemplo', () {
      var conUrl = 0;
      for (final r in (routes['rutas'] as List).cast<Map<String, dynamic>>()) {
        for (final n in (r['niveles'] as List).cast<Map<String, dynamic>>()) {
          for (final d in (n['documentos'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
            final url = d['url'] as String?;
            if (url == null || url.isEmpty) continue;
            conUrl++;
            expect(url, startsWith('https://'),
                reason: '${d['nombre']}: $url');
            expect(url, isNot(contains('example.com')));
            expect(url, isNot(contains('localhost')));
          }
        }
      }
      expect(conUrl, greaterThan(0), reason: 'debe haber enlaces reales');
    });

    test('el documento con enlace declara también su fuente', () {
      for (final r in (routes['rutas'] as List).cast<Map<String, dynamic>>()) {
        for (final n in (r['niveles'] as List).cast<Map<String, dynamic>>()) {
          for (final d in (n['documentos'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
            final url = d['url'] as String?;
            if (url == null || url.isEmpty) continue;
            expect(d['fuente'], isNotNull,
                reason: '${d['nombre']} tiene enlace pero no fuente');
          }
        }
      }
    });
  });

  group('Directorio de unidades', () {
    test('ninguna persona trae correo ajeno a una institución publicada', () {
      // Algunas unidades conservan dominios institucionales propios
      // (`@fcfm.buap.mx`) además del dominio central `@correo.buap.mx`. No se
      // rechazan: están publicados literalmente por la página oficial. Sí se
      // rechazan buzones comerciales o dominios que no pertenecen a BUAP.
      for (final f in facultades.cast<Map<String, dynamic>>()) {
        final dir = f['directorio'];
        if (dir is! Map) continue;
        for (final p in (dir['personas'] as List).cast<Map<String, dynamic>>()) {
          final correo = p['correo'] as String?;
          if (correo == null) continue;
          expect(
            correo.toLowerCase().endsWith('.buap.mx'),
            isTrue,
            reason: '${f['clave']} — ${p['nombre']}: $correo',
          );
        }
      }
    });

    test('toda persona del directorio tiene nombre y puesto', () {
      var total = 0;
      for (final f in facultades.cast<Map<String, dynamic>>()) {
        final dir = f['directorio'];
        if (dir is! Map) continue;
        for (final p in (dir['personas'] as List).cast<Map<String, dynamic>>()) {
          expect((p['nombre'] as String? ?? '').isNotEmpty, isTrue);
          expect(p['puesto'], isNotNull,
              reason: '${f['clave']}: sin puesto no se sabe a quién acudir');
          total++;
        }
      }
      expect(total, greaterThan(100),
          reason: 'el directorio debe traer personal real de las unidades');
    });

    test('el directorio indica dónde está la persona cuando la unidad lo publica',
        () {
      var conUbicacion = 0;
      for (final f in facultades.cast<Map<String, dynamic>>()) {
        final dir = f['directorio'];
        if (dir is! Map) continue;
        for (final p in (dir['personas'] as List).cast<Map<String, dynamic>>()) {
          if (p['ubicacion'] != null) conUbicacion++;
        }
      }
      expect(conUbicacion, greaterThan(50),
          reason: 'varias unidades publican cubículo: es el dato que faltaba');
    });

    test('la búsqueda del directorio ignora acentos y mayúsculas', () {
      const personas = [
        PersonaDirectorio(
          nombre: 'Ana Pérez',
          puesto: 'Secretaria Académica',
          ubicacion: 'CCO4-209',
        ),
      ];
      expect(DirectorioUnidad.buscarEn(personas, 'Perez').length, 1);
      expect(DirectorioUnidad.buscarEn(personas, 'pÉREZ').length, 1);
      expect(DirectorioUnidad.buscarEn(personas, 'academica').length, 1);
      expect(DirectorioUnidad.buscarEn(personas, 'CCO4').length, 1);
      expect(DirectorioUnidad.buscarEn(personas, 'zzz').length, 0);
      expect(DirectorioUnidad.buscarEn(personas, '').length, 1);
    });

    test('una unidad sin directorio no inventa nombres', () {
      const f = Facultad(nombre: 'Prueba', clave: 'X');
      expect(f.tieneDirectorio, isFalse);
      expect(f.directorio.cita, isEmpty);
    });

    test('las ubicaciones no traen erratas de transcripción', () {
      // «Edficio ADM1 Oficina 201» se coló copiando la página de la unidad: una
      // palabra mal escrita hace que el alumno no encuentre la oficina y no
      // puede distinguir un dato mal copiado de uno que no existe.
      const sospechosas = ['Edficio', 'edficio', 'Ofcina', 'oficina ', 'Cubíclo'];
      for (final raw in facultades.cast<Map<String, dynamic>>()) {
        final f = Facultad.fromJson(raw);
        for (final p in f.personasDirectorio) {
          for (final campo in ['nombre', 'puesto', 'ubicacion']) {
            final v = (campo == 'nombre'
                    ? p.nombre
                    : campo == 'puesto'
                        ? (p.puesto ?? '')
                        : (p.ubicacion ?? ''))
                .trim();
            if (v.isEmpty) continue;
            for (final mala in sospechosas) {
              expect(v.contains(mala), isFalse,
                  reason: '${f.clave} · $campo dice «$v» (contiene «$mala»)');
            }
          }
        }
      }
    });

    test('todo directorio dice de qué página se leyó y cuándo', () {
      // Un cubículo y un correo se copian de una página que puede cambiar. Sin
      // la fuente, un dato equivocado es indistinguible de uno bueno: el modelo
      // leía `url` y `consultadoEn` del JSON y los tiraba.
      final conDir = facultades.cast<Map<String, dynamic>>()
          .where((f) => f['directorio'] != null)
          .toList();
      expect(conDir, isNotEmpty);
      for (final raw in conDir) {
        final f = Facultad.fromJson(raw);
        expect(f.directorio.url, isNotEmpty,
            reason: '${f.clave} publica directorio sin decir de dónde');
        expect(f.directorio.consultadoEn, isNotEmpty,
            reason: '${f.clave} publica directorio sin fecha de consulta');
        expect(f.directorio.cita, contains(f.directorio.url),
            reason: '${f.clave}: la cita no incluye la URL');
        // La fecha se muestra como día, no como marca de máquina.
        expect(f.directorio.consultadoEn, isNot(contains('T')));
      }
    });
  });

  group('Modelo de Facultad', () {
    test('lee el directorio embebido sin romperse', () {
      final conDir = facultades.cast<Map<String, dynamic>>()
          .where((f) => f['directorio'] != null)
          .toList();
      expect(conDir, isNotEmpty);
      final f = Facultad.fromJson(conDir.first);
      expect(f.tieneDirectorio, isTrue);
      expect(f.personasDirectorio.every((p) => p.nombre.isNotEmpty), isTrue);
    });

    test('una facultad sin la clave directorio no falla', () {
      final f = Facultad.fromJson({'nombre': 'X', 'clave': 'X'});
      expect(f.tieneDirectorio, isFalse);
    });
  });
}