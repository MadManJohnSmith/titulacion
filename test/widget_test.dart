import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/level_detail_screen.dart';
import 'package:titulacion/screens/map_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// Un cliente HTTP que responde con lo que le pongamos, sin tocar la red.
class _ClienteFalso extends http.BaseClient {
  _ClienteFalso(this.respuestas);

  final Map<String, String> respuestas;
  final List<String> pedidos = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    pedidos.add(url);
    final cuerpo = respuestas[url];
    if (cuerpo == null) {
      return http.StreamedResponse(
        const Stream<List<int>>.empty(),
        404,
        request: request,
      );
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(cuerpo)),
      200,
      request: request,
    );
  }
}

/// El título en arco ocupa alto: sin una ventana alta, los documentos quedan
/// fuera de la vista y el ListView no los construye.
void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modelos desde JSON', () {
    test('una ruta se parsea con sus niveles', () {
      final ruta = Ruta.fromJson(const {
        'id': 'demo',
        'nombre': 'Ruta de prueba',
        'descripcion': 'Descripción',
        'mascotaInicio': 'mascota.svg',
        'pergaminoInicio': 'pergamino.svg',
        'niveles': [
          {'numero': 0, 'titulo': 'Inicio', 'esInicio': true},
          {
            'numero': 1,
            'titulo': 'Nivel 1',
            'pasos': [
              {'titulo': 'Paso A', 'detalle': 'Detalle A'},
            ],
            'documentos': [
              {'nombre': 'Documento 1', 'nota': 'Nota'},
            ],
          },
        ],
      });

      expect(ruta.id, 'demo');
      expect(ruta.niveles.length, 2);
      // El nivel de inicio no cuenta como nivel jugable.
      expect(ruta.nivelesJugables.length, 1);
      expect(ruta.nivelesJugables.first.pasos.first.titulo, 'Paso A');
      expect(ruta.nivelesJugables.first.documentos.first.nombre, 'Documento 1');
    });

    test('una facultad sin correo no se marca como con contacto', () {
      final conCorreo = Facultad.fromJson(const {
        'nombre': 'Facultad X',
        'clave': 'FX',
        'correo': 'titulacion@correo.buap.mx',
      });
      final sinCorreo = Facultad.fromJson(const {
        'nombre': 'Facultad Y',
        'clave': 'FY',
        'correo': '',
      });

      expect(conCorreo.tieneContacto, isTrue);
      expect(sinCorreo.tieneContacto, isFalse);
    });
  });

  group('Progreso', () {
    late AppState state;

    // Los números de nivel, que no son la cantidad de niveles: el avance se
    // calcula sobre ellos, así que las pruebas los pasan explícitamente.
    final siete = <int>[1, 2, 3, 4, 5, 6, 7];
    final ocho = <int>[1, 2, 3, 4, 5, 6, 7, 8];
    final cinco = <int>[1, 2, 3, 4, 5];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState(await SharedPreferences.getInstance());
    });

    test(
      'sin progreso, el primer nivel es el siguiente y está desbloqueado',
      () {
        expect(state.siguienteNivel('promedio', siete), 1);
        expect(state.nivelDesbloqueado('promedio', 1, siete), isTrue);
        expect(state.nivelDesbloqueado('promedio', 2, siete), isFalse);
      },
    );

    test('completar un nivel desbloquea el siguiente', () async {
      await state.completarNivel('promedio', 1);

      expect(state.estaCompletado('promedio', 1), isTrue);
      expect(state.siguienteNivel('promedio', siete), 2);
      expect(state.nivelDesbloqueado('promedio', 2, siete), isTrue);
      expect(state.nivelDesbloqueado('promedio', 3, siete), isFalse);
    });

    test('el progreso se calcula sobre el total de niveles', () async {
      expect(state.progresoDe('ceneval', ocho), 0);
      await state.completarNivel('ceneval', 1);
      await state.completarNivel('ceneval', 2);
      expect(state.progresoDe('ceneval', ocho), 0.25);
    });

    test('el progreso sobrevive a una recarga de la app', () async {
      await state.completarNivel('promedio', 1);
      await state.alternarDocumento('promedio', 1, 0);

      // Una instancia nueva lee lo que se guardó.
      final recargado = AppState(await SharedPreferences.getInstance());

      expect(recargado.estaCompletado('promedio', 1), isTrue);
      expect(recargado.documentoMarcado('promedio', 1, 0), isTrue);
    });

    test('marcar un documento espera a que quede escrito', () async {
      // La API es asíncrona a propósito: la casilla marcada se anuncia cuando
      // la marca ya está en el disco, no cuando solo está en memoria.
      final pendiente = state.alternarDocumento('promedio', 1, 0);
      expect(pendiente, isA<Future<void>>());
      await pendiente;

      final prefs = await SharedPreferences.getInstance();
      final escrito = json.decode(prefs.getString('progreso')!) as Map;
      expect((escrito['documentos'] as List).cast<String>(), contains('promedio:1:0'));

      // Y otra instancia lo lee: nadie depende de un Future que nadie esperó.
      final recargado = AppState(await SharedPreferences.getInstance());
      expect(recargado.documentoMarcado('promedio', 1, 0), isTrue);

      // Desmarcar también espera.
      await recargado.alternarDocumento('promedio', 1, 0);
      final otro = AppState(await SharedPreferences.getInstance());
      expect(otro.documentoMarcado('promedio', 1, 0), isFalse);
    });

    test('un nivel que no es entero no llega a la interfaz', () async {
      // `List.cast<int>()` es una vista perezosa: la carga pasaba y el fallo
      // reventaba en mapa, perfil o notas. Con un nivel mezclado la app
      // arranca en cero, como promete el comentario de la carga.
      SharedPreferences.setMockInitialValues({
        'progreso': json.encode({
          'completados': {
            'tesis': [1, '2'],
          },
          'documentos': ['tesis:1:0'],
        }),
      });
      final s = AppState(await SharedPreferences.getInstance());

      expect(() => s.completadosDe('tesis'), returnsNormally);
      expect(s.completadosDe('tesis'), isEmpty);
      expect(s.estaCompletado('tesis', 1), isFalse);
      expect(s.siguienteNivel('tesis', cinco), 1);
      expect(s.nivelDesbloqueado('tesis', 2, cinco), isFalse);
      expect(s.progresoDe('tesis', cinco), 0);
      expect(s.documentoMarcado('tesis', 1, 0), isFalse);
      expect(s.nivelesAMigrar('tesis'), 0);
      expect(s.migracionDisponible('tesis-fcc', 'tesis'), isFalse);
      // Y la pantalla sigue funcionando: se puede volver a avanzar de verdad.
      await s.completarNivel('tesis', 1);
      expect(s.estaCompletado('tesis', 1), isTrue);
      expect(AppState(await SharedPreferences.getInstance()).estaCompletado('tesis', 1), isTrue);
    });

    test('una clave de documento que no es texto tampoco llega', () async {
      SharedPreferences.setMockInitialValues({
        'progreso': json.encode({
          'completados': <String, List<int>>{},
          'documentos': ['tesis:1:0', 7],
        }),
      });
      final s = AppState(await SharedPreferences.getInstance());

      expect(() => s.documentoMarcado('tesis', 1, 0), returnsNormally);
      expect(s.documentoMarcado('tesis', 1, 0), isFalse);
    });

    test('un progreso bien escrito se lee exactamente igual que antes', () async {
      SharedPreferences.setMockInitialValues({
        'progreso': json.encode({
          'completados': {
            'tesis': [2, 1],
          },
          'documentos': ['tesis:1:0'],
        }),
      });
      final s = AppState(await SharedPreferences.getInstance());

      expect(s.completadosDe('tesis'), [2, 1]);
      expect(s.estaCompletado('tesis', 1), isTrue);
      expect(s.siguienteNivel('tesis', cinco), 3);
      expect(s.documentoMarcado('tesis', 1, 0), isTrue);
      expect(s.migracionDisponible('tesis-fcc', 'tesis'), isTrue);
    });

    test('registrar guarda el alumno y su facultad', () async {
      await state.registrar(
        const Alumno(nombre: 'Ada Lovelace', matricula: '20201'),
        facultadClave: 'FING',
      );

      final recargado = AppState(await SharedPreferences.getInstance());
      expect(recargado.estaRegistrado, isTrue);
      expect(recargado.alumno!.nombre, 'Ada Lovelace');
      expect(recargado.facultadClave, 'FING');
    });
  });

  group('MapScreen', () {
    late AppState state;
    late Ruta ruta;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState(await SharedPreferences.getInstance());
      ruta = Ruta.fromJson(const {
        'id': 'demo',
        'nombre': 'Ruta de prueba',
        'descripcion': '',
        'mascotaInicio': '',
        'pergaminoInicio': '',
        'niveles': [
          {'numero': 0, 'titulo': 'Inicio', 'esInicio': true},
          {'numero': 1, 'titulo': 'Primer nivel'},
          {'numero': 2, 'titulo': 'Segundo nivel'},
        ],
      });
    });

    testWidgets('muestra una isla por nivel jugable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MapScreen(ruta: ruta, state: state)),
      );
      await tester.pump();

      expect(find.text('Primer nivel'), findsOneWidget);
      expect(find.text('Segundo nivel'), findsOneWidget);
      // El nivel de inicio no aparece como isla.
      expect(find.text('Inicio'), findsNothing);
    });

    testWidgets('un nivel bloqueado no abre su detalle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MapScreen(ruta: ruta, state: state)),
      );
      await tester.pump();

      await tester.tap(find.text('Segundo nivel'));
      await tester.pumpAndSettle();

      // Sigue en el mapa: no se abrió la pantalla de nivel.
      expect(find.text('Segundo nivel'), findsOneWidget);
    });

    testWidgets('tocar el nivel actual abre su detalle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MapScreen(ruta: ruta, state: state)),
      );
      await tester.pump();

      await tester.tap(find.text('Primer nivel'));
      await tester.pumpAndSettle();

      // En el mapa la cifra va dentro del icono; en la pantalla del nivel
      // aparece en el encabezado, que solo enseña la mascota.
      expect(find.text('Nivel 1'), findsOneWidget);
    });
  });

  group('LevelDetailScreen', () {
    late AppState state;
    late Ruta ruta;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState(await SharedPreferences.getInstance());
      ruta = Ruta.fromJson(const {
        'id': 'demo',
        'nombre': 'Ruta de prueba',
        'descripcion': '',
        'mascotaInicio': '',
        'pergaminoInicio': '',
        'niveles': [
          {'numero': 0, 'titulo': 'Inicio', 'esInicio': true},
          {
            'numero': 1,
            'titulo': 'Primer nivel',
            'descripcion': 'Lo que hay que hacer aquí',
            'pasos': [
              {'titulo': 'Paso uno', 'detalle': 'Detalle del paso'},
            ],
            'documentos': [
              {'nombre': 'Constancia'},
              {'nombre': 'Identificación'},
            ],
          },
        ],
      });
    });

    testWidgets('lista los pasos y los documentos del nivel', (tester) async {
      pantallaAlta(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            ruta: ruta,
            nivel: ruta.nivelesJugables.first,
            state: state,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Lo que hay que hacer aquí'), findsOneWidget);
      expect(find.text('Paso uno'), findsOneWidget);
      expect(find.text('Detalle del paso'), findsOneWidget);
      expect(find.text('Constancia'), findsOneWidget);
      expect(find.text('Identificación'), findsOneWidget);
    });

    testWidgets('marcar un documento lo cuenta en el encabezado', (
      tester,
    ) async {
      pantallaAlta(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            ruta: ruta,
            nivel: ruta.nivelesJugables.first,
            state: state,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Documentos (0/2)'), findsOneWidget);

      await tester.tap(find.text('Constancia'));
      await tester.pump();

      expect(find.text('Documentos (1/2)'), findsOneWidget);
      expect(state.documentoMarcado('demo', 1, 0), isTrue);
    });

    testWidgets('completar el nivel lo registra y vuelve al mapa', (
      tester,
    ) async {
      pantallaAlta(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            ruta: ruta,
            nivel: ruta.nivelesJugables.first,
            state: state,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Completar nivel (faltan 2 docs)'));
      await tester.pumpAndSettle();

      expect(state.estaCompletado('demo', 1), isTrue);
      // Volvió al mapa de la ruta.
      expect(find.text('Ruta de prueba'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Requisitos legibles por máquina
  // -------------------------------------------------------------------------

  group('Requisitos', () {
    test(
      'lo que la unidad no publica se lee como "no publicado", no como 0',
      () {
        const r = Requisitos();
        expect(r.sinDatos, isTrue);
        for (final fila in r.filas) {
          expect(fila.conocido, isFalse, reason: fila.clave);
          expect(fila.valor, isEmpty, reason: fila.clave);
        }
      },
    );

    test('los valores se leen con su tipo, no como texto', () {
      final r = Requisitos.fromJson(const {
        'promedioMinimo': 8.5,
        'permiteRecursar': false,
        'porcentajeCreditosMinimo': 100,
        'exigeServicioSocial': true,
      });
      expect(r.promedioMinimo, 8.5);
      expect(r.permiteRecursar, isFalse);
      expect(r.porcentajeCreditosMinimo, 100);
      expect(r.exigeServicioSocial, isTrue);
      // Lo que no viene se queda en null, no en false.
      expect(r.exigeTrabajoEscrito, isNull);
      expect(
        r.filas.firstWhere((f) => f.clave == 'permiteRecursar').valor,
        'No',
      );
    });

    test(
      'la unidad le gana a la ruta base, y la base rellena lo que falta',
      () {
        const base = Requisitos(promedioMinimo: 8.0, exigeEgelCeneval: true);
        const unidad = Requisitos(promedioMinimo: 8.5);
        final f = base.fusionar(unidad);

        expect(f.promedioMinimo, 8.5, reason: 'la unidad manda');
        expect(f.exigeEgelCeneval, isTrue, reason: 'la base rellena el hueco');
        expect(f.exigeTrabajoEscrito, isNull, reason: 'nadie lo publica');
      },
    );
  });

  group('Perfil de aplicación (elegibilidad)', () {
    test('si la unidad no publica perfil, no se puede afirmar nada', () {
      const p = PerfilAplicacion();
      expect(p.publicado, isFalse);
      final e = p.comprobar(carreraId: 'cualquiera', anioIngreso: 2021);
      expect(e.estado, EstadoElegibilidad.unidadNoPublica);
      expect(e.etiqueta, contains('confirma con ella'));
    });

    test('dato publicado y coincidente, coincidencia', () {
      const p = PerfilAplicacion(
        carreraIds: ['fcc-carrera'],
        cohortesDesde: 2020,
      );
      expect(
        p.comprobar(carreraId: 'fcc-carrera', anioIngreso: 2021).estado,
        EstadoElegibilidad.coincide,
      );
    });

    test('dato publicado y fuera de rango', () {
      const p = PerfilAplicacion(cohortesDesde: 2020, cohortesHasta: 2022);
      expect(
        p.comprobar(anioIngreso: 2019).estado,
        EstadoElegibilidad.fueraDeRango,
      );
      expect(
        p.comprobar(anioIngreso: 2023).estado,
        EstadoElegibilidad.fueraDeRango,
      );
      expect(
        p.comprobar(anioIngreso: 2021).estado,
        EstadoElegibilidad.coincide,
      );
    });

    test('dato faltante del alumno no se cuenta como aprobado', () {
      const p = PerfilAplicacion(carreraIds: ['fcc-carrera']);
      final e = p.comprobar();
      expect(e.estado, EstadoElegibilidad.faltaDatoAlumno);
      expect(e.estado, isNot(EstadoElegibilidad.coincide));
    });
  });

  // -------------------------------------------------------------------------
  // Catálogo por unidad y ruta compuesta
  // -------------------------------------------------------------------------

  group('Oferta por unidad', () {
    late ContentRepository repo;

    setUpAll(() {
      repo = ContentRepository.instance..cargarDesdeDiscoParaTests();
    });

    setUp(() {
      repo.invalidarCacheEnMemoria();
    });

    test('el catálogo cubre las 34 unidades con estado declarado', () async {
      final catalogo = await repo.catalogo();
      expect(catalogo.unidades, hasLength(34));
      expect(catalogo.fechaCorte, isNotEmpty);
      expect(catalogo.norma.articuloModalidades, isNotEmpty);
      for (final u in catalogo.unidades) {
        expect(u.estadoCatalogo, isNotEmpty, reason: '${u.clave} sin estado');
      }
    });

    test(
      'una unidad sin catálogo devuelve cero rutas y el rastro de búsqueda',
      () async {
        final oferta = await repo.ofertaDeUnidad('FADMON');
        expect(oferta.vacia, isTrue);
        expect(oferta.unidad!.noPublicaCatalogo, isTrue);
        // Nunca una pantalla vacía: mensaje, URLs consultadas y resultado.
        expect(oferta.mensajeSinCatalogo, contains('no publica catálogo'));
        expect(oferta.rastro, isNotEmpty);
        for (final r in oferta.rastro) {
          expect(r.url, startsWith('https://'));
          expect(r.consultadoEn, isNotEmpty, reason: '${r.url} sin fecha');
          expect(r.resultado, isNotEmpty, reason: '${r.url} sin resultado');
        }
      },
    );

    test('el listado sale filtrado: FCC solo muestra lo suyo', () async {
      final fcc = await repo.ofertaDeUnidad('FCC');
      final arpa = await repo.ofertaDeUnidad('ARPA');
      expect(fcc.vacia, isFalse);
      expect(arpa.vacia, isFalse);

      final idsFcc = fcc.rutas.map((r) => r.id).toSet();
      final idsArpa = arpa.rutas.map((r) => r.id).toSet();
      expect(
        idsFcc.intersection(idsArpa),
        isEmpty,
        reason: 'una modalidad no puede salir en dos unidades',
      );
      for (final id in idsFcc) {
        expect(
          id,
          contains('fcc'),
          reason:
              'se coló la modalidad "$id" de '
              'otra unidad en el listado de FCC',
        );
      }
    });

    test('toda ruta acreditada trae fuente con URL y fecha', () async {
      for (final clave in ['FCC', 'ARPA', 'FING', 'CRNO']) {
        final oferta = await repo.ofertaDeUnidad(clave);
        for (final r in oferta.rutas) {
          final m = r.modalidad!;
          expect(m.tieneFuente, isTrue, reason: '${r.id} sin fuente');
          expect(m.consultadoEn, isNotEmpty, reason: '${r.id} sin fecha');
          expect(r.ruta.citaFuente, isNotEmpty, reason: '${r.id} sin cita');
        }
      }
    });

    test(
      'las modalidades sin ruta base quedan como información, no como oferta',
      () async {
        final arpa = await repo.ofertaDeUnidad('ARPA');
        final sinRuta =
            arpa.informativas.where((i) => i.modalidadId.isNotEmpty).toList();
        expect(sinRuta, isNotEmpty);
        for (final i in sinRuta) {
          expect(
            i.motivo,
            isNotEmpty,
            reason: '${i.modalidadId} sin explicación',
          );
          expect(arpa.rutas.map((r) => r.id), isNot(contains(i.modalidadId)));
        }
      },
    );

    test('una clave que no existe en el catálogo lo dice, no truena', () async {
      final oferta = await repo.ofertaDeUnidad('NOEXISTE');
      expect(oferta.existe, isFalse);
      expect(oferta.vacia, isTrue);
      expect(oferta.mensajeSinCatalogo, contains('NOEXISTE'));
    });
  });

  group('Ruta compuesta', () {
    late ContentRepository repo;

    setUpAll(() {
      repo = ContentRepository.instance..cargarDesdeDiscoParaTests();
    });

    setUp(() {
      repo.invalidarCacheEnMemoria();
    });

    test('la base no se modifica: la variante es una copia', () async {
      final base = await repo.rutaPorId('tesis');
      final nivelesBase = base.niveles.length;

      final compuesta = await repo.rutaCompuestaPorModalidad('tesis-fcc');
      expect(compuesta, isNotNull);
      expect(compuesta!.ruta.id, 'tesis-fcc');
      expect(compuesta.ruta.niveles.length, greaterThan(nivelesBase));

      // La base sigue igual después de componer.
      final despues = await repo.rutaPorId('tesis');
      expect(despues.niveles.length, nivelesBase);
      expect(despues.id, 'tesis');
    });

    test(
      'la variante agrega el nivel de la unidad con su fuente y fecha',
      () async {
        final compuesta = (await repo.rutaCompuestaPorModalidad('tesis-fcc'))!;
        final ultimo = compuesta.ruta.nivelesJugables.last;

        expect(
          ultimo.fuente,
          isNotEmpty,
          reason: 'el nivel de la unidad sin fuente',
        );
        expect(
          ultimo.fecha,
          isNotEmpty,
          reason: 'el nivel de la unidad sin fecha',
        );
        expect(ultimo.pasos, isNotEmpty);
        // El número sigue a la secuencia: no se pisa con un nivel existente.
        final numeros = compuesta.ruta.niveles.map((n) => n.numero).toList();
        expect(
          numeros.toSet().length,
          numeros.length,
          reason: 'hay dos niveles con el mismo número: ${numeros.join(",")}',
        );
      },
    );

    test(
      'los requisitos de la unidad se fusionan sobre los de la base',
      () async {
        final compuesta = (await repo.rutaCompuestaPorModalidad('tesis-fcc'))!;
        final base = await repo.rutaPorId('tesis');
        final deUnidad = compuesta.modalidad!.requisitos;

        var revisados = 0;
        for (final fila in compuesta.requisitos.filas) {
          final unidadFila = deUnidad.filas.firstWhere(
            (f) => f.clave == fila.clave,
          );
          final baseFila = base.requisitosBase.filas.firstWhere(
            (f) => f.clave == fila.clave,
          );
          if (unidadFila.conocido) {
            // Donde la unidad publica, la unidad manda.
            expect(fila.valor, unidadFila.valor, reason: fila.clave);
          } else if (baseFila.conocido) {
            // Donde la unidad no publica, la base rellena el hueco.
            expect(fila.valor, baseFila.valor, reason: fila.clave);
          } else {
            // Donde nadie publica: "no publicado", nunca un cero inventado.
            expect(fila.conocido, isFalse, reason: fila.clave);
          }
          revisados++;
        }
        expect(revisados, greaterThan(5));

        // La ruta base sola no dice que FCC exija trabajo escrito: eso lo aporta
        // la unidad, y por eso la fusión no es un alias de la base.
        expect(
          base.requisitosBase.filas
              .firstWhere((f) => f.clave == 'exigeTrabajoEscrito')
              .conocido,
          isFalse,
        );
        expect(
          compuesta.requisitos.filas
              .firstWhere((f) => f.clave == 'exigeTrabajoEscrito')
              .conocido,
          isTrue,
        );
      },
    );

    test('el adaptador legado devuelve la ruta global sin modalidad', () async {
      final c = await repo.rutaDeOferta('ceneval');
      expect(c, isNotNull);
      expect(c!.modalidad, isNull);
      expect(c.ruta.id, 'ceneval');
      expect(c.requisitos, isNotNull);
      // Un id que no existe en ningún lado devuelve null, no truena.
      expect(await repo.rutaDeOferta('no-existe'), isNull);
      expect(await repo.rutaDeOferta(''), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Progreso: esquemas, aislamiento y migración
  // -------------------------------------------------------------------------

  group('AppState: esquema 2 y aislamiento del progreso', () {
    late AppState state;

    Future<AppState> estadoLimpio([
      Map<String, Object> inicial = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(Map<String, Object>.from(inicial));
      return AppState(await SharedPreferences.getInstance());
    }

    setUp(() async {
      state = await estadoLimpio();
    });

    test('registrar exige unidad y deja el esquema en 2', () async {
      await state.registrar(
        const Alumno(nombre: 'Ada', matricula: '202145678'),
        facultadClave: 'FING',
      );
      expect(state.esquema, 2);
      expect(state.facultadClave, 'FING');
      expect(state.modalidadActiva, isNull);
    });

    test('el avance de una modalidad no aparece en otra', () async {
      await state.registrar(
        const Alumno(nombre: 'Ada', matricula: '202145678'),
        facultadClave: 'FCC',
      );
      await state.elegirModalidad('tesis-fcc', 'tesis');
      await state.completarNivel('tesis-fcc', 1);

      expect(state.estaCompletado('tesis-fcc', 1), isTrue);
      // Ni en la ruta base ni en otra modalidad de la misma unidad.
      expect(state.estaCompletado('tesis', 1), isFalse);
      expect(state.estaCompletado('experiencia-profesional-fcc', 1), isFalse);
      expect(state.estaCompletado('promedio', 1), isFalse);
    });

    test(
      'al elegir una modalidad el avance empieza en cero, sin pedir permiso',
      () async {
        await state.registrar(
          const Alumno(nombre: 'Ada', matricula: '202145678'),
          facultadClave: 'FCC',
        );
        await state.completarNivel('tesis', 1); // avance legado de la ruta base
        await state.elegirModalidad('tesis-fcc', 'tesis');

        expect(state.estaCompletado('tesis-fcc', 1), isFalse);
        expect(state.migracionDisponible('tesis-fcc', 'tesis'), isTrue);
        expect(state.nivelesAMigrar('tesis'), 1);
      },
    );

    test('la migración copia el avance y no borra el original', () async {
      await state.registrar(
        const Alumno(nombre: 'Ada', matricula: '202145678'),
        facultadClave: 'FCC',
      );
      await state.completarNivel('tesis', 1);
      await state.alternarDocumento('tesis', 2, 0);

      await state.elegirModalidad('tesis-fcc', 'tesis');
      await state.migrarProgreso('tesis-fcc', 'tesis');

      expect(state.estaCompletado('tesis-fcc', 1), isTrue);
      expect(state.documentoMarcado('tesis-fcc', 2, 0), isTrue);
      // El original sigue ahí: si el alumno se arrepiente, no perdió nada.
      expect(state.estaCompletado('tesis', 1), isTrue);

      // Y no se vuelve a ofrecer.
      expect(state.migracionDisponible('tesis-fcc', 'tesis'), isFalse);
    });

    test(
      'cambiar de unidad deselecciona la oferta y aísla el avance',
      () async {
        await state.registrar(
          const Alumno(nombre: 'Ada', matricula: '202145678'),
          facultadClave: 'FCC',
        );
        await state.elegirModalidad('tesis-fcc', 'tesis');
        await state.completarNivel('tesis-fcc', 1);

        await state.elegirFacultad('ARPA');

        expect(state.modalidadActiva, isNull);
        expect(state.rutaActiva, isNull);
        // El avance no se borra: sigue en su propio espacio de nombres.
        final recargado = AppState(await SharedPreferences.getInstance());
        await recargado.registrar(
          const Alumno(nombre: 'Ada', matricula: '202145678'),
          facultadClave: 'FCC',
        );
        await recargado.elegirModalidad('tesis-fcc', 'tesis');
        expect(recargado.estaCompletado('tesis-fcc', 1), isTrue);
      },
    );

    test('las claves de la versión 1 se leen y no se borran', () async {
      // Estado escrito por la app anterior: progreso bajo `rutaId`.
      final previo = await estadoLimpio({
        'alumno': json.encode({'nombre': 'Ada', 'matricula': '202145678'}),
        'facultad': 'FING',
        'ruta': 'ceneval',
        'progreso': json.encode({
          'completados': {
            'ceneval': [1, 2],
          },
          'documentos': ['ceneval:3:0'],
        }),
      });

      expect(previo.esquema, 1, reason: 'el estado viejo se reconoce como tal');
      expect(previo.estaCompletado('ceneval', 2), isTrue);
      expect(previo.documentoMarcado('ceneval', 3, 0), isTrue);

      // Al elegir una modalidad se escribe el esquema 2, pero lo viejo queda.
      await previo.elegirModalidad('ceneval-fcc', 'ceneval');
      expect(previo.esquema, 2);
      expect(previo.modalidadActiva, 'ceneval-fcc');
      // La modalidad NO lee el avance legado por su cuenta.
      expect(previo.estaCompletado('ceneval-fcc', 1), isFalse);
      expect(previo.migracionDisponible('ceneval-fcc', 'ceneval'), isTrue);

      // Y el adaptador legado sigue funcionando con `elegirRuta`.
      await previo.elegirRuta('ceneval');
      expect(previo.estaCompletado('ceneval', 2), isTrue);
      expect(previo.modalidadActiva, isNull);
    });

    test('el contexto académico se guarda y es opcional', () async {
      await state.registrar(
        const Alumno(nombre: 'Ada', matricula: '202145678'),
        facultadClave: 'FING',
      );
      expect(state.tieneContexto, isFalse);

      await state.guardarContexto(carreraId: ' FING-CI ', anioIngreso: 2021);
      expect(state.carreraId, 'FING-CI');
      expect(state.anioIngreso, 2021);
      expect(state.tieneContexto, isTrue);

      final recargado = AppState(await SharedPreferences.getInstance());
      expect(recargado.carreraId, 'FING-CI');
      expect(recargado.anioIngreso, 2021);
    });
  });

  // -------------------------------------------------------------------------
  // Actualizador de contenido
  // -------------------------------------------------------------------------

  group('Actualizador de contenido', () {
    late ContentRepository repo;
    late Map<String, dynamic> catalogoBase;

    const manifiesto = 'https://contenido.buap.mx/catalogo.json';
    const urlCatalogo = 'https://contenido.buap.mx/catalogo_2027.json';
    const claveId = 'buap-2099';

    /// Par de claves de la prueba. La app verifica la firma de verdad, así que
    /// aquí hay que firmar de verdad: antes estas pruebas ponían 'AAA' como
    /// clave y 'ZmFrZQ==' como firma, y pasaban porque nadie comprobaba nada.
    late KeyPair parDePrueba;
    late String publicaB64;

    setUp(() async {
      parDePrueba = await Ed25519().newKeyPair();
      publicaB64 = base64Encode(
        ((await parDePrueba.extractPublicKey()) as SimplePublicKey).bytes,
      );
      ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
      SharedPreferences.setMockInitialValues({});
      repo = ContentRepository.instance..cargarDesdeDiscoParaTests();
      repo.invalidarCacheEnMemoria();
      catalogoBase =
          json.decode(
                File(
                  '${Directory.current.path}/assets/json/catalogo_modalidades.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
    });

    tearDown(() {
      ContentRepository.hostsPermitidosDePrueba = null;
      ContentRepository.clavesPublicasDePrueba = null;
      repo.clienteHttpParaPruebas(null);
    });

    /// Arma un manifiesto y el catálogo que él describe.
    /// La cadena canónica que firma la app, tal cual la rebuild
    /// `ManifiestoContenido.bytesFirmados`.
    List<int> payloadFirmado({
      required String version,
      required String generado,
      required String expira,
      required String url,
      required String hash,
    }) => utf8.encode(
      <String>[
        'loboapp-contenido-v1',
        version,
        generado,
        expira,
        url,
        hash,
        // Salto final firmado, igual que en `bytesFirmados`.
        '',
      ].join('\n'),
    );

    Future<String> firmarPayload(List<int> payload) async => base64Encode(
      (await Ed25519().sign(payload, keyPair: parDePrueba)).bytes,
    );

    /// Arma un manifiesto firmado de verdad y el catálogo que él describe.
    ///
    /// [alterar] permite dejar el manifiesto desincronizado de su firma, que
    /// es justo lo que la app tiene que detectar.
    Future<Map<String, String>> respuestas({
      String version = '2099.01.01-001',
      String expira = '2099-01-01T00:00:00Z',
      String sha = '',
      String algoritmo = 'Ed25519',
      bool firmar = true,
      Map<String, dynamic>? catalogo,
      void Function(Map<String, dynamic> manifiesto)? alterar,
    }) async {
      final cuerpo = catalogo ?? catalogoBase;
      final bytes = utf8.encode(json.encode(cuerpo));
      final hashReal = sha256.convert(bytes).toString();
      final generado = '2026-09-29T00:00:00Z';
      final hashFinal = sha.isEmpty ? hashReal : sha;

      final manifiestoJson = <String, dynamic>{
        'catalogoVersion': version,
        'generadoEn': generado,
        'expiraEn': expira,
        'urlContenido': urlCatalogo,
        'sha256': hashFinal,
        'firma': {
          'algoritmo': algoritmo,
          'claveId': claveId,
          'valorBase64':
              firmar
                  ? await firmarPayload(
                    payloadFirmado(
                      version: version,
                      generado: generado,
                      expira: expira,
                      url: urlCatalogo,
                      hash: hashFinal,
                    ),
                  )
                  : base64Encode(List<int>.filled(64, 0)),
        },
      };
      alterar?.call(manifiestoJson);
      return {
        manifiesto: json.encode(manifiestoJson),
        urlCatalogo: json.encode(cuerpo),
      };
    }

    test('sin host de publicación declarado no se descarga nada', () async {
      // Vacío a propósito: simula una compilación donde no se declaró ningún
      // host. En producción sí hay uno (GitHub Pages), así que sin esto la
      // prueba dependería de la lista de compilación.
      ContentRepository.hostsPermitidosDePrueba = const {};
      final cliente = _ClienteFalso(await respuestas());
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.sinConfianza);
      expect(cliente.pedidos, isEmpty, reason: 'no debe tocar la red');
      // Y la app sigue con el asset embebido.
      expect((await repo.catalogo()).origen, CatalogoModalidades.origenEmbi);
    });

    test('un host que no está en la lista se rechaza sin descargar', () async {
      ContentRepository.hostsPermitidosDePrueba = {'titulacion.buap.mx'};
      final cliente = _ClienteFalso(await respuestas());
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.rechazada);
      expect(r.motivo, contains('contenido.buap.mx'));
      expect(cliente.pedidos, isEmpty);
    });

    test('solo HTTPS: un manifiesto en http plano no se acepta', () async {
      ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
      final cliente = _ClienteFalso(await respuestas());
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(
        manifiestoUrl: 'http://contenido.buap.mx/catalogo.json',
      );
      expect(r.estado, EstadoActualizacion.rechazada);
      expect(r.motivo, contains('HTTPS'));
      expect(cliente.pedidos, isEmpty);
    });

    test(
      'una firma de una clave en la que no se confía no se instala',
      () async {
        ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
        // Vacío: la app cae en sus claves de compilación, que no conocen la
        // clave de la prueba.
        ContentRepository.clavesPublicasDePrueba = const {};
        final cliente = _ClienteFalso(await respuestas());
        repo.clienteHttpParaPruebas(cliente);

        final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
        expect(r.estado, EstadoActualizacion.sinConfianza);
        expect(r.motivo, contains('buap-2099'));
        expect(
          (await repo.catalogo()).catalogoVersion,
          isNot('2099.01.01-001'),
        );
      },
    );

    test('un manifiesto sin firma tampoco', () async {
      ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
      ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
      final cliente = _ClienteFalso(await respuestas(algoritmo: ''));
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.sinConfianza);
      expect(r.motivo, contains('firma'));
    });

    test('un manifiesto vencido no se instala', () async {
      ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
      ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
      final cliente = _ClienteFalso(await respuestas(expira: '2020-01-01T00:00:00Z'));
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.rechazada);
      expect(r.motivo, contains('venció'));
    });

    test('si el contenido no cuadra con el hash se descarta', () async {
      ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
      ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
      final cliente = _ClienteFalso(await respuestas(sha: 'a' * 64));
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.rechazada);
      expect(r.motivo, contains('hash'));
      // Sigue el contenido anterior.
      expect((await repo.catalogo()).origen, CatalogoModalidades.origenEmbi);
    });

    test('un catálogo con el mismo contenido no cambia nada', () async {
      ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
      ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
      final cliente = _ClienteFalso(
        await respuestas(version: catalogoBase['catalogoVersion'] as String),
      );
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.sinCambio);
    });

    test('un catálogo con el mismo contenido y otra URL y hash, sin firma '
        'confiable, tampoco pasa', () async {
      // Sustituir url + hash juntos es el ataque clásico; la firma es lo único
      // que lo detiene.
      ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
      ContentRepository.clavesPublicasDePrueba = const {};
      final cliente = _ClienteFalso(await respuestas());
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.sinConfianza);
      expect((await repo.catalogo()).origen, CatalogoModalidades.origenEmbi);
    });

    test(
      'con host, clave y hash correctos se instala y queda en caché',
      () async {
        ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
        ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
        final nuevo =
            Map<String, dynamic>.from(catalogoBase)
              ..['catalogoVersion'] = '2099.01.01-001'
              ..['fechaCorte'] = '2027-01-01';
        final cliente = _ClienteFalso(await respuestas(catalogo: nuevo));
        repo.clienteHttpParaPruebas(cliente);

        final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
        expect(r.estado, EstadoActualizacion.actualizada);
        expect(r.version, '2099.01.01-001');
        expect((await repo.catalogo()).origen, CatalogoModalidades.origenCache);
        expect((await repo.catalogo()).fechaCorte, '2027-01-01');

        // Y la caché sobrevive a reiniciar el repositorio en memoria.
        repo.invalidarCacheEnMemoria();
        final otra = await repo.catalogo();
        expect(otra.catalogoVersion, '2099.01.01-001');
        expect(otra.fechaCorte, '2027-01-01');

        // Descartarla devuelve al asset embebido.
        await repo.descartarCache();
        expect((await repo.catalogo()).origen, CatalogoModalidades.origenEmbi);
      },
    );

    test('un manifiesto al que le cambian el hash es rechazado', () async {
      // El ataque que la verificación de firma tiene que detener: publicar el
      // mismo catálogo pero prometer otro hash. El SHA-256 del contenido sigue
      // cuadrando con el contenido real, así que la única defensa es la firma.
      ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
      ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
      final cliente = _ClienteFalso(
        await respuestas(
          alterar:
              (m) => m['sha256'] =
                  '0000000000000000000000000000000000000000000000000000000000000000',
        ),
      );
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.sinConfianza);
      expect(r.motivo, contains('firma'));
      expect((await repo.catalogo()).origen, CatalogoModalidades.origenEmbi);
    });

    test('un manifiesto con otra caducidad es rechazado', () async {
      // Alguien alarga la vigencia para que un manifiesto viejo siga valiendo.
      ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
      ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
      final cliente = _ClienteFalso(
        await respuestas(
          alterar: (m) => m['expiraEn'] = '2099-12-31T00:00:00Z',
        ),
      );
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.sinConfianza);
      expect((await repo.catalogo()).origen, CatalogoModalidades.origenEmbi);
    });

    test('una firma hecha con otra clave es rechazada', () async {
      // El manifiesto bien formado y bien firmado, pero por una clave en la
      // que la app no confía.
      final otroPar = await Ed25519().newKeyPair();
      final bytes = utf8.encode(json.encode(catalogoBase));
      final hash = sha256.convert(bytes).toString();
      final firmaAjena = base64Encode(
        (
          await Ed25519().sign(
            payloadFirmado(
              version: '2099.01.01-001',
              generado: '2026-09-29T00:00:00Z',
              expira: '2099-01-01T00:00:00Z',
              url: urlCatalogo,
              hash: hash,
            ),
            keyPair: otroPar,
          )
        ).bytes,
      );
      ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
      ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
      final cliente = _ClienteFalso(
        await respuestas(
          alterar: (m) => m['firma'] = {
            'algoritmo': 'Ed25519',
            'claveId': claveId,
            'valorBase64': firmaAjena,
          },
        ),
      );
      repo.clienteHttpParaPruebas(cliente);

      final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
      expect(r.estado, EstadoActualizacion.sinConfianza);
      expect((await repo.catalogo()).origen, CatalogoModalidades.origenEmbi);
    });

    test(
      'un catálogo remoto sin unidades se rechaza aunque el hash cuadre',
      () async {
        ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
        ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
        final cliente = _ClienteFalso(
          await respuestas(
            catalogo: const {
              'catalogoVersion': '2099.01.01-001',
              'fechaCorte': '2027-01-01',
              'unidades': <dynamic>[],
            },
          ),
        );
        repo.clienteHttpParaPruebas(cliente);

        final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
        expect(r.estado, EstadoActualizacion.rechazada);
        expect(r.motivo, contains('unidades'));
      },
    );

    test(
      'un catálogo remoto que contradice su propio estado se rechaza',
      () async {
        ContentRepository.hostsPermitidosDePrueba = {'contenido.buap.mx'};
        ContentRepository.clavesPublicasDePrueba = {claveId: publicaB64};
        // Declara que no publica catálogo pero trae modalidades.
        final unidades =
            (catalogoBase['unidades'] as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        final sinCatalogo = unidades.firstWhere((u) => u['clave'] == 'FADMON');
        sinCatalogo['estadoCatalogo'] = 'unidad_no_publica_catalogo';
        sinCatalogo['modalidades'] = [
          {
            'modalidadId': 'inventada',
            'rutaId': 'tesis',
            'nombreOficial': 'Inventada',
            'seleccionable': true,
            'fuente': 'https://ejemplo.invalid/',
          },
        ];
        final cliente = _ClienteFalso(
          await respuestas(
            catalogo: {
              'catalogoVersion': '2099.01.01-001',
              'fechaCorte': '2027-01-01',
              'unidades': unidades,
            },
          ),
        );
        repo.clienteHttpParaPruebas(cliente);

        final r = await repo.actualizarDesdeWeb(manifiestoUrl: manifiesto);
        expect(r.estado, EstadoActualizacion.rechazada);
        expect(r.motivo, contains('FADMON'));
      },
    );

    test('el manifiesto vencido y sin fecha no vence nunca por invención', () {
      final sinFecha = ManifiestoContenido.fromJson(const {
        'catalogoVersion': 'a',
        'urlContenido': 'https://x.example/c.json',
        'sha256': 'b',
      });
      expect(sinFecha.estaVencido, isFalse);
      final futuro = ManifiestoContenido.fromJson(const {
        'catalogoVersion': 'a',
        'expiraEn': '2099-01-01T00:00:00Z',
        'urlContenido': 'https://x.example/c.json',
        'sha256': 'b',
      });
      expect(futuro.estaVencido, isFalse);
    });
  });
}
