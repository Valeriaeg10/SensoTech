import 'package:flutter/material.dart';
import '../modelos/cuenta.dart';
import '../modelos/perfil.dart';
import '../servicios/brazalete.dart';
import '../servicios/brazalete_simulado.dart';
import '../servicios/nube.dart';
import '../servicios/repositorio_perfiles.dart';
import '../widgets/logo.dart';
import 'cambiar_clave_pantalla.dart';
import 'fisio_inicio_pantalla.dart';
import 'login_pantalla.dart';
import 'panel_pantalla.dart';

// Un solo brazalete para toda la app (simulado por ahora)
final Brazalete brazaleteApp = BrazaleteSimulado();

// Pantalla inicial según el rol de la cuenta
Widget inicioSegunRol(Cuenta c) {
  if (c.debeCambiarClave) return CambiarClavePantalla(cuenta: c); // primer ingreso con clave temporal
  return c.esFisio ? FisioInicioPantalla(cuenta: c) : InicioPaciente(cuenta: c);
}

// Al abrir la app: si hay sesión abierta entra directo, si no, al login
class Arranque extends StatefulWidget {
  const Arranque({super.key});

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  @override
  void initState() {
    super.initState();
    _decidir();
  }

  Future<void> _decidir() async {
    Cuenta? c;
    try {
      c = await nube.sesionActual().timeout(const Duration(seconds: 5));
    } catch (_) {
      c = null; // ante cualquier error, al login
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => c == null ? const LoginPantalla() : inicioSegunRol(c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: LogoSensoTech(tamano: 96, conNombre: false)),
    );
  }
}

// Paciente: busca (o crea) sus preferencias del brazalete y abre el panel
class InicioPaciente extends StatefulWidget {
  final Cuenta cuenta;

  const InicioPaciente({super.key, required this.cuenta});

  @override
  State<InicioPaciente> createState() => _InicioPacienteState();
}

class _InicioPacienteState extends State<InicioPaciente> {
  Perfil? _perfil;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final repo = RepositorioPerfiles();
    final todos = await repo.leerTodos();
    Perfil? p;
    for (final x in todos) {
      if (x.id == widget.cuenta.id) p = x;
    }
    if (p == null) {
      p = Perfil(id: widget.cuenta.id, nombre: widget.cuenta.nombre, creado: widget.cuenta.creado);
      await repo.guardar(p);
    }
    if (mounted) setState(() => _perfil = p);
  }

  @override
  Widget build(BuildContext context) {
    final p = _perfil;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return PanelPantalla(perfil: p, cuenta: widget.cuenta, brazalete: brazaleteApp);
  }
}

// Cierra la sesión y vuelve al login
Future<void> cerrarSesion(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Quieres salir de tu cuenta?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
      ],
    ),
  );
  if (ok != true) return;
  await brazaleteApp.desconectar();
  await nube.cerrarSesion();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPantalla()),
    (_) => false,
  );
}
