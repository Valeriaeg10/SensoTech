import 'package:flutter/material.dart';
import '../modelos/cuenta.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/ficha_clinica.dart';
import '../modelos/perfil.dart';
import '../modelos/rutina.dart';
import '../modelos/sesion.dart';
import '../servicios/nube.dart';
import '../servicios/repositorio_sesiones.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/encuesta_dolor.dart';
import '../widgets/grafica_dolor.dart';
import '../widgets/grafica_rango.dart';
import '../widgets/icono_chip.dart';

// Historial del paciente: jornadas de prevención y sesiones de rehabilitación
class HistorialPantalla extends StatefulWidget {
  final Perfil perfil;
  final Cuenta cuenta;

  const HistorialPantalla({super.key, required this.perfil, required this.cuenta});

  @override
  State<HistorialPantalla> createState() => _HistorialPantallaState();
}

class _HistorialPantallaState extends State<HistorialPantalla> {
  List<SesionPrevencion>? _sesiones;

  @override
  void initState() {
    super.initState();
    RepositorioSesiones().leer(widget.perfil.id).then((s) {
      if (mounted) setState(() => _sesiones = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _sesiones;
    // Cada paciente ve solo su modo
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: SafeArea(
        child: widget.cuenta.esRehabilitacion ? HistorialRehab(pacienteId: widget.cuenta.id) : _prevencion(s),
      ),
    );
  }

  Widget _prevencion(List<SesionPrevencion>? s) {
    return s == null
            ? const Center(child: CircularProgressIndicator())
            : s.isEmpty
                ? _vacio()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _resumen(s),
                      const SizedBox(height: 16),
                      _grafica(s),
                      const SizedBox(height: 20),
                      const Text('Jornadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      for (final sesion in s) ...[
                        _filaSesion(sesion),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
  }

  Widget _vacio() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconoChip(icono: Icons.insert_chart_outlined_rounded, tamano: 80),
            SizedBox(height: 16),
            Text('Sin jornadas guardadas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Al terminar una jornada de prevención aparecerá aquí',
                textAlign: TextAlign.center, style: TextStyle(color: Colores.textoSuave)),
          ],
        ),
      ),
    );
  }

  // Totales del perfil
  Widget _resumen(List<SesionPrevencion> s) {
    final trabajo = s.fold<int>(0, (a, x) => a + x.segundosTrabajo);
    final fuera = s.fold<int>(0, (a, x) => a + x.segundosFuera);
    final alertas = s.fold<int>(0, (a, x) => a + x.alertas);
    final promedio = trabajo == 0 ? 0 : (fuera * 100 / trabajo).round();
    return Row(
      children: [
        Expanded(child: _dato(Icons.calendar_month_rounded, 'Jornadas', '${s.length}')),
        const SizedBox(width: 10),
        Expanded(child: _dato(Icons.timer_off_outlined, 'Fuera de rango', '$promedio %')),
        const SizedBox(width: 10),
        Expanded(child: _dato(Icons.notifications_active_outlined, 'Alertas', '$alertas')),
      ],
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
          Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // Barras: % fuera de rango de las últimas 7 jornadas
  Widget _grafica(List<SesionPrevencion> s) {
    final ultimas = s.take(7).toList().reversed.toList(); // de antigua a reciente
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              IconoChip(icono: Icons.bar_chart_rounded, tamano: 34),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tiempo fuera de rango', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('Últimas jornadas · menos es mejor',
                        style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final x in ultimas)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${x.porcentajeFuera}%',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Container(
                            height: 4 + 100 * x.porcentajeFuera / 100,
                            decoration: BoxDecoration(
                              color: _colorBarra(x.porcentajeFuera),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('${x.fecha.day}/${x.fecha.month}',
                              style: const TextStyle(fontSize: 10, color: Colores.textoSuave)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorBarra(int p) {
    if (p < 15) return Colores.verde;
    if (p < 35) return Colores.amarillo;
    return Colores.rojo;
  }

  Widget _filaSesion(SesionPrevencion x) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoracionTarjeta(),
      child: Row(
        children: [
          IconoChip(icono: x.completa ? Icons.task_alt_rounded : Icons.timelapse_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(x.fechaTexto, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    if (!x.completa)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colores.amarillo.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Incompleta', style: TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${x.tipo.texto} · ${formatoDuracion(x.segundosTrabajo)} · '
                  '${x.porcentajeFuera} % fuera · ${x.alertas} alertas · ${x.pausas} pausas',
                  style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pestaña de rehabilitación: rango articular, dolor y sesiones (también la usa el fisio)
class HistorialRehab extends StatefulWidget {
  final String pacienteId;

  const HistorialRehab({super.key, required this.pacienteId});

  @override
  State<HistorialRehab> createState() => _HistorialRehabState();
}

class _HistorialRehabState extends State<HistorialRehab> {
  List<SesionRehab>? _s;

  @override
  void initState() {
    super.initState();
    nube.sesionesRehab(widget.pacienteId).then((s) {
      if (mounted) setState(() => _s = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const Center(child: CircularProgressIndicator());
    if (s.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconoChip(icono: Icons.fitness_center_rounded, tamano: 80),
              SizedBox(height: 16),
              Text('Sin sesiones de rehabilitación', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Al terminar una sesión aparecerá aquí con tu rango articular y tu dolor',
                  textAlign: TextAlign.center, style: TextStyle(color: Colores.textoSuave)),
            ],
          ),
        ),
      );
    }
    final completas = s.where((x) => x.completa).toList();
    final primera = completas.isEmpty ? s.first : completas.first;
    final ultima = completas.isEmpty ? s.last : completas.last;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rango articular', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Text('Cuánto mueves la muñeca en cada dirección',
                  style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
              const SizedBox(height: 12),
              for (final t in TipoEjercicio.values) ...[
                BarraRango(tipo: t, base: primera.maximo(t), actual: ultima.maximo(t), comparar: primera != ultima),
                const SizedBox(height: 14),
              ],
              const LeyendaRango(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Evolución por sesión', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              GraficaRango(sesiones: s, visibles: TipoEjercicio.values.toSet()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final t in TipoEjercicio.values) LeyendaColor(color: coloresMovimiento[t]!, texto: t.texto),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dolor (EVA 0–10)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              GraficaDolor(sesiones: s),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Sesiones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final x in s.reversed) ...[
          FilaSesionRehab(sesion: x),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// Una sesión de rehabilitación en lista
class FilaSesionRehab extends StatelessWidget {
  final SesionRehab sesion;

  const FilaSesionRehab({super.key, required this.sesion});

  @override
  Widget build(BuildContext context) {
    final x = sesion;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoracionTarjeta(),
      child: Row(
        children: [
          IconoChip(icono: x.completa ? Icons.task_alt_rounded : Icons.timelapse_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(fechaHora(x.fecha), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    if (!x.completa)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colores.amarillo.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Incompleta', style: TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Flex ${x.flexion.round()}° · Ext ${x.extension.round()}° · '
                  'D. rad ${x.radial.round()}° · D. cub ${x.cubital.round()}°',
                  style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
                ),
              ],
            ),
          ),
          if (x.dolorAntes != null || x.dolorDespues != null)
            Column(
              children: [
                const Text('EVA', style: TextStyle(color: Colores.textoSuave, fontSize: 10)),
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: x.dolorAntes?.toString() ?? '–',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: x.dolorAntes == null ? Colores.textoSuave : EncuestaDolor.color(x.dolorAntes!)),
                  ),
                  const TextSpan(text: ' → ', style: TextStyle(color: Colores.textoSuave)),
                  TextSpan(
                    text: x.dolorDespues?.toString() ?? '–',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: x.dolorDespues == null ? Colores.textoSuave : EncuestaDolor.color(x.dolorDespues!)),
                  ),
                ])),
              ],
            ),
        ],
      ),
    );
  }
}
