import 'dart:async';
import 'package:flutter/material.dart';
import '../modelos/cuenta.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/perfil.dart';
import '../modelos/rutina.dart';
import '../servicios/brazalete.dart';
import '../servicios/brazalete_simulado.dart';
import '../servicios/selector_brazalete.dart';
import '../servicios/nube.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/animacion_ejercicio.dart';
import '../widgets/encuesta_dolor.dart';
import '../widgets/icono_chip.dart';
import '../widgets/tarjeta_ejercicio_guiado.dart';

enum _Etapa { cargando, dolorAntes, enCurso, dolorDespues, resumen }

// Modo rehabilitación (hoja 3): dolor antes → calibración → línea base si no hay →
// rutina guiada → evaluación final → dolor después → guardar y comparar
class RehabilitacionPantalla extends StatefulWidget {
  final Perfil perfil;
  final Cuenta cuenta;
  final Brazalete brazalete;

  const RehabilitacionPantalla({super.key, required this.perfil, required this.cuenta, required this.brazalete});

  @override
  State<RehabilitacionPantalla> createState() => _RehabilitacionPantallaState();
}

class _RehabilitacionPantallaState extends State<RehabilitacionPantalla> {
  _Etapa _etapa = _Etapa.cargando;
  bool _izquierda = false; // mano del brazalete, definida por el fisio en la historia clínica
  Rutina _rutina = Rutina.predefinida();
  bool _rutinaDelFisio = false;
  SesionRehab? _anterior; // última sesión completa
  int? _dolorAntes;
  int? _dolorDespues;

  StreamSubscription<LecturaEnVivo>? _subL;
  StreamSubscription<EjercicioEnCurso>? _subE;
  StreamSubscription<ResultadoRehab>? _subR;
  LecturaEnVivo? _lectura;
  EjercicioEnCurso? _ejercicio;
  bool _hizoEjercicios = false; // para saber si la evaluación es la inicial o la final
  final Set<int> _codigosVistos = {};
  ResultadoRehab? _resultado;
  SesionRehab? _guardada;
  bool _guardando = false;

  Brazalete get _b => widget.brazalete;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await nube.rutina(widget.cuenta.id);
    final sesiones = await nube.sesionesRehab(widget.cuenta.id);
    final completas = sesiones.where((s) => s.completa).toList();
    final ficha = await nube.ficha(widget.cuenta.id);
    if (!mounted) return;
    setState(() {
      _izquierda = ficha?.brazaleteIzquierda ?? (widget.perfil.mano == Mano.izquierda);
      _rutina = r ?? Rutina.predefinida();
      _rutinaDelFisio = r != null;
      _anterior = completas.isEmpty ? null : completas.last;
      _etapa = _Etapa.dolorAntes;
    });
  }

  @override
  void dispose() {
    _subL?.cancel();
    _subE?.cancel();
    _subR?.cancel();
    if (_etapa == _Etapa.enCurso) _b.cancelar();
    super.dispose();
  }

  // Envía al brazalete hora, últimos máximos, mano y rutina; el brazalete empieza
  Future<void> _empezar() async {
    _subL = _b.lecturas.listen((l) => setState(() => _lectura = l));
    _subE = _b.ejercicio.listen((e) {
      setState(() {
        _ejercicio = e;
        if (!e.esEvaluacion) {
          _hizoEjercicios = true;
          _codigosVistos.add(e.codigo);
        }
      });
    });
    _subR = _b.resultados.listen(_alTerminar);
    setState(() => _etapa = _Etapa.enCurso);
    await _b.sincronizar(_anterior?.maximos, izquierda: _izquierda);
    await _b.enviarRutina(_rutina);
  }

  void _alTerminar(ResultadoRehab r) {
    setState(() {
      _resultado = r;
      _etapa = _Etapa.dolorDespues;
    });
  }

  Future<void> _confirmarCancelar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar la sesión'),
        content: const Text('La sesión se guardará como incompleta. ¿Quieres terminarla?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terminar')),
        ],
      ),
    );
    if (ok == true) await _b.cancelar(); // llega el resultado incompleto
  }

  Future<void> _guardar() async {
    final r = _resultado;
    if (r == null || _guardando) return;
    setState(() => _guardando = true);
    final s = SesionRehab(
      perfilId: widget.cuenta.id,
      fecha: r.fecha,
      flexion: r.maximos[TipoEjercicio.flexion] ?? 0,
      extension: r.maximos[TipoEjercicio.extension] ?? 0,
      radial: r.maximos[TipoEjercicio.radial] ?? 0,
      cubital: r.maximos[TipoEjercicio.cubital] ?? 0,
      completa: r.completa,
      dolorAntes: _dolorAntes,
      dolorDespues: _dolorDespues,
      realizados: [
        for (final e in _rutina.ejercicios)
          if (_codigosVistos.contains(e.id.index)) e,
      ],
    );
    await nube.guardarRehab(s);
    if (!mounted) return;
    setState(() {
      _guardada = s;
      _etapa = _Etapa.resumen;
    });
  }


  @override
  Widget build(BuildContext context) {
    final enCurso = _etapa == _Etapa.enCurso;
    return PopScope(
      canPop: !enCurso && _etapa != _Etapa.dolorDespues,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho && enCurso) _confirmarCancelar();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Rehabilitación')),
        body: SafeArea(
          child: switch (_etapa) {
            _Etapa.cargando => const Center(child: CircularProgressIndicator()),
            _Etapa.dolorAntes => _vistaDolorAntes(),
            _Etapa.enCurso => _vistaEnCurso(),
            _Etapa.dolorDespues => _vistaDolorDespues(),
            _Etapa.resumen => _vistaResumen(),
          },
        ),
      ),
    );
  }

  // ---------------- 1. Dolor antes y rutina del día ----------------

  Widget _vistaDolorAntes() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        EncuestaDolor(
          pregunta: '¿Cuánto dolor tienes en la muñeca en este momento?',
          valor: _dolorAntes,
          alCambiar: (v) => setState(() => _dolorAntes = v),
        ),
        const SizedBox(height: 16),
        _tarjetaRutina(),
        const SizedBox(height: 16),
        if (_dolorAntes != null && _dolorAntes! >= 8)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colores.amarillo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colores.amarillo),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colores.amarillo),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dolor intenso: realiza los movimientos con suavidad y detén la sesión si aumenta. '
                    'Tu fisioterapeuta verá este registro.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: _dolorAntes == null ? null : _empezar,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(_dolorAntes == null ? 'Responde la encuesta para empezar' : 'Empezar sesión'),
        ),
      ],
    );
  }

  Widget _tarjetaRutina() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoChip(icono: Icons.assignment_outlined, tamano: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_rutinaDelFisio ? 'Rutina asignada por tu fisioterapeuta' : 'Rutina predefinida',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (_rutina.nota != null && _rutina.nota!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('“${_rutina.nota}”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          for (final e in _rutina.ejercicios)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: AnimacionEjercicio(
                      demo: e.def.demo,
                      izquierda: _izquierda,
                      titulo: e.def.nombre,
                      descripcion: e.def.instruccion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.def.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${e.series} × ${e.repeticiones} · meta ${e.meta == null ? 'progresiva' : '${e.meta!.round()}°'}',
                            style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            _anterior == null
                ? 'Primera sesión: el brazalete medirá tu rango articular inicial (línea base).'
                : 'Al final, el brazalete mide tu rango articular para ver tu progreso.',
            style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
          ),
          if (BrazaleteSimulado.abreviado &&
              (widget.brazalete is BrazaleteSimulado ||
                  (widget.brazalete is SelectorBrazalete && (widget.brazalete as SelectorBrazalete).usarSimulado)))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Simulación abreviada: menos repeticiones y descansos cortos.',
                  style: TextStyle(color: Colores.primario, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  // ---------------- 2. Sesión en curso ----------------

  Widget _vistaEnCurso() {
    final l = _lectura;
    final e = _ejercicio;
    final izquierda = _izquierda;
    final calibrando = l?.fase == FaseBrazalete.calibrando || (l != null && e == null);

    String posicion() {
      if (e == null) return '';
      if (e.esEvaluacion) return _hizoEjercicios ? 'Evaluación final' : 'Evaluación inicial';
      final i = _rutina.ejercicios.indexWhere((x) => x.id.index == e.codigo);
      return i < 0 ? '' : 'Ejercicio ${i + 1} de ${_rutina.ejercicios.length}';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (l == null)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (calibrando)
          _tarjetaCalibrando()
        else if (e != null)
          TarjetaEjercicioGuiado(
            ejercicio: e,
            lectura: l,
            izquierda: izquierda,
            etiqueta: 'Rehabilitación',
            posicion: posicion(),
          ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _confirmarCancelar,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Terminar sesión'),
        ),
      ],
    );
  }

  Widget _tarjetaCalibrando() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: decoracionTarjeta(),
      child: const Column(
        children: [
          SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 5)),
          SizedBox(height: 14),
          Text('Calibrando', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text(
            'Apoya el antebrazo con la muñeca en posición neutra y no la muevas durante 5 segundos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colores.textoSuave),
          ),
        ],
      ),
    );
  }

  // ---------------- 3. Dolor después ----------------

  Widget _vistaDolorDespues() {
    final r = _resultado!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: decoracionTarjeta(),
          child: Row(
            children: [
              IconoChip(icono: r.completa ? Icons.task_alt_rounded : Icons.pause_circle_outline_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.completa ? 'Sesión completada' : 'Sesión terminada antes de tiempo',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EncuestaDolor(
          pregunta: '¿Cuánto dolor tienes ahora, después de la sesión?',
          valor: _dolorDespues,
          alCambiar: (v) => setState(() => _dolorDespues = v),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _dolorDespues == null || _guardando ? null : _guardar,
          icon: const Icon(Icons.save_rounded),
          label: Text(_dolorDespues == null ? 'Responde la encuesta para guardar' : 'Guardar sesión'),
        ),
      ],
    );
  }

  // ---------------- 4. Resumen comparado ----------------

  Widget _vistaResumen() {
    final s = _guardada!;
    final a = _anterior;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rango articular de hoy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(a == null ? 'Primera medición (línea base)' : 'Comparado con la sesión anterior',
                  style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
              const SizedBox(height: 12),
              for (final t in TipoEjercicio.values) _filaComparacion(t, s.maximo(t), a?.maximo(t)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: Row(
            children: [
              Expanded(child: _dolor('Dolor antes', s.dolorAntes)),
              const Icon(Icons.arrow_forward_rounded, color: Colores.textoSuave),
              Expanded(child: _dolor('Dolor después', s.dolorDespues)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          s.completa
              ? 'Sesión guardada. Tu fisioterapeuta puede ver estos resultados.'
              : 'Sesión guardada como incompleta. Tu fisioterapeuta puede verla.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colores.verde, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Volver al inicio')),
      ],
    );
  }

  Widget _filaComparacion(TipoEjercicio t, double hoy, double? antes) {
    final ref = rangoReferencia[t]!;
    final dif = antes == null ? null : hoy - antes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.texto, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('${hoy.round()}°', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (dif != null) ...[
                const SizedBox(width: 8),
                Icon(
                  dif >= 0.5
                      ? Icons.arrow_upward_rounded
                      : (dif <= -0.5 ? Icons.arrow_downward_rounded : Icons.remove_rounded),
                  size: 16,
                  color: dif >= 0.5 ? Colores.verde : (dif <= -0.5 ? Colores.rojo : Colores.textoSuave),
                ),
                Text('${dif >= 0 ? '+' : ''}${dif.round()}°',
                    style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (hoy / ref).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: Colores.azulSuave,
              color: Colores.primario,
            ),
          ),
          Text('Rango normal de referencia ${ref.round()}°',
              style: const TextStyle(color: Colores.textoSuave, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _dolor(String titulo, int? v) {
    return Column(
      children: [
        Text(titulo, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
        const SizedBox(height: 4),
        if (v == null)
          const Text('—')
        else ...[
          Icon(EncuestaDolor.cara(v), color: EncuestaDolor.color(v), size: 32),
          Text('$v / 10', style: TextStyle(fontWeight: FontWeight.w800, color: EncuestaDolor.color(v))),
        ],
      ],
    );
  }
}
