import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titulacion/models/models.dart';

/// Blindaje contra las clases de error que se encontraron al revisar el
/// contenido el 2026-09-30: campos `url` que en realidad eran una frase con
/// varias direcciones pegadas, direcciones mal codificadas que respondían 404,
/// y correos personales sin alternativa institucional.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<File> archivos;

  setUpAll(() {
    archivos = Directory('assets/json')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(archivos, isNotEmpty);
  });

  final urlDeCampo = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://\S+$');
  /// Un `%` debe ir seguido de dos dígitos hexadecimales. El defecto encontrado
  /// era «PLAN%20DE%ESTUDIOS», con la palabra pegada tras un `%` suelto.
  final porcentajeMalFormado = RegExp(r'%(?![0-9A-Fa-f]{2})');

  /// Un enlace en http es aceptable solo cuando el servidor no publica TLS y el
  /// propio registro lo declara: cambiarlo a https lo dejaría roto.
  final httpSoloSinTls = <String>{
    'http://academica.ece.buap.mx/image-resources/objects/opciones.pdf',
  };

  void cadaUrlEnCampo(
    void Function(String archivo, String ruta, String valor) f,
  ) {
    void walk(Object? o, String ruta, String archivo) {
      if (o is Map) {
        for (final e in o.entries) {
          final k = e.key.toString();
          final v = e.value;
          if ((k == 'url' || k == 'fuente' || k == 'urlDirectorio') &&
              v is String &&
              v.startsWith('http')) {
            f(archivo, '$ruta.$k', v);
          } else {
            walk(v, '$ruta.$k', archivo);
          }
        }
      } else if (o is List) {
        for (var i = 0; i < o.length; i++) {
          walk(o[i], '$ruta[$i]', archivo);
        }
      }
    }

    for (final a in archivos) {
      walk(json.decode(a.readAsStringSync(encoding: utf8)), '', a.path);
    }
  }

  test('todo campo url/fuente contiene UNA dirección, no una frase', () {
    var total = 0;
    cadaUrlEnCampo((archivo, ruta, valor) {
      total++;
      expect(valor, matches(urlDeCampo),
          reason: '$archivo$ruta no es una dirección pura.\n'
              'Trae texto o más de una URL pegadas; si es una cita debe estar en '
              '"citaFuente", no dentro de "url"/"fuente".\nValor: $valor');
      // Separadores de prosa que nunca pertenecen a una dirección.
      for (final signo in [';', '»', '…', "'", '"', ' ', '\n']) {
        expect(valor.contains(signo), isFalse,
            reason: '$archivo$ruta contiene «$signo»:\n  $valor');
      }
    });
    expect(total, greaterThan(50));
  });

  test('todo campo url/fuente está en https y bien codificado', () {
    cadaUrlEnCampo((archivo, ruta, valor) {
      // El https es la regla. La excepcion es un servidor que no publica TLS:
      // ahi el enlace se declara en http a proposito, porque cambiarlo lo
      // dejaria roto.
      if (!valor.startsWith('https://')) {
        expect(httpSoloSinTls.contains(valor), isTrue,
            reason: '$archivo$ruta usa http sin declararlo: $valor');
      }
      expect(porcentajeMalFormado.hasMatch(valor), isFalse,
          reason: '$archivo$ruta tiene un % sin dos dígitos hexadecimales: $valor');
    });
  });

  test('todo enlace marcado como no verificado explica por qué', () {
    var marcados = 0;
    for (final a in archivos) {
      void walk(Object? x) {
        if (x is Map) {
          if (x['estadoEnlace'] == 'no_verificado') {
            marcados++;
            expect(x['notaEnlace'], isNotNull,
                reason: '${a.path}: enlace no verificado sin explicación');
            expect(x['notaEnlace'].toString(), contains('2026-09-30'),
                reason: '${a.path}: la explicación debe decir cuándo se comprobó');
          }
          x.values.forEach(walk);
        } else if (x is List) {
          x.forEach(walk);
        }
      }

      walk(json.decode(a.readAsStringSync(encoding: utf8)));
    }
    expect(marcados, greaterThanOrEqualTo(4),
        reason: 'los enlaces que no responden se declaran, no se esconden');
  });

  test('el contenido no trae caracteres de otra escritura ni de relleno', () {
    // ASCII imprimible más español y puntuación tipográfica. Se compara por
    // código para no depender de cómo el archivo representa el rango.
    final permitidos = <int>{
      for (var c = 0x20; c <= 0x7E; c++) c,
      for (final c
          in 'áéíóúüñÁÉÍÓÚÜÑ¡¿·°ºª–—…§¶•‘’“”→«»≥≤±×÷©®'.split('')) c.codeUnitAt(0),
      0x0A, 0x0D, 0x09, 0xA0,
    };
    for (final a in archivos) {
      final texto = a.readAsStringSync(encoding: utf8);
      for (var i = 0; i < texto.length; i++) {
        final c = texto.codeUnitAt(i);
        expect(permitidos.contains(c), isTrue,
            reason: '${a.path} trae «${texto[i]}» (U+'
                '${c.toRadixString(16)}) cerca de: '
                '${texto.substring((i - 30).clamp(0, i), i)}');
      }
    }
  });

  test('ningún correo del contenido es de ejemplo', () {
    final correos = RegExp(
      r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
    );
    var total = 0;
    for (final a in archivos) {
      for (final m
          in correos.allMatches(a.readAsStringSync(encoding: utf8))) {
        total++;
        expect(m.group(0), isNot(contains('example')),
            reason: '${a.path}: correo de ejemplo ${m.group(0)}');
      }
    }
    expect(total, greaterThan(20));
  });

  test('un buzón personal siempre trae su alternativa institucional', () {
    // FCFM publica paty@fcfm.buap.mx para el oficio de modalidad: es oficial,
    // pero es una persona. Si se va, el alumno debe tener a dónde acudir.
    final cat = json.decode(
      File('assets/json/catalogo_modalidades.json').readAsStringSync(
        encoding: utf8,
      ),
    ) as Map<String, dynamic>;

    var revisados = 0;
    void walk(Object? o) {
      if (o is Map) {
        if (jsonEncode(o).contains('paty@fcfm.buap.mx')) {
          revisados++;
          expect(o['contactoInstitucional'], isNotNull,
              reason: 'un buzón personal sin alternativa institucional');
          expect(o['notaContacto'].toString(), contains('Secretaría Académica'),
              reason: 'falta explicar a dónde acudir si el buzón deja de servir');
        }
        o.values.forEach(walk);
      } else if (o is List) {
        o.forEach(walk);
      }
    }

    walk(cat);
    expect(revisados, greaterThan(0),
        reason: 'se esperaba encontrar el caso de FCFM');
  });

  test('un documento no puede apuntar a un enlace muerto sin decirlo', () {
    // `estadoEnlace` se agregó al JSON para no dar por bueno lo que no se pudo
    // comprobar, pero ningún modelo lo leía: el botón «Abrir documento
    // oficial» salía idéntico para un PDF vivo y para un servidor caído.
    final rutas =
        (json.decode(
              File('assets/json/routes.json').readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['rutas'] as List<dynamic>;

    // Direcciones que, al comprobarlas el 2026-09-30, no respondieron.
    const caidos = {
      'mederi.buap.mx',
      'webserver.siiaa.siu.buap.mx',
      'autoservicios.buap.mx',
      'des.buap.mx',
    };

    var conUrl = 0;
    for (final r in rutas.cast<Map<String, dynamic>>()) {
      for (final n in (r['niveles'] as List).cast<Map<String, dynamic>>()) {
        final docs =
            (n['documentos'] as List? ?? const <dynamic>[])
                .cast<Map<String, dynamic>>();
        for (final doc in docs) {
          final url = doc['url'] as String? ?? '';
          if (!url.startsWith('http')) continue;
          conUrl++;
          final caido = caidos.any(url.contains);
          final declarado = (doc['estadoEnlace'] as String? ?? '').isNotEmpty;
          if (caido) {
            expect(declarado, isTrue,
                reason: '${r['id']} · nivel ${n['numero']} · '
                    '«${doc['nombre']}» apunta a $url, que no responde, y no lo '
                    'advierte');
          } else {
            expect(declarado, isFalse,
                reason: '${r['id']} · nivel ${n['numero']} · '
                    '«${doc['nombre']}» se declara no verificado pero $url sí '
                    'respondió: sobra una advertencia que ya no es cierta');
          }
        }
      }
    }
    expect(conUrl, greaterThan(10), reason: 'no se revisó ningún documento');
  });

  test('el modelo lee el estado del enlace y sabe decir si sirve', () {
    // Si el JSON declara y la pantalla no muestra, el aviso no existe para el
    // alumno: por eso el dato tiene que entrar al modelo.
    final caido = DocumentoRequisito.fromJson({
      'nombre': 'Comprobante de la encuesta a egresados',
      'url': 'https://webserver.siiaa.siu.buap.mx/egresados/registro.solicitud',
      'estadoEnlace': 'no_verificado',
      'notaEnlace': 'Verificado el 2026-09-30: el servidor no responde.',
    });
    expect(caido.estadoEnlace, 'no_verificado');
    expect(caido.enlaceVerificado, isFalse);
    expect(caido.avisoEnlace, contains('no responde'));

    final vivo = DocumentoRequisito.fromJson({
      'nombre': 'Acta de nacimiento',
      'url': 'https://secretacademica.cs.buap.mx/acta.pdf',
    });
    expect(vivo.enlaceVerificado, isTrue);
    expect(vivo.avisoEnlace, isEmpty);
  });

  test('los enlaces de links.json también declaran su estado en el modelo', () {
    // Los mismos dos enlaces caídos viven en `links.json`, que se pintaba
    // entero sin mirar el estado: el alumno los veía como si funcionaran.
    final enlaces =
        (json.decode(
              File('assets/json/links.json').readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['links'] as List<dynamic>;

    final modelo = enlaces
        .cast<Map<String, dynamic>>()
        .map(LinkBuap.fromJson)
        .toList();

    final caidos = modelo.where((l) => !l.enlaceVerificado).toList();
    expect(caidos, isNotEmpty, reason: 'debería haber enlaces sin comprobar');
    for (final l in caidos) {
      expect(l.avisoEnlace, isNotEmpty,
          reason: '${l.titulo} se declara no verificado y no dice por qué');
      expect(l.url, isNotEmpty, reason: 'declarar un enlace sin URL no aplica');
    }
    // Y los que sí respondieron no pueden venir marcados.
    for (final l in modelo.where((l) => l.url.isNotEmpty)) {
      if (caidos.any((c) => c.url == l.url)) continue;
      expect(l.estadoEnlace, isEmpty,
          reason: '${l.titulo} se marca ${l.estadoEnlace} sin comprobación');
    }
  });

  test('la nota de mapa y la fuente de particularidades llegan a la pantalla', () {
    // `mapaNota` dice cuándo el fondo **no** es arte de la BUAP y
    // `fuenteDeParticularidades` de dónde salen los requisitos por unidad.
    // Ambos se descartaban al leer el JSON.
    final rutas =
        (json.decode(
              File('assets/json/routes.json').readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['rutas'] as List<dynamic>;

    var notas = 0;
    var fuentes = 0;
    for (final raw in rutas.cast<Map<String, dynamic>>()) {
      final ruta = Ruta.fromJson(raw);
      if (raw['mapaNota'] != null) {
        expect(ruta.mapaNota, isNotEmpty,
            reason: '${ruta.id} declara mapaNota y el modelo la pierde');
        notas++;
      }
      if (raw['fuenteDeParticularidades'] != null) {
        expect(ruta.fuenteDeParticularidades, isNotEmpty,
            reason: '${ruta.id} declara la fuente de sus particularidades y '
                'el modelo la pierde');
        fuentes++;
      }
    }
    expect(notas, greaterThan(0), reason: 'nunca hubo notas de mapa');
    expect(fuentes, greaterThan(0), reason: 'nunca hubo fuente declarada');
  });

  test('los requisitos que publica la unidad llegan a la modalidad', () {    // `particularidadesPorUnidad` se armaba y se cargaba en
    // `RutaOferta.particularidad`, pero ninguna pantalla lo mostraba.
    final rutas =
        (json.decode(
              File('assets/json/routes.json').readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['rutas'] as List<dynamic>;

    var total = 0;
    var conDetalle = 0;
    for (final raw in rutas.cast<Map<String, dynamic>>()) {
      final ruta = Ruta.fromJson(raw);
      for (final p in ruta.particularidades) {
        total++;
        if (p.detalle.isEmpty) continue;
        conDetalle++;
        // Lo que la unidad publica tiene que poder citarse: sin fuente, el
        // bloque nuevo sería una afirmación sin respaldo.
        expect(p.fuente.isNotEmpty || p.fecha.isNotEmpty, isTrue,
            reason: '${ruta.id} · ${p.nombreEnUnidad}: detalle sin fuente '
                'ni fecha');
      }
    }
    expect(total, greaterThan(50), reason: 'faltan particularidades');
    expect(conDetalle, greaterThan(20),
        reason: 'prácticamente ningún requisito de unidad tiene detalle');
  });

  test('toda búsqueda documentada aparece en el catálogo que la app lee', () {
    // `facultades.json → rastroBusqueda` y `catalogo_modalidades.json →
    // fuentesConsulta` son el mismo rastro en dos archivos. Cuatro unidades
    // (FENF, FESTO, FFL, FIQ) solo lo tenían en el primero, así que la app
    // decía «modalidades sin fuente registrada» sin decir dónde buscó.
    final unidades =
        (json.decode(
              File('assets/json/catalogo_modalidades.json')
                  .readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['unidades'] as List<dynamic>;
    final facultades =
        (json.decode(
              File('assets/json/facultades.json')
                  .readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['facultades'] as List<dynamic>;

    final cat = <String, Set<String?>>{};
    for (final u in unidades.cast<Map<String, dynamic>>()) {
      cat['${u['clave']}'] = {
        for (final r
            in (u['fuentesConsulta'] as List? ?? const <dynamic>[]).cast<Map<String, dynamic>>())
          r['url'] as String?,
      };
    }

    var revisadas = 0;
    for (final f in facultades.cast<Map<String, dynamic>>()) {
      final enCatalogo = cat['${f['clave']}'];
      if (enCatalogo == null) continue;
      for (final r
          in (f['rastroBusqueda'] as List? ?? const <dynamic>[]).cast<Map<String, dynamic>>()) {
        revisadas++;
        expect(
          enCatalogo.contains(r['url'] as String?),
          isTrue,
          reason:
              '${f['clave']} buscó en ${r['url']} y el catálogo que lee la app '
              'no lo tiene: ese rastro no se le mostraría al alumno',
        );
      }
    }
    expect(revisadas, greaterThan(60), reason: 'se esperaba el rastro completo');
  });

  test('una modalidad «tesina» en la ruta de tesis lo advierte', () {
    // En el Reglamento la tesis (art. 7 fr. I) y la tesina (art. 7 fr. VII)
    // son procesos distintos: protocolo, jurado y defensa contra una
    // asignatura optativa con créditos. Nueve modalidades se llaman «tesina» y
    // el catálogo las encamina a la ruta de tesis. Cambiar el mapeo sin
    // comprobar cada unidad sería inventar, así que se exige que la app lo
    // diga y que la advertencia exista para todas.
    final unidades =
        (json.decode(
              File('assets/json/catalogo_modalidades.json')
                  .readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['unidades'] as List<dynamic>;

    var tesinas = 0;
    var jugables = 0;
    for (final u in unidades.cast<Map<String, dynamic>>()) {
      for (final m in (u['modalidades'] as List? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()) {
        final mod = ModalidadUnidad.fromJson(
          m,
          unidadClave: '${u['clave']}',
          unidadNombre: '${u['nombreOficial']}',
        );
        if (!mod.tesinaEnRutaDeTesis) continue;
        tesinas++;
        if (mod.seleccionable) jugables++;
      }
    }
    expect(tesinas, greaterThan(0),
        reason: 'ninguna modalidad «tesina» cae en la ruta de tesis');
    // Si alguien corrigiera el mapeo en el JSON, el contador bajaría y esta
    // prueba avisaría de que la advertencia ya no se necesita.
    expect(jugables, greaterThan(0),
        reason: 'ninguna «tesina» con la advertencia llega a ser jugable');
  });

  test('la cita oficial de la unidad no se pierde al leer el JSON', () {
    // Diez de las 114 particularidades traen `citaFuente` (el artículo, la
    // convocatoria o el PDF concreto) y el modelo la descartaba.
    final rutas =
        (json.decode(
              File('assets/json/routes.json').readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['rutas'] as List<dynamic>;

    var declaradas = 0;
    var conservadas = 0;
    for (final raw in rutas.cast<Map<String, dynamic>>()) {
      for (final q in (raw['particularidadesPorUnidad'] as List? ??
              const <dynamic>[])
          .cast<Map<String, dynamic>>()) {
        if ((q['citaFuente'] as String? ?? '').isEmpty) continue;
        declaradas++;
        final p = ParticularidadUnidad.fromJson(q);
        if (p.citaFuente.isNotEmpty) conservadas++;
      }
    }
    expect(declaradas, greaterThan(0), reason: 'ninguna trae cita');
    expect(conservadas, declaradas,
        reason: 'hay citas que el modelo deja de guardar');
  });

  test('el rastro de búsqueda declara los enlaces que no respondieron', () {
    // Sin esto, «no encontramos catálogo aquí» aparenta una comprobación que
    // en esos dos casos no ocurrió: la página no cargó.
    final unidades =
        (json.decode(
              File('assets/json/catalogo_modalidades.json')
                  .readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['unidades'] as List<dynamic>;

    var noVerificados = 0;
    for (final u in unidades.cast<Map<String, dynamic>>()) {
      for (final f in (u['fuentesConsulta'] as List? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()) {
        if ((f['estadoEnlace'] as String? ?? '').isEmpty) continue;
        noVerificados++;
        final r = RastroConsulta.fromJson(f);
        expect(r.estadoEnlace, isNotEmpty,
            reason: '${u['clave']}: el rastro pierde el estado del enlace');
        expect(r.avisoEnlace, isNotEmpty,
            reason: '${u['clave']}: estado sin explicación');
      }
    }
    expect(noVerificados, greaterThan(0),
        reason: 'no hay rastros con enlace sin comprobar');
  });

  test('la unidad dice de dónde sale su catálogo y advierte si es parcial', () {
    // `fuenteCatalogo` (21 unidades) y `salvedad` (15) se leían del JSON y no
    // llegaban al modelo: «publicado» salía sin poder comprobarse.
    final facultades =
        (json.decode(
              File('assets/json/facultades.json').readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>)['facultades'] as List<dynamic>;

    var conFuente = 0;
    var conSalvedad = 0;
    for (final raw in facultades.cast<Map<String, dynamic>>()) {
      final f = Facultad.fromJson(raw);
      if (raw['fuenteCatalogo'] != null) {
        expect(f.fuenteCatalogo, isNotEmpty,
            reason: '${f.clave} declara fuenteCatalogo y el modelo la pierde');
        for (final u in f.fuenteCatalogo) {
          expect(u.startsWith('http'), isTrue,
              reason: '${f.clave}: fuente de catálogo «$u» no es una URL');
        }
        conFuente++;
      }
      // Trece unidades traen `salvedad` como cadena vacía: no advierten nada.
      // Solo cuenta la que trae texto de verdad.
      if ((raw['salvedad'] as String? ?? '').trim().isNotEmpty) {
        expect(f.salvedad.trim(), isNotEmpty,
            reason: '${f.clave} declara salvedad con texto y el modelo la pierde');
        conSalvedad++;
      }
    }
    expect(conFuente, greaterThan(15), reason: 'faltan fuentes de catálogo');
    expect(conSalvedad, greaterThan(10), reason: 'faltan salvedades');
  });
}
