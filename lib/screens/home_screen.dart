import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'contacts_screen.dart';
import 'directorio_unidad_screen.dart';
import 'map_screen.dart';
import 'menu_screen.dart';
import 'profile_screen.dart';
import 'route_selection_screen.dart';

/// Pantalla principal: el avance del alumno y **las modalidades que publica su
/// unidad académica**, nunca una lista global de rutas.
///
/// Lo que la unidad no publica no se sustituye por la ruta genérica: se explica
/// que no se encontró, con el rastro de las URLs revisadas y un contacto.
///
/// La lista sigue a la unidad: cuando el alumno cambia de unidad académica, la
/// pantalla escucha a [AppState] y vuelve a leer el catálogo. Las modalidades de
/// la unidad anterior no se quedan pintadas, y con ellas tampoco queda la
/// tarjeta que las hacía elegibles.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = ContentRepository.instance;
  OfertaUnidad? _oferta;
  bool _cargando = true;
  String _error = '';

  /// La unidad para la que se pintó [_oferta].
  ///
  /// Es lo que se compara cuando [AppState] avisa de un cambio: si la unidad ya
  /// no es la misma, la lista se vuelve a leer. Sin esto, cambiar de unidad
  /// dejaba en pantalla las modalidades de la anterior y sus tarjetas seguían
  /// siendo elegibles.
  String? _claveCargada;

  /// Número de la lectura en curso. Si el alumno cambia de unidad dos veces
  /// seguidas, solo se pinta la última: la respuesta lenta de la unidad
  /// anterior ya no puede llegar después.
  int _lectura = 0;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_alCambiarElEstado);
    _cargar();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_alCambiarElEstado);
      widget.state.addListener(_alCambiarElEstado);
      _cargar();
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_alCambiarElEstado);
    super.dispose();
  }

  /// Recarga cuando cambia la unidad académica.
  ///
  /// El resto de los cambios (avance, modalidad activa) los trae el mismo
  /// [AppState] y los pinta el rebuild que dispara quien lo escucha.
  void _alCambiarElEstado() {
    if (!mounted) return;
    if (widget.state.facultadClave != _claveCargada) _cargar();
  }

  Future<void> _cargar() async {
    final lectura = ++_lectura;
    final clave = widget.state.facultadClave;
    final cambiaDeUnidad = clave != _claveCargada;
    if (cambiaDeUnidad && mounted && !_cargando) {
      // Mientras se lee el catálogo nuevo no se pintan las tarjetas del
      // anterior: son de otra unidad y no se pueden elegir.
      setState(() => _cargando = true);
    }
    if (clave == null || clave.isEmpty) {
      if (!mounted || lectura != _lectura) return;
      setState(() {
        _oferta = null;
        _claveCargada = clave;
        _cargando = false;
        _error = '';
      });
      return;
    }
    try {
      final oferta = await _repo.ofertaDeUnidad(clave);
      if (!mounted || lectura != _lectura) return;
      setState(() {
        _oferta = oferta;
        _claveCargada = clave;
        _cargando = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted || lectura != _lectura) return;
      setState(() {
        _oferta = null;
        _claveCargada = clave;
        _cargando = false;
        _error = 'No se pudo leer el catálogo de tu unidad: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final alumno = state.alumno;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [LoboColors.navy, LoboColors.steelBlue],
                ),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: -40,
            child: Opacity(
              opacity: 0.12,
              child: AssetImageSafe(
                'assets/images/lobo_deportivo.svg',
                height: 220,
              ),
            ),
          ),
          SafeArea(
            child:
                _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          _encabezado(alumno),
                          const SizedBox(height: 22),
                          if (_error.isNotEmpty)
                            _tarjetaError(_error)
                          else if (_oferta == null)
                            _sinUnidad()
                          else if (_oferta!.vacia)
                            _sinOferta(_oferta!)
                          else
                            _listaOferta(_oferta!),
                          const SizedBox(height: 20),
                          _buildFooter(context),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _encabezado(Alumno? alumno) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _saludo(alumno?.nombre),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (alumno != null)
                Text(
                  alumno.matricula.isEmpty
                      ? 'Sesión de invitado'
                      : 'Matrícula ${alumno.matricula}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              if (_oferta != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Tu unidad: ${_oferta!.nombre}',
                  style: const TextStyle(
                    color: LoboColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_oferta!.estadoExplicado} · corte ${_oferta!.fechaCorte}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Menú',
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MenuScreen(state: widget.state),
                ),
              ),
          icon: const Icon(Icons.menu, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Mi perfil',
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(state: widget.state),
                ),
              ),
          icon: const CircleAvatar(
            radius: 18,
            backgroundColor: LoboColors.gold,
            child: Icon(Icons.person, color: LoboColors.deepBlue),
          ),
        ),
      ],
    );
  }

  String _saludo(String? nombre) {
    if (nombre == null || nombre.isEmpty) return '¡Hola, viajero!';
    return '¡Hola, ${nombre.split(' ').first}!';
  }

  Widget _tarjetaError(String texto) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.redAccent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(texto, style: const TextStyle(fontSize: 14, height: 1.4)),
  );

  Widget _sinUnidad() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'Elige tu unidad académica para ver las modalidades de titulación '
      'que publica. Sin unidad no se puede filtrar el catálogo.',
      style: TextStyle(fontSize: 15, height: 1.5),
    ),
  );

  /// Unidad sin catálogo. Nunca una lista vacía: se explica qué se buscó.
  Widget _sinOferta(OfertaUnidad oferta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige tu modalidad de titulación',
          style: loboDisplay.copyWith(fontSize: 19, color: Colors.white),
        ),
        const SizedBox(height: 12),
        _avisoSinCatalogo(oferta),
      ],
    );
  }

  Widget _avisoSinCatalogo(OfertaUnidad oferta) {
    return Column(
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
                oferta.mensajeSinCatalogo,
                style: loboCuerpo.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              if (oferta.contacto.correo.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Escríbele a ${oferta.contacto.coordinacion.isEmpty ? 'tu unidad' : oferta.contacto.coordinacion}: '
                  '${oferta.contacto.correo}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
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
                  builder:
                      (_) => RouteSelectionScreen(
                        oferta: oferta,
                        state: widget.state,
                        repository: _repo,
                      ),
                ),
              ),
          icon: const Icon(Icons.assignment_outlined, size: 18),
          label: const Text('Ver búsqueda y fuentes'),
        ),
        if (oferta.informativas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${oferta.informativas.length} modalidad(es) en el registro de '
            'evidencia, sin ruta acreditada:',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          for (final m in oferta.informativas.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· ${m.nombre}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }

  Widget _listaOferta(OfertaUnidad oferta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige tu modalidad de titulación',
          style: loboDisplay.copyWith(fontSize: 19, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          '${oferta.rutas.length} que publica ${oferta.nombre}.',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 16),
        ...oferta.rutas.map((r) => _buildRutaCard(context, r)),
        if (oferta.errores.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${oferta.errores.length} modalidad(es) quedaron fuera por un '
            'problema de composición; las demás siguen disponibles.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildRutaCard(BuildContext context, RutaOferta oferta) {
    final state = widget.state;
    final ruta = oferta.ruta.ruta;
    final numeros = ruta.numerosJugables;
    final total = numeros.length;
    final progreso = state.progresoDe(oferta.id, numeros);
    final siguiente = state.siguienteNivel(oferta.id, numeros);
    final nivelActual =
        ruta.nivelesJugables.where((n) => n.numero == siguiente).firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => RouteSelectionScreen(
                        oferta: _oferta!,
                        ruta: oferta,
                        state: state,
                        repository: _repo,
                      ),
                ),
              ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AssetImageSafe(
                  ruta.mascotaInicio,
                  height: 64,
                  fallbackIcon: Icons.pets,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        oferta.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progreso > 0
                            ? (nivelActual == null
                                ? '¡Ruta completada! 🎉'
                                : 'Siguiente: ${nivelActual.titulo}')
                            : '$total niveles por superar',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progreso,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                            LoboColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactsScreen(state: widget.state),
                  ),
                ),
            icon: const Icon(Icons.support_agent, size: 18),
            label: const Text('Contactos'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _abrirDirectorioDeMiUnidad,
            icon: const Icon(Icons.groups_outlined, size: 18),
            label: const Text('Directorio'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _abrirMapaActivo,
            icon: const Icon(Icons.map, size: 18),
            label: const Text('Mapa'),
          ),
        ),
      ],
    );
  }

  /// Abre el directorio oficial de la unidad de la persona.
  ///
  /// Antes este botón buscaba en un padrón general de trabajadores de la BUAP
  /// que viajaba dentro del paquete. Ese padrón ya no se distribuye: son 43 mil
  /// nombres con matrícula y correo, y sin registro no hay forma de dar acceso
  /// controlado a esa información. Ahora va al directorio que cada unidad publica
  /// para ser contactada, que sí existe con ese propósito.
  Future<void> _abrirDirectorioDeMiUnidad() async {
    final clave = widget.state.facultadClave;
    if (clave == null) return;
    final f = await _repo.facultadPorClave(clave);
    if (f == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DirectorioUnidadScreen(facultad: f)),
    );
  }

  /// El botón de mapa resuelve el id guardado: puede ser una modalidad de la
  /// unidad o una ruta global de las que ya estaban en el dispositivo.
  Future<void> _abrirMapaActivo() async {
    final rutaActiva = widget.state.rutaActiva;
    if (rutaActiva == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero elige una modalidad para ver su mapa'),
        ),
      );
      return;
    }
    Ruta? ruta;
    try {
      ruta = await _repo.rutaEfectivaPorId(rutaActiva);
    } catch (e) {
      // El catálogo no llegó (asset ausente o ilegible). Antes la excepción se
      // escapaba suelta del manejador de pulsaciones y el botón no respondía
      // nada; ahora se dice, como ya hacen contactos, directorio y registro.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir el mapa: esta app no pudo leer su catálogo '
            '($e).',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (ruta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La modalidad guardada "$rutaActiva" ya no está en el catálogo. '
            'Elige otra en la lista.',
          ),
        ),
      );
      return;
    }
    // `final` local: una variable normal no se promueve dentro del closure del
    // builder, y `MapScreen` exige una `Ruta`, no una `Ruta?`.
    final rutaResuelta = ruta;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(ruta: rutaResuelta, state: widget.state),
      ),
    );
  }
}
