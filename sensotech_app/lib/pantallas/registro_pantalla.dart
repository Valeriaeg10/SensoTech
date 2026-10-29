import 'package:flutter/material.dart';
import '../modelos/cuenta.dart';
import '../servicios/nube.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/campo_texto.dart';
import '../widgets/icono_chip.dart';
import 'arranque.dart';

// Crear cuenta: nombre, correo, contraseña, rol y autorización de datos
class RegistroPantalla extends StatefulWidget {
  const RegistroPantalla({super.key});

  @override
  State<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends State<RegistroPantalla> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  final _tarjeta = TextEditingController();
  Rol _rol = Rol.paciente;
  bool _acepta = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _clave, _clave2, _tarjeta]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    if (!_acepta) {
      setState(() => _error = 'Debes autorizar el tratamiento de datos para continuar');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final cuenta = await nube.registrar(
        nombre: _nombre.text,
        correo: _correo.text,
        contrasena: _clave.text,
        rol: _rol,
        tarjetaProfesional: _rol == Rol.fisioterapeuta ? _tarjeta.text : null,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text('¿Cómo vas a usar SensoTech?', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _opcionRol(Rol.paciente, Icons.person_rounded, 'Uso el brazalete (prevención)'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _opcionRol(Rol.fisioterapeuta, Icons.medical_services_rounded, 'Sigo pacientes'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CampoTexto(
                controlador: _nombre,
                etiqueta: 'Nombre completo',
                icono: Icons.badge_outlined,
                mayusculas: TextCapitalization.words,
                validar: (v) => v.trim().length < 3 ? 'Escribe tu nombre' : null,
              ),
              if (_rol == Rol.fisioterapeuta) ...[
                const SizedBox(height: 14),
                CampoTexto(
                  controlador: _tarjeta,
                  etiqueta: 'Tarjeta profesional (RETHUS)',
                  icono: Icons.verified_outlined,
                  validar: (v) => v.trim().length < 4 ? 'Necesaria para firmar los informes' : null,
                ),
              ],
              const SizedBox(height: 14),
              CampoTexto(
                controlador: _correo,
                etiqueta: 'Correo',
                icono: Icons.mail_outline_rounded,
                teclado: TextInputType.emailAddress,
                validar: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())
                    ? null
                    : 'Escribe un correo válido',
              ),
              const SizedBox(height: 14),
              CampoTexto(
                controlador: _clave,
                etiqueta: 'Contraseña',
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
              const SizedBox(height: 16),
              // Ley 1581 de 2012: los datos de salud son sensibles
              InkWell(
                onTap: () => setState(() => _acepta = !_acepta),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(value: _acepta, onChanged: (v) => setState(() => _acepta = v ?? false)),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Autorizo el tratamiento de mis datos personales y de salud para el seguimiento '
                          'de prevención y rehabilitación (Ley 1581 de 2012).',
                          style: TextStyle(fontSize: 12, color: Colores.textoSuave),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colores.rojo)),
                ),
              FilledButton.icon(
                onPressed: _cargando ? null : _crear,
                icon: const Icon(Icons.check_rounded),
                label: Text(_cargando ? 'Creando…' : 'Crear cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcionRol(Rol rol, IconData icono, String detalle) {
    final sel = _rol == rol;
    return GestureDetector(
      onTap: () => setState(() => _rol = rol),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: decoracionTarjeta().copyWith(
          border: Border.all(color: sel ? Colores.primario : Colores.borde, width: sel ? 2 : 1),
        ),
        child: Column(
          children: [
            IconoChip(icono: icono, tamano: 44),
            const SizedBox(height: 8),
            Text(rol.texto, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(detalle, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
