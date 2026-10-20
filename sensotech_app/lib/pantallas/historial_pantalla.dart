import 'package:flutter/material.dart';
import '../modelos/perfil.dart';
import '../modelos/sesion.dart';
import '../servicios/repositorio_sesiones.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/icono_chip.dart';

// Historial de jornadas de un perfil
class HistorialPantalla extends StatefulWidget {
  final Perfil perfil;

  const HistorialPantalla({super.key, required this.perfil});

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
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: SafeArea(
        child: s == null
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
                  ),
      ),
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
                  '${x.porcentajeFuera} % fuera · ${x.alertas} alertas',
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
