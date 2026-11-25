import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gnesys_as/services/resource_service.dart';

/// Imagen y color de marca de un programa de fidelidad: el logo se sirve desde la Orange (como los de las formas de pago)
/// y el color es el dominante de esa imagen.
class FidelityBrand {
  final String logoUrl;
  final Color color;

  const FidelityBrand({required this.logoUrl, required this.color});

  /// Version oscura del color, para titulos sobre fondo claro.
  Color get dark => _withLightness(color, 0.28);

  /// Version media, para textos secundarios.
  Color get mid => _withLightness(color, 0.40);

  /// Color del boton: el de marca, oscurecido si es muy claro para que el texto blanco se lea.
  Color get button {
    final hsl = HSLColor.fromColor(color);
    return hsl.lightness > 0.5 ? hsl.withLightness(0.42).toColor() : color;
  }

  static Color _withLightness(Color c, double lightness) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(lightness).withSaturation(hsl.saturation.clamp(0.0, 0.9)).toColor();
  }
}

class FidelityBrandService {
  static final Map<String, FidelityBrand?> _cache = {};

  /// Nombre de archivo en la Orange: minusculas y espacios como guion bajo ("Puntos Colombia" -> puntos_colombia.png).
  static String fileNameFor(String programName) => '${programName.trim().toLowerCase().replaceAll(' ', '_')}.png';

  /// Busca la imagen del programa (primero por su nombre y luego por los nombres alternos) y calcula su color.
  /// Devuelve null si no hay imagen.
  static Future<FidelityBrand?> load(String programName, {List<String> alternateFiles = const []}) async {
    final key = programName.trim().toLowerCase();
    if (_cache.containsKey(key)) return _cache[key];

    FidelityBrand? brand;
    for (final file in [fileNameFor(programName), ...alternateFiles]) {
      final url = await ResourceService.getImageUrl(file);
      final color = await _dominantColor(url);
      if (color != null) {
        brand = FidelityBrand(logoUrl: url, color: color);
        break;
      }
    }
    _cache[key] = brand;
    return brand;
  }

  static Future<Color?> _dominantColor(String url) async {
    final completer = Completer<ui.Image?>();
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    final image = await completer.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (image == null) return null;
    return dominantColorOf(image);
  }

  /// Color dominante de una imagen (ver [load]).
  static Future<Color?> dominantColorOf(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    // Promedio ponderado de los pixeles visibles: pesa mas lo saturado (el color de marca) que el blanco o el gris
    final step = ((image.width * image.height) ~/ 4000).clamp(1, 1 << 20);
    double r = 0, g = 0, b = 0, total = 0;
    for (int i = 0; i < image.width * image.height; i += step) {
      final o = i * 4;
      final a = data.getUint8(o + 3) / 255.0;
      if (a < 0.5) continue;
      final pr = data.getUint8(o) / 255.0, pg = data.getUint8(o + 1) / 255.0, pb = data.getUint8(o + 2) / 255.0;
      final hsv = HSVColor.fromColor(Color.fromARGB(255, data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2)));
      final weight = a * hsv.saturation * hsv.saturation * (hsv.value > 0.15 ? 1.0 : 0.1);
      if (weight <= 0.0001) continue;
      r += pr * weight;
      g += pg * weight;
      b += pb * weight;
      total += weight;
    }
    if (total <= 0) return const Color(0xFF546E7A); // logo sin color (gris): se usa un gris azulado
    return Color.fromARGB(255, (r / total * 255).round().clamp(0, 255), (g / total * 255).round().clamp(0, 255), (b / total * 255).round().clamp(0, 255));
  }
}
