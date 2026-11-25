import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teclado numerico con el mismo estilo del de identificacion. Las teclas ocupan el alto disponible hasta una proporcion
/// maxima respecto a su ancho; si sobra alto, el teclado queda pegado abajo en vez de estirarse.
class NumericKeypad extends StatelessWidget {
  final Color accentColor;
  final void Function(String key) onKey;
  final VoidCallback onBackspace;
  final String extraKey; // tecla del hueco inferior izquierdo (p. ej. '000' o '.'); vacia si no hay

  const NumericKeypad({
    super.key,
    required this.accentColor,
    required this.onKey,
    required this.onBackspace,
    this.extraKey = '',
  });

  static const List<List<String>> _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'BACKSPACE'],
  ];

  // Alto maximo de una tecla respecto a su ancho
  static const double _maxKeyAspect = 0.85;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyWidth = constraints.maxWidth / 3;
        final byWidth = keyWidth * _maxKeyAspect;
        final byHeight = constraints.hasBoundedHeight ? constraints.maxHeight / _rows.length : byWidth;
        final rowHeight = byHeight < byWidth ? byHeight : byWidth;

        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: SizedBox(
            height: rowHeight * _rows.length,
            child: Column(
              children: [
                for (final row in _rows)
                  Expanded(
                    child: Row(
                      children: [for (final key in row) Expanded(child: _buildKey(key.isEmpty ? extraKey : key))],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKey(String label) {
    if (label.isEmpty) {
      return const Padding(padding: EdgeInsets.all(3.0));
    }

    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        elevation: 1.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          splashColor: accentColor.withOpacity(0.15),
          highlightColor: accentColor.withOpacity(0.08),
          onTap: () {
            HapticFeedback.lightImpact();
            if (label == 'BACKSPACE') {
              onBackspace();
            } else {
              onKey(label);
            }
          },
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (label == 'BACKSPACE') {
                  return Icon(
                    Icons.backspace_outlined,
                    size: (constraints.maxHeight * 0.4).clamp(22.0, double.infinity),
                    color: Colors.black.withOpacity(0.6),
                  );
                }
                return Text(
                  label,
                  style: TextStyle(
                    fontSize: (constraints.maxHeight * (label.length > 1 ? 0.32 : 0.45)).clamp(18.0, double.infinity),
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
