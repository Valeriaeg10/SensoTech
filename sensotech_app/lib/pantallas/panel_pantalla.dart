import 'dart:async';
import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/perfil.dart';
import '../servicios/brazalete.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/icono_chip.dart';
import '../widgets/indicador_estado.dart';
import '../widgets/vista_brazo.dart';

// Panel principal: conexión, estado y brazo en tiempo real
class PanelPantalla extends StatefulWidget {
  final Perfil perfil;
  final Brazalete brazalete;

  const PanelPantalla({super.key, required this.perfil, required this.brazalete});

  @override
  State<PanelPantalla> createState() => _PanelPantallaState();
}

class _PanelPantallaState extends State<PanelPantalla> {
  StreamSubscription<LecturaEnVivo>? _sub;
  LecturaEnVivo? _ultima;
  bool _conectando = false;

  Brazalete get _b => widget.brazalete;

  @override
  void initState() {
    super.initState();
    // Escucha las lecturas mientras esta pantalla esté abierta
    _sub = _b.lecturas.listen((l) => setState(() => _ultima = l));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _b.desconectar();
    super.dispose();
  }

  Future<void> _alternarConexion() async {
    if (_b.conectado) {
      await _b.desconectar();
      setState(() => _ultima = null);
      return;
    }
    setState(() => _conectando = true);
    await _b.conectar();
    if (!mounted) return;
    setState(() => _conectando = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = _ultima;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.perfil.nombre),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.work_outline, size: 18, color: Colores.primario),
              label: Text(widget.perfil.tipoTexto),
              backgroundColor: Colores.azulSuave,
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _tarjetaConexion(),
            const SizedBox(height: 16),
            if (_b.conectado && l != null) ...[
              IndicadorEstado(estado: l.estado),
              const SizedBox(height: 16),
              _tarjetaVista(
                icono: Icons.swap_vert_rounded,
                titulo: 'Vista lateral',
                detalle: 'Flexión y extensión',
                vista: TipoVista.lateral,
                l: l,
              ),
              const SizedBox(height: 16),
              _tarjetaVista(
                icono: Icons.swap_horiz_rounded,
                titulo: 'Vista superior',
                detalle: 'Hacia el pulgar o el meñique',
                vista: TipoVista.superior,
                l: l,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _tarjetaAngulo(Icons.pan_tool_alt_outlined, 'Flexión', l.flexion)),
                  const SizedBox(width: 10),
                  Expanded(child: _tarjetaAngulo(Icons.open_with_rounded, 'Desviación', l.desviacion)),
                  const SizedBox(width: 10),
                  Expanded(child: _tarjetaAngulo(Icons.straighten_rounded, 'Antebrazo', l.antebrazo)),
                ],
              ),
            ] else
              _mensajeSinConexion(),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaConexion() {
    final conectado = _b.conectado;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(
        children: [
          Row(
            children: [
              IconoChip(
                icono: conectado ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conectado ? _b.nombre : 'Brazalete desconectado',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(conectado ? 'Recibiendo datos' : 'Toca conectar para empezar',
                        style: const TextStyle(color: Colores.textoSuave, fontSize: 13)),
                  ],
                ),
              ),
              if (conectado) ...[
                const Icon(Icons.battery_5_bar_rounded, size: 20, color: Colores.verde),
                Text(' ${_b.bateria} %',
                    style: const TextStyle(color: Colores.textoSuave, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          conectado
              ? OutlinedButton.icon(
                  onPressed: _alternarConexion,
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Desconectar'),
                )
              : FilledButton.icon(
                  onPressed: _conectando ? null : _alternarConexion,
                  icon: _conectando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colores.blanco),
                        )
                      : const Icon(Icons.bluetooth_searching_rounded),
                  label: Text(_conectando ? 'Buscando…' : 'Conectar brazalete'),
                ),
        ],
      ),
    );
  }

  Widget _tarjetaVista({
    required IconData icono,
    required String titulo,
    required String detalle,
    required TipoVista vista,
    required LecturaEnVivo l,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoChip(icono: icono, tamano: 34),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(detalle, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          VistaBrazo(
            vista: vista,
            flexion: l.flexion,
            desviacion: l.desviacion,
            antebrazo: l.antebrazo,
            colorEstado: colorDeEstado(l.estado),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaAngulo(IconData icono, String titulo, double valor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: Colores.primario),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
          Text('${valor.toStringAsFixed(1)}°',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _mensajeSinConexion() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: decoracionTarjeta(),
      child: const Column(
        children: [
          IconoChip(icono: Icons.watch_rounded, tamano: 64),
          SizedBox(height: 14),
          Text('Sin brazalete conectado',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 4),
          Text('Conéctalo para ver el brazo y la mano en tiempo real',
              textAlign: TextAlign.center, style: TextStyle(color: Colores.textoSuave)),
        ],
      ),
    );
  }
}
