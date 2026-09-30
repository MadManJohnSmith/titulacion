import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/register_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// F-12: el avance y las notas se guardan por modalidad y no por persona.
///
/// Quien se registra después en el mismo teléfono ve lo de quien estaba antes en
/// la misma modalidad. El criterio de aceptación del hallazgo admite las dos
/// salidas: aislar el estado por persona, o **avisar explícitamente en el
/// registro** y decirlo en `docs/PRIVACIDAD.md`. Aquí se comprueba la segunda, y
/// también que el aviso describe la conducta real: si el aviso mintiera, el
/// hallazgo seguiría vivo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ContentRepository.instance.cargarDesdeDiscoParaTests();
  });

  Future<AppState> estadoConAlumna() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    await state.registrar(
      const Alumno(nombre: 'María Fernanda López', matricula: '202145678'),
      facultadClave: 'FCC',
    );
    await state.elegirModalidad('tesis-fcc', 'tesis');
    await state.completarNivel('tesis-fcc', 1);
    await state.notas.guardar(
      state.namespaceDe('tesis-fcc'),
      1,
      'mi nota privada',
    );
    return state;
  }

  group('F-12: registrar a otra persona avisa antes de seguir', () {
    testWidgets('el aviso aparece y cancelar no registra a nadie', (tester) async {
      final state = await estadoConAlumna();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: RegisterScreen(state: state)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facultad de Ciencias de la Computación').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar como invitado'));
      await tester.pumpAndSettle();

      expect(find.text('Vas a registrar a otra persona'), findsOneWidget);
      expect(find.textContaining('María Fernanda López'), findsOneWidget);
      expect(find.textContaining('no los borra'), findsOneWidget);
      expect(find.textContaining('Cerrar sesión'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(state.alumno!.nombre, 'María Fernanda López');
    });

    testWidgets('quien acepta el aviso registra a la otra persona', (tester) async {
      final state = await estadoConAlumna();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: RegisterScreen(state: state)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facultad de Ciencias de la Computación').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar como invitado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar de todos modos'));
      await tester.pumpAndSettle();

      expect(state.alumno!.matricula, isEmpty, reason: 'entró como invitado');
      expect(state.facultadClave, 'FCC');
      expect(state.rutaActiva, isNull, reason: 'registrar deselecciona la oferta');

      // El aviso es obligatorio, no un adorno: al elegir la misma modalidad, la
      // segunda persona ve el avance y las notas de la primera. Si esto dejara
      // de ser cierto, el aviso de F-12 estaría mintiendo.
      await state.elegirModalidad('tesis-fcc', 'tesis');
      expect(state.completadosDe('tesis-fcc'), [1]);
      expect(state.notas.textoDe('modalidad:tesis-fcc', 1), 'mi nota privada');
    });

    test('el aviso de privacidad dice lo mismo que el registro', () {
      final aviso = File('docs/PRIVACIDAD.md').readAsStringSync();
      expect(
        aviso,
        contains('Registrar a otra persona no borra lo anterior'),
      );
      expect(aviso, contains('Cerrar sesión'));
    });
  });
}
