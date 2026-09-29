import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/level_detail_screen.dart';
import 'package:titulacion/screens/map_screen.dart';
import 'package:titulacion/state/app_state.dart';

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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState(await SharedPreferences.getInstance());
    });

    test('sin progreso, el primer nivel es el siguiente y está desbloqueado', () {
      expect(state.siguienteNivel('promedio', 7), 1);
      expect(state.nivelDesbloqueado('promedio', 1), isTrue);
      expect(state.nivelDesbloqueado('promedio', 2), isFalse);
    });

    test('completar un nivel desbloquea el siguiente', () async {
      await state.completarNivel('promedio', 1);

      expect(state.estaCompletado('promedio', 1), isTrue);
      expect(state.siguienteNivel('promedio', 7), 2);
      expect(state.nivelDesbloqueado('promedio', 2), isTrue);
      expect(state.nivelDesbloqueado('promedio', 3), isFalse);
    });

    test('el progreso se calcula sobre el total de niveles', () async {
      expect(state.progresoDe('ceneval', 8), 0);
      await state.completarNivel('ceneval', 1);
      await state.completarNivel('ceneval', 2);
      expect(state.progresoDe('ceneval', 8), 0.25);
    });

    test('el progreso sobrevive a una recarga de la app', () async {
      await state.completarNivel('promedio', 1);
      state.alternarDocumento('promedio', 1, 0);

      // Una instancia nueva lee lo que se guardó.
      final recargado = AppState(await SharedPreferences.getInstance());

      expect(recargado.estaCompletado('promedio', 1), isTrue);
      expect(recargado.documentoMarcado('promedio', 1, 0), isTrue);
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

    testWidgets('marcar un documento lo cuenta en el encabezado', (tester) async {
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

    testWidgets('completar el nivel lo registra y vuelve al mapa',
        (tester) async {
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
}
