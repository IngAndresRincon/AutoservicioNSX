import 'package:flutter/widgets.dart';

/// Escala toda la interfaz en pantallas grandes: la app se dibuja con el tamano de una tablet de referencia (800 de lado corto)
/// y se amplia de forma uniforme al tamano real, asi botones, logo, campos y textos guardan siempre la misma proporcion.
/// En pantallas iguales o menores a la referencia no cambia nada.
class ScaleToScreen extends StatelessWidget {
  static const double referenceShortSide = 800;
  static const double maxScale = 2.5;

  final Widget child;
  const ScaleToScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = (media.size.shortestSide / referenceShortSide).clamp(1.0, maxScale);
    if (scale <= 1.001) return child;

    final inner = media.size / scale;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: inner.width,
        height: inner.height,
        child: MediaQuery(
          data: media.copyWith(
            size: inner,
            padding: media.padding / scale,
            viewPadding: media.viewPadding / scale,
            viewInsets: media.viewInsets / scale,
            systemGestureInsets: media.systemGestureInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Amplia un contenido pensado para un tamano de referencia hasta ocupar todo el espacio disponible, de forma uniforme:
/// textos, botones, iconos y espacios crecen juntos. Con espacio menor o igual al de referencia no cambia nada.
///
/// Con [fitControllers] (los controladores de los scrolls del contenido) tambien se ajusta al alto real: si el contenido
/// no cabe y hay que hacer scroll, reduce la escala hasta que quepa (sin bajar de [minScale]). Es para pantallas que el
/// cliente no debe scrollear.
class ScaleUp extends StatefulWidget {
  final Size reference;
  final double maxScale;
  final double minScale;
  final List<ScrollController> fitControllers;
  final Widget child;

  const ScaleUp({
    super.key,
    required this.reference,
    required this.child,
    this.maxScale = 2.0,
    this.minScale = 1.0,
    this.fitControllers = const [],
  });

  @override
  State<ScaleUp> createState() => _ScaleUpState();
}

class _ScaleUpState extends State<ScaleUp> {
  double _fit = 1.0; // factor de reduccion para que el contenido quepa
  Size? _lastBox;
  int _passes = 0;

  void _checkFit(double scale) {
    if (!mounted || widget.fitControllers.isEmpty) return;
    double worst = 1.0;
    for (final c in widget.fitControllers) {
      if (!c.hasClients) continue;
      final p = c.position;
      if (p.maxScrollExtent > 1.0) {
        final f = p.viewportDimension / (p.viewportDimension + p.maxScrollExtent);
        if (f < worst) worst = f;
      }
    }
    if (worst >= 0.999 || _passes >= 6) return;
    _passes++;
    final base = scale / _fit;
    final next = ((scale * worst * 0.995).clamp(widget.minScale, widget.maxScale)) / base;
    if ((next - _fit).abs() > 0.002) setState(() => _fit = next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedWidth || !box.hasBoundedHeight) return widget.child;

        final size = Size(box.maxWidth, box.maxHeight);
        if (_lastBox != size) {
          _lastBox = size;
          _fit = 1.0;
          _passes = 0;
        }

        final byW = box.maxWidth / widget.reference.width;
        final byH = box.maxHeight / widget.reference.height;
        final base = (byW < byH ? byW : byH).clamp(widget.minScale, widget.maxScale);
        final scale = (base * _fit).clamp(widget.minScale, widget.maxScale);

        WidgetsBinding.instance.addPostFrameCallback((_) => _checkFit(scale));

        if (scale > 0.999 && scale < 1.001) return widget.child;

        final inner = Size(box.maxWidth / scale, box.maxHeight / scale);
        final media = MediaQuery.of(context);
        // Restricciones firmes: con las sueltas de un Scaffold el FittedBox se quedaba del tamano del contenido sin ampliarlo
        return SizedBox(
          width: box.maxWidth,
          height: box.maxHeight,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: inner.width,
              height: inner.height,
              child: MediaQuery(
                data: media.copyWith(
                  size: inner,
                  padding: media.padding / scale,
                  viewPadding: media.viewPadding / scale,
                  viewInsets: media.viewInsets / scale,
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
