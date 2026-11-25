import 'dart:async';
import 'package:flutter/material.dart';

class ClockWidget extends StatefulWidget {
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final bool autoScale; // false si quien lo usa ya multiplica el tamano por su propio factor

  const ClockWidget({
    super.key,
    this.color = Colors.white,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w700,
    this.autoScale = true,
  });

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  static const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  Timer? _timer;

  // El reloj se repinta cada segundo; hora y fecha se calculan al dibujar
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Crece con la pantalla (400 de ancho = 1) y un poco mas de base para que se lea de lejos
    final f = widget.autoScale ? (MediaQuery.of(context).size.width / 400).clamp(1.0, 1.5) * 1.2 : 1.0;
    final size = widget.fontSize * f;

    final now = DateTime.now();
    final hora12 = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final hora = '${hora12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour < 12 ? 'AM' : 'PM'}';
    final fecha = '${_dias[now.weekday - 1]} ${now.day} ${_meses[now.month - 1]}';

    // Hora grande arriba y fecha corta debajo
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          hora,
          style: TextStyle(
            color: widget.color,
            fontSize: size,
            fontWeight: widget.fontWeight,
            letterSpacing: 0.5,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          fecha,
          style: TextStyle(
            color: widget.color.withOpacity(0.85),
            fontSize: size * 0.68,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
