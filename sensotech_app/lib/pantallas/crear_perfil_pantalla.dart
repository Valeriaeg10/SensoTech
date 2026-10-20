import 'package:flutter/material.dart';
import '../modelos/perfil.dart';
import '../tema/colores.dart';
import '../widgets/icono_chip.dart';

// Formulario para registrar un usuario nuevo (solo el nombre)
class CrearPerfilPantalla extends StatefulWidget {
  const CrearPerfilPantalla({super.key});

  @override
  State<CrearPerfilPantalla> createState() => _CrearPerfilPantallaState();
}

class _CrearPerfilPantallaState extends State<CrearPerfilPantalla> {
  final _nombre = TextEditingController();

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
            const Center(child: IconoChip(icono: Icons.person_add_alt_1_rounded, tamano: 80)),
            const SizedBox(height: 24),
            const Text('Nombre', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nombre,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _guardar(),
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
