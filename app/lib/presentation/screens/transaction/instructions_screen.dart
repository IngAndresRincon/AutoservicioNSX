import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../data/enums/enums.dart';
import '../../../data/models/models.dart';
import '../../../services/service.dart';
import '../../../utils/color_utils.dart';
import '../../widgets/seller_widgets.dart' show PaymentLogo;

class InstructionsScreen extends StatefulWidget {
  final dynamic payload;
  final ProductHose hose;
  final CustomerModel customer;
  final double? programmingValue;
  final ProgrammingType? programmingType;

  const InstructionsScreen({
    super.key,
    required this.payload,
    required this.hose,
    required this.customer,
    this.programmingValue,
    this.programmingType,
  });

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  Timer? _timer;
  Timer? _statusPollTimer;
  String? _deviceSerial;
  bool _dispensingTriggered = false;
  bool _manijaEquivocada = false;
  bool _ventaZeroMostrada = false;
  bool _mostrarBannerAutorizado = true;
  Timer? _authBannerTimer;
  DateTime? _pollStartTime;

  // Margen de gracia: el backend puede tardar unos segundos en reflejar el
  // cambio a "Autorizado" justo después de conceder la autorización, así
  // que no se valida "Espera" (venta cero) hasta pasado este tiempo.
  static const Duration _graceEspera = Duration(seconds: 8);

  // Colores dinámicos
  Color _primaryColor = const Color(0xFF1565C0);
  Color _secondaryColor = const Color(0xFF2F80ED);
  Color _accentColor = const Color(0xFF56CCF2);
  String? _logoUrl;

  // Animación de progreso
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // Animación de entrada del paso
  late AnimationController _stepController;
  late Animation<double> _stepFadeAnimation;
  late Animation<Offset> _stepSlideAnimation;

  // Animación de pulso para la advertencia de manguera equivocada
  late AnimationController _warningController;

  // Animación de pulso para el banner de "transacción autorizada"
  late AnimationController _authPulseController;

  static const _stepDuration = Duration(seconds: 4);

  final List<Map<String, dynamic>> _steps = [
    // 'image': nombre del archivo en los recursos de la Orange (<image>.png); si no esta se muestra el icono
    {
      'title': 'Apague el motor',
      'desc': 'Por seguridad, asegúrese de apagar el motor de su vehículo.',
      'icon': Icons.power_settings_new_rounded,
      'image': 'paso_motor',
    },
    {
      'title': 'Destape el tanque',
      'desc': 'Abra la tapa del tanque de combustible de su vehículo.',
      'icon': Icons.lock_open_rounded,
      'image': 'paso_tanque',
    },
    {
      'title': 'Descuelgue la manija',
      'desc': 'Tome la manija del surtidor de color correspondiente a su producto.',
      'icon': Icons.back_hand_outlined,
      'image': 'paso_manija',
    },
    {
      'title': 'Inserte la pistola',
      'desc': 'Coloque la boquilla firmemente en la entrada de combustible.',
      'icon': Icons.local_gas_station_outlined,
      'image': 'paso_pistola',
    },
    {
      'title': 'Apriete el gatillo',
      'desc': 'Presione el gatillo para iniciar. El surtidor se detendrá solo al completar.',
      'icon': Icons.play_circle_outline_rounded,
      'image': 'paso_gatillo',
    },
  ];

  @override
  void initState() {
    super.initState();
    _cargarColores();
    _loadSerialAndListen();

    _progressController = AnimationController(
      vsync: this,
      duration: _stepDuration,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );

    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _stepFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _stepController, curve: Curves.easeOut),
    );
    _stepSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _stepController, curve: Curves.easeOut));

    _warningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _authPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _authBannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _mostrarBannerAutorizado = false);
    });

    _startStep(0);
    _startStatusPolling();
    AudioService.playTransition('autorizado.mp3');
  }

  /// Consulta periódicamente el estado real del surtidor para detectar
  /// cuándo empieza a surtir (o si levantaron la manguera equivocada),
  /// sin depender únicamente del socket.
  bool _pollBusy = false;

  void _startStatusPolling() {
    _pollStartTime = DateTime.now();
    // Consulta rápida: al surtir, el equipo ya cuenta y la pantalla de despacho debe abrir sin demora
    _pollOnce();
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_pollBusy || _dispensingTriggered) return;
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

  void _handleStatusPosition(StatusPositionData data) {
    if (data.estadoSurtidor == PumpStatus.surtiendo) {
      _goToDispensing();
      return;
    }

    // Si el surtidor volvió a "Espera" mientras esperábamos que levantaran
    // la manija, es que se venció el tiempo de la autorización. Se le da un
    // margen inicial porque el backend puede tardar unos segundos en
    // reflejar el cambio a "Autorizado" recién concedida la autorización.
    final bool dentroDelMargen = _pollStartTime != null &&
        DateTime.now().difference(_pollStartTime!) < _graceEspera;

    if (data.estadoSurtidor == PumpStatus.espera && !dentroDelMargen) {
      _mostrarVentaZero();
      return;
    }

    final manijaEquivocada = data.estadoSurtidor == PumpStatus.autorizado &&
        data.grado != 0 &&
        data.grado != data.gradoPreset;

    if (manijaEquivocada != _manijaEquivocada) {
      setState(() => _manijaEquivocada = manijaEquivocada);
      // Solo se anuncia al momento en que se detecta (no en cada ciclo de polling
      // mientras siga con la manguera equivocada puesta).
      if (manijaEquivocada) {
        AudioService.playTransition('manguera_erronea.mp3');
      }
    }
  }

  Future<void> _cargarColores() async {
    final primary = await StorageService.getPrimaryColor();
    final secondary = await StorageService.getSecondaryColor();
    final accent = await StorageService.getAccentColor();
    final logo = await StorageService.getLogoUrl();
    if (!mounted) return;
    setState(() {
      _primaryColor = primary;
      _secondaryColor = secondary;
      _accentColor = accent;
      _logoUrl = logo;
    });
  }

  Future<void> _loadSerialAndListen() async {
    _listenAuth();
    _deviceSerial = await StorageService.getDeviceSerial();
  }

  void _listenAuth() {
    if (_deviceSerial == null) return;
    SocketService.setAuthorizationListener(
      deviceSerial: _deviceSerial!,
      positionId: widget.hose.positionId,
      callback: (payload) {
        if (!mounted) return;
        final int? idPresetNsx = payload['id_presetnsx'];
        final int? saleId = payload['saleid'];
        final int sync = payload['sync'];

        debugPrint('✅ [Instructions] Sync recibido: $sync | idPresetNsx: $idPresetNsx');

        if (sync == 8) {
          _goToDispensing();
          return;
        }

        if (sync == 6) {
          _mostrarVentaZero();
          return;
        }

        if (idPresetNsx != null && idPresetNsx > 0 && saleId == null) {
          if (sync == 2) {
            context.push('/instructions', extra: {
              'payload': payload,
              'hose': widget.hose,
              'customer': widget.customer,
              'programmingValue': widget.programmingValue,
              'programmingType': widget.programmingType,
            });
          }
        } else if (sync == 4 || (saleId != null && saleId > 0)) {
          _onSaleFinished(payload);
        }
      },
    );
  }

  void _mostrarVentaZero() {
    if (_ventaZeroMostrada) return;
    _ventaZeroMostrada = true;
    _timer?.cancel();
    _statusPollTimer?.cancel();
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
              child: Icon(
                Icons.timer_off_outlined,
                color: Colors.orange.shade600,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tiempo agotado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'El surtidor finalizó la espera porque no se levantó la pistola a tiempo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Por favor ingrese su documento nuevamente para intentarlo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
                height: 1.4,
              ),
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
                    Navigator.pop(context); // cierra dialog
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

  void _onSaleFinished(dynamic payload) async{
    final int authId = payload['authorizationid'];

    // 1. Consultamos el detalle real de la venta al API de NSX
    final saleData = await TransactionService.getSaleData(authId);

    if (saleData != null) {
      // 2. Si tenemos datos, vamos a la pantalla de resumen con la data real
      if (mounted) {
        SocketService.clearAuthorizationState();
        context.go('/sale-summary', extra: {
          'sale': saleData,
          'customer': widget.customer,
          'hose': widget.hose,
        });
      }
    } else {
      // 3. Fallback: Si el API de venta falla, pasamos el payload del socket
      // para no dejar al usuario bloqueado (aunque tenga menos info)
      if (mounted) {
        SocketService.clearAuthorizationState();
        context.go('/sale-summary', extra: {
          'sale': payload,
          'customer': widget.customer,
          'hose': widget.hose,
          'isFallback': true
        });
      }
    }
  }

  void _startStep(int step) {
    _timer?.cancel();
    _progressController.reset();
    _stepController.forward(from: 0);
    _progressController.forward();

    // El último paso ("Inicie el despacho") no avanza solo por tiempo:
    // se queda esperando a que el surtidor confirme que ya está surtiendo
    // (por socket o por el polling de estado).
    if (step >= _steps.length - 1) return;

    _timer = Timer(_stepDuration, () {
      setState(() => _currentStep++);
      _startStep(_currentStep);
    });
  }

  /// Salida oculta: mantener presionado el logo regresa al inicio.
  /// No es un gesto visible para el cliente, solo para soporte/operador.
  void _salidaSecreta() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _statusPollTimer?.cancel();
    context.go('/');
  }

  void _goToDispensing() {
    if (_dispensingTriggered) return;
    _dispensingTriggered = true;
    _timer?.cancel();
    _statusPollTimer?.cancel();
    context.push('/dispensing', extra: {
      'hose': widget.hose,
      'customer': widget.customer,
      'programmingValue': widget.programmingValue,
      'programmingType': widget.programmingType,
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusPollTimer?.cancel();
    _authBannerTimer?.cancel();
    _progressController.dispose();
    _stepController.dispose();
    _warningController.dispose();
    _authPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoseColor = Color(
      int.parse(widget.hose.color?.replaceAll('#', 'FF') ?? 'FF1565C0', radix: 16),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor.withOpacity(0.15), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(child: _buildStepsLayout(hoseColor)),

          // ── BANNER: TRANSACCIÓN AUTORIZADA / ADVERTENCIA MANGUERA ───────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  if (_mostrarBannerAutorizado) _buildAutorizadoBanner(),
                  if (_manijaEquivocada) _buildManijaEquivocadaBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Salta a un paso (toque en los lados) y reinicia su cuenta
  void _goToStep(int step) {
    if (step < 0 || step >= _steps.length || step == _currentStep) return;
    setState(() => _currentStep = step);
    _startStep(step);
  }

  // Un paso a la vez, grande: puntos de avance arriba, imagen y texto al centro, barra del paso abajo.
  // Tocar la mitad izquierda retrocede y la derecha avanza.
  Widget _buildStepsLayout(Color hoseColor) {
    return Column(
      children: [
        _buildHeader(hoseColor),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight * 1.2;
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  children: [
                    _buildStepDots(hoseColor, box.maxWidth),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _goToStep(
                          d.localPosition.dx < (box.maxWidth - 48) / 2 ? _currentStep - 1 : _currentStep + 1,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: KeyedSubtree(
                            key: ValueKey(_currentStep),
                            child: _buildStepBody(hoseColor, wide),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProgressSection(hoseColor),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStepDots(Color hoseColor, double width) {
    final size = (width * 0.075).clamp(30.0, 52.0);

    Widget dot(int i) {
      final done = i < _currentStep;
      final current = i == _currentStep;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? Colors.green.shade500 : (current ? hoseColor : const Color(0xFFE6E6E6)),
        ),
        child: Center(
          child: done
              ? Icon(Icons.check_rounded, color: Colors.white, size: size * 0.62)
              : Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.w800,
                    color: current ? Colors.white : const Color(0xFF9A9A9A),
                  ),
                ),
        ),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < _steps.length; i++) ...[
          dot(i),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i < _currentStep ? Colors.green.shade400 : const Color(0xFFE6E6E6),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStepBody(Color hoseColor, bool wide) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;
    final isHose = _currentStep == 2; // la manija se resalta con el color del producto

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final d = wide ? (h * 0.92).clamp(0.0, w * 0.45) : (w * 0.8 < h * 0.5 ? w * 0.8 : h * 0.5);
        final titleSize = (wide ? w * 0.045 : w * 0.075).clamp(26.0, 64.0);
        final descSize = (wide ? w * 0.026 : w * 0.04).clamp(16.0, 34.0);

        // La imagen viene de los recursos de la Orange (paso_*.png); sin ella se muestra el icono del paso
        final image = Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHose ? hoseColor.withOpacity(0.28) : _primaryColor.withOpacity(0.08),
            border: isHose ? Border.all(color: hoseColor, width: 6) : null,
          ),
          child: Center(
            child: PaymentLogo(
              name: step['image'] as String,
              size: d * 0.68,
              color: isHose ? hoseColor : _primaryColor,
              fallback: step['icon'] as IconData,
            ),
          ),
        );

        final texts = SlideTransition(
          position: _stepSlideAnimation,
          child: FadeTransition(
            opacity: _stepFadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Text(
                  step['title'] as String,
                  textAlign: wide ? TextAlign.start : TextAlign.center,
                  style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.1),
                ),
                SizedBox(height: titleSize * 0.3),
                Text(
                  step['desc'] as String,
                  textAlign: wide ? TextAlign.start : TextAlign.center,
                  style: TextStyle(fontSize: descSize, color: const Color(0xFF666666), height: 1.35),
                ),
                if (isLast) ...[
                  SizedBox(height: titleSize * 0.5),
                  _buildEsperandoSurtidoRow(hoseColor),
                ],
              ],
            ),
          ),
        );

        return Center(
          child: wide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [image, const SizedBox(width: 32), Expanded(child: texts)],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [image, SizedBox(height: titleSize * 0.6), texts],
                ),
        );
      },
    );
  }

  Widget _buildHeader(Color hoseColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(color: _primaryColor),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onLongPress: _salidaSecreta,
                child: _logoUrl != null
                    ? Image.network(
                        _logoUrl!,
                        height: 36,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : const SizedBox(height: 36),
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/logo_insepet_blanco.png',
                          height: 36,
                        ),
                      )
                    : Image.asset('assets/images/logo_insepet_blanco.png',
                        height: 36),
              ),
              const Spacer(),
              const SizedBox(width: 34), // balance
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Instrucciones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Siga los pasos para completar el despacho',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEsperandoSurtidoRow(Color hoseColor) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: hoseColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Esperando que el surtidor confirme el inicio del despacho...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: hoseColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Banner grande y llamativo (pulsante) que confirma al cliente que su
  /// transacción fue autorizada al entrar a esta pantalla.
  Widget _buildAutorizadoBanner() {
    return AnimatedBuilder(
      animation: _authPulseController,
      builder: (context, child) {
        final t = _authPulseController.value; // 0 → 1 → 0
        final glow = 0.35 + (t * 0.35);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(glow),
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
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡TRANSACCIÓN AUTORIZADA!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sigue los pasos para iniciar el suministro de combustible.',
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
              GestureDetector(
                onTap: () {
                  _authBannerTimer?.cancel();
                  setState(() => _mostrarBannerAutorizado = false);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Banner grande y llamativo (pulsante) que se superpone a toda la pantalla
  /// cuando el cliente levantó una manguera distinta a la programada.
  Widget _buildManijaEquivocadaBanner() {
    return AnimatedBuilder(
      animation: _warningController,
      builder: (context, child) {
        final t = _warningController.value; // 0 → 1 → 0
        final glow = 0.35 + (t * 0.35);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade600, Colors.deepOrange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(glow),
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
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡MANGUERA EQUIVOCADA!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bajó una manguera distinta a la del color indicado. '
                      'Cuélguela y tome la correcta para continuar.',
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
    );
  }

  Widget _buildProgressSection(Color hoseColor) {
    final stepLabel = _steps[_currentStep]['title'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Paso ${_currentStep + 1} de ${_steps.length}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hoseColor,
              ),
            ),
            // Ícono de surtidor animado
            _AnimatedPumpIcon(color: hoseColor),
          ],
        ),
        const SizedBox(height: 10),

        // Barra de progreso del paso actual
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (_, __) => FractionallySizedBox(
              widthFactor: _progressAnimation.value,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [_accentColor, hoseColor],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Progreso total (pasos completados)
        Row(
          children: List.generate(_steps.length, (i) {
            final done = i < _currentStep;
            final current = i == _currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: done
                      ? Colors.green.shade400
                      : current
                          ? hoseColor
                          : const Color(0xFFE0E0E0),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

}

// ── WIDGET AUXILIAR ───────────────────────────────────────────────────────────

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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_ctrl),
      child: Icon(Icons.local_gas_station_rounded, color: widget.color, size: 24),
    );
  }
}