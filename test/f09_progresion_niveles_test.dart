import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// F-09: el desbloqueo de niveles mezclaba la cantidad de niveles con el número
/// de nivel.
///
/// Con una ruta de los niveles 1, 2 y 7 (tres niveles jugables, último número
/// 7) el código tomaba el total como si fuera el número del último nivel: el
/// mapa pedía el nivel 3, que no existe, el 7 quedaba bloqueado para siempre y
/// la barra de avance no llegaba al 100 %. Aquí se comprueba lo contrario con
/// una ruta numerada con huecos y, además, que el contenido publicado no tenga
/// esos huecos.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> estadoLimpio() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance());
  }

  group('F-09: el avance se calcula sobre números de nivel', () {
    test('el siguiente nivel es un nivel que existe, aunque haya huecos', () async {
      final state = await estadoLimpio();
      const numeros = <int>[1, 2, 7];

      // Tres niveles jugables: el total (3) no es el número del último (7).
      expect(numeros.length, 3);
      expect(numeros.last, 7);

      expect(state.siguienteNivel('hueco', numeros), 1);
      expect(numeros, contains(state.siguienteNivel('hueco', numeros)));

      await state.completarNivel('hueco', 1);
      expect(state.siguienteNivel('hueco', numeros), 2);

      await state.completarNivel('hueco', 2);
      // Antes devolvía 3: un nivel que no existe, y el 7 quedaba inalcanzable.
      expect(state.siguienteNivel('hueco', numeros), 7);
      expect(numeros, contains(state.siguienteNivel('hueco', numeros)));
    });

    test('un nivel con hueco se desbloquea al terminar el jugable anterior', () async {
      final state = await estadoLimpio();
      const numeros = <int>[1, 2, 7];

      expect(state.nivelDesbloqueado('hueco', 1, numeros), isTrue);
      expect(state.nivelDesbloqueado('hueco', 2, numeros), isFalse);
      expect(state.nivelDesbloqueado('hueco', 7, numeros), isFalse);

      await state.completarNivel('hueco', 1);
      expect(state.nivelDesbloqueado('hueco', 2, numeros), isTrue);
      expect(state.nivelDesbloqueado('hueco', 7, numeros), isFalse);

      // El 3 no existe en esta ruta, así que el 7 se abre con el 2.
      await state.completarNivel('hueco', 2);
      expect(state.nivelDesbloqueado('hueco', 7, numeros), isTrue);
    });

    test('la barra de avance llega al 100 % aunque el último número sea mayor', () async {
      final state = await estadoLimpio();
      const numeros = <int>[1, 2, 7];

      expect(state.progresoDe('hueco', numeros), 0);

      await state.completarNivel('hueco', 1);
      await state.completarNivel('hueco', 2);
      expect(state.progresoDe('hueco', numeros), closeTo(2 / 3, 0.0001));

      await state.completarNivel('hueco', 7);
      // Antes el filtro `n <= total` descartaba el 7 y la barra se quedaba
      // en 66 % con la ruta terminada.
      expect(state.progresoDe('hueco', numeros), 1.0);
    });

    test('con la numeración contigua el comportamiento es el de siempre', () async {
      final state = await estadoLimpio();
      const numeros = <int>[1, 2, 3, 4, 5];

      expect(state.siguienteNivel('normal', numeros), 1);
      expect(state.nivelDesbloqueado('normal', 1, numeros), isTrue);
      expect(state.nivelDesbloqueado('normal', 2, numeros), isFalse);
      expect(state.progresoDe('normal', numeros), 0);

      await state.completarNivel('normal', 1);
      expect(state.siguienteNivel('normal', numeros), 2);
      expect(state.nivelDesbloqueado('normal', 2, numeros), isTrue);
      expect(state.nivelDesbloqueado('normal', 3, numeros), isFalse);
      expect(state.progresoDe('normal', numeros), closeTo(0.2, 0.0001));

      for (final n in numeros.skip(1)) {
        await state.completarNivel('normal', n);
      }
      expect(state.siguienteNivel('normal', numeros), numeros.last);
      expect(state.progresoDe('normal', numeros), 1.0);
    });

    test('una ruta sin niveles jugables no rompe nada', () async {
      final state = await estadoLimpio();

      expect(state.siguienteNivel('vacia', const <int>[]), 0);
      expect(state.nivelDesbloqueado('vacia', 1, const <int>[]), isFalse);
      expect(state.progresoDe('vacia', const <int>[]), 0);
    });
  });

  group('F-09: el contenido publicado numera los niveles sin huecos', () {
    test('ninguna ruta de assets/json/routes.json deja un nivel bloqueado', () async {
      ContentRepository.instance.cargarDesdeDiscoParaTests();
      final rutas = await ContentRepository.instance.rutas();

      expect(rutas, isNotEmpty, reason: 'el producto publica rutas reales');

      for (final ruta in rutas) {
        final numeros = ruta.numerosJugables;
        final esperados = List<int>.generate(numeros.length, (i) => i + 1);

        expect(
          numeros,
          esperados,
          reason:
              'la ruta "${ruta.id}" debe numerar sus niveles jugables de forma '
              'contigua desde 1; con un hueco el último nivel queda bloqueado '
              'para siempre',
        );
        expect(
          numeros.toSet().length,
          numeros.length,
          reason: 'la ruta "${ruta.id}" no puede repetir el número de un nivel',
        );
        expect(numeros, isNot(contains(0)), reason: 'el nivel 0 es la pantalla de inicio');
      }
    });
  });
}
