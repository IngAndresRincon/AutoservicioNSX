import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:gnesys_as/presentation/widgets/app_notice.dart';

import '../../widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  String screenIdLabel = "Cargando...";
  bool _loadingLastSale = false;
  bool _checkingStatus = false;
  Color _primaryColor = const Color(0xFF1565C0);
  String? _logoUrl;
  bool _hasHybrid = false; // el mapeo tiene dispensadores hibridos: se habilita el acceso de vendedor

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadScreenId();
    _setupVideo();
    _cargarColores();

    StorageService.videoUpdateNotifier.addListener(_onVideoParameterChanged);
    Future.microtask(() => SocketService.connect());
    Future.microtask(() => LocalApiServer.start());
  }

  void _onVideoParameterChanged() async {
    if (!mounted) return;

    // Pausa y descarta el controller actual
    final old = _videoController;
    setState(() {
      _videoController = null;
      _isInitialized = false;
    });
    await old?.pause();
    old?.dispose();

    // Reinicia con los nuevos parámetros
    await _setupVideo();
  }

  Timer? _sellerHoldTimer;

  void _openSellerAccess() {
    _cancelSellerHold();
    context.push('/seller/login');
  }

  // Mantener presionado el logo 2 s (el doble toque tambien abre el acceso)
  void _startSellerHold() {
    _sellerHoldTimer?.cancel();
    _sellerHoldTimer = Timer(const Duration(seconds: 2), _openSellerAccess);
  }

  void _cancelSellerHold() {
    _sellerHoldTimer?.cancel();
    _sellerHoldTimer = null;
  }

  Future<void> _loadScreenId() async {
    final int? id = await StorageService.getScreenNumber();
    if (mounted) {
      setState(() => screenIdLabel = id != null ? "$id" : "Sin Configurar");
    }
    _loadHybrid(id);
  }

  // Primero el mapeo guardado y luego el del servidor, para no esperar la red al abrir
  Future<void> _loadHybrid(int? screenId) async {
    try {
      final cached = await StorageService.loadMapping();
      if (mounted && cached != null) setState(() => _hasHybrid = cached.hasHybrid);

      final fresh = await PumpService.getMapping(screenId: screenId ?? 1);
      if (mounted && fresh != null) setState(() => _hasHybrid = fresh.hasHybrid);
    } catch (e) {
      debugPrint('⚠️ [Home] No se pudo leer el mapeo para el acceso de vendedor: $e');
    }
  }

  Future<void> _cargarColores() async {
    final primary = await StorageService.getPrimaryColor();
    final logo = await StorageService.getLogoUrl();
    if (!mounted) return;
    setState(() {
      _primaryColor = primary;
      _logoUrl = logo;
    });
  }

  Future<void> _setupVideo() async {
    if (_videoController != null) return; // evita múltiples inicializaciones
    
    try {
      final String videoFileName = await StorageService.getStandbyVideo();
      final videoUrl = await ResourceService.getVideoUrl(videoFileName);
      final double volumen = await StorageService.getVideoVolume();

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _isInitialized = true;
      });

      await controller.setVolume(volumen);
      await controller.setLooping(true);
      await controller.play();
    } catch (e) {
      debugPrint("❌ Error video: $e");
    }
  }

  Future<void> _disposeVideo() async {
    if (_videoController != null) {
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
      if (mounted) setState(() => _isInitialized = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sellerHoldTimer?.cancel();
    StorageService.videoUpdateNotifier.removeListener(_onVideoParameterChanged);
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _videoController?.play();
    } else if (state == AppLifecycleState.paused) {
      _videoController?.pause();
    }
  }

  void _navigateTo(String route) async {
    await _disposeVideo();
    if (mounted) {
      await context.push(route);
      // La pantalla de inicio sigue viva debajo: al volver de configuracion hay que releer
      // el numero de pantalla y los colores, que pudieron cambiar al sincronizar
      _loadScreenId();
      _cargarColores();
      _setupVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── VIDEO ──────────────────────────────────────────────────────
          if (_isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),

          // ── TOQUE PARA INICIAR — va antes para quedar debajo ───────────
          Positioned.fill(
            child: GestureDetector(
              onTap: _navigateToIdentification,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            bottom: isLandscape ? 80 : 100,
            left: 0,
            right: 0,
            child: const IgnorePointer(child: _TapIndicator()),
          ),

          // ── BARRA SUPERIOR ─────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 32 : 20,
                  vertical: isLandscape ? 8 : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ID de pantalla, pequeño y discreto (referencia para soporte técnico)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.desktop_windows_outlined,
                            color: Colors.white.withOpacity(0.55), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'Pantalla $screenIdLabel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const ClockWidget(fontSize: 15),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () async {
                            await _mostrarPinConfiguracion();
                            if (mounted) _cargarColores(); // recarga al volver
                          },
                          onLongPress: () => _mostrarControlVolumen(),
                          child: _buildGlassBadge(
                            padding: const EdgeInsets.all(12),
                            child: Icon(Icons.settings_outlined,
                                color: Colors.white.withOpacity(0.45), size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── BARRA INFERIOR ─────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: EdgeInsets.only(
                    left: isLandscape ? 32 : 24,
                    right: isLandscape ? 32 : 24,
                    top: isLandscape ? 10 : 14,
                    bottom: MediaQuery.of(context).padding.bottom +
                        (isLandscape ? 8 : 14),
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.82),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Logo dinámico de la estación; doble toque = acceso del vendedor (solo con dispensador híbrido)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: _hasHybrid ? _openSellerAccess : null,
                        onLongPressStart: _hasHybrid ? (_) => _startSellerHold() : null,
                        onLongPressEnd: (_) => _cancelSellerHold(),
                        onLongPressCancel: _cancelSellerHold,
                        child: _logoUrl != null
                          ? Image.network(
                              _logoUrl!,
                              height: isLandscape ? 42 : 56,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                      ? child
                                      : const SizedBox(width: 56),
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/logo_insepet_blanco.png',
                                height: isLandscape ? 42 : 56,
                              ),
                            )
                          : Image.asset(
                              'assets/images/logo_insepet_blanco.png',
                              height: isLandscape ? 42 : 56,
                            ),
                      ),

                      const Spacer(),

                      // Botón última transacción
                      GestureDetector(
                        onTap: _loadingLastSale ? null : _onLastTransaction,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 24 : 20,
                            vertical: isLandscape ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: _loadingLastSale
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      color: Colors.white.withOpacity(0.9),
                                      size: isLandscape ? 16 : 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Última transacción',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: isLandscape ? 13 : 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const Spacer(),

                      // Logo Insepet fijo
                      Image.asset(
                        'assets/images/logo_insepet_blanco.png',
                        height: isLandscape ? 42 : 56,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToIdentification() async {
    if (_checkingStatus) return;
    setState(() => _checkingStatus = true);

    try {
      final screenId = await StorageService.getScreenNumber();
      final mapping = await PumpService.getMappingWithFallback(screenId ?? 1);
      if (mapping == null) throw Exception('Sin configuración de mapeado');

      final hoses = mapping.productHoses;
      if (hoses.isEmpty) throw Exception('Sin mangueras configuradas');

      final hose = hoses.firstWhere((h) => h.activeHose, orElse: () => hoses.first);

      final status = await PumpService.getStatusPosition(hose.nsxPositionId);

      if (!status.data.estadoSurtidor.canContinue) {
        if (mounted) _mostrarAlertaNoDisponible(status.data.estadoSurtidor.description);
        return;
      }

      if (!mounted) return;
      _videoController?.pause();
      await context.push('/identification');
      if (mounted) {
        _videoController?.play();
      }
    } catch (e) {
      if (mounted) {
        _mostrarAlertaNoDisponible('No se pudo consultar el estado del surtidor: $e');
      }
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  void _mostrarAlertaNoDisponible(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_gas_station_outlined,
                  color: Colors.orange.shade600, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('No se puede continuar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarPinConfiguracion() async {
  final pinController = TextEditingController();
  bool pinError = false;
  const String pin = '1234'; // <- mover a StorageService idealmente

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 36, color: Colors.black54),
                const SizedBox(height: 12),
                const Text('Acceso restringido',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Ingresa el PIN de configuración',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  autofocus: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  onChanged: (_) { if (pinError) setDialog(() => pinError = false); },
                  onSubmitted: (_) => _validarPin(pinController.text, pin, ctx, () => setDialog(() => pinError = true)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • •',
                    hintStyle: const TextStyle(letterSpacing: 6, color: Color(0xFFCCCCCC)),
                    errorText: pinError ? 'PIN incorrecto' : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black54, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    side: const BorderSide(color: Color(0xFFCCCCCC)),
                  ),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _validarPin(
                    pinController.text, pin, ctx,
                    () => setDialog(() => pinError = true),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Entrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  void _validarPin(String input, String pin, BuildContext ctx, VoidCallback onError) {
    if (input.trim() == pin) {
      Navigator.pop(ctx);
      context.push('/configuration').then((_) {
        if (mounted) {
          // Al volver de configuracion se relee lo que pudo cambiar al sincronizar
          _cargarColores();
          _loadScreenId();
        }
      });
    } else {
      onError();
    }
  }

  void _mostrarControlVolumen() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _VolumenSheet(),
    );
  }

  // Widget auxiliar para el efecto de vidrio
  Widget _buildGlassBadge({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _onLastTransaction() async {
    setState(() => _loadingLastSale = true);

    try {
      final id = await StorageService.getScreenNumber();
      final mapping = await PumpService.getMappingWithFallback(id ?? 1);
      if (mapping == null) throw Exception('Sin configuración de mapeado');

      final hoses = mapping.productHoses;
      if (hoses.isEmpty) throw Exception('Sin mangueras configuradas');

      final hose = hoses.firstWhere((h) => h.activeHose, orElse: () => hoses.first);

      final sale = await TransactionService.getLastSale(
                          dispenserId: hose.dispenserId,
                          sideId: hose.dispenserSide,
                        );

      if (sale == null) throw Exception('No se encontró ninguna venta');

      // La posición puede tener varias mangueras (productos distintos); se
      // cruza el número real que reportó la venta contra el mapeo para
      // mostrar el producto correcto, en vez de la manguera arbitraria que
      // se usó solo para armar la consulta.
      final int? numeroMangueraVenta = (sale['numeroManguera'] as num?)?.toInt();
      final matchedHose = numeroMangueraVenta != null
          ? hoses.firstWhere(
              (h) => h.hoseNumber == numeroMangueraVenta,
              orElse: () => hose,
            )
          : hose;

      if (!mounted) return;
      await _disposeVideo();
      await context.push('/transactions', extra: {
        'sale': sale,
        'customer': null,
        'hose': matchedHose,
      });
      _setupVideo();

    } catch (e) {
      if (mounted) {
        showAppNotice(context, 'No se pudo obtener la última venta: $e', kind: NoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _loadingLastSale = false);
    }
  }
}

class _VolumenSheet extends StatefulWidget {
  @override
  State<_VolumenSheet> createState() => _VolumenSheetState();
}

class _VolumenSheetState extends State<_VolumenSheet> {
  double _volumen = 0.5;

  @override
  void initState() {
    super.initState();
    _cargarVolumen();
  }

  Future<void> _cargarVolumen() async {
    final v = await StorageService.getVideoVolume();
    setState(() => _volumen = v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.volume_down_rounded, color: Colors.black54),
              Expanded(
                child: Slider(
                  value: _volumen,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  activeColor: Colors.black87,
                  onChanged: (v) => setState(() => _volumen = v),
                  onChangeEnd: (v) async {
                    await StorageService.setVideoVolume(v);
                    // Notifica al HomeScreen para actualizar el video
                    StorageService.videoUpdateNotifier.notifyListeners();
                  },
                ),
              ),
              const Icon(Icons.volume_up_rounded, color: Colors.black54),
            ],
          ),
          Text(
            '${(_volumen * 100).round()}%',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TapIndicator extends StatefulWidget {
  const _TapIndicator();

  @override
  State<_TapIndicator> createState() => _TapIndicatorState();
}

class _TapIndicatorState extends State<_TapIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scale = Tween(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final iconSize = size.shortestSide * 0.16;
    final fontSize = size.shortestSide * 0.06;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_rounded,
                color: Colors.white.withOpacity(0.85),
                size: iconSize,
              ),
              SizedBox(height: size.shortestSide * 0.01),
              Text(
                'Toca para comenzar',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}