import 'package:flutter/material.dart';

import '../demo.dart';
import '../models/models.dart';
import '../services/content_repository.dart';
import '../services/student_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

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

  // Contexto académico opcional: solo sirve para comparar contra lo que la
  // unidad publica. Nunca es obligatorio y nunca se inventa.
  final _carrera = TextEditingController();
  final _plan = TextEditingController();
  final _anio = TextEditingController();
  String _estadoCatalogoDe = '';

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
    _carrera.dispose();
    _plan.dispose();
    _anio.dispose();
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

  /// El estado del catálogo de la unidad elegida, con su fecha de corte.
  ///
  /// Se consulta al vuelo para que el alumno sepa **antes** de entrar si su
  /// unidad publica modalidades o no: no hay sorpresas después.
  Future<void> _alElegirUnidad(String? clave) async {
    setState(() {
      _facultad = clave;
      // El aviso de "elige tu unidad" ya no aplica si acaba de elegirla.
      if (clave != null && clave.isNotEmpty &&
          _error == 'Elige tu unidad académica para continuar.') {
        _error = '';
      }
    });
    if (clave == null) {
      setState(() => _estadoCatalogoDe = '');
      return;
    }
    try {
      final oferta = await _repo.ofertaDeUnidad(clave);
      if (!mounted || _facultad != clave) return;
      setState(
        () =>
            _estadoCatalogoDe =
                oferta.unidad == null
                    ? 'Sin catálogo'
                    : '${oferta.estadoCatalogo} · corte ${oferta.fechaCorte}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _estadoCatalogoDe = 'No se pudo leer el catálogo: $e');
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

    final limpio = _digitos.esMatricula(q) ? q : _digitos.normalizar(q);

    final Alumno? encontrado;
    try {
      encontrado = await _alumnosRepo.buscar(limpio);
    } catch (e) {
      // La base que no carga no deja el spinner girando: se avisa y la persona
      // puede continuar como invitada.
      if (!mounted) return;
      setState(() {
        _buscando = false;
        _alumno = null;
        _error = 'No se pudo consultar la base de la BUAP: $e';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _buscando = false;
      if (encontrado == null) {
        _alumno = null;
        _error =
            limpio.length == 9
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
    final facultad = _facultad;
    if (facultad == null || facultad.isEmpty) {
      setState(() => _error = 'Elige tu unidad académica para continuar.');
      return;
    }
    // Si no se encontró en la base, la persona entra como invitada: su
    // progreso se guarda igual en el dispositivo.
    final encontrado = _alumno;
    final alumno =
        encontrado == null
            ? Alumno(nombre: '', matricula: '', facultad: facultad)
            : Alumno(
              nombre: encontrado.nombre,
              matricula: encontrado.matricula,
              facultad: facultad,
              carrera: _carrera.text.trim(),
              plan: _plan.text.trim(),
              anioIngreso: int.tryParse(_anio.text.trim()),
            );
    // El avance y las notas se guardan por modalidad, no por persona: registrar
    // a otra persona en este teléfono no borra nada de la anterior, solo deja de
    // mostrar su oferta. Por eso se avisa antes, con la salida que sí limpia.
    if (_esOtraPersona(alumno)) {
      final continuar = await _advertirDatosDeOtraPersona();
      if (continuar != true) return;
    }
    await widget.state.registrar(alumno, facultadClave: facultad);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// ¿Lo que se va a registrar es otra persona que la que ya está en el
  /// teléfono? Usa la misma regla que [AppState.registrar], para que el aviso y
  /// el comportamiento nunca discrepen.
  bool _esOtraPersona(Alumno alumno) {
    final previo = widget.state.alumno;
    if (previo == null) return false;
    return previo.matricula != alumno.matricula ||
        previo.nombre != alumno.nombre;
  }

  /// Aviso antes de registrar a otra persona: lo que queda en el teléfono, de
  /// quién es, y el único botón que lo borra.
  Future<bool?> _advertirDatosDeOtraPersona() {
    final previo = widget.state.alumno!;
    final quien = previo.nombre.trim().isEmpty
        ? 'la persona que estaba registrada'
        : previo.nombre.trim();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vas a registrar a otra persona'),
        content: Text(
          'El avance (niveles completados y documentos marcados) y las notas '
          'de $quien siguen guardados en este teléfono: registrarse otra vez no '
          'los borra. Si esa persona elige una modalidad, los verá como si '
          'fueran suyos.\n\n'
          'En un teléfono compartido, cierra la sesión antes: Menú → Mi perfil '
          '→ Cerrar sesión borra el registro, la unidad, el avance de todas las '
          'modalidades y las notas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Registrar de todos modos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tu cuenta'), leading: const SizedBox()),
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
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (!kDemoWeb)
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
                  suffixIcon:
                      _buscando
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
              )
            else ...[
              const AvisoDemo(
                'La búsqueda por matrícula no viene en la demo web. '
                'Continúa como invitado: en la app instalada sí puedes '
                'encontrarte en la base de la BUAP.',
              ),
              const SizedBox(height: 8),
            ],
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
                    const Icon(
                      Icons.info_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
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
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
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
              items:
                  _facultades
                      .map(
                        (f) => DropdownMenuItem(
                          value: f.clave,
                          child: Text(
                            f.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: _alElegirUnidad,
            ),
            if (_estadoCatalogoDe.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Catálogo de la unidad: $_estadoCatalogoDe',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _bloqueContextoAcademico(),
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
                _alumno == null
                    ? 'Continuar como invitado'
                    : 'Comenzar mi aventura',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Si no estás en la base todavía puedes entrar: tu progreso se '
              'guarda en este dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Datos académicos opcionales.
  ///
  /// Sirven para comparar tu perfil contra el que publica tu unidad. Ninguna
  /// unidad publica todavía ese perfil, así que la app **no** puede decirte si
  /// te aplica o no: lo que hace es dejar el dato listo y, si la unidad algún
  /// día lo publica, compararlo. Sin esto no pierdes nada.
  Widget _bloqueContextoAcademico() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text(
          'Carrera, plan y cohorte (opcional)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: const Text(
          'Solo para comparar contra lo que publica tu unidad. '
          'Ninguna unidad lo publica todavía.',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
        ),
        children: [
          _campoOpcional(_carrera, 'Carrera', 'Licenciatura en …'),
          const SizedBox(height: 10),
          _campoOpcional(_plan, 'Plan de estudios', 'Plan 2015, plan 2020…'),
          const SizedBox(height: 10),
          _campoOpcional(_anio, 'Año de ingreso', '2021', soloDigitos: true),
        ],
      ),
    );
  }

  Widget _campoOpcional(
    TextEditingController controller,
    String etiqueta,
    String ejemplo, {
    bool soloDigitos = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: soloDigitos ? TextInputType.number : TextInputType.text,
      autocorrect: false,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: ejemplo,
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
