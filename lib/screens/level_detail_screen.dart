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
          // Fondo del nivel; si no hay, el gradiente de la app.
          Positioned.fill(
            child: nivel.fondo.isEmpty
                ? Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [LoboColors.steelBlue, LoboColors.deepBlue],
                      ),
                    ),
                  )
                : Image.asset(
                    nivel.fondo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [LoboColors.steelBlue, LoboColors.deepBlue],
                        ),
                      ),
                    ),
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
        color: marcado
            ? LoboColors.gold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _state.alternarDocumento(widget.ruta.id, widget.nivel.numero, indice);
          }),
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
                          decoration: marcado
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
                      if (doc.url != null && doc.url!.isNotEmpty)
                        InkWell(
                          onTap: () => abrirUrl(context, doc.url!),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Ver más',
                              style: TextStyle(
                                color: LoboColors.gold.withValues(alpha: 0.9),
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
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
