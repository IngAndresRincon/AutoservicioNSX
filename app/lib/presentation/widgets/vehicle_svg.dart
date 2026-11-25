import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

enum VehicleKind { carro, camioneta, camion }

/// Vehiculo segun el producto: diesel camion, extra camioneta, el resto carro
VehicleKind vehicleForProduct(String? product) {
  final p = (product ?? '').toUpperCase();
  if (p.contains('DIESEL') || p.contains('DIÉSEL') || p.contains('ACPM')) return VehicleKind.camion;
  if (p.contains('EXTRA')) return VehicleKind.camioneta;
  return VehicleKind.carro;
}

/// Vehiculo futurista (assets/vehicles) pintado con el color del producto: neon y carroceria teñida, con brillo
class VehicleSvg extends StatefulWidget {
  final VehicleKind kind;
  final Color color;

  const VehicleSvg({super.key, required this.kind, required this.color});

  @override
  State<VehicleSvg> createState() => _VehicleSvgState();
}

class _VehicleSvgState extends State<VehicleSvg> {
  static final Map<VehicleKind, String> _templates = {};

  String? _svg;
  Widget? _picture;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(covariant VehicleSvg old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind || old.color != widget.color) _build();
  }

  Future<void> _build() async {
    final kind = widget.kind;
    final color = widget.color;
    var template = _templates[kind];
    if (template == null) {
      try {
        template = await rootBundle.loadString('assets/vehicles/${kind.name}.svg');
      } catch (_) {
        return;
      }
      _templates[kind] = template;
    }
    if (!mounted || kind != widget.kind || color != widget.color) return;
    final svg = template
        .replaceAll('@NEON@', _hex(color))
        .replaceAll('@LIGHT@', _hex(_lighten(color, 0.72)))
        .replaceAll('@BODY1@', _hex(_darken(color, 0.30)))
        .replaceAll('@BODY2@', _hex(_darken(color, 0.07)))
        .replaceAll('@MID@', _hex(_darken(color, 0.18)));
    setState(() {
      _svg = svg;
      _picture = SvgPicture.string(svg, fit: BoxFit.contain);
    });
  }

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Color _darken(Color c, double t) =>
      Color.fromARGB(255, (c.r * 255 * t).round(), (c.g * 255 * t).round(), (c.b * 255 * t).round());

  static Color _lighten(Color c, double t) => Color.fromARGB(
        255,
        (c.r * 255 + (255 - c.r * 255) * t).round(),
        (c.g * 255 + (255 - c.g * 255) * t).round(),
        (c.b * 255 + (255 - c.b * 255) * t).round(),
      );

  @override
  Widget build(BuildContext context) {
    final picture = _picture;
    if (_svg == null || picture == null) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Brillo: copia desenfocada debajo
        Opacity(
          opacity: 0.55,
          child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: picture),
        ),
        picture,
      ],
    );
  }
}
