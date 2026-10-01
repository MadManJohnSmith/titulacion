import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/level_detail_screen.dart';
import 'package:titulacion/screens/route_selection_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';
import 'package:titulacion/widgets/common.dart';

/// El rollo de pergamino es vertical y el panel de texto se estiraba a lo ancho
/// de la pantalla: se veía el dibujo correcto embadurnado en una banda de más de
/// mil píxeles que no era el pergamino. Estas pruebas fijan dos cosas: que la
/// medida que declara el JSON sea la del `viewBox` real, y que en pantalla el
/// panel tome la forma del rollo.
///
/// La segunda mitad de la sesión también revisó las fechas: el rastreo pintaba
/// el ISO crudo («consultado 2026-09-29T00:00:00Z») en lugar del día.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ContentRepository.instance.cargarDesdeDiscoParaTests();
  });

  Future<AppState> estadoLimpio() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance());
  }

  group('La medida del pergamino sale del SVG, no de un ojo', () {
    test('cada ruta con marco declara la relación real de su viewBox', () {
      final rutas =
          (json.decode(
                File('assets/json/routes.json').readAsStringSync(
                  encoding: utf8,
                ),
              )
              as Map<String, dynamic>)['rutas'] as List<dynamic>;

      var vistas = 0;
      for (final r in rutas.cast<Map<String, dynamic>>()) {
        final p = r['pergaminoInicio'] as String? ?? '';
        if (p.isEmpty) continue;
        vistas++;

        final svg = File(p).readAsStringSync(encoding: utf8);
        final m = RegExp(r'viewBox="([^"]+)"').firstMatch(svg);
        expect(m, isNotNull, reason: '$p no declara viewBox');
        final vb = m!.group(1)!.trim().split(RegExp(r'[\s,]+')).map(double.parse).toList();
        final real = vb[2] / vb[3];

        final declarada = (r['pergaminoRelacion'] as num?)?.toDouble();
        expect(
          declarada,
          isNotNull,
          reason:
              '${r['id']} trae $p pero no declara pergaminoRelacion: sin ella la UI '
              'no puede saber que el rollo es vertical',
        );
        expect(
          declarada!,
          closeTo(real, 0.001),
          reason:
              '${r['id']}: el JSON dice $declarada pero el viewBox de $p da $real',
        );
      }
      expect(vistas, greaterThan(0), reason: 'ningún pergamino revisado');
    });

    test('las rutas sin marco no inventan una medida', () {
      final rutas =
          (json.decode(
                File('assets/json/routes.json').readAsStringSync(
                  encoding: utf8,
                ),
              )
              as Map<String, dynamic>)['rutas'] as List<dynamic>;
      for (final r in rutas.cast<Map<String, dynamic>>()) {
        if ((r['pergaminoInicio'] as String? ?? '').isNotEmpty) continue;
        expect(
          r.containsKey('pergaminoRelacion'),
          isFalse,
          reason:
              '${r['id']} no trae pergaminoInicio, así que una relación de '
              'aspecto sería un dato sin dibujo al que pertenece',
        );
      }
    });
  });

  group('En pantalla el panel toma la forma del rollo', () {
    testWidgets('la caja del pergamino es vertical y no una banda ancha', (
      tester,
    ) async {
      final state = await estadoLimpio();
      await state.registrar(
        const Alumno(nombre: 'Alumno', matricula: '123'),
        facultadClave: 'FCC',
      );

      final repo = ContentRepository.instance;
      final oferta = await repo.ofertaDeUnidad('FCC');
      // Las rutas son de la unidad: la de CENEVAL aquí es «ceneval-fcc».
      final rutaOferta = oferta.rutas.firstWhere(
        (r) => r.ruta.ruta.id.startsWith('ceneval'),
      );
      final relacion = rutaOferta.ruta.ruta.pergaminoRelacion!;

      await tester.pumpWidget(
        MaterialApp(
          home: RouteSelectionScreen(
            oferta: oferta,
            ruta: rutaOferta,
            state: state,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // El SVG va con `Positioned.fill`, así que su tamaño ES el del panel.
      final svg = tester
          .widgetList<AssetImageSafe>(find.byType(AssetImageSafe))
          .firstWhere((w) => w.path == rutaOferta.ruta.ruta.pergaminoInicio);
      final size = tester.getSize(find.byWidget(svg));
      expect(
        size.width / size.height,
        closeTo(relacion, 0.01),
        reason: 'la caja del pergamino debe tener la proporción del rollo',
      );
      expect(
        size.width,
        lessThan(size.height),
        reason:
            'un rollo vertical más ancho que alto significa que volvimos a la '
            'banda horizontal que tapaba el diseño',
      );
      expect(size.height, lessThanOrEqualTo(470.0));
      expect(size.width, greaterThan(0));
    });

    testWidgets('en pantalla angosta nada se desborda', (tester) async {
      // El ancho de un teléfono chico. Con el nombre completo de la unidad, la
      // fila del encabezado se salía de la pantalla.
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final state = await estadoLimpio();
      await state.registrar(
        const Alumno(nombre: 'Alumno', matricula: '123'),
        facultadClave: 'FCC',
      );

      final repo = ContentRepository.instance;
      final oferta = await repo.ofertaDeUnidad('FCC');
      final rutaOferta = oferta.rutas.firstWhere(
        (r) => r.ruta.ruta.id.startsWith('ceneval'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouteSelectionScreen(
            oferta: oferta,
            ruta: rutaOferta,
            state: state,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('El número del nivel se ve una vez y siempre está', () {
    testWidgets('«Tu ruta» no repite la cifra que ya trae el icono', (
      tester,
    ) async {
      final state = await estadoLimpio();
      await state.registrar(
        const Alumno(nombre: 'Alumno', matricula: '123'),
        facultadClave: 'FCC',
      );
      final repo = ContentRepository.instance;
      final oferta = await repo.ofertaDeUnidad('FCC');
      final rutaOferta = oferta.rutas.firstWhere(
        (r) => r.ruta.ruta.id.startsWith('ceneval'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouteSelectionScreen(
            oferta: oferta,
            ruta: rutaOferta,
            state: state,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nivel = rutaOferta.ruta.ruta.nivelesJugables.first;
      // En la fila del icono, la cifra va en el SVG; un «N» suelto al lado es
      // justo lo que el alumno reportó ver duplicado.
      final sueltos = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data?.trim() == '${nivel.numero}')
          .length;
      expect(
        sueltos,
        0,
        reason:
            'el icono del nivel ya dibuja su número: repetirlo en texto lo '
            'muestra dos veces',
      );
    });

    testWidgets('la pantalla del nivel sí dice en qué nivel estás', (
      tester,
    ) async {
      final state = await estadoLimpio();
      await state.registrar(
        const Alumno(nombre: 'Alumno', matricula: '123'),
        facultadClave: 'FCC',
      );
      final repo = ContentRepository.instance;
      final oferta = await repo.ofertaDeUnidad('FCC');
      final rutaOferta = oferta.rutas.firstWhere(
        (r) => r.ruta.ruta.id.startsWith('ceneval'),
      );
      final nivel = rutaOferta.ruta.ruta.nivelesJugables.first;

      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            ruta: rutaOferta.ruta.ruta,
            nivel: nivel,
            state: state,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En esta pantalla se ve la mascota, no el icono numerado: si aquí tampoco
      // va la cifra, el alumno pierde en qué nivel está.
      expect(find.text('Nivel ${nivel.numero}'), findsOneWidget);
    });
  });

  group('Los requisitos que publica la unidad llegan a la pantalla', () {
    testWidgets('el bloque aparece con su detalle y su fuente', (tester) async {
      // `particularidadesPorUnidad` se armaba y se cargaba en
      // `RutaOferta.particularidad`, pero ninguna pantalla lo mostraba: el
      // alumno veía los requisitos genéricos de la ruta y perdía lo único que
      // distingue a su unidad del resto.
      final state = await estadoLimpio();
      await state.registrar(
        const Alumno(nombre: 'Alumno', matricula: '123'),
        facultadClave: 'FCFM',
      );
      final repo = ContentRepository.instance;
      final oferta = await repo.ofertaDeUnidad('FCFM');

      // Al menos una modalidad de esta unidad debe traer requisitos propios.
      final conDetalle = oferta.rutas.where(
        (r) => (r.particularidad?.detalle.isNotEmpty ?? false),
      );
      expect(conDetalle, isNotEmpty, reason: 'FCFM no trae requisitos propios');

      final rutaOferta = conDetalle.first;
      await tester.pumpWidget(
        MaterialApp(
          home: RouteSelectionScreen(
            oferta: oferta,
            ruta: rutaOferta,
            state: state,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final p = rutaOferta.particularidad!;
      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();

      expect(
        textos.any((t) => t.contains(p.detalle.substring(0, 40))),
        isTrue,
        reason: 'el detalle que publica la unidad no aparece en pantalla',
      );
      expect(
        textos.any((t) => t.contains('Lo que publica')),
        isTrue,
        reason: 'falta el encabezado del bloque de requisitos de la unidad',
      );
      // Y tiene que poder citarse: un requisito sin origen es una afirmación.
      if (p.fuente.isNotEmpty) {
        expect(
          textos.any((t) => t.contains('Fuente: ${p.fuente}')),
          isTrue,
          reason: 'el bloque muestra requisitos de la unidad sin su fuente',
        );
      }
    });
  });

  group('Lo que publica la unidad, sin que se pierda', () {
    testWidgets('el bloque avisa cuando es una tesina en la ruta de tesis', (
      tester,
    ) async {
      // Tesis (art. 7 fr. I) y tesina (art. 7 fr. VII) son procesos distintos.
      // Hay modalidades que la unidad llama «tesina» y el catálogo encamina a
      // la ruta de tesis; la app no puede corregirlo sin comprobar la unidad,
      // así que tiene que decirlo.
      final state = await estadoLimpio();
      await state.registrar(
        const Alumno(nombre: 'Alumno', matricula: '123'),
        facultadClave: 'FDERE',
      );
      final repo = ContentRepository.instance;
      final oferta = await repo.ofertaDeUnidad('FDERE');
      final conTesina = oferta.rutas
          .where((r) => r.modalidad?.tesinaEnRutaDeTesis ?? false)
          .toList();
      expect(conTesina, isNotEmpty, reason: 'FDERE no trae una tesina');

      await tester.pumpWidget(
        MaterialApp(
          home: RouteSelectionScreen(
            oferta: oferta,
            ruta: conTesina.first,
            state: state,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' | ');
      expect(textos.contains('art. 7 fr. VII'), isTrue,
          reason: 'la diferencia entre tesis y tesina no se explica');
      expect(textos.contains('Confírmalo con tu unidad'), isTrue,
          reason: 'no se pide confirmar con la unidad antes de seguir');
    });

    testWidgets('el aviso de buzón personal aparece con la vía estable', (
      tester,
    ) async {
      final state = await estadoLimpio();
      await state.registrar(
        const Alumno(nombre: 'Alumno', matricula: '123'),
        facultadClave: 'FCFM',
      );
      final repo = ContentRepository.instance;
      final oferta = await repo.ofertaDeUnidad('FCFM');
      final conNota = oferta.rutas
          .where((r) => (r.modalidad?.notaContacto.isNotEmpty ?? false))
          .toList();
      expect(conNota, isNotEmpty, reason: 'FCFM no declara esa advertencia');

      await tester.pumpWidget(
        MaterialApp(
          home: RouteSelectionScreen(
            oferta: oferta,
            ruta: conNota.first,
            state: state,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final m = conNota.first.modalidad!;
      expect(find.text(m.notaContacto), findsOneWidget);
      // La vía institucional estable tiene que poder pulsarse, no solo leerse.
      expect(
        find.text(m.contactoInstitucional),
        findsWidgets,
        reason: 'la unidad declara una alternativa institucional y no se ofrece',
      );
    });

    test('los requisitos de ingreso que publica la unidad se conservan', () {
      // 39 modalidades traen el texto de la unidad; el modelo lo leía y la
      // pantalla no lo mostraba nunca.
      final unidades =
          (json.decode(
                File('assets/json/catalogo_modalidades.json')
                    .readAsStringSync(encoding: utf8),
              )
              as Map<String, dynamic>)['unidades'] as List<dynamic>;

      var conTexto = 0;
      for (final u in unidades.cast<Map<String, dynamic>>()) {
        for (final m in (u['modalidades'] as List? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>()) {
          final mod = ModalidadUnidad.fromJson(
            m,
            unidadClave: '${u['clave']}',
            unidadNombre: '${u['nombreOficial']}',
          );
          if (mod.perfil.textoPublicacion.isNotEmpty) conTexto++;
        }
      }
      expect(conTexto, greaterThan(30),
          reason: 'los requisitos publicados por la unidad se están perdiendo');
    });
  });

  group('Las fechas se leen como fecha, no como marca de máquina', () {
    test('fechaLegible quita la hora y conserva el día', () {
      expect(fechaLegible('2026-09-29T00:00:00Z'), '2026-09-29');
      expect(fechaLegible('2026-09-29'), '2026-09-29');
      expect(fechaLegible(''), '');
    });

    test('el rastro de consulta y la fuente no enseñan el ISO crudo', () {
      final rastro = RastroConsulta.fromJson({
        'url': 'https://www.buap.mx/content/unidades-academicas',
        'consultadoEn': '2026-09-29T00:00:00Z',
        'resultado': 'sin_catalogo_publicado',
      });
      expect(rastro.fecha, '2026-09-29');
      expect(rastro.fecha, isNot(contains('T')));

      final fuente = Fuente.fromJson({
        'titulo': 'Reglamento General de Titulación',
        'url': 'https://www.buap.mx/reglamento.pdf',
        'consultadoEn': '2026-09-29T00:00:00Z',
      });
      expect(fuente.etiqueta, isNot(contains('T00:00:00Z')));
      expect(fuente.etiqueta, contains('2026-09-29'));
    });

    test('ninguna etiqueta de fuente del catálogo lleva la hora', () {
      final datos =
          json.decode(
            File('assets/json/catalogo_modalidades.json').readAsStringSync(
              encoding: utf8,
            ),
          )
              as Map<String, dynamic>;

      final texto = datos.toString();
      final conHora = RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z').allMatches(texto.toString());
      // El JSON sí guarda el instante completo (ordena y compara igual); lo que
      // no debe pasar es que ese texto llegue a una etiqueta de la UI.
      expect(conHora, isNotEmpty, reason: 'el JSON debería conservar el instante');
      for (final m in conHora) {
        expect(
          fechaLegible(m.group(0)!),
          isNot(contains('T')),
          reason: 'fechaLegible no debe devolver la hora',
        );
      }
    });
  });
}