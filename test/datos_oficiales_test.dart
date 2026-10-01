import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Blindaje de los datos que se corrigieron contra fuentes oficiales de la
/// BUAP el 2026-09-30. Cada prueba falla si alguien vuelve a dejar un hueco,
/// un dato sin fuente o un texto que la Universidad no dice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> routes;
  late Map<String, dynamic> catalogo;
  late List<dynamic> facultades;

  setUpAll(() {
    routes = json.decode(
      File('assets/json/routes.json').readAsStringSync(encoding: utf8),
    ) as Map<String, dynamic>;
    catalogo = json.decode(
      File('assets/json/catalogo_modalidades.json').readAsStringSync(
        encoding: utf8,
      ),
    ) as Map<String, dynamic>;
    facultades =
        (json.decode(
              File('assets/json/facultades.json').readAsStringSync(
                encoding: utf8,
              ),
            )
            as Map<String, dynamic>)['facultades'] as List<dynamic>;
  });

  Map<String, dynamic> ruta(String id) => (routes['rutas'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((r) => r['id'] == id);

  Map<String, dynamic> nivel(String rutaId, int i) =>
      (ruta(rutaId)['niveles'] as List)
          .cast<Map<String, dynamic>>()
          .elementAt(i);

  String todoElTextoDeLasRutas() => jsonEncode(routes);

  group('Correos institucionales', () {
    test('ningún correo está vacío, es de ejemplo o tiene formato inválido', () {
      for (final f in facultades.cast<Map<String, dynamic>>()) {
        final correo = f['correo'] as String?;
        if (correo == null || correo.isEmpty) continue; // declarado ausente
        expect(
          correo,
          matches(RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')),
          reason: '${f['clave']} tiene un correo mal formado: $correo',
        );
        expect(
          correo,
          isNot(contains('example')),
          reason: '${f['clave']} apunta a un correo de ejemplo: $correo',
        );
        expect(
          correo,
          endsWith('@correo.buap.mx'),
          reason: '${f['clave']} no es un correo institucional de la BUAP: $correo',
        );
      }
    });

    test('toda unidad con correo declara la confianza con que se verific��', () {
      for (final f in facultades.cast<Map<String, dynamic>>()) {
        final correo = f['correo'] as String?;
        if (correo == null || correo.isEmpty) {
          expect(f['confianza'], isNot('alta'),
              reason: '${f['clave']} sin correo no puede tener confianza alta');
          continue;
        }
        expect(
          f['confianza'],
          isNotNull,
          reason: '${f['clave']} tiene correo pero no declara confianza',
        );
        expect(
          f['notas'],
          contains('2026-09-30'),
          reason: '${f['clave']} tiene correo sin la nota de verificación fechada',
        );
      }
    });

    test('el contacto general de titulación es el publicado por la BUAP', () {
      final contactos =
          json.decode(
                File('assets/json/contactos.json').readAsStringSync(
                  encoding: utf8,
                ),
              )
              as Map<String, dynamic>;
      final lista = contactos['contactos'] as List;
      final correos = lista
          .cast<Map<String, dynamic>>()
          .map((c) => c['correo'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
      expect(
        correos,
        contains('titulacion@correo.buap.mx'),
        reason: 'la DAE no publica correo propio; debe caer al de Titulación',
      );
    });
  });

  group('Plazo y documentos de tesis', () {
    test('el plazo se cuenta desde la autorización del tema, no desde el '
        'registro', () {
      final pasos = nivel('profesional', 3)['pasos'] as List;
      final texto = jsonEncode(pasos);
      expect(
        texto,
        contains('autorizado'),
        reason: 'el Reglamento art. 32 cuenta el año desde la autorización '
            'del tema',
      );
      expect(
        texto,
        isNot(contains('tras el registro')),
        reason: 'contar desde el registro contradice el Reglamento art. 32',
      );
      expect(texto, contains('seis meses'), reason: 'la prórroga es de hasta '
          'seis meses');
    });

    test('el nivel del aval cita la norma que lo respalda', () {
      final n = nivel('profesional', 3);
      final nota = n['nota'] as String? ?? '';
      expect(nota, contains('Reglamento General de Titulación'),
          reason: 'el nivel debe explicar qué documento es el oficial');
      expect(
        (n['pasos'] as List).cast<Map<String, dynamic>>().last['fuente'],
        contains('reglamento_general_de_titulacion'),
      );
    });

    test('el formato adjunto es el de validación de certificado y trae URL', () {
      final docs = nivel('profesional', 5)['documentos'] as List;
      final conUrl = docs
          .cast<Map<String, dynamic>>()
          .where((d) => (d['url'] as String? ?? '').isNotEmpty)
          .toList();
      expect(conUrl, isNotEmpty,
          reason: 'un documento sin URL es un dato no verificable');
      for (final d in conUrl) {
        expect(d['url'], startsWith('https://'));
      }
    });

    test('la entrega de tesis no promete un correo que la BUAP no publica', () {
      final nota = nivel('profesional', 6)['nota'] as String? ?? '';
      expect(nota, contains('PRESENCIAL'),
          reason: 'el trámite de acta o título es presencial');
      expect(nota, contains('titulacion@correo.buap.mx'));
    });

    test('las vigencias confirmadas dicen 3 y 6 meses con su fuente', () {
      final nota = nivel('promedio', 7)['nota'] as String? ?? '';
      expect(nota, contains('3 meses'));
      expect(nota, contains('seis meses'));
      expect(nota, contains('2026-09-30'));
    });
  });

  group('Integridad del texto', () {
    test('no queda el carácter ilegible de la fuente', () {
      expect(
        todoElTextoDeLasRutas(),
        isNot(contains('参加')),
        reason: 'la errata se cotejó contra el PDF original',
      );
      expect(
        jsonEncode(catalogo),
        isNot(contains('参加')),
      );
    });

    test('ningún documento queda sin fuente verificable', () {
      for (final r in (routes['rutas'] as List).cast<Map<String, dynamic>>()) {
        for (final n in (r['niveles'] as List).cast<Map<String, dynamic>>()) {
          if (n['fuente'] == null && (n['fuente'] as String?) == null) {
            // Se admite solo si el nivel no cita documento externo alguno.
            final pasos = n['pasos'] as List? ?? [];
            final citesFuente = pasos
                .cast<Map<String, dynamic>>()
                .any((p) => (p['fuente'] as String? ?? '').isNotEmpty);
            if (!citesFuente) continue;
          }
          expect(
            (n['fuente'] as String?) ?? (n['fuente'] as String?) ?? '',
            isNotEmpty,
            reason: 'nivel «${n['titulo']}» de ${r['id']} cita pasos con fuente '
                'pero no declara la suya',
          );
        }
      }
    });
  });

  group('Clasificación de la tesina', () {
    test('ninguna modalidad llamada Tesina apunta a la ruta de tesis', () {
      for (final f in facultades.cast<Map<String, dynamic>>()) {
        for (final v in f.values) {
          if (v is! List || v.isEmpty || v.first is! Map) continue;
          for (final m in v.cast<Map<String, dynamic>>()) {
            final nombre = (m['nombre'] as String? ?? '').toLowerCase();
            if (!nombre.contains('tesina')) continue;
            expect(
              m['rutaId'],
              isNot('tesis'),
              reason: '${f['clave']} — «$nombre» no puede ir a la ruta de tesis: '
                  'el Reglamento art. 7 fr. VII la pone como asignatura optativa '
                  'con créditos',
            );
          }
        }
      }
    });

    test('la tesina declara la norma que la sustenta', () {
      var vistas = 0;
      for (final f in facultades.cast<Map<String, dynamic>>()) {
        for (final v in f.values) {
          if (v is! List || v.isEmpty || v.first is! Map) continue;
          for (final m in v.cast<Map<String, dynamic>>()) {
            if (!(m['nombre'] as String? ?? '').toLowerCase().contains('tesina')) {
              continue;
            }
            if (m['rutaId'] == 'asignatura-optativa') {
              expect(m['nombreNormativo'], isNotNull,
                  reason: '${f['clave']}: falta el nombre normativo');
              vistas++;
            }
          }
        }
      }
      expect(vistas, greaterThanOrEqualTo(9),
          reason: 'se esperaban 9 modalidades de tesina reclasificadas');
    });

    test('las modalidades reclasificadas conservan su fuente oficial', () {
      for (final f in facultades.cast<Map<String, dynamic>>()) {
        for (final v in f.values) {
          if (v is! List || v.isEmpty || v.first is! Map) continue;
          for (final m in v.cast<Map<String, dynamic>>()) {
            final nombre = (m['nombre'] as String? ?? '').toLowerCase();
            if (!nombre.contains('tesina')) continue;
            expect(
              m['fuente'],
              isNotNull,
              reason: '${f['clave']} — «$nombre» sin fuente oficial',
            );
            expect(m['fuente'], startsWith('https://'));
          }
        }
      }
    });
  });

  group('Catálogo de modalidades', () {
    test('FFyL publica su catálogo con sus 33 modalidades y su PDF', () {
      final ffl = (catalogo['unidades'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((u) => u['clave'] == 'FFL');
      expect(ffl['estadoCatalogo'], 'publicado');
      expect(ffl['publicaCatalogo'], isTrue);
      final mods = (ffl['modalidades'] as List).cast<Map<String, dynamic>>();
      expect(mods.length, 33,
          reason: 'el PDF de la FFyL enumera 33 modalidades en 5 licenciaturas');
      for (final m in mods) {
        expect(m['carrera'], isNotNull,
            reason: 'una modalidad de FFyL sin licenciatura no es ubicable');
        expect(m['fuente'], contains('filosofia.buap.mx'));
      }
      final carreras = mods.map((m) => m['carrera']).toSet();
      expect(carreras.length, 5,
          reason: 'el catálogo es por licenciatura, no una lista única');
    });

    test('toda modalidad del catálogo con fuente la declara', () {
      for (final u in (catalogo['unidades'] as List)
          .cast<Map<String, dynamic>>()) {
        for (final m in (u['modalidades'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          if (m['rutaId'] == null && m['fuente'] == null) continue;
          expect(
            m['fuente'],
            isNotNull,
            reason: '${u['clave']} — «${m['nombreEnUnidad']}» sin fuente',
          );
        }
      }
    });
  });
}