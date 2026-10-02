import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Registro del alumno: se escribe su nombre y se elige su unidad.
///
/// La app **no consulta ningún padrón de alumnos**: ni el de la BUAP ni uno
/// propio. La matrícula que se escribe es la que la persona dice tener y lo
/// único que se comprueba es su forma (9 dígitos). La base no viaja en el
/// paquete porque son 318 mil nombres y no hay forma de consultar esa
/// información sin registro.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.state});

  final AppState state;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombre = TextEditingController();
  final _matricula = TextEditingController();
  final _repo = ContentRepository.instance;
  final _digitos = DigitosMatricula();

  List<Facultad> _facultades = [];
  String? _facultad;
  /// La unidad elegida como modelo, para poder mostrar su fuente de catálogo y
  /// su salvedad. `_facultad` es solo la clave.
  Facultad? _facultadObj;
  bool _cargando = true;
  String _error = '';

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
  }

  @override
  void dispose() {
    _nombre.dispose();
    _matricula.dispose();
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
      final modelo =
          _facultades.where((f) => f.clave == clave).firstOrNull;
      if (!mounted || _facultad != clave) return;
      setState(() {
        _facultadObj = modelo;
        _estadoCatalogoDe =
            oferta.unidad == null
                ? 'Sin catálogo'
                : '${oferta.estadoCatalogo} · corte ${oferta.fechaCorte}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _estadoCatalogoDe = 'No se pudo leer el catálogo: $e');
    }
  }

  /// Aviso de forma, no de contenido: la app no puede saber si la matrícula es
  /// real, así que solo señala que no tiene el formato de una de la BUAP.
  String get _avisoMatricula {
    final t = _matricula.text.trim();
    if (t.isEmpty) return '';
    if (_digitos.normalizar(t).length < 9) return '';
    if (_digitos.esMatricula(t)) return '';
    return 'La matrícula de la BUAP son 9 dígitos. La app no la verifica: solo '
        'te avisa del formato. Puedes corregirla cuando quieras en '
        'Menú → Mi perfil.';
  }

  Future<void> _continuar() async {
    final facultad = _facultad;
    if (facultad == null || facultad.isEmpty) {
      setState(() => _error = 'Elige tu unidad académica para continuar.');
      return;
    }
    // Nombre y matrícula son opcionales: la app no consulta ningún padrón, así
    // que no hay nada que "encontrar". Se guardan tal cual, para que la persona
    // los vea y pueda corregirlos.
    final alumno = Alumno(
      nombre: _nombre.text.trim(),
      matricula: _digitos.normalizar(_matricula.text.trim()),
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
              'Escribe tu nombre y, si te acuerdas, tu matrícula. Los dos '
              'campos son opcionales: la app no consulta ninguna base de la '
              'BUAP, solo guarda lo que escribas en este teléfono.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nombre,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              onChanged: (_) {
                if (_error.isNotEmpty) setState(() => _error = '');
              },
              decoration: InputDecoration(
                labelText: 'Nombre (opcional)',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matricula,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.number,
              autocorrect: false,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Matrícula (opcional)',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.badge_outlined, color: Colors.white70),
                helperText: _avisoMatricula.isEmpty ? null : _avisoMatricula,
                helperStyle: const TextStyle(color: Colors.white54, height: 1.4),
                helperMaxLines: 3,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
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
              // «Publicado» sin decir de dónde sale no es comprobable. La
              // unidad puede además advertir que su catálogo no es exhaustivo.
              if (_facultadObj?.fuenteCatalogo.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Fuente: ${_facultadObj!.fuenteCatalogo.join(' · ')}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              if ((_facultadObj?.salvedad.isNotEmpty ?? false)) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LoboColors.gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _facultadObj!.salvedad,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
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
              onPressed: _continuar,
              child: const Text(
                'Comenzar mi aventura',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tu avance y tus notas se guardan solo en este teléfono. Nada '
              'de lo que escribas sale de tu dispositivo.',
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
}
