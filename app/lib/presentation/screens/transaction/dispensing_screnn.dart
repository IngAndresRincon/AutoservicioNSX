import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import '../../../data/enums/enums.dart';
import '../../../data/models/models.dart';
import '../../../services/service.dart';
import '../../../utils/color_utils.dart';
import '../../widgets/realtime_strip.dart';
import '../../widgets/vehicle_svg.dart';

class DispensingScreen extends StatefulWidget {
  final ProductHose hose;
  final CustomerModel customer;
  final double? programmingValue;
  final ProgrammingType? programmingType;

  const DispensingScreen({
    super.key,
    required this.hose,
    required this.customer,
    this.programmingValue,
    this.programmingType,
  });

  @override
  State<DispensingScreen> createState() => _DispensingScreenState();
}

class _DispensingScreenState extends State<DispensingScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _videoError = false;
  String? _deviceSerial;
  Timer? _statusPollTimer;
  bool _alertaSurtiendoMostrada = false;
  bool _alertaCasiTerminadoMostrada = false;
  double _progress = 0;

  // Tiempo real: valor y galones despachados que reporta el surtidor
  RealtimeConfig _rt = const RealtimeConfig();
  double _dinero = 0;
  double _volumen = 0;
  bool _rtHasData = false;
  bool _pollBusy = false;

  // Respaldo si el socket nunca confirma el fin de venta.
  bool _vioSurtiendo = false;
  bool _flujoFinalizado = false;
  Timer? _fallbackTimer;

  // Banners tipo notificación (mismo estilo que la advertencia de
  // "manguera equivocada" en instructions_screen).
  bool _bannerSurtiendoVisible = false;
  bool _bannerCasiTerminadoVisible = false;
  bool _bannerErrorVisible = false;
  Timer? _bannerAutoHideTimer;
  late final AnimationController _bannerPulseController;

  // Volumen del video de fondo: se baja mientras suena un audio de
  // transición para que no se crucen y se entienda el mensaje.
  static const double _volumenNormalVideo = 0.4;
  static const double _volumenDuckVideo = 0.05;
  Timer? _duckRestoreTimer;

  // Colores dinámicos para el dialog de venta zero
  Color _primaryColor = const Color(0xFF1565C0);
  Color _secondaryColor = const Color(0xFF2F80ED);
  Color _accentColor = const Color(0xFF56CCF2);

  @override
  void initState() {
    super.initState();
    _bannerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _startFlow();
    _cargarColores();
    _startStatusPolling();
    _cargarTiempoReal();
  }

  /// Consulta el estado real del surtidor para avisar cuando está surtiendo
  /// y cuando el tanqueo está a punto de terminar (según lo programado).
  void _startStatusPolling({Duration every = const Duration(seconds: 2)}) {
    _statusPollTimer?.cancel();
    // Primera lectura inmediata: la venta ya viene contando y no debe verse en 0 hasta el primer ciclo
    _pollOnce();
    _statusPollTimer = Timer.periodic(every, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_pollBusy) return;
    _pollBusy = true;
    try {
      final status = await PumpService.getStatusPosition(widget.hose.nsxPositionId);
      if (!mounted) return;
      _handleStatusPosition(status.data);
    } catch (_) {
      // Se ignoran errores puntuales de la consulta; se reintenta en el próximo ciclo.
    } finally {
      _pollBusy = false;
    }
  }

  // Tiempo real de esta pantalla (configurado en la Orange): la consulta pasa a su intervalo y se muestra la franja con el carrito
  Future<void> _cargarTiempoReal() async {
    final screenId = await StorageService.getScreenNumber() ?? 1;
    final mapping = await PumpService.getMappingWithFallback(screenId);
    final realtime = mapping?.realtime ?? const RealtimeConfig();
    if (!mounted || !realtime.enabled || _flujoFinalizado) return;
    setState(() => _rt = realtime);
    _startStatusPolling(every: Duration(milliseconds: realtime.intervalMs));
  }

  // Galones despachados: los que reporta el surtidor; si no manda volumen, se calcula con el dinero y el precio del galon
  double _volumenEfectivo(StatusPositionData data) {
    final reportado = data.volumen.toDouble();
    if (reportado > 0) return reportado;
    final price = double.tryParse(widget.hose.price) ?? 0;
    return price > 0 ? data.dinero.toDouble() / price : 0;
  }

  void _handleStatusPosition(StatusPositionData data) {
    if (_flujoFinalizado) return;

    if (_rt.enabled) {
      final dinero = data.dinero.toDouble();
      final volumen = _volumenEfectivo(data);
      if (dinero != _dinero || volumen != _volumen) {
        setState(() {
          _dinero = dinero;
          _volumen = volumen;
          if (dinero > 0 || volumen > 0) _rtHasData = true;
        });
      }
    }

    if (data.estadoSurtidor == PumpStatus.surtiendo) {
      _vioSurtiendo = true;
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
      if (_bannerErrorVisible) setState(() => _bannerErrorVisible = false);
      if (!_alertaSurtiendoMostrada) {
        _alertaSurtiendoMostrada = true;
        _mostrarBannerSurtiendo();
      }
    } else if (_vioSurtiendo &&
        (data.estadoSurtidor == PumpStatus.listo ||
            data.estadoSurtidor == PumpStatus.reporte ||
            data.estadoSurtidor == PumpStatus.espera)) {
      if (_bannerErrorVisible) setState(() => _bannerErrorVisible = false);
      _programarRespaldoFinDespacho();
    } else if (data.estadoSurtidor == PumpStatus.ventaZero) {
      _flujoFinalizado = true;
      _fallbackTimer?.cancel();
      _mostrarVentaZero();
      return;
    } else if (data.estadoSurtidor == PumpStatus.error) {
      if (!_bannerErrorVisible) setState(() => _bannerErrorVisible = true);
    } else if (_bannerErrorVisible) {
      setState(() => _bannerErrorVisible = false);
    }

    final programado = widget.programmingValue;
    if (programado != null && programado > 0) {
      final actual = widget.programmingType == ProgrammingType.volumen
          ? _volumenEfectivo(data)
          : data.dinero;

      final nuevoProgreso = (actual / programado).clamp(0.0, 1.0).toDouble();
      if (nuevoProgreso != _progress && mounted) {
        setState(() => _progress = nuevoProgreso);
      }

      if (!_alertaCasiTerminadoMostrada && actual >= programado * 0.99) {
        _alertaCasiTerminadoMostrada = true;
        _mostrarBannerCasiTerminado();
      }
    }
  }

  // Si el socket no avisa en unos segundos, consulta la venta directamente.
  void _programarRespaldoFinDespacho() {
    if (_fallbackTimer != null || _flujoFinalizado) return;
    _fallbackTimer = Timer(const Duration(seconds: 8), () async {
      if (!mounted || _flujoFinalizado) return;
      debugPrint("⏱️ [Dispensing] El socket no confirmó el fin de venta, consultando directamente...");
      final sale = await TransactionService.getLastSale(
        dispenserId: widget.hose.dispenserId,
        sideId: widget.hose.dispenserSide,
      );
      if (!mounted || _flujoFinalizado) return;
      if (sale != null) {
        _flujoFinalizado = true;
        _statusPollTimer?.cancel();
        _controller?.pause();
        SocketService.clearAuthorizationState();
        context.go('/sale-summary', extra: {
          'sale': sale,
          'customer': widget.customer,
          'hose': widget.hose,
        });
      }
    });
  }

  /// Baja el volumen del video de fondo mientras suena el audio para que
  /// no se crucen, y lo restaura pasado un momento.
  void _reproducirAudioConDuck(String fileName, {Duration duckDuration = const Duration(seconds: 4)}) {
    _controller?.setVolume(_volumenDuckVideo);
    AudioService.playTransition(fileName);
    _duckRestoreTimer?.cancel();
    _duckRestoreTimer = Timer(duckDuration, () {
      _controller?.setVolume(_volumenNormalVideo);
    });
  }

  void _mostrarBannerSurtiendo() {
    _reproducirAudioConDuck('surtiendo.mp3');
    _bannerAutoHideTimer?.cancel();
    setState(() {
      _bannerSurtiendoVisible = true;
      _bannerCasiTerminadoVisible = false;
    });
    _bannerAutoHideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _bannerSurtiendoVisible = false);
    });
  }

  void _mostrarBannerCasiTerminado() {
    _reproducirAudioConDuck('fin_venta.mp3');
    _bannerAutoHideTimer?.cancel();
    setState(() {
      _bannerCasiTerminadoVisible = true;
      _bannerSurtiendoVisible = false;
    });
    _bannerAutoHideTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _bannerCasiTerminadoVisible = false);
    });
  }

  Future<void> _cargarColores() async {
    final primary = await StorageService.getPrimaryColor();
    final secondary = await StorageService.getSecondaryColor();
    final accent = await StorageService.getAccentColor();
    if (!mounted) return;
    setState(() {
      _primaryColor = primary;
      _secondaryColor = secondary;
      _accentColor = accent;
    });
  }

  Future<void> _startFlow() async {
    _deviceSerial = await StorageService.getDeviceSerial();
    await _initializeVideo();
    _configurarEscuchaFinalizacion();
  }

  Future<void> _initializeVideo() async {
    try {
      final String videoFileName = await StorageService.getDispensingVideo();
      final videoUrl = await ResourceService.getVideoUrl(videoFileName);
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _controller!.setLooping(true);
            _controller!.setVolume(_volumenNormalVideo);
            _controller!.play();
          }
        }).catchError((e) {
          debugPrint("❌ [Dispensing] Error al inicializar video: $e");
          if (mounted) setState(() => _videoError = true);
        });
    } catch (e) {
      debugPrint("❌ [Dispensing] Error video: $e");
      if (mounted) setState(() => _videoError = true);
    }
  }

  void _configurarEscuchaFinalizacion() {
    if (_deviceSerial == null) return;
    SocketService.setAuthorizationListener(
      deviceSerial: _deviceSerial!,
      positionId: widget.hose.positionId,
      callback: (payload) {
        if (!mounted) return;
        final int sync = payload['sync'];
        final int? saleId = payload['saleid'];
        if (sync == 4 || (saleId != null && saleId > 0)) {
          _onSaleFinished(payload);
        } else if (sync == 6) {
          _mostrarVentaZero();
        }
      },
    );
  }

  void _mostrarVentaZero() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timer_off_outlined, color: Colors.orange.shade600, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tiempo agotado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
            ),
            const SizedBox(height: 8),
            const Text(
              'El surtidor finalizó la espera porque no se levantó la pistola a tiempo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.5),
            ),
            const SizedBox(height: 6),
            const Text(
              'Por favor ingrese su documento nuevamente para intentarlo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF999999), height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [_accentColor, _secondaryColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/identification');
                  },
                  child: Center(
                    child: Text(
                      'Intentar de nuevo',
                      style: TextStyle(
                        color: textColorForGradient(_accentColor, _secondaryColor),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSaleFinished(dynamic payload) async {
    if (_flujoFinalizado) return;
    _flujoFinalizado = true;
    _fallbackTimer?.cancel();
    _statusPollTimer?.cancel();
    _controller?.pause();
    final int authId = payload['authorizationid'];
    final saleData = await TransactionService.getSaleData(authId);
    if (!mounted) return;
    if (saleData != null) {
      context.go('/sale-summary', extra: {
        'sale': saleData,
        'customer': widget.customer,
        'hose': widget.hose,
      });
    } else {
      context.go('/sale-summary', extra: {
        'sale': payload,
        'customer': widget.customer,
        'hose': widget.hose,
        'isFallback': true,
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _statusPollTimer?.cancel();
    _fallbackTimer?.cancel();
    _bannerAutoHideTimer?.cancel();
    _duckRestoreTimer?.cancel();
    _bannerPulseController.dispose();
    SocketService.stopListeningAuthorization();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoseColor = Color(
      int.parse(widget.hose.color?.replaceAll('#', 'FF') ?? 'FF009EBF', radix: 16),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── VIDEO ────────────────────────────────────────────────────────
          if (_isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            _buildLoadingPlaceholder(hoseColor),

          // Con tiempo real el video se atenua para que la franja sea la protagonista
          if (_rt.enabled) const RealtimeScrim(),

          // ── BARRA INFERIOR ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _scaled(_rt.enabled ? _buildRealtimeStrip(hoseColor) : _buildBottomBar(hoseColor), Alignment.bottomCenter),
          ),

          // ── BANNERS DE NOTIFICACIÓN ────────────────────────────────────────
          if (_bannerErrorVisible || _bannerSurtiendoVisible || _bannerCasiTerminadoVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: _scaled(
                  _bannerErrorVisible
                    ? _buildNotificationBanner(
                        icon: Icons.wifi_off_rounded,
                        title: 'PROBLEMA CON EL SURTIDOR',
                        message: 'Se perdió la comunicación con el surtidor. Espere mientras se restablece.',
                        colors: [Colors.red.shade600, Colors.deepOrange.shade400],
                        onDismiss: () => setState(() => _bannerErrorVisible = false),
                      )
                    : _bannerCasiTerminadoVisible
                        ? _buildNotificationBanner(
                            icon: Icons.local_gas_station_rounded,
                            title: '¡TANQUEO FINALIZADO!',
                            message: 'Su tanqueo ha finalizado. Por favor cuelgue la pistola en el surtidor.',
                            colors: [Colors.green.shade600, Colors.teal.shade500],
                            onDismiss: () => setState(() => _bannerCasiTerminadoVisible = false),
                          )
                        : _buildNotificationBanner(
                            icon: Icons.local_gas_station_rounded,
                            title: 'SURTIENDO COMBUSTIBLE',
                            message: 'El dispensador está surtiendo. Esté pendiente del combustible.',
                            colors: [Colors.blue.shade600, Colors.lightBlue.shade400],
                            onDismiss: () => setState(() => _bannerSurtiendoVisible = false),
                          ),
                  Alignment.topCenter,
                ),
              ),
            ),

          // ── SALIDA DE EMERGENCIA ─────────────────────────────────────────────
          Positioned(
            top: 0, right: 0,
            child: GestureDetector(
              onDoubleTap: () async {
                _controller?.pause();

                // Intenta obtener la última venta antes de salir
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    contentPadding: const EdgeInsets.all(28),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _primaryColor),
                        const SizedBox(height: 16),
                        const Text(
                          'Consultando venta...',
                          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                );

                try {
                  final sale = await TransactionService.getLastSale(
                    dispenserId: widget.hose.dispenserId,
                    sideId: widget.hose.dispenserSide,
                  );

                  if (!mounted) return;
                  Navigator.pop(context); // cierra loading
                  SocketService.clearAuthorizationState();

                  if (sale != null) {
                    context.go('/sale-summary', extra: {
                      'sale': sale,
                      'customer': widget.customer,
                      'hose': widget.hose,
                    });
                  } else {
                    context.go('/');
                  }
                } catch (e) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  SocketService.clearAuthorizationState();
                  context.go('/');
                }
              },
              child: Container(width: 60, height: 60, color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  // Avisos y barra sobre el video: se dibujan a 420 de ancho y se amplian al ancho real de la pantalla
  Widget _scaled(Widget child, Alignment alignment) {
    return LayoutBuilder(
      builder: (context, box) {
        final f = (box.maxWidth / 420).clamp(1.0, 2.0);
        if (f <= 1.001) return child;
        // Se escala desde el borde izquierdo (la caja angosta empieza en x=0), no desde su centro
        // El Align suelta la restriccion de ancho (un Positioned obliga a todo el ancho) para que el hijo mida W/f de verdad
        return Transform.scale(
          scale: f,
          alignment: Alignment(-1, alignment.y),
          child: Align(
            alignment: Alignment.topLeft,
            heightFactor: 1.0,
            child: SizedBox(width: box.maxWidth / f, child: child),
          ),
        );
      },
    );
  }

  /// Banner tipo notificación, pulsante — mismo estilo que la advertencia de
  /// "manguera equivocada" en instructions_screen, con colores según el tipo
  /// de aviso (informativo vs. finalización).
  Widget _buildNotificationBanner({
    required IconData icon,
    required String title,
    required String message,
    required List<Color> colors,
    required VoidCallback onDismiss,
  }) {
    return GestureDetector(
      onTap: onDismiss,
      child: AnimatedBuilder(
        animation: _bannerPulseController,
        builder: (context, child) {
          final t = _bannerPulseController.value;
          final glow = 0.35 + (t * 0.35);
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withOpacity(glow),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.5 + t * 0.5),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Transform.scale(
                  scale: 1.0 + (t * 0.18),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Franja de tiempo real: valor, galones, PPU y el carrito que avanza segun lo programado
  Widget _buildRealtimeStrip(Color hoseColor) {
    final programado = widget.programmingValue != null && widget.programmingValue! > 0;
    final price = double.tryParse(widget.hose.price) ?? 0;

    return RealtimeStrip(
      money: _dinero,
      volume: _volumen,
      ppu: price > 0 ? price : null,
      progress: programado ? _progress : null,
      color: hoseColor,
      vehicle: vehicleForProduct(widget.hose.product),
      hasData: _rtHasData,
      smooth: Duration(milliseconds: _rt.intervalMs),
    );
  }

  Widget _buildBottomBar(Color hoseColor) {
    final tieneProgreso = widget.programmingValue != null && widget.programmingValue! > 0;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        border: Border(
          top: BorderSide(color: hoseColor.withOpacity(0.3), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Ícono animado
              _AnimatedPumpIcon(color: hoseColor),
              const SizedBox(width: 14),

              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Despachando ${widget.hose.product.toUpperCase()}',
                      style: TextStyle(
                        color: hoseColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Al finalizar verás el resumen de tu venta',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              if (tieneProgreso)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _progress),
                  duration: const Duration(milliseconds: 1800),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => Text(
                    '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: hoseColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                // Indicador pulsante (fallback cuando no se conoce lo programado)
                _PulsingDot(color: hoseColor),
            ],
          ),

          if (tieneProgreso) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _progress),
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(hoseColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder(Color hoseColor) {
    return Container(
      color: const Color(0xFF0A0E12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _videoError
              ? [
                  Icon(Icons.local_gas_station_rounded, color: hoseColor, size: 48),
                  const SizedBox(height: 20),
                  const Text(
                    'Despachando...',
                    style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 1),
                  ),
                ]
              : [
                  CircularProgressIndicator(color: hoseColor),
                  const SizedBox(height: 20),
                  const Text(
                    'Preparando...',
                    style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 1),
                  ),
                ],
        ),
      ),
    );
  }
}

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _AnimatedPumpIcon extends StatefulWidget {
  final Color color;
  const _AnimatedPumpIcon({required this.color});

  @override
  State<_AnimatedPumpIcon> createState() => _AnimatedPumpIconState();
}

class _AnimatedPumpIconState extends State<_AnimatedPumpIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(_ctrl),
      child: Icon(Icons.local_gas_station_rounded, color: widget.color, size: 28),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.2, end: 1.0).animate(_ctrl),
      child: Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}