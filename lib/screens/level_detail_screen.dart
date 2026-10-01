import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'map_screen.dart';

/// La pantalla de un nivel: fondo, mascota, pasos y documentos.
class LevelDetailScreen extends StatefulWidget {
  const LevelDetailScreen({
    super.key,
    required this.ruta,
    required this.nivel,
    required this.state,
  });

  final Ruta ruta;
  final Nivel nivel;
  final AppState state;

  @override
  State<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<LevelDetailScreen> {
  late final AppState _state = widget.state;

  @override
  Widget build(BuildContext context) {
    final nivel = widget.nivel;
    final ruta = widget.ruta;
    final completado = _state.estaCompletado(ruta.id, nivel.numero);
    final totalDocs = nivel.documentos.length;
    final marcadosPorDoc = List.generate(
      totalDocs,
      (i) => _state.documentoMarcado(ruta.id, nivel.numero, i),
    );
    final marcados = marcadosPorDoc.where((b) => b).length;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo del nivel. `Image.asset` no sabe decodificar SVG: los doce
          // fondos que el diseño entrega como `.svg` caían siempre al
          // `errorBuilder` y el alumno veía el degradote en vez del dibujo.
          // `AssetImageSafe` va con `SvgPicture.asset`, y el degradado queda
          // **debajo** para el caso de que el archivo falte de verdad.
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _FondoDeNivel(),
                if (nivel.fondo.isNotEmpty)
                  AssetImageSafe(
                    nivel.fondo,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.wallpaper_outlined,
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    LoboColors.navy.withValues(alpha: 0.65),
                    LoboColors.navy.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, completado),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _buildMascota(),
                      const SizedBox(height: 16),
                      _buildDescripcion(),
                      if (nivel.pasos.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSeccion('Cómo hacerlo', Icons.map_outlined),
                        ...nivel.pasos.asMap().entries.map(
                          (e) => _buildPaso(e.key + 1, e.value),
                        ),
                      ],
                      if (nivel.documentos.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSeccion(
                          'Documentos ($marcados/$totalDocs)',
                          Icons.folder_outlined,
                        ),
                        ...nivel.documentos.asMap().entries.map(
                          (e) => _buildDocumento(
                            e.key,
                            e.value,
                            marcadosPorDoc[e.key],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      _buildBotonCompletar(completado, totalDocs, marcados),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool completado) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Volver al mapa',
        ),
// Aquí el número va en texto porque el icono del nivel no se dibuja en
        // esta pantalla: lo que se ve es la mascota. El SVG `nivel_N.svg` sí
        // trae la cifra, y por eso en «Tu ruta» —donde ese icono sí aparece— el
        // número no se repite. Aquí no hay con qué repetirlo, y quitarlo dejaba
        // al alumno sin saber en qué nivel está.
        Expanded(
          child: Center(
            child: Text(
              'Nivel ${widget.nivel.numero}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        if (completado)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.check_circle, color: LoboColors.gold, size: 24),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildMascota() {
    if (widget.nivel.mascota.isEmpty) return const SizedBox.shrink();
    return Center(
      child: AssetImageSafe(
        widget.nivel.mascota,
        height: 150,
        fallbackIcon: Icons.pets,
      ),
    );
  }

  Widget _buildDescripcion() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LoboColors.parchment,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.nivel.titulo.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Bungee',
              fontSize: 17,
              height: 1.2,
              letterSpacing: 0.5,
              color: LoboColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: LoboColors.teal, thickness: 2),
          const SizedBox(height: 12),
          Text(
            widget.nivel.descripcion,
            textAlign: TextAlign.center,
            style: loboCuerpo.copyWith(
              fontSize: 16,
              height: 1.55,
              color: LoboColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion(String titulo, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icono, color: LoboColors.gold, size: 20),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaso(int numero, Paso paso) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: LoboColors.gold,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$numero',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: LoboColors.deepBlue,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paso.titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                if (paso.detalle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      paso.detalle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumento(int indice, DocumentoRequisito doc, bool marcado) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color:
            marcado
                ? LoboColors.gold.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // Tocar la fila abre el documento oficial solo cuando el enlace se
            // comprobó; si está caído, la fila sigue sirviendo para marcar el
            // documento y el botón explica que hay que reintentar más tarde.
            if (doc.enlaceVerificado) {
              await abrirUrl(context, doc.url!);
              return;
            }
            // Primero se espera la escritura y después se repinta: la casilla
            // que ve el alumno ya está en el disco cuando la muestra marcada.
            await _state.alternarDocumento(
              widget.ruta.id,
              widget.nivel.numero,
              indice,
            );
            if (!mounted) return;
            setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  marcado ? Icons.check_box : Icons.check_box_outline_blank,
                  color: marcado ? LoboColors.gold : Colors.white54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.nombre,
                        style: TextStyle(
                          color: marcado ? Colors.white70 : Colors.white,
                          fontSize: 15,
                          decoration:
                              marcado
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                          decorationColor: Colors.white54,
                        ),
                      ),
                      if (doc.nota.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            doc.nota,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      if (doc.sinEnlace.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            doc.sinEnlace,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              height: 1.35,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      if (doc.url != null && doc.url!.startsWith('http'))
                        // Botón propio: si dependiera solo del onTap de la fila,
                        // el enlace quedaba indistinguible de marcar la casilla.
                        // El aviso va **encima**: si el servidor está caído, el
                        // botón sigue sirviendo —el trámite es real y el alumno
                        // lo tiene que hacer—, pero no puede parecer que un
                        // enlace que no responde es lo mismo que uno vivo.
                        if (doc.estadoEnlace.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: LoboColors.gold.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: LoboColors.gold.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 15,
                                    color: LoboColors.gold,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'El enlace no se pudo comprobar. '
                                      '${doc.avisoEnlace}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => abrirUrl(context, doc.url!),
                            icon: const Icon(Icons.open_in_new, size: 15),
                            // Un enlace sin comprobar no puede salir con el
                            // mismo rótulo que uno vivo: el botón sigue ahí
                            // porque el trámite es real y el servidor puede
                            // volver, pero el alumno tiene que saber que va
                            // a ciegas.
                            label: Text(
                              doc.enlaceVerificado
                                  ? 'Abrir documento oficial'
                                  : 'Reintentar el enlace',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LoboColors.gold,
                              side: BorderSide(
                                color: LoboColors.gold.withValues(alpha: 0.6),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      // De dónde sale el dato y de cuándo: sin esto el requisito
                      // es una afirmación sin respaldo.
                      if (doc.fuente.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            doc.fecha.isEmpty
                                ? 'Fuente: ${doc.fuente}'
                                : 'Fuente: ${doc.fuente} · ${doc.fecha}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotonCompletar(bool completado, int totalDocs, int marcados) {
    if (completado) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LoboColors.gold.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: LoboColors.gold),
            SizedBox(width: 10),
            Text(
              'Nivel completado',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: LoboColors.gold,
        foregroundColor: LoboColors.deepBlue,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        await _state.completarNivel(widget.ruta.id, widget.nivel.numero);
        if (!mounted) return;
        final faltan = totalDocs - marcados;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              faltan > 0
                  ? '¡Nivel completado! Te faltan $faltan documentos por marcar, pero puedes avanzar.'
                  : '¡Nivel completado con todos tus documentos!',
            ),
          ),
        );
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => MapScreen(ruta: widget.ruta, state: _state),
          ),
        );
      },
      child: Text(
        totalDocs > marcados
            ? 'Completar nivel (faltan ${totalDocs - marcados} docs)'
            : 'Completar nivel',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

/// El degradado de respaldo del fondo del nivel. Va siempre debajo del SVG
/// para que un asset faltante no deje un hueco negro.
class _FondoDeNivel extends StatelessWidget {
  const _FondoDeNivel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LoboColors.steelBlue, LoboColors.deepBlue],
        ),
      ),
    );
  }
}
