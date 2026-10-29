import 'package:flutter/material.dart';
import '../modelos/cuenta.dart';
import '../modelos/rutina.dart';
import '../servicios/nube.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/animacion_ejercicio.dart';
import '../widgets/icono_chip.dart';

// Paciente: su fisioterapeuta (el que lo agregó) y la rutina asignada
class TarjetaMiFisio extends StatefulWidget {
  final Cuenta paciente;

  const TarjetaMiFisio({super.key, required this.paciente});

  @override
  State<TarjetaMiFisio> createState() => _TarjetaMiFisioState();
}

class _TarjetaMiFisioState extends State<TarjetaMiFisio> {
  Cuenta? _fisio;
  Rutina? _rutina;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final yo = await nube.cuenta(widget.paciente.id) ?? widget.paciente; // datos al día
    final fisio = yo.fisioId == null ? null : await nube.cuenta(yo.fisioId!);
    final rutina = await nube.rutina(yo.id);
    if (!mounted) return;
    setState(() {
      _fisio = fisio;
      _rutina = rutina;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
    }
    final fisio = _fisio;
    final rutina = _rutina ?? Rutina.predefinida();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: fisio == null
              ? const Row(
                  children: [
                    IconoChip(icono: Icons.medical_services_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sin fisioterapeuta asignado', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            'Tu fisioterapeuta te agrega desde su cuenta y te entrega tu usuario.',
                            style: TextStyle(color: Colores.textoSuave, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colores.azulSuave,
                      child: Text(fisio.iniciales,
                          style: const TextStyle(color: Colores.primario, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fisio.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Text('Fisioterapeuta · TP ${fisio.tarjetaProfesional ?? '—'}',
                              style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                          const Text('Ve tus sesiones de rehabilitación y te asigna la rutina',
                              style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        TarjetaRutina(rutina: rutina, asignada: _rutina != null),
      ],
    );
  }
}

// Ejercicios de una rutina, cada uno con su demostración
class TarjetaRutina extends StatelessWidget {
  final Rutina rutina;
  final bool asignada; // false = predefinida

  const TarjetaRutina({super.key, required this.rutina, required this.asignada});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoChip(icono: Icons.fitness_center_rounded, tamano: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mi rutina de rehabilitación', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      asignada ? 'Asignada por tu fisioterapeuta' : 'Rutina predefinida',
                      style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in rutina.ejercicios)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: AnimacionEjercicio(demo: e.def.demo, titulo: e.def.nombre, descripcion: e.def.instruccion),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.def.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          '${e.series} × ${e.repeticiones}'
                          '${e.def.sostener > 0 ? ' · sostener ${e.def.sostener} s' : ''}'
                          ' · meta ${e.meta == null ? 'progresiva' : '${e.meta!.round()}°'}',
                          style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: Colores.textoSuave),
              const SizedBox(width: 6),
              Text('Descanso entre series: ${rutina.descanso} s',
                  style: const TextStyle(color: Colores.textoSuave, fontSize: 13)),
            ],
          ),
          if (rutina.nota != null && rutina.nota!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colores.azulSuave, borderRadius: BorderRadius.circular(10)),
              child: Text('Indicaciones: ${rutina.nota}', style: const TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}
