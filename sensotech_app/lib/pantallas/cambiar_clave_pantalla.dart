import 'package:flutter/material.dart';
import '../modelos/cuenta.dart';
import '../servicios/nube.dart';
import '../tema/colores.dart';
import '../widgets/campo_texto.dart';
import '../widgets/icono_chip.dart';
import 'arranque.dart';

// Primer ingreso de un paciente creado por el fisio: cambia la contraseña temporal
class CambiarClavePantalla extends StatefulWidget {
  final Cuenta cuenta;

  const CambiarClavePantalla({super.key, required this.cuenta});

  @override
  State<CambiarClavePantalla> createState() => _CambiarClavePantallaState();
}

class _CambiarClavePantallaState extends State<CambiarClavePantalla> {
  final _form = GlobalKey<FormState>();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _clave.dispose();
    _clave2.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final nueva = await nube.cambiarClave(widget.cuenta, _clave.text);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => inicioSegunRol(nueva)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea tu contraseña'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => cerrarSesion(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Center(child: IconoChip(icono: Icons.lock_reset_rounded, tamano: 72)),
              const SizedBox(height: 16),
              Text('Hola, ${widget.cuenta.nombre.split(' ').first}',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Tu fisioterapeuta creó tu cuenta con una contraseña temporal. Crea ahora tu propia contraseña.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colores.textoSuave),
              ),
              const SizedBox(height: 24),
              CampoTexto(
                controlador: _clave,
                etiqueta: 'Nueva contraseña',
                icono: Icons.lock_outline_rounded,
                clave: true,
                validar: (v) => v.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 14),
              CampoTexto(
                controlador: _clave2,
                etiqueta: 'Repite la contraseña',
                icono: Icons.lock_outline_rounded,
                clave: true,
                validar: (v) => v != _clave.text ? 'Las contraseñas no coinciden' : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Guardar y continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
