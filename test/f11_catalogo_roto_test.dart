import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/backup_screen.dart';
import 'package:titulacion/screens/home_screen.dart';
import 'package:titulacion/screens/notes_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// F-11: tres pantallas que resuelven la oferta activa sin manejar el fallo del
/// catálogo.
///
/// Notas dejaba el `CircularProgressIndicator` girando para siempre cuando
/// `rutaEfectivaPorId` lanzaba, el botón de mapa soltaba la excepción suelta y la
/// pantalla de respaldo se quedaba sin niveles ni explicación. Aquí se rompe el
/// asset real que las tres leen (`ContentRepository.assetCatalogo`, el mismo gancho
/// que usa `assetsRotosDePrueba` en el resto de las pruebas de resiliencia) y se
/// comprueba que avisan y que no queda ninguna de ellas girando.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ContentRepository.instance.cargarDesdeDiscoParaTests();
    ContentRepository.assetsRotosDePrueba = const {
      ContentRepository.assetCatalogo,
    };
    ContentRepository.instance.invalidarCacheEnMemoria();
  });

  tearDown(() {
    ContentRepository.assetsRotosDePrueba = const {};
  });

  Future<AppState> estadoConOferta() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    await state.registrar(
      const Alumno(nombre: 'María Fernanda López', matricula: '202145678'),
      facultadClave: 'FCC',
    );
    await state.elegirModalidad('tesis-fcc', 'tesis');
    return state;
  }

  group('F-11: un catálogo que no llega se explica y no se queda girando', () {
    testWidgets('notas avisa y no deja el spinner girando', (tester) async {
      final state = await estadoConOferta();

      await tester.pumpWidget(
        MaterialApp(home: NotesScreen(state: state, notas: state.notas)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.textContaining('No se pudieron cargar los niveles'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('notas vuelve a cargar cuando el contenido regresa', (tester) async {
      final state = await estadoConOferta();
      await tester.pumpWidget(
        MaterialApp(home: NotesScreen(state: state, notas: state.notas)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);

      ContentRepository.assetsRotosDePrueba = const {};
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('el botón de mapa avisa en vez de dejar la excepción suelta', (
      tester,
    ) async {
      final state = await estadoConOferta();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: HomeScreen(state: state)));
      await tester.pumpAndSettle();

      expect(find.text('Mapa'), findsOneWidget);
      await tester.ensureVisible(find.text('Mapa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No se pudo abrir el mapa'),
        findsOneWidget,
      );
      // No se empujó la pantalla del mapa: la excepción se digiere aquí.
      expect(tester.takeException(), isNull);
    });

    testWidgets('respaldo avisa y sigue permitiendo copiar', (tester) async {
      final state = await estadoConOferta();

      await tester.pumpWidget(
        MaterialApp(
          home: BackupScreen(
            state: state,
            notas: state.notas,
            escribirPortapapeles: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.textContaining('No se pudieron cargar los niveles'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      // El respaldo se puede copiar igual: lo que no viaja, el propio bloque lo
      // dice en su `alcance`.
      await tester.tap(find.text('Copiar mi respaldo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Así quedó el respaldo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
