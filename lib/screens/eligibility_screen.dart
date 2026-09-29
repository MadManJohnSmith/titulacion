import 'package:flutter/material.dart';

import '../services/content_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/buap_links.dart';
import '../widgets/modality_card.dart';
import '../widgets/eligibility_result.dart';

/// Calculadora de elegibilidad: el alumno declara lo que tiene y la pantalla
/// le dice a qué modalidades de **su** unidad puede aspirar.
///
/// Qué decide y qué no:
/// - decide comparando los requisitos que la unidad **publica** en
///   `catalogo_modalidades.json`, con la fuente y la fecha de cada uno;
/// - no decide lo que la unidad no publica: eso sale como "solo tu unidad puede
///   confirmarlo", nunca como aprobado;
/// - no guarda el promedio ni los créditos del alumno. Son datos de su
///   expediente, se comparan aquí y se quedan aquí.
class EligibilityScreen extends StatefulWidget {
  const EligibilityScreen({super.key, required this.state, this.repo});

  final AppState state;
  final ContentRepository? repo;

  @override
  State<EligibilityScreen> createState() => _EligibilityScreenState();
}

class _EligibilityScreenState extends State<EligibilityScreen> {
  late final ContentRepository _repo = widget.repo ?? ContentRepository.instance;

  final _promedio = TextEditingController();
  final _creditos = TextEditingController();
  DatosAlumno _datos = const DatosAlumno();

  OfertaUnidad? _oferta;
  String? _abierta;
  bool _cargando = true;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _promedio.dispose();
    _creditos.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final clave = widget.state.facultadClave;
    if (clave == null || clave.isEmpty) {
      setState(() {
        _oferta = null;
        _cargando = false;
      });
      return;
    }
    try {
      final oferta = await _repo.ofertaDeUnidad(clave);
      if (!mounted) return;
      setState(() {
        _oferta = oferta;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = '$e';
        _cargando = false;
      });
    }
  }

  // ----------------------------------------------------------------- veredictos

  List<VeredictoModalidad> get _veredictos {
    final oferta = _oferta;
    if (oferta == null || oferta.rutas.isEmpty) return const [];
    return CalculadoraElegibilidad.evaluarOferta(
      oferta,
      datos: _datos,
      carreraId: _carreraId,
      planId: _planId,
      anioIngreso: _anioIngreso,
    );
  }

  String? get _carreraId {
    final c = widget.state.carreraId.trim();
    return c.isEmpty ? null : c;
  }

  String? get _planId {
    final p = widget.state.planId.trim();
    return p.isEmpty ? null : p;
  }

  int? get _anioIngreso {
    final a = widget.state.anioIngreso;
    return a > 0 ? a : null;
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿A qué modalidades puedo aspirar?')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _errorCarga != null
              ? _mensaje(_errorCarga!)
              : _oferta == null
                  ? _mensaje(
                    'Regístrate y elige tu unidad académica para comparar tus '
                    'datos contra lo que ella publica.',
                  )
                  : _cuerpo(),
    );
  }

  Widget _mensaje(String texto) => ListView(
    padding: const EdgeInsets.all(16),
    children: [Text(texto, style: const TextStyle(height: 1.5))],
  );

  Widget _cuerpo() {
    final oferta = _oferta!;
    if (oferta.vacia) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            oferta.nombre,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            oferta.mensajeSinCatalogo,
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 12),
          for (final r in oferta.rastro)
            Text(
              '· ${r.resultado} — ${r.url} (consultado ${r.consultadoEn})',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          const SizedBox(height: 20),
          const EnlacesTitulacion(),
        ],
      );
    }

    final veredictos = _veredictos;
    final pueden = veredictos.where((v) => v.puedeAspirar).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          oferta.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          '${oferta.estadoExplicado} · corte del catálogo: ${oferta.fechaCorte}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _formulario(),
        const Divider(height: 32, color: Colors.white12),
        Text(
          pueden == 0
              ? 'Ninguna modalidad se puede dar por cumplida con lo que capturaste. '
                    'Eso no significa que no puedas: significa que hay puntos que '
                    'solo tu unidad puede confirmar.'
              : 'Con lo que capturaste, cumples lo publicado en $pueden '
                    '${pueden == 1 ? 'modalidad' : 'modalidades'}.',
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 4),
        const Text(
          'Toca una modalidad para ver requisito por requisito, con la cita de '
          'la fuente.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (final v in veredictos)
          ModalityCard(
            veredicto: v,
            inicial: widget.state.modalidadActiva == v.modalidadId,
            abierta: _abierta == v.modalidadId,
            onTap: () => setState(
              () => _abierta = _abierta == v.modalidadId ? null : v.modalidadId,
            ),
          ),
        if (oferta.informativas.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Modalidades que publica tu unidad pero la app no puede ofrecer:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          for (final i in oferta.informativas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '· ${i.nombre}: ${i.motivo}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
        const SizedBox(height: 24),
        const EnlacesTitulacion(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------------- formulario

  Widget _formulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lo que tú declaras',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const Text(
          'No se guarda en el teléfono: solo se compara mientras esta pantalla '
          'está abierta.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promedio,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Promedio general',
                  hintText: '8.5',
                ),
                onChanged: (t) {
                  final v = double.tryParse(t.trim().replaceAll(',', '.'));
                  setState(() => _datos = _datos.copyWith(promedio: v));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _creditos,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Créditos (%)',
                  hintText: '100',
                ),
                onChanged: (t) {
                  final v = double.tryParse(t.trim().replaceAll(',', '.'));
                  setState(
                    () => _datos = _datos.copyWith(porcentajeCreditos: v),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _triState(
          'He repetido alguna materia',
          _datos.repitioMateria,
          (v) => _datos = _datos.copyWith(repitioMateria: v),
        ),
        _triState(
          'Ya terminé el servicio social',
          _datos.servicioSocial,
          (v) => _datos = _datos.copyWith(servicioSocial: v),
        ),
        _triState(
          'Ya presenté el EGEL-CENEVAL',
          _datos.egelCeneval,
          (v) => _datos = _datos.copyWith(egelCeneval: v),
        ),
        _triState(
          'Ya hice mi trabajo escrito',
          _datos.trabajoEscrito,
          (v) => _datos = _datos.copyWith(trabajoEscrito: v),
        ),
        _triState(
          'Ya tengo experiencia profesional',
          _datos.experienciaProfesional,
          (v) => _datos = _datos.copyWith(experienciaProfesional: v),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() {
            _promedio.clear();
            _creditos.clear();
            _datos = const DatosAlumno();
          }),
          icon: const Icon(Icons.restart_alt, color: LoboColors.gold),
          label: const Text(
            'Borrar lo que capturé',
            style: TextStyle(color: LoboColors.gold),
          ),
        ),
      ],
    );
  }

  /// Sí / No / No lo sé. "No lo sé" no es "No": la app no decide por el alumno.
  Widget _triState(String etiqueta, bool? valor, ValueChanged<bool?> onChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          _botonTri('Sí', valor == true, () => onChange(true)),
          _botonTri('No', valor == false, () => onChange(false)),
          _botonTri('No sé', valor == null, () => onChange(null)),
        ],
      ),
    );
  }

  Widget _botonTri(String texto, bool activo, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: activo ? LoboColors.gold : Colors.white10,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: activo ? LoboColors.ink : Colors.white70,
              fontSize: 12,
              fontWeight: activo ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
