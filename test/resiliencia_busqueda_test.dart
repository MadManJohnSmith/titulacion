import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/screens/contacts_screen.dart';
import 'package:titulacion/screens/directory_screen.dart';
import 'package:titulacion/screens/register_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/services/staff_repository.dart';
import 'package:titulacion/services/student_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// F-06 y F-07 sobre el producto real y sus assets reales.
///
/// No hay fakes: se rompe el asset que la pantalla lee para comprobar que avisa
/// y que el spinner termina, y se buscan nombres de verdad en el padrón de la
/// BUAP para comprobar que el trabajo pesado no cae en el isolate de la interfaz.
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
    StaffRepository.assetsRotosDePrueba = const {};
    StudentRepository.assetsRotosDePrueba = const {};
    StaffRepository.instance.invalidarCacheEnMemoria();
    StudentRepository.instance.invalidarCacheEnMemoria();
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

    testWidgets('el directorio avisa si el asset no llega', (tester) async {
      StaffRepository.assetsRotosDePrueba = const {
        'assets/trabajadores/index.json',
      };
      await tester.pumpWidget(const MaterialApp(home: DirectoryScreen()));
      await tester.enterText(find.byType(TextField), 'Pérez');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.textContaining('No se pudo consultar el directorio'),
        findsOneWidget,
      );
    });

    test('el directorio sí busca cuando el asset llega', () async {
      final resultados = await StaffRepository.instance.buscar('PEREZ');

      expect(resultados, isNotEmpty);
      expect(
        resultados.first.nombre.toLowerCase(),
        contains('perez'),
      );
    });

    testWidgets('el registro avisa si la base no llega y deja seguir', (
      tester,
    ) async {
      StudentRepository.assetsRotosDePrueba = const {
        'assets/alumnos/index.json',
      };
      final state = await estadoLimpio();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: RegisterScreen(state: state)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '202000104');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.textContaining('No se pudo consultar la base'),
        findsOneWidget,
      );
      expect(find.text('Continuar como invitado'), findsOneWidget);
    });
  });

  group('F-07: la búsqueda por nombre sale del isolate de la interfaz', () {
    test(
      'el padrón se busca en un isolate hijo y no queda residente en memoria',
      () async {
        final repo = StudentRepository.instance;
        final encontrado = await repo.buscar('aguilar lopez');

        expect(encontrado, isNotNull, reason: 'el nombre está en el padrón real');
        expect(encontrado!.nombre.toLowerCase(), contains('aguilar lopez'));
        expect(encontrado.matricula, isNotEmpty);
        expect(
          StudentRepository.ultimoIsolateDeBusqueda,
          StudentRepository.etiquetaIsolateDeBusqueda,
          reason: 'la descompresión y el filtrado corren en un isolate hijo',
        );
        expect(
          Isolate.current.debugName,
          isNot(StudentRepository.etiquetaIsolateDeBusqueda),
          reason: 'el isolate de la interfaz no puede ser el que busca',
        );
        expect(
          repo.cohortesEnMemoria,
          0,
          reason: 'buscar por nombre no deja las 318 mil filas en memoria',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'mientras recorre las 318 mil filas, la interfaz sigue respondiendo',
      () async {
        var ticks = 0;
        final reloj = Timer.periodic(
          const Duration(milliseconds: 20),
          (_) => ticks++,
        );
        // Peor caso: nadie coincide, así que se descomprime el padrón entero.
        final encontrado = await StudentRepository.instance.buscar('zzzzz');
        reloj.cancel();

        expect(encontrado, isNull);
        expect(
          ticks,
          greaterThan(0),
          reason: 'el isolate principal quedó bloqueado buscando',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('buscar por matrícula sigue cargando una sola cohorte', () async {
      final repo = StudentRepository.instance;
      final encontrado = await repo.buscar('202000104');

      expect(encontrado, isNotNull);
      expect(encontrado!.matricula, '202000104');
      expect(
        repo.cohortesEnMemoria,
        1,
        reason: 'la matrícula solo lee la cohorte de su prefijo',
      );
    });

    test('si el asset no llega, la búsqueda falla en vez de colgarse', () async {
      StudentRepository.assetsRotosDePrueba = const {
        'assets/alumnos/index.json',
      };
      await expectLater(
        StudentRepository.instance.buscar('aguilar lopez'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
