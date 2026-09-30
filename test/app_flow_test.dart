import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/main.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/contacts_screen.dart';
import 'package:titulacion/screens/home_screen.dart';
import 'package:titulacion/screens/menu_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';
import 'package:titulacion/state/notas_state.dart';

/// Recorre la app como la recorre un alumno: bienvenida → registro → home →
/// ruta → mapa → nivel → completar → volver al mapa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Los tests corren en un directorio donde el bundle no existe: cargamos el
    // JSON real del disco para probar el contenido de verdad.
    ContentRepository.instance.cargarDesdeDiscoParaTests();
  });

  Future<AppState> estadoLimpio() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance());
  }

  testWidgets('un alumno sin registro entra por bienvenida', (tester) async {
    final state = await estadoLimpio();
    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('¡Bienvenido, futuro titulado!'), findsOneWidget);
    expect(find.text('Comenzar'), findsOneWidget);
  });

  testWidgets('el registro deja elegir unidad académica', (tester) async {
    final state = await estadoLimpio();
    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quién eres?'), findsOneWidget);
    // La búsqueda real contra la base de la BUAP.
    expect(find.text('Matrícula o nombre'), findsOneWidget);
    // Y se listan las unidades académicas de la BUAP.
    expect(find.text('¿De qué unidad académica vienes?'), findsOneWidget);
  });

  testWidgets('sin elegir facultad no se puede avanzar', (tester) async {
    final state = await estadoLimpio();
    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    // Sin matrícula válida, el botón ofrece el modo invitado.
    await tester.tap(find.text('Continuar como invitado'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Elige tu unidad académica'), findsOneWidget);
    expect(state.estaRegistrado, isFalse);
  });

  testWidgets('se entra como invitado si no hay matricula en la base', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await estadoLimpio();
    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facultad de Administración').last);
    await tester.pumpAndSettle();

    // Sin matrícula válida se entra como invitado, con el texto que lo dice.
    expect(find.text('Continuar como invitado'), findsOneWidget);
    await tester.tap(find.text('Continuar como invitado'));
    await tester.pumpAndSettle();

    // Entra a su casa, con la unidad guardada y su catálogo a la vista.
    expect(state.estaRegistrado, isTrue);
    expect(state.facultadClave, 'FADMON');
    expect(find.text('Elige tu modalidad de titulación'), findsOneWidget);
    // Una unidad que no publica catálogo lo dice, en vez de dejar la pantalla
    // vacía o de inventar modalidades. El texto NO lleva la palabra
    // "Catálogo" delante: se repite, porque el estado ya lo dice.
    expect(find.textContaining('Sin catálogo publicado'), findsOneWidget);
    expect(find.textContaining('Catálogo Catálogo'), findsNothing);
  });

  testWidgets('una unidad sin catálogo no deja la pantalla vacía', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await estadoLimpio();
    await state.registrar(
      const AlumnoFixture().alumno,
      facultadClave: 'FADMON',
    );

    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();

    // El mensaje es explícito, y sale el rastro de lo que se buscó.
    expect(find.text('Esta unidad no publica catálogo'), findsOneWidget);
    expect(
      find.textContaining('no publica catálogo de modalidades'),
      findsOneWidget,
    );
    expect(find.text('Ver búsqueda y fuentes'), findsOneWidget);
    // Y la unidad aparece con su nombre, no como una lista global de rutas.
    expect(
      find.textContaining('Tu unidad: Facultad de Administración'),
      findsOneWidget,
    );
    // Contacto de respaldo: hay a quién escribirle.
    expect(
      find.textContaining('titulacion.fadmon@correo.buap.mx'),
      findsOneWidget,
    );
  });

  testWidgets('la pantalla de búsqueda muestra las URLs que se consultaron', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await estadoLimpio();
    await state.registrar(
      const AlumnoFixture().alumno,
      facultadClave: 'FADMON',
    );

    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver búsqueda y fuentes'));
    await tester.pumpAndSettle();

    expect(find.text('Dónde se buscó'), findsOneWidget);
    expect(
      find.text('https://www.buap.mx/content/unidades-academicas'),
      findsWidgets,
    );
    expect(find.textContaining('sin_catalogo_publicado'), findsWidgets);
  });

  testWidgets('el listado sale filtrado por la unidad académica', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await estadoLimpio();
    await state.registrar(const AlumnoFixture().alumno, facultadClave: 'FCC');

    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Elige tu modalidad de titulación'), findsOneWidget);
    expect(
      find.textContaining('Tu unidad: Facultad de Ciencias de la Computación'),
      findsOneWidget,
    );
    // Las modalidades que publica FCC, con el nombre que usa la unidad.
    expect(
      find.textContaining('Tesis (Examen profesional por tesis)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Ceneval (Presentación del examen CENEVAL-EGEL)'),
      findsOneWidget,
    );
    // Y nada de lo que publica otra unidad: la oferta global no existe.
    expect(find.textContaining('Seminario de Titulación'), findsNothing);
    expect(find.text('Titulación por Examen Profesional'), findsNothing);
  });

  testWidgets('ruta → mapa → nivel → completar → mapa', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await estadoLimpio();
    await state.registrar(const AlumnoFixture().alumno, facultadClave: 'FCC');

    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();

    // 1. Entrar a la modalidad de tesis que publica FCC.
    await tester.tap(
      find.textContaining('Tesis (Examen profesional por tesis)'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ver mapa'), findsOneWidget);
    // La pantalla muestra la fuente y la fecha antes de entrar al mapa.
    expect(find.text('Fuente'), findsOneWidget);
    expect(find.text('Promedio general mínimo'), findsOneWidget);
    expect(find.text('no publicado'), findsWidgets);

    // 2. Al mapa.
    await tester.tap(find.text('Ver mapa'));
    await tester.pumpAndSettle();

    // La modalidad quedó como ruta activa y se guardó su id, no el de la base.
    expect(state.rutaActiva, 'tesis-fcc');
    expect(state.modalidadActiva, 'tesis-fcc');
    expect(state.rutaActivaBase, 'tesis');
    expect(find.text('Siguiente: Liberación de la Facultad'), findsOneWidget);

    // 3. Al primer nivel.
    await tester.tap(find.text('Liberación de la Facultad'));
    await tester.pumpAndSettle();

    expect(find.text('Nivel 1'), findsOneWidget);

    // 4. Completar el nivel.
    await tester.scrollUntilVisible(
      find.textContaining('Completar nivel'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.textContaining('Completar nivel'));
    await tester.pumpAndSettle();

    expect(state.estaCompletado('tesis-fcc', 1), isTrue);
    // De vuelta en el mapa, con el nivel 2 como siguiente.
    expect(
      find.text('Siguiente: Solicitud y certificado de estudios'),
      findsOneWidget,
    );
  });

  testWidgets('el avance de una modalidad no se filtra a otra ni a la base', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await estadoLimpio();
    await state.registrar(const AlumnoFixture().alumno, facultadClave: 'FCC');

    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(
      find.textContaining('Tesis (Examen profesional por tesis)'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver mapa'));
    await tester.pumpAndSettle();
    await state.completarNivel('tesis-fcc', 1);

    // Ni la ruta base ni otra modalidad de la misma unidad se han movido.
    expect(state.estaCompletado('tesis', 1), isFalse);
    expect(state.estaCompletado('experiencia-profesional-fcc', 1), isFalse);
    expect(state.estaCompletado('ceneval-fcc', 1), isFalse);
  });

  testWidgets(
    'al elegir una modalidad se ofrece traer el avance de la ruta base',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final state = await estadoLimpio();
      await state.registrar(const AlumnoFixture().alumno, facultadClave: 'FCC');
      // Avance heredado de cuando la app solo tenía rutas globales.
      await state.completarNivel('tesis', 1);
      await state.completarNivel('tesis', 2);

      await tester.pumpWidget(LoboApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining('Tesis (Examen profesional por tesis)'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver mapa'));
      await tester.pumpAndSettle();

      // Nada se copia a sus espaldas: se pregunta.
      expect(find.text('¿Traer tu avance anterior?'), findsOneWidget);
      expect(state.estaCompletado('tesis-fcc', 1), isFalse);

      await tester.tap(find.text('Traer mi avance'));
      await tester.pumpAndSettle();

      expect(state.estaCompletado('tesis-fcc', 1), isTrue);
      expect(state.estaCompletado('tesis-fcc', 2), isTrue);
      // El original no se borra.
      expect(state.estaCompletado('tesis', 1), isTrue);
    },
  );

  testWidgets(
    'el alumno con una ruta global guardada la sigue viendo en el mapa',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final state = await estadoLimpio();
      await state.registrar(
        const AlumnoFixture().alumno,
        facultadClave: 'FADMON',
      );
      // Estado de la versión 1: una ruta global, no una modalidad de la unidad.
      await state.elegirRuta('ceneval');

      await tester.pumpWidget(LoboApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();

      // El adaptador legado resuelve el id guardado sin consultar el catálogo.
      expect(find.text('Titulación por CENEVAL'), findsOneWidget);
    },
  );

  testWidgets('el contacto de la facultad aparece sobre el general', (
    tester,
  ) async {
    final state = await estadoLimpio();
    await state.registrar(
      const AlumnoFixture().alumno,
      facultadClave: 'FADMON',
    );

    await tester.pumpWidget(MaterialApp(home: ContactsScreen(state: state)));
    await tester.pumpAndSettle();

    // La facultad de Administración sí publica su correo de titulación.
    expect(find.text('Facultad de Administración'), findsOneWidget);
    expect(find.text('titulacion.fadmon@correo.buap.mx'), findsOneWidget);
    // Y el contacto general de la BUAP está disponible.
    expect(find.text('Contacto general BUAP'), findsOneWidget);
  });

  testWidgets('una facultad sin correo propio lo dice y cae al general', (
    tester,
  ) async {
    final state = await estadoLimpio();
    await state.registrar(
      const AlumnoFixture().alumno,
      facultadClave: 'FECON', // Facultad de Economía: sin correo publicado.
    );

    await tester.pumpWidget(MaterialApp(home: ContactsScreen(state: state)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no publica un correo de titulación propio'),
      findsOneWidget,
    );
  });

  testWidgets('la pestaña de links trae los enlaces de la BUAP', (
    tester,
  ) async {
    final state = await estadoLimpio();
    // Superficie alta: si no, la lista de links queda fuera de la vista.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: ContactsScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();

    expect(find.text('Autoservicios BUAP'), findsOneWidget);
    expect(find.text('CURP (gob.mx)'), findsOneWidget);
  });

  testWidgets('el perfil muestra el avance de cada ruta', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await estadoLimpio();
    await state.registrar(const AlumnoFixture().alumno, facultadClave: 'FCC');
    // El avance se guarda bajo la modalidad que la unidad compone, que es el
    // mismo id que usan el mapa y el detalle del nivel.
    await state.elegirModalidad('tesis-fcc', 'tesis');
    await state.completarNivel('tesis-fcc', 1);

    await tester.pumpWidget(MaterialApp(home: HomeScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    expect(find.text('Mi progreso'), findsOneWidget);
    final compuesta = await ContentRepository.instance.rutaCompuestaPorModalidad(
      'tesis-fcc',
    );
    final total = compuesta!.totalNiveles;
    // Con un nivel completado, el perfil lo tiene que mostrar.
    expect(find.text('1/$total'), findsOneWidget);
  });

  testWidgets(
    'el perfil lista las modalidades que publica la unidad del alumno',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final state = await estadoLimpio();
      await state.registrar(
        const AlumnoFixture().alumno,
        facultadClave: 'FING',
      );

      await tester.pumpWidget(MaterialApp(home: HomeScreen(state: state)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      final oferta = await ContentRepository.instance.ofertaDeUnidad('FING');
      for (final r in oferta.rutas) {
        expect(find.text(r.nombre), findsOneWidget);
      }
      // El catálogo global no es de esta unidad: sus rutas no se le atribuyen.
      final global = await ContentRepository.instance.rutas();
      final nombresDeFING = oferta.rutas.map((r) => r.nombre).toSet();
      for (final g in global) {
        if (nombresDeFING.contains(g.nombre)) continue;
        expect(find.text(g.nombre), findsNothing);
      }
    },
  );

  testWidgets('el menú abre todo lo que la app promises', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await estadoLimpio();
    await state.registrar(const AlumnoFixture().alumno, facultadClave: 'FCC');
    await state.elegirModalidad('tesis-fcc', 'tesis');

    await tester.pumpWidget(MaterialApp(home: MenuScreen(state: state)));
    await tester.pumpAndSettle();

    // Ninguna de estas pantallas puede quedar sin puerta de entrada.
    const entradas = <String, String>{
      'Mis notas': 'Mis notas por nivel',
      'Respaldar mi avance': 'Respaldo de mi avance',
    };
    for (final entrada in entradas.keys) {
      expect(find.text(entrada), findsOneWidget, reason: 'falta $entrada en el menú');
      await tester.tap(find.text(entrada));
      await tester.pumpAndSettle();
      expect(
        find.text(entradas[entrada]!),
        findsOneWidget,
        reason: '$entrada no abrió su pantalla',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('el perfil sin unidad elegida cae al catálogo global', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = await estadoLimpio();

    await tester.pumpWidget(MaterialApp(home: HomeScreen(state: state)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    expect(find.text('Mi progreso'), findsOneWidget);
    final rutas = await ContentRepository.instance.rutas();
    expect(rutas, isNotEmpty);
    // Sin unidad no hay a quién atribuirle un catálogo: se muestra el global.
    for (final r in rutas) {
      expect(find.text(r.nombre), findsOneWidget);
    }
  });

  testWidgets(
    'el contenido real conserva las rutas legadas y suma las del art. 7',
    (tester) async {
      final rutas = await ContentRepository.instance.rutas();
      final ids = rutas.map((r) => r.id).toSet();

      // Las tres legadas no se tocan: su id es la llave del progreso ya guardado.
      expect({
        'promedio',
        'ceneval',
        'profesional',
      }, ids.intersection({'promedio', 'ceneval', 'profesional'}));
      // Las cinco del art. 7 que el catálogo acredita.
      expect(
        {
          'tesis',
          'diplomado',
          'experiencia-profesional',
          'seminario',
          'asignatura-optativa',
        },
        ids.intersection({
          'tesis',
          'diplomado',
          'experiencia-profesional',
          'seminario',
          'asignatura-optativa',
        }),
      );
      expect(rutas, hasLength(8));

      for (final ruta in rutas) {
        expect(
          ruta.nivelesJugables,
          isNotEmpty,
          reason: '${ruta.id} sin niveles',
        );
        expect(
          ruta.descripcion,
          isNotEmpty,
          reason: '${ruta.id} sin descripción',
        );
        // Toda ruta dice de dónde sale su contenido, aunque sea "no verificado".
        expect(
          ruta.citaFuente,
          isNotEmpty,
          reason: '${ruta.id} sin fuente ni nota de por qué no la tiene',
        );
        for (final nivel in ruta.nivelesJugables) {
          expect(nivel.titulo, isNotEmpty);
          expect(
            nivel.pasos.isNotEmpty || nivel.documentos.isNotEmpty,
            isTrue,
            reason: 'el nivel ${ruta.id}/${nivel.numero} no tiene contenido',
          );
        }
      }
    },
  );

  testWidgets('las rutas nuevas del art. 7 traen fuente verificable y fecha', (
    tester,
  ) async {
    final rutas = await ContentRepository.instance.rutas();
    for (final ruta in rutas.where((r) => r.esRutaNueva)) {
      expect(
        ruta.fuenteBase,
        isNotEmpty,
        reason: '${ruta.id} es ruta nueva pero no dice de qué fuente sale',
      );
      expect(
        ruta.fechaBase,
        isNotEmpty,
        reason: '${ruta.id} es ruta nueva pero no dice cuándo se consultó',
      );
      expect(
        ruta.alcance,
        isNotEmpty,
        reason: '${ruta.id} debe decir qué cubre y qué no',
      );
      expect(ruta.mapa, isNotEmpty, reason: '${ruta.id} sin mapa asignado');
    }
    // Las tres legadas declaran por escrito que su contenido no está verificado.
    for (final ruta in rutas.where((r) => !r.esRutaNueva)) {
      expect(
        ruta.tieneFuenteVerificada,
        isFalse,
        reason: '${ruta.id} es contenido heredado: no puede declarar fuente',
      );
      expect(ruta.notaFuente, isNotEmpty);
    }
  });

  testWidgets('todas las carpetas de assets están declaradas en pubspec', (
    tester,
  ) async {
    // Declarar solo `assets/images/` NO trae los archivos de sus
    // subdirectorios: el build los deja fuera y en la app salen rotos.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final carpetas =
        Directory('assets/images')
            .listSync()
            .whereType<Directory>()
            .map((d) => 'assets/images/${d.path.split('/').last}/')
            .toList();

    for (final carpeta in carpetas) {
      expect(
        pubspec.contains(carpeta),
        isTrue,
        reason:
            '$carpeta tiene archivos pero no está declarada en pubspec.yaml',
      );
    }

    // Y ningún asset puede vivir a dos niveles: Flutter no los empaqueta aunque
    // declares la carpeta intermedia, y en la app salen como imágenes rotas.
    final anidados =
        Directory('assets/images')
            .listSync()
            .whereType<Directory>()
            .expand((d) => d.listSync().whereType<Directory>())
            .toList();
    expect(
      anidados,
      isEmpty,
      reason:
          'assets anidados a 2 niveles no se empaquetan: '
          '${anidados.map((d) => d.path).join(", ")}',
    );
  });

  testWidgets('no hay assets muertos en la app', (tester) async {
    // Un asset que nadie usa sigue ocupando espacio en el APK. Esto falla si
    // agregas un archivo y no lo usas (o si lo usas y se te olvida ponerlo).
    final referenciados = <String>{};
    for (final dir in Directory('lib').listSync(recursive: true)) {
      if (dir is File && dir.path.endsWith('.dart')) {
        referenciados.addAll(
          RegExp(
            r"assets/[A-Za-z0-9_/.\-]+",
          ).allMatches(dir.readAsStringSync()).map((m) => m.group(0)!),
        );
      }
    }
    for (final j in Directory('assets/json').listSync()) {
      if (j is File && j.path.endsWith('.json')) {
        referenciados.addAll(
          RegExp(
            r"assets/[A-Za-z0-9_/.\-]+",
          ).allMatches(j.readAsStringSync()).map((m) => m.group(0)!),
        );
      }
    }
    // Las fuentes y las bases comprimidas se declaran en pubspec o se cargan
    // por ruta en tiempo de ejecución, no aparecen como literales.
    final excepciones = [
      'assets/fonts/',
      'assets/alumnos/',
      'assets/trabajadores/',
    ];

    final muertos = <String>[];
    for (final f in Directory('assets/images').listSync(recursive: true)) {
      if (f is! File) continue;
      final p = f.path;
      if (excepciones.any(p.startsWith)) continue;
      final base = p.split('/').last;
      final referenciado = referenciados.any((r) => r.endsWith(base));
      if (!referenciado) muertos.add('$p (${f.lengthSync() ~/ 1024} KB)');
    }
    expect(
      muertos,
      isEmpty,
      reason: 'assets sin usar en el APK:\n${muertos.join("\n")}',
    );
  });

  testWidgets('toda ruta de asset citada en el JSON existe en disco', (
    tester,
  ) async {
    final rutas = await ContentRepository.instance.rutas();
    final facultades = await ContentRepository.instance.facultades();

    final rutasAsset = <String>[];
    for (final ruta in rutas) {
      if (ruta.mascotaInicio.isNotEmpty) rutasAsset.add(ruta.mascotaInicio);
      if (ruta.pergaminoInicio.isNotEmpty) rutasAsset.add(ruta.pergaminoInicio);
      if (ruta.tituloAsset.isNotEmpty) rutasAsset.add(ruta.tituloAsset);
      if (ruta.descripcionAsset.isNotEmpty) {
        rutasAsset.add(ruta.descripcionAsset);
      }
      if (ruta.mapa.isNotEmpty) rutasAsset.add(ruta.mapa);
      for (final nivel in ruta.niveles) {
        if (nivel.icono.isNotEmpty) rutasAsset.add(nivel.icono);
        if (nivel.mascota.isNotEmpty) rutasAsset.add(nivel.mascota);
        if (nivel.fondo.isNotEmpty) rutasAsset.add(nivel.fondo);
      }
    }

    for (final asset in rutasAsset.toSet()) {
      expect(
        ContentRepository.existeAsset(asset),
        isTrue,
        reason: 'el JSON referencia "$asset" pero no está en assets/',
      );
    }

    // Y las facultades tienen clave y nombre, que es como se guardan.
    for (final f in facultades) {
      expect(f.clave, isNotEmpty, reason: '${f.nombre} sin clave');
      expect(f.nombre, isNotEmpty);
    }
  });

  // =====================================================================
  // Cierre de sesión
  // =====================================================================

  group('cierre de sesión', () {
    test('borra del dispositivo todo lo que guardó esa sesión', () async {
      final s = await estadoLimpio();
      await s.registrar(
        const Alumno(nombre: 'María Fernanda López', matricula: '202145678'),
        facultadClave: 'ARPA',
      );
      await s.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      await s.completarNivel('titulacion-automatica-arpa', 1);
      await s.completarNivel('titulacion-automatica-arpa', 2);
      await s.alternarDocumento('titulacion-automatica-arpa', 1, 0);
      await s.guardarContexto(carreraId: 'INFORMATICA', anioIngreso: 2020);
      await s.notas.guardar(
        'modalidad:titulacion-automatica-arpa',
        1,
        'la DAE es el jueves',
      );

      // Antes de cerrar, todo está guardado.
      expect(s.estaRegistrado, isTrue);
      expect(s.completadosDe('titulacion-automatica-arpa'), [1, 2]);

      await s.cerrarSesion();

      // En memoria no quedan persona, unidad, oferta, avance ni notas.
      expect(s.estaRegistrado, isFalse);
      expect(s.alumno, isNull);
      expect(s.facultadClave, isNull);
      expect(s.rutaActiva, isNull);
      expect(s.modalidadActiva, isNull);
      expect(s.rutaActivaBase, isNull);
      expect(s.completadosDe('titulacion-automatica-arpa'), isEmpty);
      expect(s.documentoMarcado('titulacion-automatica-arpa', 1, 0), isFalse);
      expect(s.notas.todas(), isEmpty);
      expect(s.carreraId, isEmpty);
      expect(s.tieneContexto, isFalse);

      // Y en las preferencias tampoco sobrevive ninguna clave de la sesión.
      final prefs = await SharedPreferences.getInstance();
      for (final clave in const [
        'alumno',
        'facultad',
        'ruta',
        'modalidadActiva',
        'rutaActivaBase',
        'contextoAlumno',
        'migracionesProgreso',
        'estadoSchema',
        'progreso',
        NotasState.clavePref,
      ]) {
        expect(prefs.getString(clave), isNull, reason: 'sobrevive $clave');
        expect(
          prefs.getKeys(),
          isNot(contains(clave)),
          reason: 'sobrevive la clave $clave',
        );
      }
    });

    test('quien se registra después en la misma unidad empieza en cero', () async {
      final s = await estadoLimpio();
      await s.registrar(
        const Alumno(nombre: 'María Fernanda López', matricula: '202145678'),
        facultadClave: 'ARPA',
      );
      await s.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      await s.completarNivel('titulacion-automatica-arpa', 1);
      await s.alternarDocumento('titulacion-automatica-arpa', 1, 0);
      await s.notas.guardar(
        'modalidad:titulacion-automatica-arpa',
        1,
        'nota de la primera persona',
      );
      await s.cerrarSesion();

      // Otra persona, la MISMA unidad: la modalidad se puede volver a elegir.
      await s.registrar(
        const Alumno(nombre: 'Bruno Díaz', matricula: '202245678'),
        facultadClave: 'ARPA',
      );
      expect(s.estaRegistrado, isTrue);
      expect(s.facultadClave, 'ARPA');
      expect(s.modalidadActiva, isNull);

      await s.elegirModalidad('titulacion-automatica-arpa', 'promedio');
      expect(s.completadosDe('titulacion-automatica-arpa'), isEmpty);
      expect(s.documentoMarcado('titulacion-automatica-arpa', 1, 0), isFalse);
      expect(
        s.notas.textoDe('modalidad:titulacion-automatica-arpa', 1),
        isEmpty,
      );
    });

    test('el aviso de privacidad dice lo mismo que el código', () {
      final aviso = File(
        '${Directory.current.path}/docs/PRIVACIDAD.md',
      ).readAsStringSync();

      // La promesa anterior: cerrar sesión solo quitaba el registro.
      expect(aviso, isNot(contains('borrar solo el progreso')));
      // Y ahora declara qué borra de verdad.
      expect(aviso, contains('Cerrar sesión borra todo'));
      expect(aviso, contains('tus notas'));
      expect(aviso, contains('empieza en cero'));
    });
  });

  // =====================================================================
  // Cambio de unidad académica
  // =====================================================================

  group('cambio de unidad académica', () {
    testWidgets(
      'la portada recarga el catálogo y no deja elegir modalidades de la unidad anterior',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 6000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final state = await estadoLimpio();
        await state.registrar(const AlumnoFixture().alumno, facultadClave: 'FCC');

        await tester.pumpWidget(LoboApp(state: state));
        await tester.pumpAndSettle();

        // La unidad A publica esto, y esto es lo único que se pinta.
        final deA = await ContentRepository.instance.ofertaDeUnidad('FCC');
        expect(deA.rutas, isNotEmpty);
        expect(
          find.textContaining('Tu unidad: Facultad de Ciencias de la Computación'),
          findsOneWidget,
        );
        for (final r in deA.rutas) {
          expect(find.text(r.nombre), findsOneWidget, reason: 'falta ${r.nombre}');
        }

        // El flujo real del alumno: perfil → cambiar de unidad → registro.
        await tester.tap(find.byIcon(Icons.person));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Facultad de Ciencias de la Computación'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Facultad de Ciencias de la Comunicación').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuar como invitado'));
        await tester.pumpAndSettle();
        // F-12: se está registrando a otra persona en este mismo teléfono, así
        // que el registro avisa antes de seguir (el avance y las notas de la
        // anterior se conservan y solo se borran con "Cerrar sesión").
        expect(find.text('Vas a registrar a otra persona'), findsOneWidget);
        await tester.tap(find.text('Registrar de todos modos'));
        await tester.pumpAndSettle();

        // La unidad guardada es la nueva...
        expect(state.facultadClave, 'FCCOM');
        expect(
          find.textContaining('Tu unidad: Facultad de Ciencias de la Comunicación'),
          findsOneWidget,
        );
        // ...y las tarjetas que se pintan son las que publica ella.
        final deB = await ContentRepository.instance.ofertaDeUnidad('FCCOM');
        expect(deB.rutas, isNotEmpty);
        for (final r in deB.rutas) {
          expect(
            find.text(r.nombre),
            findsOneWidget,
            reason: 'falta ${r.nombre}, que sí publica la unidad nueva',
          );
        }
        // Y ninguna modalidad de la unidad anterior quedó en pantalla: elegir
        // una de ésas metía al alumno en una oferta que su unidad no publica.
        for (final r in deA.rutas) {
          expect(
            find.text(r.nombre),
            findsNothing,
            reason: '${r.nombre} es de la unidad anterior y sigue pintada',
          );
        }
      },
    );
  });
}

/// Un alumno de ejemplo, para no repetir la construcción en cada test.
class AlumnoFixture {
  const AlumnoFixture();

  get alumno => _alumno;
}

final _alumno = Alumno(nombre: 'María Fernanda López', matricula: '202145678');
