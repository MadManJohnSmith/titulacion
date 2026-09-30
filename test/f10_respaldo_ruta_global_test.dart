import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/backup_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// F-10: un respaldo heredado de la versión 1 (sin modalidad, con el avance en
/// el espacio de nombres de la ruta global) se quedaba sin salida.
///
/// El paso 3 solo elegía oferta cuando el respaldo traía `modalidadActiva`, y el
/// paso 4 solo sabía comparar espacios de nombres: con la ruta global activa los
/// espacios nunca coincidian, así que el aviso pedía "elige una modalidad y vuelve
/// a pegar el respaldo", una acción que la interfaz no permite (en `lib` toda
/// `RutaOferta` se construye con modalidad). Aquí se comprueba lo reparado sobre
/// el producto y su catálogo real: el respaldo heredado sí se restaura, y cuando
/// no se puede, el aviso dice por qué sin prometer nada imposible.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ContentRepository.instance.cargarDesdeDiscoParaTests();
  });

  Future<AppState> estadoLimpio() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance());
  }

  /// Un bloque de respaldo tal y como lo escribía la versión 1: sin modalidad y
  /// con el avance en el espacio de nombres de la ruta global.
  String respaldoHeredado({
    required String ruta,
    required List<int> niveles,
    String? modalidad,
    String? rutaBase,
    String? namespace,
  }) => json.encode({
    'tipo': 'loboapp-respaldo',
    'version': 1,
    'generadoEn': '2026-01-01T00:00:00Z',
    'esquemaEstado': 1,
    'alumno': <String, dynamic>{
      'nombre': 'María Fernanda López',
      'matricula': '202145678',
      'facultad': 'FCC',
      'carrera': '',
      'plan': '',
      'anioIngreso': null,
    },
    'facultadClave': 'FCC',
    'contexto': <String, dynamic>{
      'carreraId': null,
      'planId': null,
      'anioIngreso': null,
    },
    'oferta': <String, dynamic>{
      'modalidadActiva': modalidad,
      'rutaActiva': ruta,
      'rutaActivaBase': rutaBase,
    },
    'progreso': <String, dynamic>{
      'namespace': namespace ?? ruta,
      'nivelesCompletados': niveles,
      'documentosMarcados': <String>[],
    },
    'notas': <String, dynamic>{ruta: <String, dynamic>{'3': 'traer credencial'}},
    'alcance': <String>[],
  });

  Future<InformeRespaldo> restaurar(AppState state, String texto) async {
    final errores = <String>[];
    final r = RespaldoAlumno.analizar(texto, errores);
    expect(errores, isEmpty, reason: 'el respaldo debe leerse sin errores');
    expect(r, isNotNull);
    return restaurarRespaldo(
      state: state,
      notas: state.notas,
      respaldo: r!,
      repo: ContentRepository.instance,
    );
  }

  group('F-10: el respaldo heredado de la versión 1 tiene salida', () {
    test('se restaura en un teléfono que no tiene oferta activa', () async {
      final state = await estadoLimpio();
      expect(state.rutaActiva, isNull, reason: 'el caso del hallazgo: sin oferta');

      final informe = await restaurar(
        state,
        respaldoHeredado(ruta: 'promedio', niveles: [1, 2, 3]),
      );

      // La ruta global del respaldo es ahora la oferta activa: es lo único que
      // hace que su espacio de nombres coincida con el del avance.
      expect(state.rutaActiva, 'promedio');
      expect(state.modalidadActiva, isNull);
      expect(
        state.completadosDe('promedio'),
        [1, 2, 3],
        reason: 'el avance se escribió en el espacio que declara el respaldo',
      );
      expect(informe.aplicados.join(' '), contains('Ruta global promedio'));
      expect(
        informe.avisos.where((a) => a.contains('vuelve a pegar el respaldo')),
        isEmpty,
        reason: 'el aviso no puede pedir una acción que la app no permite',
      );
      // Y las notas, que antes se escribían en silencio sin más, quedan dichas.
      expect(informe.aplicados.join(' '), contains('1 notas escritas'));
      expect(state.notas.textoDe('promedio', 3), 'traer credencial');
    });

    test('con otra modalidad abierta no se cambia la oferta ni se mezclan', () async {
      final state = await estadoLimpio();
      // La misma persona y la misma unidad que trae el respaldo: así el paso 1
      // no invalida la oferta y el caso es el del desajuste de espacios.
      await state.registrar(
        const Alumno(nombre: 'María Fernanda López', matricula: '202145678'),
        facultadClave: 'FCC',
      );
      await state.elegirModalidad('tesis-fcc', 'tesis');
      await state.completarNivel('tesis-fcc', 1);

      final informe = await restaurar(
        state,
        respaldoHeredado(ruta: 'promedio', niveles: [1, 2, 3]),
      );

      // La oferta que ya está abierta manda (regla de F-02): pegar un respaldo
      // no cambia lo que el alumno tenía elegido.
      expect(state.modalidadActiva, 'tesis-fcc');
      expect(state.completadosDe('tesis-fcc'), [1]);
      expect(state.completadosDe('promedio'), isEmpty);
      expect(
        informe.aplicados.where((a) => a.startsWith('Avance:')),
        isEmpty,
      );
      // Y el aviso explica el desajuste sin pedir una modalidad que este
      // respaldo no trae: era la otra mitad del defecto.
      final avisos = informe.avisos.join(' ');
      expect(avisos, contains('viene sin modalidad'));
      expect(avisos, contains('no se escribió nada'));
      expect(avisos, isNot(contains('vuelve a pegar')));
    });

    test('si la ruta global ya no existe, lo dice sin prometer una salida', () async {
      final state = await estadoLimpio();

      final informe = await restaurar(
        state,
        respaldoHeredado(ruta: 'ruta-que-no-existe', niveles: [1, 2, 3]),
      );

      final avisos = informe.avisos.join(' ');
      expect(state.rutaActiva, isNull, reason: 'no se eligió una oferta inventada');
      expect(state.completadosDe('ruta-que-no-existe'), isEmpty);
      expect(avisos, contains('ruta-que-no-existe'));
      expect(avisos, contains('no está en el catálogo'));
      expect(
        avisos,
        isNot(contains('vuelve a pegar el respaldo')),
        reason: 'repetir el paso no cambiaría nada: la app lo dice',
      );
      expect(
        informe.aplicados.where((a) => a.startsWith('Avance:')),
        isEmpty,
        reason: 'no se escribe nada, así que no se anuncia avance',
      );
      // Las notas sí se restauraron, y el informe lo dice.
      expect(state.notas.textoDe('ruta-que-no-existe', 3), 'traer credencial');
    });

    test('una modalidad que no existe se nombra, sin pedir volver a pegar', () async {
      final state = await estadoLimpio();

      final informe = await restaurar(
        state,
        respaldoHeredado(
          ruta: 'tesis',
          rutaBase: 'tesis',
          modalidad: 'tesis-fantasma',
          niveles: [1],
        ),
      );

      final avisos = informe.avisos.join(' ');
      expect(state.rutaActiva, isNull);
      expect(avisos, contains('tesis-fantasma'));
      expect(avisos, contains('no se escribió ningún nivel ni documento'));
      expect(avisos, isNot(contains('vuelve a pegar')));
    });

    test('una modalidad que sí existe se sigue aplicando como antes', () async {
      final state = await estadoLimpio();

      final informe = await restaurar(
        state,
        respaldoHeredado(
          ruta: 'tesis-fcc',
          rutaBase: 'tesis',
          modalidad: 'tesis-fcc',
          niveles: [1, 2],
          namespace: 'modalidad:tesis-fcc',
        ),
      );

      expect(state.modalidadActiva, 'tesis-fcc');
      expect(state.completadosDe('tesis-fcc'), [1, 2]);
      expect(informe.aplicados.join(' '), contains('Modalidad tesis-fcc'));
    });
  });
}
