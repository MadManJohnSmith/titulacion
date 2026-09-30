import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/backup_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

/// F-13: al restaurar un respaldo se comprobaba que la modalidad existiera en el
/// catálogo, pero no que fuera de la unidad del alumno.
///
/// `_modalidadExiste` recorría todas las unidades y se conformaba con encontrar
/// la modalidad en cualquiera de ellas, así que un respaldo con `modalidadActiva`
/// de la unidad A y `facultadClave` de la unidad B dejaba el teléfono con la
/// oferta de A activa: una modalidad que B no publica, con su avance y sus notas
/// en el espacio de nombres de A, en un estado que ninguna pantalla sabe
/// explicar.
///
/// Aquí se comprueba lo reparado contra el producto y su catálogo real
/// (`assets/json/catalogo_modalidades.json`, leído de disco como en las demás
/// pruebas): la pregunta del paso 3 es si **la unidad del alumno** publica esa
/// modalidad, no si existe en alguna parte del catálogo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ContentRepository.instance.cargarDesdeDiscoParaTests();
  });

  Future<AppState> estadoLimpio() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance());
  }

  /// Respaldo de la versión 2, con la unidad del alumno y su oferta declaradas.
  String respaldo({
    required String unidad,
    required String modalidad,
    required String rutaBase,
    List<int> niveles = const [1, 2],
  }) => json.encode({
    'tipo': 'loboapp-respaldo',
    'version': 1,
    'generadoEn': '2026-01-01T00:00:00Z',
    'esquemaEstado': 2,
    'alumno': <String, dynamic>{
      'nombre': 'María Fernanda López',
      'matricula': '202145678',
      'facultad': unidad,
      'carrera': '',
      'plan': '',
      'anioIngreso': null,
    },
    'facultadClave': unidad,
    'contexto': <String, dynamic>{
      'carreraId': null,
      'planId': null,
      'anioIngreso': null,
    },
    'oferta': <String, dynamic>{
      'modalidadActiva': modalidad,
      'rutaActiva': modalidad,
      'rutaActivaBase': rutaBase,
    },
    'progreso': <String, dynamic>{
      'namespace': 'modalidad:$modalidad',
      'nivelesCompletados': niveles,
      'documentosMarcados': <String>[],
    },
    'notas': <String, dynamic>{},
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

  group('F-13: la modalidad se valida contra la unidad del alumno', () {
    test('una modalidad de otra unidad avisa y no se selecciona', () async {
      final state = await estadoLimpio();

      // 'titulacion-por-tesis-fccom' la publica la Facultad de Ciencias de la
      // Comunicación; el respaldo dice que el alumno es de la FCC.
      const modalidadAjena = 'titulacion-por-tesis-fccom';
      final informe = await restaurar(
        state,
        respaldo(
          unidad: 'FCC',
          modalidad: modalidadAjena,
          rutaBase: 'tesis',
          niveles: const [1, 2, 3],
        ),
      );

      // El caso del hallazgo: la oferta de otra unidad no queda activa.
      expect(state.facultadClave, 'FCC');
      expect(state.modalidadActiva, isNull);
      expect(state.rutaActiva, isNull);
      expect(state.completadosDe(modalidadAjena), isEmpty);

      final avisos = informe.avisos.join(' ');
      expect(avisos, contains(modalidadAjena));
      expect(
        avisos,
        contains('catálogo de la unidad "FCC"'),
        reason: 'el aviso nombra la unidad del alumno, no el catálogo entero',
      );
      expect(
        avisos,
        contains('no se escribió ningún nivel ni documento'),
        reason: 'sin oferta activa no se escribe el avance, y se dice',
      );
      expect(
        informe.aplicados.where((a) => a.startsWith('Modalidad ')),
        isEmpty,
        reason: 'no se selecciona una modalidad que la unidad no publica',
      );
      expect(informe.aplicados.where((a) => a.startsWith('Avance:')), isEmpty);
    });

    test('la validación no es "¿existe en el catálogo?": para su unidad vale',
        () async {
      // El mismo identificador, pero con la unidad que lo publica. Si el paso 3
      // se conformara con encontrarlo en cualquier parte del catálogo, esto
      // seguiría funcionando; si se conformara con descartarlo siempre, esto
      // sería lo que se rompería.
      final state = await estadoLimpio();

      final informe = await restaurar(
        state,
        respaldo(
          unidad: 'FCCOM',
          modalidad: 'titulacion-por-tesis-fccom',
          rutaBase: 'tesis',
          niveles: const [1, 2],
        ),
      );

      expect(state.facultadClave, 'FCCOM');
      expect(state.modalidadActiva, 'titulacion-por-tesis-fccom');
      expect(state.completadosDe('titulacion-por-tesis-fccom'), [1, 2]);
      expect(informe.aplicados.join(' '), contains('Modalidad'));
    });

    test('una modalidad de la unidad del alumno se sigue restaurando', () async {
      final state = await estadoLimpio();

      final informe = await restaurar(
        state,
        respaldo(
          unidad: 'FCC',
          modalidad: 'tesis-fcc',
          rutaBase: 'tesis',
          niveles: const [1, 2],
        ),
      );

      expect(state.modalidadActiva, 'tesis-fcc');
      expect(state.completadosDe('tesis-fcc'), [1, 2]);
      expect(informe.avisos, isNot(contains(contains('catálogo de la unidad'))));
    });

    test('una unidad que no publica catálogo lo dice, sin elegir nada', () async {
      final state = await estadoLimpio();

      final informe = await restaurar(
        state,
        respaldo(
          unidad: 'FING',
          modalidad: 'tesis-fing',
          rutaBase: 'tesis',
          niveles: const [1],
        ),
      );

      expect(state.modalidadActiva, isNull);
      expect(state.rutaActiva, isNull);
      final avisos = informe.avisos.join(' ');
      expect(avisos, contains('FING'));
      expect(avisos, contains('no publica catálogo'));
      expect(informe.aplicados.where((a) => a.startsWith('Avance:')), isEmpty);
    });

    test('la modalidad ajena no pisa el avance que el alumno ya tenía', () async {
      final state = await estadoLimpio();
      // Misma persona y misma unidad que trae el respaldo: el paso 1 no
      // invalida la oferta, así que el caso es el del desajuste de espacios.
      await state.registrar(
        const Alumno(nombre: 'María Fernanda López', matricula: '202145678'),
        facultadClave: 'FCC',
      );
      await state.elegirModalidad('tesis-fcc', 'tesis');
      await state.completarNivel('tesis-fcc', 1);

      final informe = await restaurar(
        state,
        respaldo(
          unidad: 'FCC',
          modalidad: 'titulacion-por-tesis-fccom',
          rutaBase: 'tesis',
          niveles: const [1, 2, 3],
        ),
      );

      // Ni se cambia la oferta abierta ni se escribe el avance de la otra
      // unidad: el aviso lo explica y nada se anuncia como aplicado.
      expect(state.modalidadActiva, 'tesis-fcc');
      expect(state.completadosDe('tesis-fcc'), [1]);
      expect(state.completadosDe('titulacion-por-tesis-fccom'), isEmpty);
      final avisos = informe.avisos.join(' ');
      expect(avisos, contains('catálogo de la unidad "FCC"'));
      expect(avisos, contains('no se escribió nada'));
      expect(informe.aplicados.where((a) => a.startsWith('Avance:')), isEmpty);
    });
  });
}
