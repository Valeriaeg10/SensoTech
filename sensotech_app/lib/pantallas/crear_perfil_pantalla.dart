import 'package:flutter/material.dart';
import '../modelos/perfil.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/icono_chip.dart';

// Formulario para registrar un usuario nuevo
class CrearPerfilPantalla extends StatefulWidget {
  const CrearPerfilPantalla({super.key});

  @override
  State<CrearPerfilPantalla> createState() => _CrearPerfilPantallaState();
}

class _CrearPerfilPantallaState extends State<CrearPerfilPantalla> {
  final _nombre = TextEditingController();
  TipoTrabajo _tipo = TipoTrabajo.administrativo;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre')),
      );
      return;
    }
    final perfil = Perfil(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: nombre,
      tipoTrabajo: _tipo,
      creado: DateTime.now(),
    );
    Navigator.pop(context, perfil); // devuelve el perfil a la lista
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Nombre', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Ej: Laura Gómez',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: Colores.primario),
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
            const SizedBox(height: 24),
            const Text('Tipo de trabajo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _OpcionTipo(
              titulo: 'Administrativo',
              detalle: 'Pausa activa cada 60 min',
              icono: Icons.computer_rounded,
              seleccionada: _tipo == TipoTrabajo.administrativo,
              alTocar: () => setState(() => _tipo = TipoTrabajo.administrativo),
            ),
            const SizedBox(height: 10),
            _OpcionTipo(
              titulo: 'Repetitivo',
              detalle: 'Pausa activa cada 45 min',
              icono: Icons.precision_manufacturing_rounded,
              seleccionada: _tipo == TipoTrabajo.repetitivo,
              alTocar: () => setState(() => _tipo = TipoTrabajo.repetitivo),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Guardar perfil'),
            ),
          ],
        ),
      ),
    );
  }
}

// Tarjeta seleccionable para el tipo de trabajo
class _OpcionTipo extends StatelessWidget {
  final String titulo;
  final String detalle;
  final IconData icono;
  final bool seleccionada;
  final VoidCallback alTocar;

  const _OpcionTipo({
    required this.titulo,
    required this.detalle,
    required this.icono,
    required this.seleccionada,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: decoracionTarjeta().copyWith(
          border: Border.all(
            color: seleccionada ? Colores.primario : Colores.borde,
            width: seleccionada ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            IconoChip(icono: icono),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(detalle, style: const TextStyle(color: Colores.textoSuave)),
                ],
              ),
            ),
            Icon(
              seleccionada ? Icons.radio_button_checked : Icons.radio_button_off,
              color: seleccionada ? Colores.primario : Colores.textoSuave,
            ),
          ],
        ),
      ),
    );
  }
}
