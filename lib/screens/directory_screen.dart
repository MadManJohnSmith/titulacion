import 'package:flutter/material.dart';

import '../services/staff_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Búsqueda en el directorio de trabajadores de la BUAP.
///
/// La base no tiene la unidad académica de cada persona, así que esto **no**
/// filtra por facultad: es un buscador general de la universidad.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _ctrl = TextEditingController();
  final _repo = StaffRepository.instance;

  List<Trabajador> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final q = _ctrl.text.trim();
    if (q.length < 3) {
      setState(() {
        _resultados = const [];
        _buscado = false;
      });
      return;
    }
    setState(() {
      _buscando = true;
      _buscado = false;
    });
    final r = await _repo.buscar(q);
    if (!mounted) return;
    setState(() {
      _resultados = r;
      _buscando = false;
      _buscado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directorio BUAP')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nombre o matrícula',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'El directorio no indica la unidad académica de cada persona, así '
              'que la búsqueda es de toda la universidad.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_ctrl.text.trim().length < 3) {
      return const Center(
        child: Text(
          'Escribe al menos 3 letras',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    if (_buscando) return const SizedBox();
    if (_resultados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _buscado
                ? 'Sin resultados para "${_ctrl.text.trim()}".'
                : '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _resultados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = _resultados[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: LoboColors.steelBlue,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Matrícula ${t.matricula}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (t.tieneCorreo)
                IconButton(
                  tooltip: 'Escribir a ${t.nombre}',
                  onPressed: () => abrirUrl(context, 'mailto:${t.correo}'),
                  icon: const Icon(Icons.mail_outline, color: LoboColors.gold),
                ),
            ],
          ),
        );
      },
    );
  }
}
