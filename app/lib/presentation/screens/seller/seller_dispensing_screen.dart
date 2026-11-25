import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:gnesys_as/data/models/models.dart';
import 'package:gnesys_as/presentation/widgets/realtime_strip.dart';
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/presentation/widgets/vehicle_svg.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:gnesys_as/utils/responsive.dart';

/// Seguimiento del preset del vendedor: antes de surtir una vista clara; al surtir, el video con barra de avance
/// (igual que el cliente), y al terminar el resultado.
class SellerDispensingScreen extends StatefulWidget {
  final int presetId;
  final int positionId;
  final int nsxPositionId;
  final String product;
  final String hoseColor;
  final String programmed;
  final int programmingType; // 1 lleno, 2 dinero, 3 volumen
  final double programmedValue;
  final bool isCredit; // preset del cliente de credito: otro canal y otra consulta; no se cancela desde aqui

  const SellerDispensingScreen({
    super.key,
    this.isCredit = false,
    required this.presetId,
    required this.positionId,
    required this.nsxPositionId,
    required this.product,
    required this.hoseColor,
    required this.programmed,
    required this.programmingType,
    required this.programmedValue,
  });

  @override
  State<SellerDispensingScreen> createState() => _SellerDispensingScreenState();
}

class _SellerDispensingScreenState extends State<SellerDispensingScreen> with SingleTickerProviderStateMixin {
  AppColors _colors = const AppColors();
  int _sync = 0;
  int? _saleId;
  int? _presetNsxId;
  String? _message;
  bool _cancelling = false;

  // Estado real del surtidor (consulta cada 2 s)
  PumpStatus? _pump;
  int _pumpGrade = 0;
  int _presetGrade = 0;
  double _progress = 0;
  List<ProductHose> _hoses = [];

  bool _surtiendoShown = false;
  bool _almostShown = false;
  bool _surtiendoBanner = false;
  bool _almostBanner = false;
  bool _commError = false;
  Timer? _bannerTimer;
  late final AnimationController _pulse;

  VideoPlayerController? _video;
  bool _videoReady = false;
  bool _videoPlaying = false;

  SocketSubscription? _subscription;
  Timer? _poll;
  Timer? _pumpPoll;
  bool _multiPosition = false;

  // Tiempo real (se configura por pantalla en la Orange): valor, galones y carrito en la franja de abajo
  RealtimeConfig _rt = const RealtimeConfig();
  double _dinero = 0;
  double _volumen = 0;
  bool _rtHasData = false;
  bool _pumpBusy = false;
  void Function()? _removeReconnect;

  static const double _videoVolume = 0.4;
  static const double _videoDuck = 0.05;

  bool get _final => const [PresetSync.rejected, PresetSync.reported, PresetSync.cancelled, PresetSync.zeroSale].contains(_sync);
  bool get _dispensing => !_final && (_sync == PresetSync.dispensing || _pump == PumpStatus.surtiendo);
  bool get _canCancel => !widget.isCredit && !_dispensing && (_sync == 0 || _sync == PresetSync.confirmed);

  Future<SellerPreset> _fetchPreset() =>
      widget.isCredit ? SellerService.getClientPreset(widget.presetId) : SellerService.getPreset(widget.presetId);
  // Solo se avisa si la manguera levantada es una que el mapeo conoce; un numero fuera de las mangueras de la posicion es ruido
  bool get _hoseMismatch =>
      !_final && _pumpGrade > 0 && _presetGrade > 0 && _pumpGrade != _presetGrade && _hoses.any((h) => h.hoseNumber == _pumpGrade);

  Color get _hoseTint {
    try {
      return Color(int.parse(widget.hoseColor.replaceAll('#', '').padLeft(8, 'F'), radix: 16));
    } catch (_) {
      return _colors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
    _loadHoses();
    _initVideo();

    _subscription = SocketService.listen(
      channel: widget.isCredit ? SocketChannels.clientPreset : SocketChannels.sellerPreset,
      positionId: widget.positionId,
      presetId: widget.presetId,
      onEvent: (payload) => _apply((payload['sync'] as num?)?.toInt(), saleId: (payload['saleid'] as num?)?.toInt()),
    );
    _removeReconnect = SocketService.addReconnectListener(_refresh);
    _loadMultiPosition();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    _pumpPoll = Timer.periodic(const Duration(seconds: 2), (_) => _refreshPump());
    _refresh();
    _refreshPump();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _removeReconnect?.call();
    _poll?.cancel();
    _pumpPoll?.cancel();
    _bannerTimer?.cancel();
    _pulse.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _loadHoses() async {
    final screenId = await StorageService.getScreenNumber() ?? 1;
    final mapping = await PumpService.getMappingWithFallback(screenId);
    if (!mounted) return;
    final realtime = mapping?.realtime ?? const RealtimeConfig();
    setState(() {
      _hoses = (mapping?.productHoses ?? const <ProductHose>[]).where((h) => h.positionId == widget.positionId).toList();
      _rt = realtime;
    });
    // Con tiempo real la consulta del surtidor pasa a su intervalo (500 ms por defecto) en vez de cada 2 s
    if (realtime.enabled && !_final) {
      _pumpPoll?.cancel();
      _pumpPoll = Timer.periodic(Duration(milliseconds: realtime.intervalMs), (_) => _refreshPump());
    }
  }

  /// Nombre del producto de un grado de esta posicion; si no se encuentra, el numero
  String _gradeName(int grade) {
    final hose = _hoses.where((h) => h.hoseNumber == grade).firstOrNull;
    return hose?.product ?? 'manguera $grade';
  }

  Future<void> _initVideo() async {
    try {
      final url = await ResourceService.getVideoUrl(await StorageService.getDispensingVideo());
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _video = controller;
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(_videoVolume);
      if (mounted) setState(() => _videoReady = true);
      _syncVideo();
    } catch (_) {
      // Sin video se usa el fondo oscuro de respaldo
    }
  }

  void _syncVideo() {
    final video = _video;
    if (video == null || !_videoReady) return;
    if (_dispensing && !_videoPlaying) {
      _videoPlaying = true;
      video.play();
    } else if (!_dispensing && _videoPlaying) {
      _videoPlaying = false;
      video.pause();
    }
  }

  void _apply(int? sync, {int? saleId, String? message}) {
    if (!mounted || sync == null) return;
    // Un estado atrasado (consulta lenta) no debe pisar uno final
    if (_final) return;
    setState(() {
      _sync = sync;
      _saleId = saleId ?? _saleId;
      _message = message ?? _message;
    });
    if (_final) {
      _poll?.cancel();
      _pumpPoll?.cancel();
    }
    _syncVideo();
    if (sync == PresetSync.reported) _goSummary();
  }

  Future<void> _loadMultiPosition() async {
    final screenId = await StorageService.getScreenNumber() ?? 1;
    final mapping = await PumpService.getMappingWithFallback(screenId);
    final positions = (mapping?.productHoses ?? const <ProductHose>[])
        .where((h) => h.hybrid && h.activeHose && h.activePosition)
        .map((h) => h.positionId)
        .toSet();
    if (mounted) setState(() => _multiPosition = positions.length > 1);
  }

  Future<void> _goSummary() async {
    int? nsxId = _presetNsxId;
    if (nsxId == null) {
      try {
        nsxId = (await _fetchPreset()).presetNsxId;
      } on SellerException {
        // Sin el id no se puede abrir la venta: se vuelve al menu
      }
    }
    if (!mounted) return;
    if (nsxId == null) {
      context.go('/seller/menu');
      return;
    }
    context.go('/seller/summary', extra: {
      'presetNsxId': nsxId,
      'product': widget.product,
      'hoseColor': widget.hoseColor,
      'nsxPositionId': widget.nsxPositionId,
      'isCredit': widget.isCredit,
    });
  }

  Future<void> _refresh() async {
    if (_final) return;
    try {
      SellerService.touch();
      final preset = await _fetchPreset();
      _presetNsxId = preset.presetNsxId ?? _presetNsxId;
      _apply(preset.sync, saleId: preset.saleId, message: preset.message);
    } on SellerException catch (e) {
      if (e.sessionExpired && mounted) context.go('/seller/login');
    }
  }

  // Galones despachados: los que reporta el surtidor; si no manda volumen, se calcula con el dinero y el precio del galon
  double _volumenEfectivo(StatusPositionData data) {
    final reportado = data.volumen.toDouble();
    if (reportado > 0) return reportado;
    final price = double.tryParse(_hoses.where((h) => h.product == widget.product).firstOrNull?.sellerPrice ?? '') ?? 0;
    return price > 0 ? data.dinero.toDouble() / price : 0;
  }

  Future<void> _refreshPump() async {
    if (_final || _pumpBusy) return;
    _pumpBusy = true;
    try {
      final data = (await PumpService.getStatusPosition(widget.nsxPositionId)).data;
      if (!mounted || _final) return;

      double progress = _progress;
      if (widget.programmingType != 1 && widget.programmedValue > 0) {
        final actual = widget.programmingType == 3 ? _volumenEfectivo(data) : data.dinero.toDouble();
        progress = (actual / widget.programmedValue).clamp(0.0, 1.0).toDouble();
        if (!_almostShown && actual >= widget.programmedValue * 0.99) {
          _almostShown = true;
          _showBanner(almost: true);
        }
      }

      if (data.estadoSurtidor == PumpStatus.surtiendo && !_surtiendoShown) {
        _surtiendoShown = true;
        _showBanner(almost: false);
      }

      setState(() {
        _pump = data.estadoSurtidor;
        _pumpGrade = data.grado;
        _presetGrade = data.gradoPreset;
        _progress = progress;
        _dinero = data.dinero.toDouble();
        _volumen = _volumenEfectivo(data);
        if (_dinero > 0 || _volumen > 0) _rtHasData = true;
        _commError = data.estadoSurtidor == PumpStatus.error;
      });
      _syncVideo();
    } catch (_) {
      // Se reintenta en el proximo ciclo
    } finally {
      _pumpBusy = false;
    }
  }

  void _showBanner({required bool almost}) {
    _video?.setVolume(_videoDuck);
    AudioService.playTransition(almost ? 'fin_venta.mp3' : 'surtiendo.mp3');
    Timer(const Duration(seconds: 4), () => _video?.setVolume(_videoVolume));

    _bannerTimer?.cancel();
    setState(() {
      _surtiendoBanner = !almost;
      _almostBanner = almost;
    });
    _bannerTimer = Timer(Duration(seconds: almost ? 8 : 6), () {
      if (mounted) {
        setState(() {
          _surtiendoBanner = false;
          _almostBanner = false;
        });
      }
    });
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar preset'),
        content: const Text('¿Cancelar el preset de esta posición?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await SellerService.cancelPreset(widget.positionId);
      _apply(PresetSync.cancelled);
    } on SellerException catch (e) {
      if (!mounted) return;
      showSellerNotice(context, e.message, error: true);
      if (e.sessionExpired) context.go('/seller/login');
      _refresh();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  ({String title, String detail, IconData icon, Color color}) get _view {
    switch (_sync) {
      case PresetSync.confirmed:
        return (title: 'Listo para surtir', detail: 'Levante la manguera del surtidor.', icon: Icons.local_gas_station_rounded, color: _colors.primary);
      case PresetSync.reported:
        return (title: 'Despacho finalizado', detail: _saleId != null ? 'Venta $_saleId registrada.' : 'Venta registrada.', icon: Icons.check_circle_rounded, color: Colors.green.shade600);
      case PresetSync.zeroSale:
        return (title: 'Sin despacho', detail: 'No se surtió combustible.', icon: Icons.remove_circle_outline_rounded, color: Colors.orange.shade700);
      case PresetSync.rejected:
        return (title: 'Preset rechazado', detail: _message ?? 'El sistema no aceptó el preset.', icon: Icons.error_outline_rounded, color: Colors.redAccent);
      case PresetSync.cancelled:
        return (title: 'Preset cancelado', detail: 'La posición quedó libre.', icon: Icons.cancel_outlined, color: Colors.grey.shade600);
      default:
        return (title: 'Enviando preset', detail: 'Un momento, comunicando con el surtidor.', icon: Icons.sync_rounded, color: _colors.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (SellerService.session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/seller/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    return _dispensing ? _buildDispensing() : _buildWaiting();
  }

  // --- Surtiendo: video, avisos y barra de avance ---

  Widget _buildDispensing() {
    final tint = _hoseTint;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SellerService.touch(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_videoReady && _video != null)
              Center(child: AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!)))
            else
              Container(
                color: const Color(0xFF0A0E12),
                child: Center(child: Icon(Icons.local_gas_station_rounded, color: tint, size: 56)),
              ),
            // Con tiempo real el video se atenua para que la franja sea la protagonista
            if (_rt.enabled) const RealtimeScrim(),
            Positioned(left: 0, right: 0, bottom: 0, child: _scaled(_rt.enabled ? _buildRealtimeStrip(tint) : _buildBottomBar(tint), Alignment.bottomCenter)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: _scaled(_buildBanners(), Alignment.topCenter)),
            ),
          ],
        ),
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

  Widget _buildBanners() {
    final banners = <Widget>[
      if (_commError)
        _banner(Icons.wifi_off_rounded, 'PROBLEMA CON EL SURTIDOR', 'Se perdió la comunicación con el surtidor. Espere mientras se restablece.', [Colors.red.shade600, Colors.deepOrange.shade400]),
      if (_hoseMismatch) _mismatchBanner(),
      if (_almostBanner)
        _banner(Icons.local_gas_station_rounded, '¡TANQUEO FINALIZADO!', 'El tanqueo ha finalizado. Cuelgue la pistola en el surtidor.', [Colors.green.shade600, Colors.teal.shade500])
      else if (_surtiendoBanner)
        _banner(Icons.local_gas_station_rounded, 'SURTIENDO COMBUSTIBLE', 'El dispensador está surtiendo. Esté pendiente del combustible.', [Colors.blue.shade600, Colors.lightBlue.shade400]),
    ];
    return Column(mainAxisSize: MainAxisSize.min, children: banners);
  }

  Widget _mismatchBanner() => _banner(
        Icons.warning_amber_rounded,
        'MANGUERA DISTINTA',
        'Levantaron ${_gradeName(_pumpGrade)} y el preset es de ${_gradeName(_presetGrade)}.',
        [Colors.red.shade700, Colors.redAccent],
      );

  Widget _banner(IconData icon, String title, String message, List<Color> colors) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: colors.last.withOpacity(0.35 + t * 0.35), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 6))],
            border: Border.all(color: Colors.white.withOpacity(0.5 + t * 0.5), width: 2),
          ),
          child: Row(
            children: [
              Transform.scale(
                scale: 1.0 + t * 0.18,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                    const SizedBox(height: 2),
                    Text(message, style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(Color tint) {
    final hasProgress = widget.programmingType != 1 && widget.programmedValue > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        border: Border(top: BorderSide(color: tint.withOpacity(0.3), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.5, end: 1.0).animate(_pulse),
                child: Icon(Icons.local_gas_station_rounded, color: tint, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Despachando ${widget.product.toUpperCase()}', style: TextStyle(color: tint, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('Programado ${widget.programmed} · Posición ${widget.nsxPositionId}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              if (hasProgress)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _progress),
                  duration: const Duration(milliseconds: 1800),
                  curve: Curves.easeOut,
                  builder: (_, value, __) => Text('${(value * 100).clamp(0, 100).toStringAsFixed(0)}%', style: TextStyle(color: tint, fontSize: 16, fontWeight: FontWeight.w800)),
                )
              else
                FadeTransition(
                  opacity: Tween(begin: 0.2, end: 1.0).animate(_pulse),
                  child: Container(width: 8, height: 8, decoration: BoxDecoration(color: tint, shape: BoxShape.circle)),
                ),
            ],
          ),
          if (hasProgress) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _progress),
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeOut,
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(tint),
                ),
              ),
            ),
          ],
          if (_multiPosition) ...[
            const SizedBox(height: 8),
            _exitButton(),
          ],
        ],
      ),
    );
  }

  Widget _exitButton() => Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => context.go('/seller/menu'),
          icon: const Icon(Icons.exit_to_app_rounded, size: 18, color: Colors.white),
          label: const Text('Salir y programar otra posición', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      );

  // Franja de tiempo real: valor, galones, PPU (no en credito) y el carrito que avanza segun lo programado
  Widget _buildRealtimeStrip(Color tint) {
    final hose = _hoses.where((h) => h.product == widget.product).firstOrNull;
    final price = double.tryParse(hose?.sellerPrice ?? '') ?? 0;
    final programmed = widget.programmingType != 1 && widget.programmedValue > 0;

    return RealtimeStrip(
      money: _dinero,
      volume: _volumen,
      ppu: widget.isCredit || price <= 0 ? null : price,
      progress: programmed ? _progress : null,
      color: tint,
      vehicle: vehicleForProduct(widget.product),
      hasData: _rtHasData,
      smooth: Duration(milliseconds: _rt.intervalMs),
      footer: _multiPosition ? _exitButton() : null,
    );
  }

  // --- Antes de surtir y resultado ---

  Widget _buildWaiting() {
    final view = _view;
    final working = !_final && _sync != PresetSync.confirmed;

    return SellerScaffold(
      colors: _colors,
      onBack: () => context.go('/seller/menu'),
      // Se dibuja a un tamano de referencia y se amplia parejo a la pantalla (icono, textos, tarjeta y botones)
      child: ScaleUp(
        reference: const Size(420, 760),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hoseMismatch) Padding(padding: const EdgeInsets.only(bottom: 4), child: _mismatchBanner()),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (working) SizedBox(width: 116, height: 116, child: CircularProgressIndicator(strokeWidth: 5, color: view.color)),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: view.color.withOpacity(0.12)),
                            child: Icon(view.icon, size: 52, color: view.color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(view.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(view.detail, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(color: _colors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.product, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _colors.primary)),
                            Text(widget.programmed, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            Text('Posición ${widget.nsxPositionId}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_sync == PresetSync.rejected || _sync == PresetSync.cancelled || _sync == PresetSync.zeroSale)
              GradientButton(label: 'Nueva venta', colors: _colors, height: 50, onTap: () => context.go('/seller/sale')),
            if (_canCancel)
              OutlinedButton(
                onPressed: _cancelling ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _cancelling
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cancelar preset', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            if (!_final) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/seller/menu'),
                child: const Text('Volver al menú', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
