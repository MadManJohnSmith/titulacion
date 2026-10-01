import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/directorio_unidad_screen.dart';
import 'package:titulacion/screens/map_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// El flujo de guardar y deshacer el progreso de la ruta.
///
/// El alumno complained de que el botón atrás del teléfono lo sacaba de la
/// ruta. Aquí se fija que la navegación no toca el progreso y que deshacer
/// deja el nivel pendiente sin borrarlo de forma irreversible.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ContentRepository.instance.cargarDesdeDiscoParaTests();
  });

  Future<AppState> estadoLimpio() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance());
  }

  test('deshacer devuelve el último nivel a pendiente y se puede rehacer', () async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FADMON',
    );

    final repos = await ContentRepository.instance.rutas();
    final ruta = repos.firstWhere((r) => r.id == 'promedio');

    await state.completarNivel(ruta.id, 1);
    await state.completarNivel(ruta.id, 2);
    expect(state.estaCompletado(ruta.id, 1), isTrue);
    expect(state.estaCompletado(ruta.id, 2), isTrue);
    expect(state.ultimoCompletado(ruta.id), 2);

    // Deshacer quita el último, no el primero.
    final deshecho = await state.deshacerProgreso(ruta.id);
    expect(deshecho, 2);
    expect(state.estaCompletado(ruta.id, 2), isFalse,
        reason: 'deshacer debe devolver el nivel a pendiente');
    expect(state.estaCompletado(ruta.id, 1), isTrue,
        reason: 'deshacer no debe tocar los pasos anteriores');

    // Y se puede volver a completar.
    await state.completarNivel(ruta.id, 2);
    expect(state.estaCompletado(ruta.id, 2), isTrue);

    // Sin progreso no hay nada que deshacer.
    await state.deshacerProgreso(ruta.id);
    await state.deshacerProgreso(ruta.id);
    expect(await state.deshacerProgreso(ruta.id), isNull);
  });

  test('el progreso sobrevive a cerrar y abrir la app', () async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FADMON',
    );
    final repos = await ContentRepository.instance.rutas();
    final ruta = repos.firstWhere((r) => r.id == 'promedio');
    await state.completarNivel(ruta.id, 1);

    // Instancia nueva sobre el MISMO almacenamiento: es lo que pasa al
    // reabrir la aplicación. Si se crearan preferencias nuevas se probaría el
    // mock, no la persistencia.
    final otra = AppState(await SharedPreferences.getInstance());
    expect(otra.estaCompletado(ruta.id, 1), isTrue,
        reason: 'el avance tiene que quedar guardado, no solo en memoria');
  });

  testWidgets('el mapa ofrece deshacer solo cuando hay progreso', (
    tester,
  ) async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FADMON',
    );
    final repos = await ContentRepository.instance.rutas();
    final ruta = repos.firstWhere((r) => r.id == 'promedio');

    await tester.pumpWidget(MaterialApp(home: MapScreen(ruta: ruta, state: state)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Deshacer el último paso completado'), findsNothing,
        reason: 'sin avance no hay nada que deshacer');

    await state.completarNivel(ruta.id, 1);
    await tester.pumpWidget(MaterialApp(home: MapScreen(ruta: ruta, state: state)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Deshacer el último paso completado'), findsOneWidget);

    // Pulsarlo deshace y avisa de qué.
    await tester.tap(find.byTooltip('Deshacer el último paso completado'));
    await tester.pumpAndSettle();
    expect(state.estaCompletado(ruta.id, 1), isFalse);
    expect(find.textContaining('Se deshizo'), findsOneWidget);
  });

  testWidgets('el directorio filtra y no inventa datos', (tester) async {
    const f = Facultad(
      nombre: 'Facultad de Prueba',
      clave: 'PRUEBA',
      directorio: DirectorioUnidad(
        clave: 'PRUEBA',
        personas: [
          PersonaDirectorio(
            nombre: 'Dra. Ana Pérez',
            puesto: 'Secretaria Académica',
            correo: 'prueba@correo.buap.mx',
            ubicacion: 'CCO4-209',
          ),
          PersonaDirectorio(nombre: 'Mtro. Luis Gómez', puesto: 'Director'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: DirectorioUnidadScreen(facultad: f)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dra. Ana Pérez'), findsOneWidget);
    expect(find.text('CCO4-209'), findsOneWidget,
        reason: 'la ubicación es el dato que el alumno no tenía');
    expect(find.text('prueba@correo.buap.mx'), findsOneWidget);
    expect(find.text('Mtro. Luis Gómez'), findsOneWidget);

    // Buscar sin acentos encuentra a la persona.
    await tester.enterText(find.byType(TextField), 'Perez');
    await tester.pumpAndSettle();
    expect(find.text('Dra. Ana Pérez'), findsOneWidget);
    expect(find.text('Mtro. Luis Gómez'), findsNothing);

    // Buscar por cubículo también.
    await tester.enterText(find.byType(TextField), 'CCO4');
    await tester.pumpAndSettle();
    expect(find.text('Dra. Ana Pérez'), findsOneWidget);
  });

  testWidgets('una unidad sin directorio lo dice en vez de mostrar gente', (
    tester,
  ) async {
    const f = Facultad(nombre: 'Facultad Sin Directorio', clave: 'SIN');
    await tester.pumpWidget(
      MaterialApp(home: DirectorioUnidadScreen(facultad: f)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no publica un directorio'), findsOneWidget);
  });

  testWidgets('el directorio dice de qué página se leyó y cuándo', (tester) async {
    // La app manda a un alumno a un cubículo concreto. Si el dato está mal, no
    // hay forma de distinguirlo de uno bueno salvo que la fuente esté a la
    // vista: antes el modelo leía `url` y `consultadoEn` y los tiraba.
    final repo = ContentRepository.instance;
    final f = await repo.facultadPorClave('FCC');
    expect(f, isNotNull);
    expect(f!.directorio.cita, isNotEmpty);

    await tester.pumpWidget(MaterialApp(home: DirectorioUnidadScreen(facultad: f)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fuente: ${f.directorio.url}'), findsOneWidget);
    expect(
      find.textContaining('consultado ${f.directorio.consultadoEn}'),
      findsOneWidget,
    );
    // Y el día se muestra sin la hora de máquina.
    expect(find.textContaining('T00:00:00'), findsNothing);
  });
}