import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/perfil.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import 'icono_chip.dart';
import 'indicador_estado.dart';
import 'cache_brazo.dart';
import 'vista_brazo.dart';

// Brazo en vivo: vista lateral y superior al mismo tiempo, para la mano elegida
class TarjetaMovimiento extends StatefulWidget {
  final LecturaEnVivo lectura;
  final Mano? mano; // null = preguntar primero
  final ValueChanged<Mano> alElegirMano;

  const TarjetaMovimiento({
    super.key,
    required this.lectura,
    required this.mano,
    required this.alElegirMano,
  });

  @override
  State<TarjetaMovimiento> createState() => _TarjetaMovimientoState();
}

class _TarjetaMovimientoState extends State<TarjetaMovimiento> {
  @override
  void initState() {
    super.initState();
    // Carga las imágenes del brazo una sola vez
    CacheBrazo.cargar().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final mano = widget.mano;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoChip(icono: Icons.accessibility_new_rounded, tamano: 34),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Movimiento en vivo', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              // Cambiar de mano en cualquier momento
              if (mano != null)
                ActionChip(
                  avatar: const Icon(Icons.pan_tool_outlined, size: 16, color: Colores.primario),
                  label: Text(mano == Mano.derecha ? 'Derecha' : 'Izquierda'),
                  backgroundColor: Colores.azulSuave,
                  side: BorderSide.none,
                  onPressed: () => widget.alElegirMano(mano == Mano.derecha ? Mano.izquierda : Mano.derecha),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (mano == null)
            _elegirMano()
          else if (CacheBrazo.error != null)
            Text(CacheBrazo.error!, style: const TextStyle(color: Colores.rojo))
          else if (!CacheBrazo.listo)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._vistas(mano == Mano.izquierda),
        ],
      ),
    );
  }

  // Primera vez: en qué mano lleva el brazalete
  Widget _elegirMano() {
    return Column(
      children: [
        const Text('¿En qué mano llevas el brazalete?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Así el dibujo muestra tu mano tal como la mueves',
            style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _botonMano(Mano.izquierda, 'Izquierda')),
            const SizedBox(width: 10),
            Expanded(child: _botonMano(Mano.derecha, 'Derecha')),
          ],
        ),
      ],
    );
  }

  Widget _botonMano(Mano m, String texto) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
      onPressed: () => widget.alElegirMano(m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // El ícono de la mano izquierda va en espejo
          Transform.flip(
            flipX: m == Mano.izquierda,
            child: const Icon(Icons.back_hand_outlined),
          ),
          Text(texto),
        ],
      ),
    );
  }

  // Las dos vistas, una debajo de la otra
  List<Widget> _vistas(bool izquierda) {
    final l = widget.lectura;
    final color = colorDeEstado(l.estado);
    Widget subtitulo(String t, String d) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 6),
              Text(d, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
            ],
          ),
        );
    return [
      subtitulo('Plano sagital', 'flexión palmar y extensión'),
      VistaBrazo(
        vista: TipoVista.lateral,
        lectura: l,
        colorEstado: color,
        izquierda: izquierda,
      ),
      const SizedBox(height: 12),
      subtitulo('Plano frontal', 'desviación radial y cubital'),
      VistaBrazo(
        vista: TipoVista.superior,
        lectura: l,
        colorEstado: color,
        izquierda: izquierda,
      ),
      const SizedBox(height: 10),
      const Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _ItemLeyenda(numero: '1', texto: 'IMU antebrazo'),
          _ItemLeyenda(numero: '2', texto: 'IMU mano'),
          _ItemLeyenda(texto: 'Mano recta', punteada: true),
        ],
      ),
    ];
  }
}

class _ItemLeyenda extends StatelessWidget {
  final String? numero;
  final String texto;
  final bool punteada;

  const _ItemLeyenda({this.numero, required this.texto, this.punteada = false});

  @override
  Widget build(BuildContext context) {
    final Widget marca;
    if (punteada) {
      marca = const Text('- - -', style: TextStyle(color: Colores.textoSuave, fontWeight: FontWeight.w700));
    } else {
      marca = Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colores.primario, shape: BoxShape.circle),
        child: Text(numero ?? '',
            style: const TextStyle(color: Colores.blanco, fontSize: 10, fontWeight: FontWeight.w700)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marca,
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
      ],
    );
  }
}
