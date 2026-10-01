import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// El directorio oficial de una unidad académica.
///
/// Muestra a quién puede acudir el alumno, con el puesto que publica la
/// unidad y dónde encontrarlo. Los campos que la unidad no publica no se
/// rellenan: se omiten, porque un cubículo o un correo inventados hacen que
/// el alumno vaya a un lugar donde no hay nadie.
class DirectorioUnidadScreen extends StatefulWidget {
  const DirectorioUnidadScreen({
    super.key,
    required this.facultad,
  });

  final Facultad facultad;

  @override
  State<DirectorioUnidadScreen> createState() =>
      _DirectorioUnidadScreenState();
}

class _DirectorioUnidadScreenState extends State<DirectorioUnidadScreen> {
  String _filtro = '';

  List<PersonaDirectorio> get _personas =>
      widget.facultad.personasDirectorio;

  List<PersonaDirectorio> get _visibles {
    final q = DirectorioUnidad.buscarEn(_personas, _filtro);
    return q;
  }

  @override
  Widget build(BuildContext context) {
    final personas = _personas;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Directorio de la unidad'),
        backgroundColor: LoboColors.navy,
        foregroundColor: Colors.white,
      ),
      body: personas.isEmpty
          ? _sinDirectorio(context)
          : Column(
              children: [
                _buscador(context),
                _fuente(),
                Expanded(
                  child: _visibles.isEmpty
                      ? const Center(
                          child: Text(
                            'Nadie coincide con esa búsqueda.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _visibles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _tarjeta(context, _visibles[i]),
                        ),
                ),
              ],
            ),
    );
  }

  /// De dónde sale el directorio y de cuándo.
  ///
  /// Un cubículo y un correo se copian de una página que puede cambiar; sin la
  /// fuente, un dato equivado es indistinguible de uno bueno y el alumno va a
  /// buscar a una oficina donde no hay nadie.
  Widget _fuente() {
    final d = widget.facultad.directorio;
    if (d.cita.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.description_outlined, size: 13, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              d.cita,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buscador(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        onChanged: (v) => setState(() => _filtro = v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Busca por nombre, puesto o cubículo',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(BuildContext context, PersonaDirectorio p) {
    return Card(
      color: LoboColors.navy.withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.nombre,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (p.tienePuesto) ...[
              const SizedBox(height: 4),
              Text(
                p.puesto!,
                style: const TextStyle(color: LoboColors.gold, fontSize: 13),
              ),
            ],
            // Dónde encontrarlo: es el dato que el alumno no tenía antes.
            if (p.tieneUbicacion) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 15, color: Colors.white70),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.ubicacion!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // El `Wrap` reparte sus hijos en varias líneas, pero a cada uno lo
            // mide sin límite de ancho: un correo largo se salía de la tarjeta
            // en vez de bajar de línea. Por eso cada acción se acota al ancho
            // disponible antes de medir su texto.
            LayoutBuilder(
              builder: (context, limites) => Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (p.correo != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: limites.maxWidth),
                      child: _accion(
                        Icons.mail_outline,
                        p.correo!,
                        () => abrirUrl(context, 'mailto:${p.correo}'),
                      ),
                    ),
                  if (p.telefono != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: limites.maxWidth),
                      child: _accion(
                        Icons.phone_outlined,
                        p.telefono!,
                        () => abrirUrl(context, 'tel:${p.telefono}'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accion(IconData icono, String texto, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: Colors.white70),
            const SizedBox(width: 5),
            // `Flexible` para que el correo baje de línea en vez de empujar la
            // fila; con `maxLines: 1` y puntos suspensivos, un correo más largo
            // que la tarjeta se recorta sin desbordar.
            Flexible(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sinDirectorio(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.groups_outlined, size: 46, color: Colors.white54),
          const SizedBox(height: 14),
          Text(
            '${widget.facultad.nombre} no publica un directorio en su sitio '
            'oficial, así que aquí no hay nombres.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          if (widget.facultad.correo.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  abrirUrl(context, 'mailto:${widget.facultad.correo}'),
              icon: const Icon(Icons.mail_outline, size: 16),
              label: Text(widget.facultad.correo),
              style: OutlinedButton.styleFrom(
                foregroundColor: LoboColors.gold,
                side: BorderSide(color: LoboColors.gold.withValues(alpha: 0.6)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}