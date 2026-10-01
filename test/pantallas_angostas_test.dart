import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/backup_screen.dart';
import 'package:titulacion/screens/contacts_screen.dart';
import 'package:titulacion/screens/directorio_unidad_screen.dart';
import 'package:titulacion/screens/directory_screen.dart';
import 'package:titulacion/screens/eligibility_screen.dart';
import 'package:titulacion/screens/home_screen.dart';
import 'package:titulacion/screens/level_detail_screen.dart';
import 'package:titulacion/screens/map_screen.dart';
import 'package:titulacion/screens/menu_screen.dart';
import 'package:titulacion/screens/notes_screen.dart';
import 'package:titulacion/screens/profile_screen.dart';
import 'package:titulacion/screens/register_screen.dart';
import 'package:titulacion/screens/route_selection_screen.dart';
import 'package:titulacion/screens/welcome_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// Barrido de todas las pantallas en un teléfono angosto.
///
/// La fila «Requisitos de *unidad*» se salía de la pantalla porque el texto no
/// cabía en la fila, y eso no lo vio ninguna prueba: no había ninguna que
/// mirara las pantallas a lo ancho de un teléfono. Esta abre **todas** a
/// 360×640 y falla si alguna tira un `RenderFlex overflowed`.
///
/// El ancho se elige a propósito: 360 es el teléfono angosto que todavía se
/// vende, y es donde un nombre largo de unidad hace daño.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => ContentRepository.instance.cargarDesdeDiscoParaTests());

  /// Vuelve a armar un estado limpio: las pruebas comparten el mismo
  /// almacenamiento simulado y una pantalla que borra datos afecta a la otra.
  Future<AppState> estadoLimpio() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance());
  }

  Future<void> a360(WidgetTester tester, String nombre, Widget pantalla) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: pantalla));
    // Varias pantallas piden datos al montar; dos vueltas bastan para que la
    // lectura del repositorio termine sin dejar un spinner colgado.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.takeException(),
      isNull,
      reason: '$nombre se desborda o lanza a 360×640',
    );
  }

  testWidgets('WelcomeScreen', (t) => a360(t, 'WelcomeScreen', WelcomeScreen(onContinuar: () {})));

  testWidgets('RegisterScreen', (t) async {
    final state = await estadoLimpio();
    await a360(t, 'RegisterScreen', RegisterScreen(state: state));
  });

  testWidgets('HomeScreen sin unidad', (t) async {
    final state = await estadoLimpio();
    await a360(t, 'HomeScreen sin unidad', HomeScreen(state: state));
  });

  testWidgets('HomeScreen con unidad y catálogo', (t) async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FCC',
    );
    await a360(t, 'HomeScreen con unidad', HomeScreen(state: state));
  });

  testWidgets('ContactsScreen', (t) async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FCC',
    );
    await a360(t, 'ContactsScreen', ContactsScreen(state: state));
  });

  testWidgets('DirectoryScreen', (t) => a360(t, 'DirectoryScreen', const DirectoryScreen()));

  testWidgets('DirectorioUnidadScreen', (t) async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FCC',
    );
    final facultad = await ContentRepository.instance.facultadPorClave('FCC');
    expect(facultad, isNotNull);
    await a360(
      t,
      'DirectorioUnidadScreen',
      DirectorioUnidadScreen(facultad: facultad!),
    );
  });

  testWidgets('EligibilityScreen', (t) async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FCC',
    );
    await a360(t, 'EligibilityScreen', EligibilityScreen(state: state));
  });

  testWidgets('ProfileScreen', (t) async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FCC',
    );
    await a360(t, 'ProfileScreen', ProfileScreen(state: state));
  });

  testWidgets('MenuScreen', (t) async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FCC',
    );
    await a360(t, 'MenuScreen', MenuScreen(state: state));
  });

  testWidgets('NotesScreen y BackupScreen', (t) async {
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FCC',
    );
    SharedPreferences.setMockInitialValues({});
    final notas = NotasState(await SharedPreferences.getInstance());

    await a360(t, 'NotesScreen', NotesScreen(state: state, notas: notas));
    await a360(t, 'BackupScreen', BackupScreen(state: state, notas: notas));
  });

  testWidgets('MapScreen y LevelDetailScreen', (t) async {
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
    final ruta = rutaOferta.ruta.ruta;

    await a360(t, 'MapScreen', MapScreen(ruta: ruta, state: state));
    await a360(
      t,
      'LevelDetailScreen',
      LevelDetailScreen(
        ruta: ruta,
        nivel: ruta.nivelesJugables.first,
        state: state,
      ),
    );
  });

  testWidgets('RouteSelectionScreen de cada ruta publicada', (t) async {
    // No solo una: cada modalidad pinta su propio nombre de unidad y su propio
    // bloque de requisitos, y son esos textos los que se desbordan.
    final state = await estadoLimpio();
    await state.registrar(
      const Alumno(nombre: 'Alumno', matricula: '123'),
      facultadClave: 'FCC',
    );
    final repo = ContentRepository.instance;
    final oferta = await repo.ofertaDeUnidad('FCC');

    for (final rutaOferta in oferta.rutas) {
      await a360(
        t,
        'RouteSelectionScreen ${rutaOferta.ruta.ruta.id}',
        RouteSelectionScreen(
          oferta: oferta,
          ruta: rutaOferta,
          state: state,
          repository: repo,
        ),
      );
    }
  });

  testWidgets('RouteSelectionScreen de las 34 unidades', (t) async {
    // El encabezado dice «Requisitos de <nombre de la unidad>», y los nombres
    // van de 22 a 65 letras: «Instituto de Ciencias Sociales y Humanidades
    // Alfonso Vélez Pliego» es el que revienta. Se revisan todas, con y sin
    // catálogo, porque el estado vacío también pinta el nombre.
    final repo = ContentRepository.instance;
    final facultades = await repo.facultades();
    expect(facultades.length, greaterThan(30), reason: 'faltan unidades');

    var vistas = 0;
    for (final facultad in facultades) {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(await SharedPreferences.getInstance());
      await state.registrar(
        const Alumno(nombre: 'Alumno', matricula: '123'),
        facultadClave: facultad.clave,
      );
      final oferta = await repo.ofertaDeUnidad(facultad.clave);

      // Sin catálogo se abre igual: ese es el estado que ve quien entra a una
      // unidad que no publica modalidades.
      final rutas = oferta.rutas.isEmpty ? [null] : oferta.rutas;
      for (final rutaOferta in rutas) {
        await a360(
          t,
          'RouteSelection ${facultad.nombre}'
              '${rutaOferta == null ? ' (sin catálogo)' : ''}',
          RouteSelectionScreen(
            oferta: oferta,
            ruta: rutaOferta,
            state: state,
            repository: repo,
          ),
        );
        vistas++;
      }
    }
    expect(vistas, greaterThan(30));
  });

  testWidgets('HomeScreen de las 34 unidades', (t) async {
    // El nombre de la unidad sale también en la portada y en cada tarjeta de
    // modalidad, con el nombre oficial que publica cada una.
    final repo = ContentRepository.instance;
    for (final facultad in await repo.facultades()) {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(await SharedPreferences.getInstance());
      await state.registrar(
        const Alumno(nombre: 'Alumno', matricula: '123'),
        facultadClave: facultad.clave,
      );
      await a360(t, 'HomeScreen ${facultad.nombre}', HomeScreen(state: state));
    }
  });
}