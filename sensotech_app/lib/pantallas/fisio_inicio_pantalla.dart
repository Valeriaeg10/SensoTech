import 'package:flutter/material.dart';
import '../modelos/cuenta.dart';
import '../servicios/datos_demo.dart';
import '../servicios/nube.dart';
import '../servicios/resumen_paciente.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/icono_chip.dart';
import 'agregar_paciente_pantalla.dart';
import 'arranque.dart';
import 'paciente_ficha_pantalla.dart';

// Inicio del fisioterapeuta: sus pacientes (él los agrega) y su seguimiento
class FisioInicioPantalla extends StatefulWidget {
  final Cuenta cuenta;

  const FisioInicioPantalla({super.key, required this.cuenta});

  @override
  State<FisioInicioPantalla> createState() => _FisioInicioPantallaState();
}

class _FisioInicioPantallaState extends State<FisioInicioPantalla> {
  List<ResumenPaciente>? _pacientes;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cuentas = await nube.pacientesDe(widget.cuenta.id);
    final resumenes = <ResumenPaciente>[];
    for (final c in cuentas) {
      resumenes.add(await ResumenPaciente.cargar(c));
    }
    if (mounted) setState(() => _pacientes = resumenes);
  }

  Future<void> _cargarDemo() async {
    setState(() => _pacientes = null);
    await crearPacientesDemo(widget.cuenta);
    await _cargar();
  }

  Future<void> _agregar() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AgregarPacientePantalla(fisio: widget.cuenta)),
    );
    if (creado == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final lista = _pacientes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pacientes'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => cerrarSesion(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Agregar paciente'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
            children: [
              _tarjetaFisio(lista?.length),
              const SizedBox(height: 16),
              if (lista == null)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (lista.isEmpty)
                _vacio()
              else ...[
                _resumenGeneral(lista),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Buscar paciente',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colores.blanco,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colores.borde),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colores.borde),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final p in lista.where((x) => x.cuenta.nombre.toLowerCase().contains(_filtro))) ...[
                  _filaPaciente(p),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaFisio(int? pacientes) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5AB0FF), Colores.primarioOscuro]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colores.blanco,
            child: Text(widget.cuenta.iniciales,
                style: const TextStyle(color: Colores.primario, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.cuenta.nombre,
                    style: const TextStyle(color: Colores.blanco, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Fisioterapeuta · TP ${widget.cuenta.tarjetaProfesional ?? '—'}',
                    style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12)),
                const SizedBox(height: 6),
                Text(pacientes == null ? '' : '$pacientes pacientes en seguimiento',
                    style: const TextStyle(color: Colores.blanco, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cuántos pacientes hay en cada estado de constancia
  Widget _resumenGeneral(List<ResumenPaciente> l) {
    int n(Constancia c) => l.where((x) => x.constancia == c).length;
    return Row(
      children: [
        Expanded(child: _contador('Al día', n(Constancia.alDia), Colores.verde)),
        const SizedBox(width: 10),
        Expanded(child: _contador('Faltó a 1', n(Constancia.pendiente), Colores.amarillo)),
        const SizedBox(width: 10),
        Expanded(child: _contador('Faltó a 2+', n(Constancia.inactivo), Colores.rojo)),
      ],
    );
  }

  Widget _contador(String titulo, int n, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(titulo, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _filaPaciente(ResumenPaciente p) {
    final (color, texto) = switch (p.constancia) {
      Constancia.alDia => (Colores.verde, 'Al día'),
      Constancia.pendiente => (Colores.amarillo, 'Faltó 1'),
      Constancia.inactivo => (Colores.rojo, 'Faltó 2+'),
      Constancia.sinProgramar => (Colores.textoSuave, 'Sin agenda'),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PacienteFichaPantalla(resumen: p, fisio: widget.cuenta)),
        );
        _cargar(); // por si cambió la rutina
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: decoracionTarjeta(),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colores.azulSuave,
              child: Text(p.cuenta.iniciales,
                  style: const TextStyle(color: Colores.primario, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.cuenta.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(p.textoActividad, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colores.textoSuave),
          ],
        ),
      ),
    );
  }

  Widget _vacio() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: decoracionTarjeta(),
      child: Column(
        children: [
          const IconoChip(icono: Icons.group_add_rounded, tamano: 72),
          const SizedBox(height: 14),
          const Text('Aún no tienes pacientes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Agrega a tu paciente con su historia clínica. La app le crea una cuenta con contraseña temporal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colores.textoSuave),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _agregar,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Agregar paciente'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _cargarDemo,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Cargar pacientes de demostración'),
          ),
        ],
      ),
    );
  }
}
