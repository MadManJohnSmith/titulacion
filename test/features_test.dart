import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/backup_screen.dart';
import 'package:titulacion/screens/eligibility_screen.dart';
import 'package:titulacion/screens/notes_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';
import 'package:titulacion/theme.dart';
import 'package:titulacion/widgets/buap_links.dart';
import 'package:titulacion/widgets/eligibility_result.dart';

/// Pruebas del frente **features**: calculadora de elegibilidad, respaldo del
/// avance, notas por nivel y enlaces profundos.
///
/// Todas leen el contenido real de `assets/json/`, no un fake: si el catálogo
/// cambia, estas pruebas lo dicen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = ContentRepository.instance;

  setUpAll(() {
    // Los tests corren fuera del bundle: el JSON se lee del disco del proyecto.
    repo.cargarDesdeDiscoParaTests();
  });

  Future<AppState> estadoLimpio([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(prefs));
    return AppState(await SharedPreferences.getInstance());
  }

  /// Un estado con alumno y unidad, listo para las pantallas.
  Future<AppState> estadoDeAlumno(String clave) async {
    final s = await estadoLimpio();
    await s.registrar(
      const Alumno(nombre: 'Alma Löwe', matricula: '2020401'),
      facultadClave: clave,
    );
    return s;
  }

  // =====================================================================
  // Enlaces profundos
  // =====================================================================

  group('enlaces profundos', () {
    test('todo enlace que se abre tiene HTTPS, fuente oficial y fecha', () {
      for (final e in enlacesTitulacionBUAP) {
        if (!e.puedeAbrirse) continue;
        expect(e.url.startsWith('https://'), isTrue, reason: e.clave);
        expect(e.fuente.trim(), isNotEmpty, reason: e.clave);
        expect(
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(e.consultadoEn),
          isTrue,
          reason: '${e.clave}: ${e.consultadoEn}',
        );
        expect(e.queAbre.trim(), isNotEmpty, reason: e.clave);
      }
      final abiertos =
          enlacesTitulacionBUAP.where((e) => e.puedeAbrirse).length;
      expect(abiertos, greaterThanOrEqualTo(2));
    });

    test('el portal de la DAE y el calendario apuntan al sitio oficial', () {
      final dae = enlacePorClave(enlacesTitulacionBUAP, 'dae-titulacion')!;
      expect(dae.url, 'https://titulacion.buap.mx/');
      expect(dae.consultadoEn, '2026-09-29');

      final calendario =
          enlacePorClave(enlacesTitulacionBUAP, 'calendario-titulacion')!;
      expect(
        calendario.url,
        'https://titulacion.buap.mx/content/calendarios-institucionales-buap-2026',
      );
      expect(calendario.consultadoEn, '2026-09-29');
    });

    test('un enlace sin fuente ni fecha no se abre', () {
      // El "RVO" que proponía el plan se descartó por esto mismo: sin fuente
      // oficial verificada, la lista de enlaces no lo tiene.
      expect(enlacePorClave(enlacesTitulacionBUAP, 'rvo'), isNull);

      const sinFuente = EnlaceOficial(
        clave: 'inventado',
        titulo: 'Algo sin fuente',
        queAbre: 'No debería abrirse nunca.',
        url: 'https://ejemplo.invalid/',
        fuente: '',
        consultadoEn: '',
      );
      expect(sinFuente.puedeAbrirse, isFalse);
      expect(sinFuente.pendiente, isFalse);
    });

    testWidgets('la lista dibuja los dos enlaces verificados', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLoboTheme(),
          home: const Scaffold(body: EnlacesTitulacion()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Portal de Titulación de la DAE'), findsOneWidget);
      expect(find.text('Calendario de titulación BUAP 2026'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      // Los dos verificados traen la flecha que invita a abrir y la cita.
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('un enlace sin fuente se dibuja con candado y no abre', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLoboTheme(),
          home: const Scaffold(
            body: EnlacesTitulacion(
              enlaces: [
                EnlaceOficial(
                  clave: 'inventado',
                  titulo: 'Algo sin fuente',
                  queAbre: 'No debería abrirse nunca.',
                  url: 'https://ejemplo.invalid/',
                  fuente: '',
                  consultadoEn: '',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  // =====================================================================
  // Calculadora de elegibilidad
  // =====================================================================

  group('calculadora de elegibilidad', () {
    /// ARPA publica promedio 8.5 y que no se puede recursar, en su titulación
    /// automática (`catalogo_modalidades.json`, corte 2026-09-29).
    Future<RutaOferta> automaticaArpa() async {
      final oferta = await repo.ofertaDeUnidad('ARPA');
      return oferta.rutas.firstWhere(
        (r) => r.idModalidad == 'titulacion-automatica-arpa',
      );
    }

    test('el catálogo trae el promedio y el recursar de ARPA', () async {
      final o = await automaticaArpa();
      expect(o.requisitos.promedioMinimo, 8.5);
      expect(o.requisitos.permiteRecursar, isFalse);
      expect(o.ruta.citaFuente.isNotEmpty, isTrue);
    });

    test('promedio 9.0 cumple y 8.0 no, contra el 8.5 publicado', () async {
      final o = await automaticaArpa();
      final bueno = CalculadoraElegibilidad.evaluar(
        o,
        datos: const DatosAlumno(promedio: 9.0, repitioMateria: false),
      );
      final malo = CalculadoraElegibilidad.evaluar(
        o,
        datos: const DatosAlumno(promedio: 8.0, repitioMateria: false),
      );
      VeredictoRequisito p(VeredictoModalidad v) =>
          v.requisitos.firstWhere((r) => r.clave == 'promedioMinimo');

      expect(p(bueno).estado, EstadoRequisito.cumple);
      expect(p(bueno).publicado, '8.50');
      expect(p(malo).estado, EstadoRequisito.noCumple);
      expect(malo.estado, EstadoModalidad.noCumple);
      expect(malo.incumplidos, greaterThanOrEqualTo(1));
    });

    /// Una oferta armada a mano, para probar reglas que el catálogo de hoy no
    /// tiene ninguna modalidad que active.
    RutaOferta ofertaDePrueba({
      Requisitos requisitos = const Requisitos(),
      PerfilAplicacion perfil = const PerfilAplicacion(),
    }) {
      final ruta = Ruta.fromJson({
        'id': 'prueba',
        'nombre': 'Ruta de prueba',
        'niveles': [
          {'numero': 1, 'titulo': 'Uno'},
        ],
      });
      final modalidad = ModalidadUnidad(
        modalidadId: 'prueba-xyz',
        unidadClave: 'PRUEBA',
        unidadNombre: 'Unidad de prueba',
        rutaId: 'prueba',
        nombreOficial: 'Prueba',
        seleccionable: true,
        fuente: 'https://ejemplo.buap.mx/real',
        fecha: 'Consultada 2026-09-29',
        requisitos: requisitos,
        perfil: perfil,
      );
      return RutaOferta(
        ruta: RutaCompuesta(
          rutaBase: ruta,
          ruta: ruta,
          modalidad: modalidad,
          particularidad: null,
          requisitos: requisitos,
          estadoCatalogoUnidad: 'publicado',
        ),
        modalidad: modalidad,
      );
    }

    test('sin promedio capturado el requisito queda pendiente, no aprobado', () async {
      final o = await automaticaArpa();
      final v = CalculadoraElegibilidad.evaluar(
        o,
        datos: const DatosAlumno(repitioMateria: false),
      );
      final promedio = v.requisitos.firstWhere(
        (r) => r.clave == 'promedioMinimo',
      );
      expect(promedio.estado, EstadoRequisito.faltaDatoAlumno);
      expect(promedio.esFavorable, isFalse);
      expect(v.estado, EstadoModalidad.confirmarConUnidad);
    });

    test('lo que la unidad no publica sale como desconocido, nunca como cumple', () async {
      final o = await automaticaArpa();
      final v = CalculadoraElegibilidad.evaluar(
        o,
        datos: const DatosAlumno(
          promedio: 9.5,
          porcentajeCreditos: 100,
          repitioMateria: false,
          servicioSocial: true,
          egelCeneval: true,
          trabajoEscrito: true,
          experienciaProfesional: true,
        ),
      );
      // ARPA no publica si exige servicio social, EGEL ni experiencia.
      for (final clave in const [
        'exigeServicioSocial',
        'exigeEgelCeneval',
        'exigeExperienciaProfesional',
      ]) {
        final r = v.requisitos.firstWhere((x) => x.clave == clave);
        expect(
          r.estado,
          EstadoRequisito.unidadNoPublica,
          reason: clave,
        );
        expect(r.esFavorable, isFalse, reason: clave);
      }
      // Por lo tanto la modalidad no se puede dar por cumplida.
      expect(v.puedeAspirar, isFalse);
      expect(v.estado, EstadoModalidad.confirmarConUnidad);
    });

    test('no recursar siempre cumple; recursar en unidad que no lo admite no', () async {
      final o = await automaticaArpa();
      VeredictoModalidad con(bool recursa) => CalculadoraElegibilidad.evaluar(
        o,
        datos: DatosAlumno(
          promedio: 9.0,
          porcentajeCreditos: 100,
          repitioMateria: recursa,
          servicioSocial: true,
          egelCeneval: true,
          trabajoEscrito: true,
          experienciaProfesional: true,
        ),
      );
      EstadoRequisito estadoDe(bool recursa) => con(recursa).requisitos
          .firstWhere((r) => r.clave == 'permiteRecursar')
          .estado;

      expect(estadoDe(false), EstadoRequisito.cumple);
      expect(estadoDe(true), EstadoRequisito.noCumple);
      expect(con(true).estado, EstadoModalidad.noCumple);
      expect(con(false).estado, EstadoModalidad.confirmarConUnidad);
    });

    test('se evalúan los siete requisitos del JSON, ni uno menos', () async {
      final oferta = await repo.ofertaDeUnidad('ARPA');
      for (final r in oferta.rutas) {
        final v = CalculadoraElegibilidad.evaluar(r, datos: const DatosAlumno());
        expect(
          v.requisitos.map((x) => x.clave).toList(),
          CalculadoraElegibilidad.orden,
        );
      }
    });

    test('nunca se marca "puede aspirar" con algún requisito sin definir', () async {
      for (final clave in const ['ARPA', 'FCC', 'FCB']) {
        final oferta = await repo.ofertaDeUnidad(clave);
        for (final v in CalculadoraElegibilidad.evaluarOferta(
          oferta,
          datos: const DatosAlumno(
            promedio: 9.9,
            porcentajeCreditos: 100,
            repitioMateria: false,
            servicioSocial: true,
            egelCeneval: true,
            trabajoEscrito: true,
            experienciaProfesional: true,
          ),
        )) {
          if (v.puedeAspirar) {
            expect(
              v.requisitos.every((r) => r.estado == EstadoRequisito.cumple),
              isTrue,
              reason: '${v.modalidadId} se marcó cumplida con datos sin definir',
            );
          }
        }
      }
    });

    test('el orden va de la que mejor le va a la que peor', () async {
      final oferta = await repo.ofertaDeUnidad('ARPA');
      final lista = CalculadoraElegibilidad.evaluarOferta(
        oferta,
        datos: const DatosAlumno(promedio: 9.9, repitioMateria: false),
      );
      expect(lista, isNotEmpty);
      for (var i = 1; i < lista.length; i++) {
        expect(
          lista[i - 1].estado.index <= lista[i].estado.index,
          isTrue,
          reason: 'orden roto en ${lista[i].modalidadId}',
        );
      }
    });

    test('si la unidad dice que NO lo exige, el alumno cumple igual', () {
      // Hoy ninguna modalidad del catálogo publica un `false` (todos los
      // "exige" son `true` o `null`), así que la rama se cubre a mano para que
      // no se quede sin probar el día que alguna unidad lo publique.
      final oferta = ofertaDePrueba(
        requisitos: const Requisitos(
          exigeServicioSocial: false,
          exigeEgelCeneval: false,
        ),
      );
      final v = CalculadoraElegibilidad.evaluar(
        oferta,
        datos: const DatosAlumno(),
      );
      for (final clave in const ['exigeServicioSocial', 'exigeEgelCeneval']) {
        expect(
          v.requisitos.firstWhere((r) => r.clave == clave).estado,
          EstadoRequisito.cumple,
          reason: clave,
        );
      }
    });

    test('el perfil publicado manda: una carrera ajena es un no', () {
      // Ninguna modalidad del catálogo publica hoy carreras, así que este
      // caso se arma a mano para no dejar la regla sin probar.
      final oferta = ofertaDePrueba(
        perfil: const PerfilAplicacion(carreraIds: ['carrera-buap']),
      );

      final ajena = CalculadoraElegibilidad.evaluar(
        oferta,
        datos: const DatosAlumno(),
        carreraId: 'otra-carrera',
      );
      expect(ajena.perfil.estado, EstadoElegibilidad.fueraDeRango);
      expect(ajena.estado, EstadoModalidad.noCumple);

      final propia = CalculadoraElegibilidad.evaluar(
        oferta,
        datos: const DatosAlumno(),
        carreraId: 'carrera-buap',
      );
      expect(propia.perfil.estado, EstadoElegibilidad.coincide);
      expect(propia.estado, isNot(EstadoModalidad.noCumple));
    });

    test('cuando la unidad no publica perfil, el aviso lo dice sin bajarlo', () async {
      final oferta = await repo.ofertaDeUnidad('FCC');
      final v = CalculadoraElegibilidad.evaluarOferta(
        oferta,
        datos: const DatosAlumno(promedio: 9.9),
      ).first;
      expect(v.perfil.estado, EstadoElegibilidad.unidadNoPublica);
      expect(v.avisoPerfil, contains('no publica'));
    });

    testWidgets('la pantalla pide los datos y muestra el veredicto', (
      tester,
    ) async {
      final state = await estadoDeAlumno('ARPA');
      final oferta = await repo.ofertaDeUnidad('ARPA');
      final nombreAutomatica = oferta.rutas
          .firstWhere((r) => r.idModalidad == 'titulacion-automatica-arpa')
          .modalidad!
          .nombreMostrado;

      await tester.pumpWidget(
        MaterialApp(theme: buildLoboTheme(), home: EligibilityScreen(state: state)),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿A qué modalidades puedo aspirar?'), findsOneWidget);
      expect(find.text('Lo que tú declaras'), findsOneWidget);

      // Con promedio alto, ARPA ya no lo tiene en rojo.
      await tester.enterText(
        find.widgetWithText(TextField, 'Promedio general'),
        '9.4',
      );
      await tester.pumpAndSettle();

      // Las tarjetas de modalidad están debajo del formulario.
      await tester.scrollUntilVisible(
        find.text(nombreAutomatica),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(nombreAutomatica), findsOneWidget);
      // Ni en verde ni en rojo: lo que ARPA no publica sigue sin definirse.
      expect(find.text('Cumple lo publicado'), findsNothing);
      expect(find.text('No cumple'), findsNothing);
      expect(find.text('Por confirmar'), findsWidgets);
    });

    testWidgets('sin unidad no hay nada que comparar', (tester) async {
      final state = await estadoLimpio();
      await tester.pumpWidget(
        MaterialApp(theme: buildLoboTheme(), home: EligibilityScreen(state: state)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Regístrate y elige tu unidad'), findsOneWidget);
    });
  });

  // =====================================================================
  // Notas por nivel
  // =====================================================================

  group('notas por nivel', () {
    test('la nota se guarda en su espacio de nombres y no se mezcla', () async {
      await estadoLimpio();
      final notas = NotasState(await SharedPreferences.getInstance());

      await notas.guardar('modalidad:ceneval-fcc', 3, 'la cita es el 14 de nov');
      expect(notas.textoDe('modalidad:ceneval-fcc', 3), 'la cita es el 14 de nov');
      expect(notas.textoDe('modalidad:tesis-fcc', 3), isEmpty);
      expect(notas.totalDe('modalidad:ceneval-fcc'), 1);
      expect(notas.totalDe('modalidad:tesis-fcc'), 0);
    });

    test('la nota sobrevive a reiniciar la app y texto vacío la borra', () async {
      await estadoLimpio();
      final prefs = await SharedPreferences.getInstance();
      await NotasState(prefs).guardar('promedio', 2, 'pedir cita en la DAE');

      final otra = NotasState(prefs);
      expect(otra.textoDe('promedio', 2), 'pedir cita en la DAE');

      await otra.guardar('promedio', 2, '   ');
      expect(otra.textoDe('promedio', 2), isEmpty);
      expect(NotasState(prefs).textoDe('promedio', 2), isEmpty);
    });

    test('las notas no tocan las claves del estado del núcleo', () async {
      final s = await estadoDeAlumno('ARPA');
      await s.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      final notas = NotasState(await SharedPreferences.getInstance());
      await notas.guardar('modalidad:titulacion-automatica-arpa', 1, 'servicio social en marcha');

      // El estado sigue intacto: misma modalidad, mismos niveles.
      expect(s.modalidadActiva, 'titulacion-automatica-arpa');
      expect(s.estaCompletado('titulacion-automatica-arpa', 1), isFalse);
      expect(
        NotasState(await SharedPreferences.getInstance()).textoDe(
          'modalidad:titulacion-automatica-arpa',
          1,
        ),
        'servicio social en marcha',
      );
    });

    testWidgets('la pantalla lista los niveles y guarda la nota', (tester) async {
      final s = await estadoDeAlumno('ARPA');
      await s.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      final notas = NotasState(await SharedPreferences.getInstance());

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLoboTheme(),
          home: NotesScreen(state: s, notas: notas),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis notas por nivel'), findsOneWidget);
      expect(find.text('Todavía no has escrito nada en estos niveles.'), findsOneWidget);

      await tester.tap(find.text('Servicio Social'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'constancia en trámite');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('constancia en trámite'), findsOneWidget);
      expect(notas.textoDe('modalidad:titulacion-automatica-arpa', 1),
          'constancia en trámite');
    });

    testWidgets('sin oferta activa avisa en vez de inventar niveles', (tester) async {
      final s = await estadoLimpio();
      final notas = NotasState(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLoboTheme(),
          home: NotesScreen(state: s, notas: notas),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Elige primero una modalidad'), findsOneWidget);
    });
  });

  // =====================================================================
  // Respaldo del avance
  // =====================================================================

  group('respaldo del avance', () {
    test('el respaldo lleva tipo, versión, fecha de generación y estado', () async {
      final s = await estadoDeAlumno('ARPA');
      await s.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      await s.completarNivel('titulacion-automatica-arpa', 1);
      final notas = NotasState(await SharedPreferences.getInstance());
      await notas.guardar('modalidad:titulacion-automatica-arpa', 1, 'voy en la DAE');

      final ruta = await repo.rutaEfectivaPorId('titulacion-automatica-arpa');
      final texto = construirRespaldo(state: s, notas: notas, niveles: ruta!.niveles);
      final m = json.decode(texto) as Map<String, dynamic>;

      expect(m['tipo'], 'loboapp-respaldo');
      expect(m['version'], 1);
      expect(m['generadoEn'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T')));
      expect((m['alumno'] as Map)['matricula'], '2020401');
      expect(m['facultadClave'], 'ARPA');
      expect((m['oferta'] as Map)['modalidadActiva'], 'titulacion-automatica-arpa');
      expect((m['oferta'] as Map)['rutaActivaBase'], 'promedio');
      expect(
        ((m['progreso'] as Map)['namespace']),
        'modalidad:titulacion-automatica-arpa',
      );
      expect(((m['progreso'] as Map)['nivelesCompletados'] as List), [1]);
      expect(
        ((m['notas'] as Map)['modalidad:titulacion-automatica-arpa'] as Map)['1'],
        'voy en la DAE',
      );
    });

    test('el respaldo dice qué se queda fuera', () async {
      final s = await estadoDeAlumno('ARPA');
      final notas = NotasState(await SharedPreferences.getInstance());
      final texto = construirRespaldo(state: s, notas: notas);
      final m = json.decode(texto) as Map<String, dynamic>;
      expect((m['alcance'] as List), isNotEmpty);
      expect(
        (m['alcance'] as List).join(' '),
        contains('no viaja'),
      );
    });

    test('analizar rechaza lo que no es un respaldo de LoboApp', () async {
      final errores1 = <String>[];
      expect(RespaldoAlumno.analizar('esto no es json', errores1), isNull);
      expect(errores1, isNotEmpty);

      final errores2 = <String>[];
      expect(
        RespaldoAlumno.analizar(json.encode({'tipo': 'otra-cosa'}), errores2),
        isNull,
      );
      expect(errores2.join(' '), contains('no es un respaldo'));

      final errores3 = <String>[];
      expect(
        RespaldoAlumno.analizar(
          json.encode({'tipo': tipoRespaldo, 'version': 99}),
          errores3,
        ),
        isNull,
      );
      expect(errores3.join(' '), contains('versión más nueva'));
    });

    test('ida y vuelta: lo que sale del teléfono vuelve igual', () async {
      final s = await estadoDeAlumno('ARPA');
      await s.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      await s.completarNivel('titulacion-automatica-arpa', 1);
      s.alternarDocumento('titulacion-automatica-arpa', 2, 0);
      final notas = NotasState(await SharedPreferences.getInstance());
      await notas.guardar('modalidad:titulacion-automatica-arpa', 2, 'falta la foto');

      final ruta = await repo.rutaEfectivaPorId('titulacion-automatica-arpa');
      final texto =
          construirRespaldo(state: s, notas: notas, niveles: ruta!.niveles);

      final errores = <String>[];
      final r = RespaldoAlumno.analizar(texto, errores)!;
      expect(errores, isEmpty);
      expect(r.alumno!.matricula, '2020401');
      expect(r.modalidadActiva, 'titulacion-automatica-arpa');
      expect(r.nivelesCompletados, [1]);
      expect(r.documentosMarcados, hasLength(1));
      expect(r.notas['modalidad:titulacion-automatica-arpa']![2], 'falta la foto');
    });

    test('restaurar en un teléfono vacío devuelve alumno, modalidad y avance', () async {
      final origen = await estadoDeAlumno('ARPA');
      await origen.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      await origen.completarNivel('titulacion-automatica-arpa', 1);
      await origen.completarNivel('titulacion-automatica-arpa', 2);
      origen.alternarDocumento('titulacion-automatica-arpa', 3, 0);
      final notasOrigen = NotasState(await SharedPreferences.getInstance());
      await notasOrigen.guardar('modalidad:titulacion-automatica-arpa', 1, 'en la DAE');

      final ruta = await repo.rutaEfectivaPorId('titulacion-automatica-arpa');
      final texto = construirRespaldo(
        state: origen,
        notas: notasOrigen,
        niveles: ruta!.niveles,
      );
      final respaldo = RespaldoAlumno.analizar(texto, <String>[])!;

      // Teléfono nuevo: sin alumno, sin unidad, sin avance.
      final destino = await estadoLimpio();
      final notasDestino = NotasState(await SharedPreferences.getInstance());
      final informe = await restaurarRespaldo(
        state: destino,
        notas: notasDestino,
        respaldo: respaldo,
        repo: repo,
      );

      expect(informe.errores, isEmpty);
      expect(destino.alumno!.matricula, '2020401');
      expect(destino.facultadClave, 'ARPA');
      expect(destino.modalidadActiva, 'titulacion-automatica-arpa');
      expect(destino.completadosDe('titulacion-automatica-arpa'), [1, 2]);
      expect(destino.documentoMarcado('titulacion-automatica-arpa', 3, 0), isTrue);
      expect(
        notasDestino.textoDe('modalidad:titulacion-automatica-arpa', 1),
        'en la DAE',
      );
      expect(informe.aplicados.join(' '), contains('Alumno'));
    });

    test('restaurar suma avance y avisa de que no borra', () async {
      final s = await estadoDeAlumno('ARPA');
      await s.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      // En este teléfono el alumno ya había llegado al nivel 3.
      await s.completarNivel('titulacion-automatica-arpa', 1);
      await s.completarNivel('titulacion-automatica-arpa', 2);
      await s.completarNivel('titulacion-automatica-arpa', 3);
      // Y el respaldo es de antes, cuando solo iba en el 1.
      final respaldo = RespaldoAlumno(
        generadoEn: '2026-09-29T00:00:00Z',
        esquemaEstado: 2,
        alumno: const Alumno(nombre: 'Alma Löwe', matricula: '2020401'),
        facultadClave: 'ARPA',
        modalidadActiva: 'titulacion-automatica-arpa',
        rutaActiva: 'titulacion-automatica-arpa',
        rutaActivaBase: 'promedio',
        carreraId: null,
        planId: null,
        anioIngreso: null,
        namespace: 'modalidad:titulacion-automatica-arpa',
        nivelesCompletados: const [1],
        documentosMarcados: const [],
        notas: const {},
        alcance: const [],
      );

      final notas = NotasState(await SharedPreferences.getInstance());
      final informe = await restaurarRespaldo(
        state: s,
        notas: notas,
        respaldo: respaldo,
        repo: repo,
      );

      expect(s.completadosDe('titulacion-automatica-arpa'), [1, 2, 3]);
      expect(informe.avisos.join(' '), contains('no borra'));
    });

    test('una unidad que ya no existe en el catálogo no se registra', () async {
      final s = await estadoLimpio();
      final notas = NotasState(await SharedPreferences.getInstance());
      final respaldo = RespaldoAlumno(
        generadoEn: '2026-09-29T00:00:00Z',
        esquemaEstado: 2,
        alumno: const Alumno(nombre: 'Alma Löwe', matricula: '2020401'),
        facultadClave: 'UNIDAD-QUE-NO-EXISTE',
        modalidadActiva: null,
        rutaActiva: null,
        rutaActivaBase: null,
        carreraId: null,
        planId: null,
        anioIngreso: null,
        namespace: null,
        nivelesCompletados: const [1],
        documentosMarcados: const [],
        notas: const {},
        alcance: const [],
      );

      final informe = await restaurarRespaldo(
        state: s,
        notas: notas,
        respaldo: respaldo,
        repo: repo,
      );
      expect(s.alumno, isNull);
      expect(informe.avisos.join(' '), contains('no existe en el catálogo'));
    });

    testWidgets('la pantalla copia, pega y restaura por el portapapeles', (
      tester,
    ) async {
      final origen = await estadoDeAlumno('ARPA');
      await origen.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      await origen.completarNivel('titulacion-automatica-arpa', 1);
      final notasOrigen = NotasState(await SharedPreferences.getInstance());
      final ruta = await repo.rutaEfectivaPorId('titulacion-automatica-arpa');
      final respaldoTexto = construirRespaldo(
        state: origen,
        notas: notasOrigen,
        niveles: ruta!.niveles,
      );

      final destino = await estadoLimpio();
      final notasDestino = NotasState(await SharedPreferences.getInstance());
      String? copiado;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLoboTheme(),
          home: BackupScreen(
            state: destino,
            notas: notasDestino,
            escribirPortapapeles: (t) async => copiado = t,
            leerPortapapeles: () async => copiado,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exportar: lo que hay en este teléfono sale como JSON al portapapeles.
      await tester.tap(find.text('Copiar mi respaldo'));
      await tester.pumpAndSettle();
      expect(copiado, isNotNull);
      expect(copiado, contains('loboapp-respaldo'));
      expect(find.textContaining('loboapp-respaldo'), findsWidgets);

      // El aviso del portapapeles tapa el botón de abajo: se espera a que se
      // vaya, si no el toque cae en él.
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Importar: ahora el portapapeles trae el respaldo del otro teléfono.
      copiado = respaldoTexto;
      await tester.tap(find.text('Pegar un respaldo y revisarlo'));
      await tester.pumpAndSettle();
      // El informe sale debajo del JSON copiado, fuera de la primera pantalla.
      await tester.scrollUntilVisible(
        find.text('Revisión'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Revisión'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Restaurar este respaldo'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar este respaldo'));
      await tester.pumpAndSettle();
      expect(destino.modalidadActiva, 'titulacion-automatica-arpa');
      expect(destino.completadosDe('titulacion-automatica-arpa'), [1]);
      expect(find.textContaining('Alumno 2020401'), findsOneWidget);
    });
  });
}
