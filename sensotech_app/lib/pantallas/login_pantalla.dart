import 'package:flutter/material.dart';
import '../servicios/nube.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/campo_texto.dart';
import '../widgets/logo.dart';
import 'arranque.dart';
import 'registro_pantalla.dart';

// Iniciar sesión con correo y contraseña
class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final cuenta = await nube.iniciarSesion(_correo.text, _clave.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => inicioSegunRol(cuenta)),
        (_) => false,
      );
    } on ErrorCuenta catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _olvido() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: const Text(
            'Cuando la app esté conectada al servidor, aquí llegará un correo para crear una contraseña nueva.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            children: [
              const LogoSensoTech(),
              const SizedBox(height: 40),
              const Text('Iniciar sesión', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              CampoTexto(
                controlador: _correo,
                etiqueta: 'Correo',
                icono: Icons.mail_outline_rounded,
                teclado: TextInputType.emailAddress,
                validar: (v) => v.contains('@') ? null : 'Escribe un correo válido',
              ),
              const SizedBox(height: 14),
              CampoTexto(
                controlador: _clave,
                etiqueta: 'Contraseña',
                icono: Icons.lock_outline_rounded,
                clave: true,
                validar: (v) => v.isEmpty ? 'Escribe tu contraseña' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _olvido, child: const Text('¿Olvidaste tu contraseña?')),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colores.rojo.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colores.rojo),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colores.rojo))),
                    ],
                  ),
                ),
              FilledButton.icon(
                onPressed: _cargando ? null : _ingresar,
                icon: _cargando
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colores.blanco))
                    : const Icon(Icons.login_rounded),
                label: const Text('Ingresar'),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: decoracionTarjeta(),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('¿No tienes cuenta?', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegistroPantalla()),
                      ),
                      child: const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
