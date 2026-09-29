import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Contactos y links de la BUAP. Muestra primero los de la facultad del alumno
/// y, si no los tiene publicados, cae al contacto general de la DAE.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _repo = ContentRepository.instance;
  List<Contacto> _contactos = [];
  List<LinkBuap> _links = [];
  Facultad? _facultad;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final resultados = await Future.wait([
      _repo.contactos(),
      _repo.links(),
      if (widget.state.facultadClave != null)
        _repo.facultadPorClave(widget.state.facultadClave!)
      else
        Future.value(null),
    ]);
    if (!mounted) return;
    setState(() {
      _contactos = resultados[0] as List<Contacto>;
      _links = resultados[1] as List<LinkBuap>;
      _facultad = resultados.length > 2 ? resultados[2] as Facultad? : null;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ayuda y contactos'),
          bottom: const TabBar(
            labelColor: LoboColors.gold,
            unselectedLabelColor: Colors.white70,
            indicatorColor: LoboColors.gold,
            tabs: [
              Tab(text: 'Contactos'),
              Tab(text: 'Links'),
            ],
          ),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [_buildContactos(), _buildLinks()],
              ),
      ),
    );
  }

  Widget _buildContactos() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_facultad != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, color: LoboColors.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _facultad!.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_facultad!.coordinacion.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _facultad!.coordinacion,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  if (_facultad!.responsable.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _facultad!.responsable,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_facultad!.correo.isNotEmpty)
                    _contactoFila(Icons.mail, _facultad!.correo,
                        mailto: _facultad!.correo)
                  else
                    const Text(
                      'Tu facultad no publica un correo de titulación propio. '
                      'Usa el contacto general de la BUAP de abajo.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  if (_facultad!.telefono.isNotEmpty)
                    _contactoFila(Icons.phone, _facultad!.telefono,
                        tel: _facultad!.telefono),
                  if (_facultad!.notas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _facultad!.notas,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Contacto general BUAP',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 10),
        ],
        ..._contactos.map((c) => _buildContactoCard(c)),
      ],
    );
  }

  Widget _contactoFila(IconData icono, String texto, {String? mailto, String? tel}) {
    return InkWell(
      onTap: () => abrirUrl(context, mailto ?? tel ?? texto),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icono, size: 18, color: LoboColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactoCard(Contacto c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (c.area.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  c.area,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
              const SizedBox(height: 10),
              if (c.telefono.isNotEmpty)
                _contactoFila(Icons.phone, c.telefono, tel: c.telefono),
              if (c.correo.isNotEmpty)
                _contactoFila(Icons.mail, c.correo, mailto: c.correo),
              if (c.redes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  c.redes,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinks() {
    final porCategoria = <String, List<LinkBuap>>{};
    for (final l in _links) {
      porCategoria.putIfAbsent(l.categoria, () => []).add(l);
    }
    final categorias = porCategoria.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: categorias.map((cat) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                cat,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: LoboColors.gold,
                ),
              ),
            ),
            ...porCategoria[cat]!.map(
              (l) => LinkTile(titulo: l.titulo, url: l.url),
            ),
            const Divider(color: Colors.white24, height: 24),
          ],
        );
      }).toList(),
    );
  }
}
