import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/screens/contacts_screen.dart';
import 'package:titulacion/screens/register_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// F-06 sobre el producto real y sus assets reales.
///
/// No hay fakes: se rompe el asset que la pantalla lee para comprobar que avisa
/// y que el spinner termina.
///
/// F-07 (la búsqueda por nombre salía del isolate de la interfaz) ya no aplica:
/// esas pruebas medían el coste de recorrer las 318 mil filas de un padrón que
/// la app ya no distribuye. En su lugar el registro se comprueba sin padrón.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> estadoLimpio() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance());
  }

  setUp(() {
    // Mismo truco que el resto de las pruebas del proyecto: en los widget tests
    // no hay bundle, así que el contenido real se lee del disco del proyecto.
    // Los fallos se provocan con los ganchos de assets, que cortan antes.
    ContentRepository.instance.cargarDesdeDiscoParaTests();
    ContentRepository.assetsRotosDePrueba = const {};
  });

  group('F-06: una carga que falla se explica y no se queda girando', () {
    testWidgets('ayuda y contactos avisa si el asset no llega', (tester) async {
      ContentRepository.assetsRotosDePrueba = const {
        'assets/json/contactos.json',
      };
      final state = await estadoLimpio();
      await tester.pumpWidget(MaterialApp(home: ContactsScreen(state: state)));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.textContaining('No se pudieron cargar los contactos'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('ayuda y contactos carga cuando el asset vuelve', (tester) async {
      ContentRepository.assetsRotosDePrueba = const {
        'assets/json/contactos.json',
      };
      final state = await estadoLimpio();
      await tester.pumpWidget(MaterialApp(home: ContactsScreen(state: state)));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);

      ContentRepository.assetsRotosDePrueba = const {};
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsNothing);
      expect(
        find.text('Dirección de Administración Escolar (DAE)'),
        findsOneWidget,
      );
    });

  });

  group('El registro funciona sin ningún padrón de alumnos', () {
    testWidgets('se registra con nombre y matrícula escritos a mano', (
      tester,
    ) async {
      final state = await estadoLimpio();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: RegisterScreen(state: state)));
      await tester.pumpAndSettle();

      // Dos campos: nombre y matrícula. No hay buscador.
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Matrícula o nombre'), findsNothing);
      // Y la pantalla dice en claro que no consulta ninguna base.
      expect(
        find.textContaining('no consulta ninguna base de la BUAP'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(0), 'María Fernanda López');
      await tester.enterText(find.byType(TextField).at(1), '202145678');
      await tester.pumpAndSettle();

      final desplegable = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(desplegable);
      await tester.tap(desplegable);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenuItem<String>).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Comenzar mi aventura'));
      await tester.pumpAndSettle();

      expect(state.alumno?.nombre, 'María Fernanda López');
      expect(state.alumno?.matricula, '202145678');
    });

    testWidgets('avisa del formato de la matrícula sin bloquear el avance', (
      tester,
    ) async {
      final state = await estadoLimpio();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: RegisterScreen(state: state)));
      await tester.pumpAndSettle();

      // 9 dígitos pero con una cohorte imposible: la forma no cuadra.
      await tester.enterText(find.byType(TextField).at(1), '123456789');
      await tester.pumpAndSettle();

      // El aviso explica que es de forma y no de contenido, y no bloquea.
      expect(find.textContaining('9 dígitos'), findsOneWidget);
      expect(find.textContaining('no la verifica'), findsOneWidget);
      expect(find.text('Comenzar mi aventura'), findsOneWidget);

      // Con una matrícula bien formada el aviso desaparece.
      await tester.enterText(find.byType(TextField).at(1), '202145678');
      await tester.pumpAndSettle();
      expect(find.textContaining('no la verifica'), findsNothing);
    });

    testWidgets('se puede entrar sin escribir nada', (tester) async {
      final state = await estadoLimpio();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: RegisterScreen(state: state)));
      await tester.pumpAndSettle();

      // Elige unidad y continúa sin nombre ni matrícula.
      final desplegable = find.byType(DropdownButtonFormField<String>);
      expect(desplegable, findsOneWidget);
      await tester.ensureVisible(desplegable);
      await tester.tap(desplegable);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenuItem<String>).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Comenzar mi aventura'));
      await tester.pumpAndSettle();

      expect(state.alumno, isNotNull);
      expect(state.alumno?.nombre, '');
      expect(state.alumno?.matricula, '');
    });
  });
}
