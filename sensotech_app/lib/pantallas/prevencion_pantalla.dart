import 'dart:async';
import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/ejercicios.dart';
import '../modelos/perfil.dart';
import '../modelos/sesion.dart';
import '../servicios/brazalete.dart';
import '../servicios/brazalete_simulado.dart';
import '../servicios/repositorio_perfiles.dart';
import '../servicios/repositorio_sesiones.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/icono_chip.dart';
import '../widgets/indicador_estado.dart';
import '../widgets/tarjeta_movimiento.dart';
import '../widgets/tarjeta_ejercicio_guiado.dart';

// Modo prevención (hoja 2): postura en vivo, contadores y pausa activa
class PrevencionPantalla extends StatefulWidget {
  final Perfil perfil;
  final TipoTrabajo tipo;
  final Brazalete brazalete;

  const PrevencionPantalla({
    super.key,
    required this.perfil,
    required this.tipo,
    required this.brazalete,
  });

  @override
  State<PrevencionPantalla> createState() => _PrevencionPantallaState();
}

class _PrevencionPantallaState extends State<PrevencionPantalla> {
  StreamSubscription<LecturaEnVivo>? _subLecturas;
  StreamSubscription<EjercicioEnCurso>? _subEjercicio;
  LecturaEnVivo? _ultima;
  EjercicioEnCurso? _ejercicio;

  // Contadores de la jornada (en segundos)
  double _trabajo = 0;
  double _desdePausa = 0; // se reinicia al completar una pausa
  double _fueraDeRango = 0;
  int _alertas = 0;
  int _pausas = 0;
  bool _guardada = false;
  final DateTime _inicio = DateTime.now();

  static bool _esPausa(LecturaEnVivo? l) =>
      l?.fase == FaseBrazalete.pausaActiva || l?.fase == FaseBrazalete.descanso;
  bool get _enPausa => _esPausa(_ultima);

  late Perfil _perfil = widget.perfil; // guarda la mano elegida

  Future<void> _elegirMano(Mano m) async {
    setState(() => _perfil = _perfil.conMano(m));
    await RepositorioPerfiles().guardar(_perfil);
  }

  @override
  void initState() {
    super.initState();
    _subLecturas = widget.brazalete.lecturas.listen(_recibir);
    _subEjercicio = widget.brazalete.ejercicio.listen((e) => setState(() => _ejercicio = e));
  }

  @override
  void dispose() {
    _subLecturas?.cancel();
    _subEjercicio?.cancel();
    // Salió sin terminar: se guarda como incompleta (hoja 1)
    if (!_guardada && _trabajo >= 1) _guardar(completa: false);
    super.dispose();
  }

  // Cada lectura equivale a 0,1 s
  void _recibir(LecturaEnVivo l) {
    final antes = _ultima;
    setState(() {
      _trabajo += 0.1;
      if (_esPausa(l)) {
        // Empezó la pausa
        if (!_esPausa(antes)) _avisar('Hora de la pausa activa');
      } else {
        _desdePausa += 0.1;
        if (l.estado != EstadoPostura.verde) _fueraDeRango += 0.1;
        if (l.estado == EstadoPostura.rojo && antes?.estado != EstadoPostura.rojo) _alertas++;
        // Terminó la pausa: contarla y reiniciar el tiempo de trabajo
        if (_esPausa(antes)) {
          _pausas++;
          _desdePausa = 0;
          _ejercicio = null;
          _avisar('¡Pausa activa completada!');
        }
      }
      _ultima = l;
    });
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
  }

  // Guarda la jornada en el historial del perfil
  Future<void> _guardar({required bool completa}) {
    _guardada = true;
    return RepositorioSesiones().guardar(SesionPrevencion(
      id: _inicio.millisecondsSinceEpoch.toString(),
      perfilId: widget.perfil.id,
      fecha: _inicio,
      tipo: widget.tipo,
      segundosTrabajo: _trabajo.round(),
      segundosFuera: _fueraDeRango.round(),
      alertas: _alertas,
      pausas: _pausas,
      completa: completa,
    ));
  }

  String _formato(double segundos) {
    final s = segundos.floor();
    final h = s ~/ 3600;
    final mm = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  Future<void> _terminar() async {
    await _guardar(completa: true);
    if (!mounted) return;
    final porcentaje = _trabajo == 0 ? 0 : (_fueraDeRango / _trabajo * 100).round();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const IconoChip(icono: Icons.task_alt_rounded, tamano: 52),
        title: const Text('Jornada terminada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filaResumen('Tiempo de trabajo', _formato(_trabajo)),
            _filaResumen('Fuera de rango', '${_formato(_fueraDeRango)} ($porcentaje %)'),
            _filaResumen('Alertas', '$_alertas'),
            _filaResumen('Pausas activas', '$_pausas'),
            const SizedBox(height: 8),
            const Text('Guardado en el historial',
                style: TextStyle(color: Colores.verde, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, false); // false = no pidió cambiar modo
  }

  Widget _filaResumen(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: const TextStyle(color: Colores.textoSuave))),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = _ultima;
    final e = _ejercicio;
    final simulado = widget.brazalete is BrazaleteSimulado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prevención'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true), // true = cambiar modo
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Cambiar modo'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: l == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // Durante la pausa se muestra el ejercicio guiado
                  if (_enPausa && e != null)
                    TarjetaEjercicioGuiado(
                      ejercicio: e,
                      lectura: l,
                      izquierda: _perfil.mano == Mano.izquierda,
                      etiqueta: 'Pausa activa',
                      posicion: 'Ejercicio ${e.codigo - IdEjercicio.p1Bombeo.index + 1} de 3',
                    )
                  else ...[
                    IndicadorEstado(estado: l.estado),
                    const SizedBox(height: 16),
                    _tarjetaPausa(simulado),
                  ],
                  // En la pausa la tarjeta guiada ya trae la muñeca en vivo: no se repite
                  if (!_enPausa) ...[
                    const SizedBox(height: 16),
                    TarjetaMovimiento(
                      lectura: l,
                      mano: _perfil.mano,
                      alElegirMano: _elegirMano,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _dato(Icons.pan_tool_alt_outlined, 'Flexión', '${l.flexion.toStringAsFixed(1)}°')),
                        const SizedBox(width: 10),
                        Expanded(child: _dato(Icons.open_with_rounded, 'Desviación', '${l.desviacion.toStringAsFixed(1)}°')),
                        const SizedBox(width: 10),
                        Expanded(child: _dato(Icons.straighten_rounded, 'Antebrazo', '${l.antebrazo.toStringAsFixed(1)}°')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _dato(Icons.schedule_rounded, 'Trabajo', _formato(_trabajo))),
                      const SizedBox(width: 10),
                      Expanded(child: _dato(Icons.notifications_active_outlined, 'Alertas', '$_alertas')),
                      const SizedBox(width: 10),
                      Expanded(child: _dato(Icons.self_improvement_rounded, 'Pausas', '$_pausas')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _terminar,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Terminar jornada'),
                  ),
                ],
              ),
      ),
    );
  }

  // Cuenta regresiva para la pausa activa
  Widget _tarjetaPausa(bool simulado) {
    final total = widget.tipo.minutosPausa * 60.0;
    final avance = (_desdePausa / total).clamp(0.0, 1.0).toDouble();
    final faltan = (total - _desdePausa).clamp(0.0, total).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoChip(icono: Icons.self_improvement_rounded, tamano: 34),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Próxima pausa activa', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(_formato(faltan),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: Colores.primarioOscuro)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: avance,
              minHeight: 8,
              backgroundColor: Colores.azulSuave,
              color: Colores.primario,
            ),
          ),
          const SizedBox(height: 6),
          Text('${widget.tipo.texto}: cada ${widget.tipo.minutosPausa} min. Bombeo de flexoextensión, '
              'isométrico en extensión y activación de dedos.',
              style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
          // Solo con el simulado, para no esperar 45 o 60 minutos
          if (simulado) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => (widget.brazalete as BrazaleteSimulado).simularPausaAhora(),
              icon: const Icon(Icons.fast_forward_rounded, size: 18),
              label: const Text('Probar pausa ahora (simulación)'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: Colores.primario),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
