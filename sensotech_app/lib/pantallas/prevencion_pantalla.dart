import 'dart:async';
import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/perfil.dart';
import '../servicios/brazalete.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/icono_chip.dart';
import '../widgets/indicador_estado.dart';
import '../widgets/tarjeta_movimiento.dart';

// Modo prevención (hoja 2): postura en vivo, contadores y pausa activa
class PrevencionPantalla extends StatefulWidget {
  final Perfil perfil;
  final Brazalete brazalete;

  const PrevencionPantalla({super.key, required this.perfil, required this.brazalete});

  @override
  State<PrevencionPantalla> createState() => _PrevencionPantallaState();
}

class _PrevencionPantallaState extends State<PrevencionPantalla> {
  StreamSubscription<LecturaEnVivo>? _sub;
  LecturaEnVivo? _ultima;

  // Contadores de la jornada (en segundos)
  double _trabajo = 0;
  double _fueraDeRango = 0;
  int _alertas = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.brazalete.lecturas.listen(_recibir);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // Cada lectura equivale a 0,1 s
  void _recibir(LecturaEnVivo l) {
    setState(() {
      _trabajo += 0.1;
      if (l.estado != EstadoPostura.verde) _fueraDeRango += 0.1;
      final pasoARojo =
          l.estado == EstadoPostura.rojo && _ultima?.estado != EstadoPostura.rojo;
      if (pasoARojo) _alertas++;
      _ultima = l;
    });
  }

  String _formato(double segundos) {
    final s = segundos.floor();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final ss = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final sss = ss.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$sss' : '$mm:$sss';
  }

  Future<void> _terminar() async {
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
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
        ],
      ),
    );
    if (mounted) Navigator.pop(context); // vuelve a elegir modo
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prevención'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.work_outline_rounded, size: 18, color: Colores.primario),
              label: Text(widget.perfil.tipoTexto),
              backgroundColor: Colores.azulSuave,
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: l == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  IndicadorEstado(estado: l.estado),
                  const SizedBox(height: 16),
                  _tarjetaPausa(),
                  const SizedBox(height: 16),
                  TarjetaMovimiento(lectura: l),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _dato(Icons.schedule_rounded, 'Trabajo', _formato(_trabajo))),
                      const SizedBox(width: 10),
                      Expanded(child: _dato(Icons.timer_off_outlined, 'Fuera rango', _formato(_fueraDeRango))),
                      const SizedBox(width: 10),
                      Expanded(child: _dato(Icons.notifications_active_outlined, 'Alertas', '$_alertas')),
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
  Widget _tarjetaPausa() {
    final total = widget.perfil.minutosPausa * 60.0;
    final avance = (_trabajo % total) / total;
    final faltan = total - (_trabajo % total);
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
          Text('Cada ${widget.perfil.minutosPausa} min: flexión y extensión de 30°, 5 repeticiones',
              style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
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
