import 'package:flutter/material.dart';
import '../tema/colores.dart';

// Campo de texto con el estilo de la app
class CampoTexto extends StatefulWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final IconData icono;
  final bool clave; // oculta el texto (contraseña)
  final TextInputType teclado;
  final String? Function(String)? validar;
  final TextCapitalization mayusculas;

  const CampoTexto({
    super.key,
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    this.clave = false,
    this.teclado = TextInputType.text,
    this.validar,
    this.mayusculas = TextCapitalization.none,
  });

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _oculto = true;

  OutlineInputBorder _borde(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controlador,
      obscureText: widget.clave && _oculto,
      keyboardType: widget.teclado,
      textCapitalization: widget.mayusculas,
      validator: widget.validar == null ? null : (v) => widget.validar!(v ?? ''),
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        prefixIcon: Icon(widget.icono, color: Colores.primario),
        suffixIcon: widget.clave
            ? IconButton(
                icon: Icon(_oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colores.textoSuave),
                onPressed: () => setState(() => _oculto = !_oculto),
              )
            : null,
        filled: true,
        fillColor: Colores.blanco,
        border: _borde(Colores.borde),
        enabledBorder: _borde(Colores.borde),
        focusedBorder: _borde(Colores.primario),
      ),
    );
  }
}
