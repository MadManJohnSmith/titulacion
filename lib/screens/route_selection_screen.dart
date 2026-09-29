import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'contacts_screen.dart';
import 'map_screen.dart';

/// Pantalla de la modalidad elegida: el pergamino de la ruta, lo que exige la
/// unidad y de dónde sale cada dato.
///
/// Recibe el [OfertaUnidad] completo, que es la lista **ya filtrada por la
/// unidad académica del alumno**. Nunca se consulta una lista global de rutas:
/// lo que esta unidad publica es lo que hay, y lo que no publica no se
/// rellena con rutas genéricas.
class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({
    super.key,
    required this.oferta,
    required this.state,
    required this.repository,
    this.ruta,
  });

  /// La oferta de la unidad del alumno.
  final OfertaUnidad oferta;

  final AppState state;
  final ContentRepository repository;

  /// La modalidad que se está viendo. `null` muestra el estado vacío: la
  /// unidad no publica catálogo, o todavía no se ha elegido ninguna.
  final RutaOferta? ruta;

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  OfertaUnidad get oferta => widget.oferta;
  AppState get state => widget.state;
  ContentRepository get repository => widget.repository;
  RutaOferta? get ruta => widget.ruta;

  @override
  Widget build(BuildContext context) {
    final r = ruta;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _Fondo()),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Volver',
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                Expanded(
                  child:
                      r == null
                          ? _EstadoVacio(oferta: oferta, state: state)
                          : _detalle(context, r),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detalle(BuildContext context, RutaOferta ofertaRuta) {
    final ruta = ofertaRuta.ruta.ruta;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        children: [
          const SizedBox(height: 4),
          _pergamino(ruta, ofertaRuta),
          const SizedBox(height: 14),
          _niveles(ruta),
          const SizedBox(height: 18),
          _requisitos(ofertaRuta),
          const SizedBox(height: 14),
          _fuentes(ofertaRuta),
          const SizedBox(height: 22),
          CloudButton(
            label: 'Ver mapa',
            onTap: () => _irAlMapa(context, ofertaRuta),
          ),
          const SizedBox(height: 12),
          Text(
            'Fuente: ${ofertaRuta.ruta.citaFuente.isEmpty ? 'sin fuente registrada' : ofertaRuta.ruta.citaFuente}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// El pergamino: si el diseño trae el SVG del marco se usa de fondo, y el
  /// título y la descripción usan los SVG del diseño cuando existen. Si no,
  /// cae a texto real, que sí se puede leer con lector de pantalla.
  Widget _pergamino(Ruta ruta, RutaOferta ofertaRuta) {
    final titulo =
        ruta.tituloAsset.isNotEmpty
            ? AssetImageSafe(ruta.tituloAsset, height: 54, width: 220)
            : Text(
              ruta.nombre.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Bungee',
                fontSize: 18,
                height: 1.2,
                letterSpacing: 0.5,
                color: LoboColors.ink,
              ),
            );

    final descripcion =
        ruta.descripcionAsset.isNotEmpty
            ? AssetImageSafe(ruta.descripcionAsset, height: 70, width: 260)
            : Text(
              ruta.descripcion,
              textAlign: TextAlign.center,
              style: loboCuerpo.copyWith(
                fontSize: 16,
                height: 1.55,
                color: LoboColors.ink,
              ),
            );

    // El pergamino del diseño va **detrás** del texto, no en vez de él: los
    // SVG de marco son ilustración, y el título y la descripción tienen que
    // seguir siendo texto real para que se puedan leer y traducir.
    return Stack(
      alignment: Alignment.center,
      children: [
        if (ruta.pergaminoInicio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AssetImageSafe(
              ruta.pergaminoInicio,
              height: 470,
              width: double.infinity,
              fallbackIcon: Icons.description_outlined,
            ),
          ),
        // Fondo de lectura: el pergamino siempre es legible, se dibuje el SVG
        // del diseño o no. Si el archivo falta o no se puede pintar, el texto
        // no queda sobre un hueco.
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 26),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: LoboColors.parchment,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              titulo,
              const SizedBox(height: 14),
              const Divider(color: LoboColors.teal, thickness: 2),
              const SizedBox(height: 14),
              descripcion,
              if (ofertaRuta.modalidad?.nombreArticulo7 != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Artículo 7: ${ofertaRuta.modalidad!.nombreArticulo7}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: LoboColors.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Los iconos de nivel que trae el diseño, con su número.
  ///
  /// Los usa el mapa como islas; aquí anticipan cuántos son y cómo se llaman.
  Widget _niveles(Ruta ruta) {
    final niveles = ruta.nivelesJugables;
    if (niveles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tu ruta',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: niveles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final n = niveles[i];
              return SizedBox(
                width: 64,
                child: Column(
                  children: [
                    AssetImageSafe(
                      n.icono,
                      height: 46,
                      width: 46,
                      fallbackIcon: Icons.flag_outlined,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${n.numero}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      n.titulo,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Requisitos legibles por máquina: cada campo con su valor o, si la unidad
  /// no lo publica, con "no publicado". Nunca se rellena un hueco.
  Widget _requisitos(RutaOferta ofertaRuta) {
    final req = ofertaRuta.requisitos;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule, color: LoboColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Requisitos de ${ofertaRuta.modalidad?.unidadNombre ?? 'la ruta'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final fila in req.filas)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 170,
                    child: Text(
                      fila.etiqueta,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      fila.conocido ? fila.valor : 'no publicado',
                      style: TextStyle(
                        color: fila.conocido ? Colors.white : Colors.white38,
                        fontSize: 13,
                        fontWeight:
                            fila.conocido ? FontWeight.w600 : FontWeight.normal,
                        fontStyle:
                            fila.conocido ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (req.nota.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              req.nota,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// De dónde sale lo que se está viendo, con su fecha.
  Widget _fuentes(RutaOferta ofertaRuta) {
    final fuentes = ofertaRuta.ruta.fuentes;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                color: LoboColors.gold,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Fuente',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (fuentes.isEmpty)
            Text(
              ofertaRuta.ruta.rutaBase.notaFuente.isEmpty
                  ? 'Esta ruta viene del contenido heredado de la app y esta '
                      'revisión no le verificó una fuente oficial.'
                  : ofertaRuta.ruta.rutaBase.notaFuente,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
            )
          else
            for (final f in fuentes)
              if (f.esAcreditable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.etiqueta,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _abrir(f.url),
                        child: Text(
                          f.url,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LoboColors.gold,
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          if (ofertaRuta.ruta.rutaBase.alcance.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ofertaRuta.ruta.rutaBase.alcance,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 4),
          _contenido(context),
        ],
      ),
    );
  }

  /// De dónde salió el catálogo y un botón para intentar actualizarlo.
  ///
  /// Mientras la app no tenga un host de publicación con firma confiable, el
  /// botón responde por qué no actualiza: el catálogo embebido manda y el
  /// alumno no se queda con la duda de si lo que ve está al día.
  Widget _contenido(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _cargaCatalogo(),
      builder: (context, snapshot) {
        final datos = snapshot.data;
        final origen = datos is String ? datos : '…';
        return Row(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white38,
              size: 14,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Catálogo: $origen',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: () => _actualizar(context),
              child: const Text(
                'Actualizar',
                style: TextStyle(fontSize: 11, color: LoboColors.gold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _cargaCatalogo() async {
    final c = await repository.catalogo();
    return '${c.catalogoVersion.isEmpty ? 'sin versión' : c.catalogoVersion} · '
        '${c.origen} · corte ${c.fechaCorte}';
  }

  Future<void> _actualizar(BuildContext context) async {
    final r = await repository.actualizarDesdeWeb();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.motivo.isEmpty
              ? 'El catálogo sigue en la versión ${r.version.isEmpty ? "instalada" : r.version}.'
              : r.motivo,
        ),
      ),
    );
    if (r.cambioInstalado && context.mounted) {
      setState(() {});
    }
  }

  void _abrir(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Entra al mapa. Si el alumno traía avance de la ruta base, se le pregunta
  /// una vez si quiere llevarlo a esta modalidad: no se copia a sus espaldas.
  Future<void> _irAlMapa(BuildContext context, RutaOferta ofertaRuta) async {
    final id = ofertaRuta.id;
    final modalidad = ofertaRuta.idModalidad;
    final base = ofertaRuta.rutaBaseId;

    if (modalidad.isNotEmpty) {
      await state.elegirModalidad(modalidad, base);
    } else {
      await state.elegirRuta(id);
    }

    if (!context.mounted) return;
    final migrar = state.migracionDisponible(id, base);
    if (migrar) {
      final niveles = state.nivelesAMigrar(base);
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: LoboColors.deepBlue,
              title: const Text('¿Traer tu avance anterior?'),
              content: Text(
                'Venías de la ruta "$base" con $niveles nivel(es) completados. '
                'Esta modalidad es de tu unidad y se guarda aparte.\n\n'
                'Si quieres, copiamos ese avance a esta modalidad. '
                'El original no se borra.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Empezar de cero'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Traer mi avance'),
                ),
              ],
            ),
      );
      if (ok == true) {
        await state.migrarProgreso(id, base);
      }
    }

    if (!context.mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(ruta: ofertaRuta.ruta.ruta, state: state),
      ),
    );
  }
}

class _Fondo extends StatelessWidget {
  const _Fondo();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LoboColors.steelBlue, LoboColors.navy],
        ),
      ),
    );
  }
}

/// Cuando la unidad no ofrece nada: nunca una pantalla vacía. Se explica qué
/// se buscó, dónde se buscó y a quién escribirle.
class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.oferta, required this.state});

  final OfertaUnidad oferta;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: LoboColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LoboColors.gold.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.search_off, color: LoboColors.gold, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta unidad no publica catálogo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${oferta.nombre}\n\n${oferta.mensajeSinCatalogo}',
                style: loboCuerpo.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (oferta.informativas.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Lo que sí aparece en el registro de evidencia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          for (final m in oferta.informativas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.motivo,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (m.fuente.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        m.fecha.isEmpty ? m.fuente : '${m.fuente}\n${m.fecha}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        if (oferta.rastro.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Dónde se buscó',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          for (final r in oferta.rastro)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.url,
                    style: const TextStyle(
                      color: LoboColors.gold,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  Text(
                    '${r.resultado}${r.consultadoEn.isEmpty ? '' : ' · consultado ${r.consultadoEn}'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 20),
        _contacto(context),
      ],
    );
  }

  Widget _contacto(BuildContext context) {
    final c = oferta.contacto;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirma con tu unidad',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (c.coordinacion.isNotEmpty)
            Text(
              c.coordinacion,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          if (c.correo.isNotEmpty)
            Text(
              c.correo,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          if (c.telefono.isNotEmpty)
            Text(
              c.telefono,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          if (c.notas.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              c.notas,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactsScreen(state: state),
                  ),
                ),
            icon: const Icon(Icons.support_agent, size: 18),
            label: const Text('Ver contactos de la BUAP'),
          ),
        ],
      ),
    );
  }
}
