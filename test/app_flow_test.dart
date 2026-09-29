import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titulacion/main.dart';
import 'package:titulacion/models/models.dart';
import 'package:titulacion/screens/contacts_screen.dart';
import 'package:titulacion/screens/home_screen.dart';
import 'package:titulacion/services/content_repository.dart';
import 'package:titulacion/state/app_state.dart';

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

  testWidgets('se entra como invitado si no hay matricula en la base',
      (tester) async {
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

    // Entra a su casa, con la facultad guardada.
    expect(state.estaRegistrado, isTrue);
    expect(state.facultadClave, 'FADMON');
    expect(find.text('Elige tu ruta'), findsOneWidget);
  });

  testWidgets('el alumno registrado llega a su casa con las tres rutas',
      (tester) async {
    final state = await estadoLimpio();
    await state.registrar(
      const AlumnoFixture().alumno,
      facultadClave: 'FING',
    );

    await tester.pumpWidget(LoboApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Elige tu ruta'), findsOneWidget);
    expect(find.text('Titulación por Promedio'), findsOneWidget);
    expect(find.text('Titulación por CENEVAL'), findsOneWidget);
    expect(find.text('Titulación por Examen Profesional'), findsOneWidget);
  });

  testWidgets('ruta → mapa → nivel → completar → mapa', (tester) async {
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

    // 1. Entrar a la ruta de CENEVAL.
    await tester.tap(find.text('Titulación por CENEVAL'));
    await tester.pumpAndSettle();

    expect(find.text('Ver mapa'), findsOneWidget);

    // 2. Al mapa.
    await tester.tap(find.text('Ver mapa'));
    await tester.pumpAndSettle();

    // La ruta se guardó como activa.
    expect(state.rutaActiva, 'ceneval');
    expect(find.text('Siguiente: Acta de nacimiento'), findsOneWidget);

    // 3. Al primer nivel.
    await tester.tap(find.text('Acta de nacimiento'));
    await tester.pumpAndSettle();

    expect(find.text('Nivel 1'), findsOneWidget);
    expect(find.text('Documentos (0/2)'), findsOneWidget);

    // 4. Marcar un documento.
    await tester.tap(find.text('Acta de nacimiento en original y actualizada'));
    await tester.pumpAndSettle();
    expect(find.text('Documentos (1/2)'), findsOneWidget);

    // 5. Completar el nivel.
    await tester.scrollUntilVisible(
      find.textContaining('Completar nivel'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.textContaining('Completar nivel'));
    await tester.pumpAndSettle();

    expect(state.estaCompletado('ceneval', 1), isTrue);
    // De vuelta en el mapa, con el nivel 2 como siguiente.
    expect(find.text('Siguiente: Identificación oficial'), findsOneWidget);
  });

  testWidgets('el contacto de la facultad aparece sobre el general',
      (tester) async {
    final state = await estadoLimpio();
    await state.registrar(
      const AlumnoFixture().alumno,
      facultadClave: 'FADMON',
    );

    await tester.pumpWidget(
      MaterialApp(home: ContactsScreen(state: state)),
    );
    await tester.pumpAndSettle();

    // La facultad de Administración sí publica su correo de titulación.
    expect(find.text('Facultad de Administración'), findsOneWidget);
    expect(find.text('titulacion.fadmon@correo.buap.mx'), findsOneWidget);
    // Y el contacto general de la BUAP está disponible.
    expect(find.text('Contacto general BUAP'), findsOneWidget);
  });

  testWidgets('una facultad sin correo propio lo dice y cae al general',
      (tester) async {
    final state = await estadoLimpio();
    await state.registrar(
      const AlumnoFixture().alumno,
      facultadClave: 'FECON', // Facultad de Economía: sin correo publicado.
    );

    await tester.pumpWidget(
      MaterialApp(home: ContactsScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no publica un correo de titulación propio'),
      findsOneWidget,
    );
  });

  testWidgets('la pestaña de links trae los enlaces de la BUAP',
      (tester) async {
    final state = await estadoLimpio();
    // Superficie alta: si no, la lista de links queda fuera de la vista.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ContactsScreen(state: state)),
    );
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
    await state.registrar(
      const AlumnoFixture().alumno,
      facultadClave: 'FING',
    );
    await state.completarNivel('promedio', 1);

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(state: state)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    expect(find.text('Mi progreso'), findsOneWidget);
    // La ruta de promedio tiene 7 niveles jugables; con 1 completado, 1/7.
    expect(find.text('1/7'), findsOneWidget);
  });

  testWidgets('el contenido real tiene las tres rutas con sus niveles',
      (tester) async {
    final rutas = await ContentRepository.instance.rutas();

    expect(rutas.map((r) => r.id).toSet(), {'promedio', 'ceneval', 'profesional'});
    for (final ruta in rutas) {
      expect(ruta.nivelesJugables, isNotEmpty, reason: '${ruta.id} sin niveles');
      expect(ruta.descripcion, isNotEmpty, reason: '${ruta.id} sin descripción');
      for (final nivel in ruta.nivelesJugables) {
        expect(nivel.titulo, isNotEmpty);
        expect(
          nivel.pasos.isNotEmpty || nivel.documentos.isNotEmpty,
          isTrue,
          reason: 'el nivel ${ruta.id}/${nivel.numero} no tiene contenido',
        );
      }
    }
  });

  testWidgets('todas las carpetas de assets están declaradas en pubspec',
      (tester) async {
    // Declarar solo `assets/images/` NO trae los archivos de sus
    // subdirectorios: el build los deja fuera y en la app salen rotos.
    final pubspec =
        File('pubspec.yaml').readAsStringSync();
    final carpetas = Directory('assets/images')
        .listSync()
        .whereType<Directory>()
        .map((d) => 'assets/images/${d.path.split('/').last}/')
        .toList();

    for (final carpeta in carpetas) {
      expect(
        pubspec.contains(carpeta),
        isTrue,
        reason: '$carpeta tiene archivos pero no está declarada en pubspec.yaml',
      );
    }

    // Y ningún asset puede vivir a dos niveles: Flutter no los empaqueta aunque
    // declares la carpeta intermedia, y en la app salen como imágenes rotas.
    final anidados = Directory('assets/images')
        .listSync()
        .whereType<Directory>()
        .expand((d) => d.listSync().whereType<Directory>())
        .toList();
    expect(
      anidados,
      isEmpty,
      reason: 'assets anidados a 2 niveles no se empaquetan: '
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
          RegExp(r"assets/[A-Za-z0-9_/.\-]+")
              .allMatches(dir.readAsStringSync())
              .map((m) => m.group(0)!),
        );
      }
    }
    for (final j in Directory('assets/json').listSync()) {
      if (j is File && j.path.endsWith('.json')) {
        referenciados.addAll(
          RegExp(r"assets/[A-Za-z0-9_/.\-]+")
              .allMatches(j.readAsStringSync())
              .map((m) => m.group(0)!),
        );
      }
    }
    // Las fuentes y las bases comprimidas se declaran en pubspec o se cargan
    // por ruta en tiempo de ejecución, no aparecen como literales.
    final excepciones = ['assets/fonts/', 'assets/alumnos/', 'assets/trabajadores/'];

    final muertos = <String>[];
    for (final f in Directory('assets/images').listSync(recursive: true)) {
      if (f is! File) continue;
      final p = f.path;
      if (excepciones.any(p.startsWith)) continue;
      final base = p.split('/').last;
      final referenciado = referenciados.any((r) => r.endsWith(base));
      if (!referenciado) muertos.add('$p (${f.lengthSync() ~/ 1024} KB)');
    }
    expect(muertos, isEmpty, reason: 'assets sin usar en el APK:\n${muertos.join("\n")}');
  });

  testWidgets('toda ruta de asset citada en el JSON existe en disco',
      (tester) async {
    final rutas = await ContentRepository.instance.rutas();
    final facultades = await ContentRepository.instance.facultades();

    final rutasAsset = <String>[];
    for (final ruta in rutas) {
      if (ruta.mascotaInicio.isNotEmpty) rutasAsset.add(ruta.mascotaInicio);
      if (ruta.pergaminoInicio.isNotEmpty) rutasAsset.add(ruta.pergaminoInicio);
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
}

/// Un alumno de ejemplo, para no repetir la construcción en cada test.
class AlumnoFixture {
  const AlumnoFixture();

  get alumno => _alumno;
}

final _alumno = Alumno(
  nombre: 'María Fernanda López',
  matricula: '202145678',
);
