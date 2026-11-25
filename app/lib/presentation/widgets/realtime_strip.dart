import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'vehicle_svg.dart';

/// Franja inferior con el tiempo real de la venta: valor, galones, PPU y un vehiculo que avanza hacia la meta.
/// Va sobre el video de publicidad: es baja y semitransparente para no taparlo.
class RealtimeStrip extends StatefulWidget {
  final double money;
  final double volume;
  final double? ppu; // null: no se muestra (credito)
  final double? progress; // 0..1; null: sin tope (lleno), el carro avanza sin meta
  final Color color;
  final bool hasData; // false: el equipo no manda tiempo real
  final Duration smooth; // los numeros suben suavizados entre lecturas
  final Widget? footer;
  final VehicleKind vehicle;

  const RealtimeStrip({
    super.key,
    required this.money,
    required this.volume,
    required this.color,
    required this.hasData,
    this.ppu,
    this.progress,
    this.smooth = const Duration(milliseconds: 500),
    this.footer,
    this.vehicle = VehicleKind.carro,
  });

  @override
  State<RealtimeStrip> createState() => _RealtimeStripState();
}

class _RealtimeStripState extends State<RealtimeStrip> with SingleTickerProviderStateMixin {
  static final NumberFormat _money = NumberFormat('\$#,##0', 'es_CO');
  static final NumberFormat _gallons = NumberFormat('0.00', 'es_CO');
  static const Color _nearColor = Color(0xFF3B8D3B);

  late final AnimationController _road;

  bool get _moving => widget.hasData && (widget.progress == null || widget.progress! < 1);

  @override
  void initState() {
    super.initState();
    _road = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    if (_moving) _road.repeat();
  }

  @override
  void didUpdateWidget(covariant RealtimeStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_moving && !_road.isAnimating) {
      _road.repeat();
    } else if (!_moving && _road.isAnimating) {
      _road.stop();
    }
  }

  @override
  void dispose() {
    _road.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final near = widget.progress != null && widget.progress! >= 0.9;
    final carColor = near ? _nearColor : widget.color;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.88),
        border: Border(top: BorderSide(color: carColor.withOpacity(0.9), width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: widget.money),
                        duration: widget.smooth,
                        builder: (_, value, __) => Text(
                          widget.hasData ? _money.format(value) : '—',
                          style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1.0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: widget.volume),
                        duration: widget.smooth,
                        builder: (_, value, __) => Text(
                          widget.hasData ? '${_gallons.format(value)} gal' : '',
                          style: const TextStyle(color: Color(0xFFE3EAE5), fontSize: 26, fontWeight: FontWeight.w700, height: 1.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.ppu != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: carColor.withOpacity(0.8), width: 1.5),
                  ),
                  child: Text(
                    'PPU ${_money.format(widget.ppu)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 300 / 62,
            child: AnimatedBuilder(
              animation: _road,
              builder: (_, __) => TweenAnimationBuilder<double>(
                tween: Tween<double>(end: widget.progress ?? 0),
                duration: widget.smooth,
                builder: (_, progress, __) {
                  final value = widget.progress == null ? null : progress;
                  return LayoutBuilder(
                    builder: (_, box) {
                      final k = box.maxWidth / 300;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _TrackPainter(progress: value, color: carColor, phase: _road.value),
                            ),
                          ),
                          Positioned(
                            left: _TrackPainter.vehicleX(value) * k,
                            top: 15 * k,
                            width: _TrackPainter.vehicleWidth * k,
                            child: VehicleSvg(kind: widget.vehicle, color: carColor),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          if (widget.footer != null) widget.footer!,
        ],
      ),
    );
  }
}

/// Pista de 300x62: carretera abajo, linea de avance con la bandera (el vehiculo se dibuja encima como widget)
class _TrackPainter extends CustomPainter {
  static const double vehicleWidth = 78;

  // El vehiculo arranca en 10 y termina con el frente en la bandera
  static double vehicleX(double? progress) => progress == null ? 110.0 : 10 + progress.clamp(0.0, 1.0) * (286 - 10 - vehicleWidth);

  final double? progress;
  final Color color;
  final double phase;

  _TrackPainter({required this.progress, required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300);

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 40, 300, 20), const Radius.circular(4)),
      Paint()..color = const Color(0xFF2B2F2D),
    );

    final dash = Paint()
      ..color = const Color(0xFFE8EFE9)
      ..strokeWidth = 2;
    for (double x = -22 - phase * 22; x < 300; x += 22) {
      final from = math.max(x, 0.0);
      final to = math.min(x + 12, 300.0);
      if (to > from) canvas.drawLine(Offset(from, 50), Offset(to, 50), dash);
    }

    final carX = vehicleX(progress);
    final track = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(10, 35), const Offset(286, 35), track..color = Colors.white24);
    if (progress != null) {
      canvas.drawLine(const Offset(10, 35), Offset(carX + vehicleWidth * 0.55, 35), track..color = color);
    }

    final flag = Path()
      ..moveTo(288, 35)
      ..lineTo(288, 10)
      ..lineTo(302, 15)
      ..lineTo(288, 21);
    canvas.drawPath(
      flag,
      Paint()
        ..color = const Color(0xFFE8EFE9)
        ..style = PaintingStyle.fill,
    );
    canvas.drawLine(
      const Offset(288, 35),
      const Offset(288, 10),
      Paint()
        ..color = const Color(0xFFE8EFE9)
        ..strokeWidth = 1.5,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) => old.progress != progress || old.color != color || old.phase != phase;
}

/// Velo sobre el video cuando hay tiempo real: lo atenua y lo oscurece mas hacia abajo para que la franja sea la protagonista
class RealtimeScrim extends StatelessWidget {
  const RealtimeScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.35), Colors.black.withOpacity(0.55), Colors.black.withOpacity(0.85)],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
