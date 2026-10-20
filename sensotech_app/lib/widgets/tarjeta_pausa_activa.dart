import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../tema/colores.dart';
import 'icono_chip.dart';

// Pausa activa guiada (hoja 2): ejercicio, objetivo, ángulo actual y repeticiones
class TarjetaPausaActiva extends StatelessWidget {
  final EjercicioEnCurso ejercicio;
  final LecturaEnVivo lectura;

  const TarjetaPausaActiva({super.key, required this.ejercicio, required this.lectura});

  @override
  Widget build(BuildContext context) {
    // Ángulo en la dirección del ejercicio (extensión es negativa)
    final actual = switch (ejercicio.tipo) {
      TipoEjercicio.flexion => lectura.flexion,
      TipoEjercicio.extension => -lectura.flexion,
      TipoEjercicio.pulgar => lectura.desviacion,
      TipoEjercicio.menique => -lectura.desviacion,
    };
    final objetivo = ejercicio.objetivo;
    final llego = actual >= objetivo - 5; // hoja 2
    final faltan = (objetivo - actual).clamp(0, 180).round();
    final avance = (actual / objetivo).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5AB0FF), Colores.primarioOscuro],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.self_improvement_rounded, color: Colores.blanco),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Pausa activa',
                    style: TextStyle(color: Colores.blanco, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Text('Ejercicio ${ejercicio.serie} de ${ejercicio.seriesTotal}',
                  style: const TextStyle(color: Colores.blanco, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colores.blanco,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconoChip(
                      icono: ejercicio.tipo == TipoEjercicio.extension
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      tamano: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${ejercicio.tipo.texto} ${objetivo.round()}°',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(ejercicio.tipo.instruccion,
                              style: const TextStyle(color: Colores.textoSuave, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Ángulo actual contra objetivo
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${actual.clamp(0, 180).round()}°',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1)),
                    Text(' / ${objetivo.round()}°',
                        style: const TextStyle(fontSize: 18, color: Colores.textoSuave)),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        llego ? '¡Llegaste!' : 'Faltan $faltan°',
                        key: ValueKey(llego),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: llego ? Colores.verde : Colores.primario,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: avance,
                    minHeight: 12,
                    backgroundColor: Colores.azulSuave,
                    color: llego ? Colores.verde : Colores.primario,
                  ),
                ),
                const SizedBox(height: 16),
                // Repeticiones
                Row(
                  children: [
                    const Text('Repeticiones',
                        style: TextStyle(color: Colores.textoSuave, fontSize: 13)),
                    const Spacer(),
                    for (var i = 0; i < ejercicio.repeticionesTotal; i++)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < ejercicio.repeticion ? Colores.verde : Colores.azulSuave,
                        ),
                        child: i < ejercicio.repeticion
                            ? const Icon(Icons.check_rounded, size: 14, color: Colores.blanco)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('La repetición cuenta al volver la mano a la posición recta',
                    style: TextStyle(color: Colores.textoSuave, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
