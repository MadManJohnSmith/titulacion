import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../services/student_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Registro del alumno: se busca en la base de la BUAP y se elige la facultad.
///
/// La base trae nombre y matrícula, pero **no la facultad**: la matrícula de la
/// BUAP no codifica la unidad académica, así que esa parte la elige la persona.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.state});

  final AppState state;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _buscador = TextEditingController();
  final _buscadorFocus = FocusNode();
  final _repo = ContentRepository.instance;
  final _alumnosRepo = StudentRepository.instance;
  final _digitos = DigitosMatricula();

  List<Facultad> _facultades = [];
  Alumno? _alumno;
  String? _facultad;
  bool _cargando = true;
  bool _buscando = false;
  String _error = '';
  String _pista = '';

  @override
  void initState() {
    super.initState();
    _cargar();
    _buscador.addListener(_alTocar);
  }

  @override
  void dispose() {
    _buscador.dispose();
    _buscadorFocus.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final facultades = await _repo.facultades();
      if (!mounted) return;
      setState(() {
        _facultades = facultades;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar la información: $e';
      });
    }
  }

  void _alTocar() {
    if (_error.isNotEmpty) setState(() => _error = '');
    final esMatricula = _digitos.esMatricula(_buscador.text.trim());
    setState(() => _pista = esMatricula ? 'Buscando por matrícula…' : '');
    if (esMatricula) {
      // La matrícula es exacta: buscamos en cuanto se complete.
      _buscar();
    } else if (_pista.isNotEmpty) {
      setState(() => _pista = '');
    }
  }

  Future<void> _buscar() async {
    final q = _buscador.text.trim();
    if (q.length < 3) {
      setState(() => _error = 'Escribe tu nombre o tu matrícula (9 dígitos).');
      return;
    }

    setState(() {
      _buscando = true;
      _error = '';
      _pista = '';
    });
    _buscadorFocus.unfocus();

    final limpio = _digitos.esMatricula(q)
        ? q
        : _digitos.normalizar(q);

    final encontrado = await _alumnosRepo.buscar(limpio);
    if (!mounted) return;
    setState(() {
      _buscando = false;
      if (encontrado == null) {
        _alumno = null;
        _error = limpio.length == 9
            ? 'La matrícula $limpio no está en la base de la BUAP. '
                'Revísala, o continúa como invitado.'
            : 'No encontramos "$q". Revisa cómo lo escribiste.';
      } else {
        _alumno = encontrado;
        _error = '';
      }
    });
  }

  Future<void> _continuar() async {
    if (_facultad == null) {
      setState(() => _error = 'Elige tu unidad académica para continuar.');
      return;
    }
    // Si no se encontró en la base, la persona entra como invitada: su
    // progreso se guarda igual en el dispositivo.
    final alumno = _alumno ??
        Alumno(nombre: '', matricula: '', facultad: _facultad);
    await widget.state.registrar(alumno, facultadClave: _facultad);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu cuenta'),
        leading: const SizedBox(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text(
              '¿Quién eres?',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Busca tu matrícula en la base de la BUAP para empezar tu camino '
              'a la titulación.',
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _buscador,
              focusNode: _buscadorFocus,
              textInputAction: TextInputAction.search,
              keyboardType: TextInputType.text,
              autocorrect: false,
              onSubmitted: (_) => _buscar(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Matrícula o nombre',
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
            if (_pista.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _pista,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
            if (_alumno != null) ...[
              const SizedBox(height: 16),
              _tarjetaAlumno(),
            ],
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            const Text(
              '¿De qué unidad académica vienes?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cada facultad tiene sus requisitos y sus contactos, así que te '
              'mostramos los de la tuya.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _facultad,
              isExpanded: true,
              dropdownColor: LoboColors.deepBlue,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _facultades
                  .map(
                    (f) => DropdownMenuItem(
                      value: f.clave,
                      child: Text(f.nombre, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _facultad = v),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LoboColors.gold,
                foregroundColor: LoboColors.deepBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _buscando ? null : _continuar,
              child: Text(
                _alumno == null ? 'Continuar como invitado' : 'Comenzar mi aventura',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Si no estás en la base todavía puedes entrar: tu progreso se '
              'guarda en este dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaAlumno() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LoboColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LoboColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: LoboColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _alumno!.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Matrícula ${_alumno!.matricula}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _buscador.clear();
              setState(() => _alumno = null);
            },
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Cambiar',
          ),
        ],
      ),
    );
  }
}
