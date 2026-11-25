import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../data/models/models.dart';
import '../../../data/enums/enums.dart';
import '../../../services/service.dart';
import '../../../utils/color_utils.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_notice.dart';

enum _PaymentPhase { selectMethod, waitingPayment }

class PaymentScreen extends StatefulWidget {
  final ProductHose hose;
  final int programmingId;
  final double programmingValue;
  final ProgrammingType programmingType;
  final List<MethodPayment> methodPayments;
  final CustomerModel customer;
  final double amountAlreadyPaid;

  const PaymentScreen({
    super.key,
    required this.hose,
    required this.programmingId,
    required this.programmingValue,
    required this.programmingType,
    required this.methodPayments,
    required this.customer,
    this.amountAlreadyPaid = 0.0,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Factor de escala de la pantalla (crece con el espacio disponible)
  double _f = 1.0;
  _PaymentPhase _phase = _PaymentPhase.selectMethod;
  int? _selectedMethodId;
  bool _isLoading = false;
  String? _error;
  String _statusMessage = "Esperando confirmación...";
  String? _deviceSerial;
  final Map<int, String> _methodImageUrls = {};
  bool _imagesLoaded = false;
  bool _mostrarInstruccionDatafono = false;
  Timer? _instruccionTimer;
  String? _instruccionImageUrl;

  // Respaldo por REST del estado del surtidor: el socket (tanto el de pagos
  // como el de autorización) es la vía principal para detectar que ya se
  // puede continuar, pero por si se demora o se pierde el evento, se
  // consulta el estado real cada 2s mientras se está esperando algo del
  // surtidor — ya sea tras "autorizar con lo abonado" o tras un pago normal.
  Timer? _statusPollTimer;
  bool _navegoPorEstadoSurtidor = false;

  Color _primaryColor = const Color(0xFF1565C0);
  Color _secondaryColor = const Color(0xFF2F80ED);
  Color _accentColor = const Color(0xFF56CCF2);
  String? _logoUrl;

  String? _qrData;
  double _amountPaid = 0.0;
  double _currentPaymentAmount = 0.0;

  double get _totalCashAmount {
    if (widget.programmingType == ProgrammingType.volumen) {
      return widget.programmingValue * double.parse(widget.hose.price);
    }
    return widget.programmingValue;
  }

  double get _remainingAmount => _totalCashAmount - _amountPaid;
  bool get _isFullPaid => _remainingAmount <= 10;
  bool _isFullPayment = true;

  @override
  void initState() {
    super.initState();
    _amountPaid = widget.amountAlreadyPaid;
    _cargarColores();
    _loadSerialAndConfig();
    _playAudio();
    _preloadMethodImages();
  }

  void _playAudio() {
    AudioService.playTransition('metodo_pago.mp3');
  }

  void _playPartialAudio() {
    AudioService.playTransition('opcion_pago.mp3');
  }

  void _playLoadingPaymentAudio() {
    AudioService.playTransition('espera_pago.mp3');
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

  Future<void> _loadSerialAndConfig() async {
    _deviceSerial = await StorageService.getDeviceSerial();
    _configurarEscuchaAutorizacion();
  }

  Future<void> _preloadMethodImages() async {
    final Map<int, String> urls = {};
    for (final m in widget.methodPayments) {
      if (m.logo != null && m.logo!.trim().isNotEmpty) {
        try {
          final url = await ResourceService.getImageUrl(m.logo!);
          urls[m.idMethodPayment] = url;
        } catch (e) {
          debugPrint('⚠️ No se pudo resolver URL para ${m.name}: $e');
        }
      }
    }
    if (mounted) {
      setState(() {
        _methodImageUrls.addAll(urls);
        _imagesLoaded = true;
      });
    }
  }

  String _formatCurrency(double value) {
    final str = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '\$${buffer.toString()}';
  }

  String _parseErrorMessage(dynamic rawResponse) {
    if (rawResponse == null) return "TRANSACCIÓN RECHAZADA";
    String strResponse = rawResponse.toString();
    if (strResponse.trim() == "null" || strResponse.trim().isEmpty) {
      return "TRANSACCIÓN RECHAZADA";
    }
    try {
      final Map<String, dynamic> layer1 = jsonDecode(strResponse);
      final String responseStr = layer1['content']['response'];
      final Map<String, dynamic> layer2 = jsonDecode(responseStr);
      final String msg = layer2['content']['Mensaje_error'] ?? "Transacción rechazada";
      return msg.toUpperCase();
    } catch (e) {
      return strResponse.length > 50 ? "ERROR AL PROCESAR" : strResponse.toUpperCase();
    }
  }

  void _configurarEscuchaAutorizacion() {
    if (_deviceSerial == null) return;
    
    SocketService.setAuthorizationListener(
      deviceSerial: _deviceSerial!,
      positionId: widget.hose.positionId,
      callback: (payload) {
        if (!mounted) return;
        // El socket llegó primero: se cancela el respaldo por REST de
        // "autorizar con abono" para que no navegue por su cuenta después.
        _navegoPorEstadoSurtidor = true;
        _statusPollTimer?.cancel();

        final int? idPresetNsx = payload['id_presetnsx'];
        final int? saleId = payload['saleid'];
        final int sync = payload['sync'];
        debugPrint("✅ [Socket Auth] Sync: $sync");

        if (sync == 1 && idPresetNsx == null) {
          context.push('/instructions', extra: {
            'payload': payload,
            'hose': widget.hose,
            'customer': widget.customer,
            'programmingValue': widget.programmingValue,
            'programmingType': widget.programmingType,
          });
        } else if (sync == 3) {
          setState(() {
            _phase = _PaymentPhase.selectMethod;
            _selectedMethodId = null;
          });
          _showTemporaryError("Error al enviar la programación al equipo.");
        } else if (idPresetNsx != null && idPresetNsx > 0 && saleId == null) {
          if (sync == 2) {
            context.push('/instructions', extra: {
              'payload': payload,
              'hose': widget.hose,
              'customer': widget.customer,
              'programmingValue': widget.programmingValue,
              'programmingType': widget.programmingType,
            });
          } else if (sync == 8) {
            context.push('/dispensing', extra: {
              'hose': widget.hose,
              'customer': widget.customer,
              'programmingValue': widget.programmingValue,
              'programmingType': widget.programmingType,
            });
          }
        } else if (saleId != null && saleId > 0) {
          context.go('/sale-summary', extra: {
            'sale': payload,
            'customer': widget.customer,
            'hose': widget.hose,
          });
        }
      },
    );
  }

  void _iniciarEscuchaSocket(int paymentId) {

    SocketService.setPaymentListener(paymentId, (payload) {
      if (!mounted) return;
      final int statusId = int.tryParse(payload['statuspaymentid']?.toString() ?? '0') ?? 0;
      final dynamic responseMsg = payload['responsepayment'];

      setState(() {
        switch (statusId) {
          case 2:
            double pagadoAhora = double.tryParse(payload['amount']?.toString() ?? '0') ?? 0;
            _amountPaid += pagadoAhora;
            _isLoading = false;
            _qrData = null;
            if (_isFullPaid) {
              _onPaymentSuccess();
            } else {
              _phase = _PaymentPhase.selectMethod;
              _selectedMethodId = null;
              _showSuccessSnackBar(
                'Abono de ${_formatCurrency(pagadoAhora)} recibido. '
                'Saldo pendiente: ${_formatCurrency(_remainingAmount)}',
              );
            }
            break;
          case 3:
          case 5:
            _qrData = null;
            _showTemporaryError(_parseErrorMessage(responseMsg));
            break;
          case 4:
            _statusMessage = "Validando transacción...";
            if (_selectedMethodId == 2 && responseMsg != null) {
              _qrData = responseMsg.toString();
            }
            break;
          case 1:
            _statusMessage = "Procesando pago...";
            break;
        }
      });
    });
  }

  // ── ACCIONES ──────────────────────────────────────────────────────────────

  void _handleConfirmButtonClick() {
    if (_selectedMethodId == null || _isLoading) return;

    if (_selectedMethodId == 3) {
      _showScannerOverlay(_isFullPayment ? _remainingAmount : 0);
      return;
    }

    if (_isFullPayment) {
      _currentPaymentAmount = _remainingAmount;
      _processPayment(_remainingAmount);
    } else {
      _goToPartialPayment();
    }
  }

  
  Future<void> _goToPartialPayment() async {
    final result = await context.push<String>(
      '/partial_payment',
      extra: {
        'totalValue': _remainingAmount,
        'hose': widget.hose,
        'programmingType': widget.programmingType,
        'methodPaymentList': widget.methodPayments,
        'customer': widget.customer,
      },
    );

    if (result != null && result.isNotEmpty) {
      final double? val = double.tryParse(result);
      if (val != null && val > 0) {
        _currentPaymentAmount = val;
        _processPayment(val);
      }
    }
  }

  Future<void> _processPayment(double amountToPay) async {
    _playLoadingPaymentAudio();
    setState(() { _isLoading = true; _error = null; });

    final result = await PaymentService.createPayment(
      programmingId: widget.programmingId,
      totalAmount: _totalCashAmount,
      amountToPay: amountToPay,
      paymentMethodId: _selectedMethodId!,
    );

    if (result.success && result.paymentId != null) {
      setState(() {
        _phase = _PaymentPhase.waitingPayment;
        _mostrarInstruccionDatafono = false;
        _statusMessage = _selectedMethodId == 2
            ? "Generando QR..."
            : "Sigue las instrucciones en el datáfono";
      });

      // Precarga la imagen de instrucción
      _precargarImagenDatafono();

      // Después de 10 segundos muestra la imagen guía
      _instruccionTimer?.cancel();
      _instruccionTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _phase == _PaymentPhase.waitingPayment) {
          setState(() => _mostrarInstruccionDatafono = true);
        }
      });

      _iniciarEscuchaSocket(result.paymentId!);

      // El socket de pagos es la vía principal para saber que ya se pagó, y
      // el de autorización para saber que el surtidor ya puede continuar —
      // pero cualquiera de los dos se puede demorar o perderse. Este
      // respaldo consulta el estado real del surtidor mientras se espera,
      // así que si ya quedó "Autorizado"/"Surtiendo" se avanza igual.
      _navegoPorEstadoSurtidor = false;
      _startStatusPolling();

      Future.delayed(const Duration(seconds: 300), () {
        if (mounted && _phase == _PaymentPhase.waitingPayment) {
          _showTemporaryError("Tiempo de espera agotado. Verifica el datáfono e intenta de nuevo.");
        }
      });
    } else {
      setState(() { _error = result.message; _isLoading = false; });
    }
  }

  Future<void> _precargarImagenDatafono() async {
    try {
      final url = await ResourceService.getImageUrl('instruccion_datafono.png');
      if (mounted) setState(() => _instruccionImageUrl = url);
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar imagen datafono: $e');
    }
  }

  Future<void> _showScannerOverlay(double amountToPay) async {
    await QrScannerSheet.show(
      context,
      accentColor: _primaryColor,
      title: "Escanear código QR",
      subtitle: "Apunta la cámara al código QR",
      onScanned: (code) => _validarCodigoQR(code),
    );
  }

  Future<void> _processPaymentQR(double valorQR, String code) async {
  setState(() {
    _isLoading = true;
    _phase = _PaymentPhase.waitingPayment;
    _statusMessage = "Procesando pago QR...";
  });

  final result = await PaymentService.createPayment(
      programmingId: widget.programmingId,
      totalAmount: _totalCashAmount,
      amountToPay: valorQR,
      paymentMethodId: 3,
      qrData: code,
    );

    if (result.success && result.paymentId != null) {

      double pagadoAhora = valorQR;
            _amountPaid += pagadoAhora;
            _isLoading = false;
            _qrData = null;
      setState(() => _isLoading = false);
      
            if (_isFullPaid) {
        _onPaymentSuccess();
      } else {
        _phase = _PaymentPhase.selectMethod;
        _selectedMethodId = null;
        _showSuccessSnackBar(
          'Abono de ${_formatCurrency(valorQR)} recibido. '
          'Saldo pendiente: ${_formatCurrency(_remainingAmount)}',
        );
      }
      //_iniciarEscuchaSocket(result.paymentId!);

      Future.delayed(const Duration(seconds: 300), () {
        if (mounted && _phase == _PaymentPhase.waitingPayment) {
          _showTemporaryError("Tiempo de espera agotado.");
        }
      });
    } else {
      setState(() { _isLoading = false; _phase = _PaymentPhase.selectMethod; });
      _showTemporaryError(result.message ?? "Error al procesar el pago QR.");
    }
  }

  Future<void> _validarCodigoQR(String code) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Validando código...";
    });

    try {
      // Llama al endpoint de validación
      final result = await PaymentService.validateQRCode(code: code);

      if (result == null) {
        setState(() => _isLoading = false);
        _showTemporaryError("Código QR inválido o expirado.");
        return;
      }
      final int statusQR = result['data']['idEstadoVuelto']?.toInt() ?? 0;

      if(statusQR == 2)
      {
        setState(() => _isLoading = false);
        _showTemporaryError("Código QR inválido." + result['message']);
        return;
      }
      else if(statusQR > 2)
      {
        setState(() => _isLoading = false);
        _showTemporaryError("Código QR inválido o expirado." + result['message']);
        return;
      }

      // result trae el valor del código
      final double valorQR = result['data']['valor']?.toDouble() ?? 0;

      if (!mounted) return;

      // Mostrar confirmación antes de procesar
      _mostrarConfirmacionQR(valorQR, code);

    } catch (e) {
      setState(() => _isLoading = false);
      _showTemporaryError("Error al validar el código.");
    }
  }

  void _mostrarConfirmacionQR(double valorQR, String code) {
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.green.shade600, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Código validado',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Se realizará el siguiente pago:',
              style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Valor del código',
                      style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                  Text(
                    _formatCurrency(valorQR),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    side: const BorderSide(color: Color(0xFFCCCCCC)),
                  ),
                  child: const Text('Cancelar',
                      style: TextStyle(
                          color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  height: 48,
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
                        _currentPaymentAmount = valorQR;
                        _processPaymentQR(valorQR, code);
                      },
                      child: Center(
                        child: Text('Confirmar',
                            style: TextStyle(
                                color: textColorForGradient(_accentColor, _secondaryColor),
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _showTemporaryError(String message) {
    setState(() {
      _error = message;
      _isLoading = false;
      _phase = _PaymentPhase.selectMethod;
    });
    showAppNotice(context, message, kind: NoticeKind.error);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _error = null);
    });
  }

  void _showSuccessSnackBar(String msg) {
    showAppNotice(context, msg, kind: NoticeKind.success);
  }

  void _onPaymentSuccess() {
    _statusMessage = "Pago completado. Sincronizando surtidor...";
    // A partir de acá solo falta que llegue la autorización del surtidor
    // (por socket); este respaldo por REST evita quedar colgado si ese
    // evento no llega.
    _navegoPorEstadoSurtidor = false;
    _startStatusPolling();
  }

  @override
  void dispose() {
    _instruccionTimer?.cancel();
    _statusPollTimer?.cancel();
    SocketService.stopListeningPayment();
    SocketService.stopListeningAuthorization();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeColor = _primaryColor;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_phase == _PaymentPhase.selectMethod) ...[
                  Expanded(
                    child: isLandscape
                        ? _buildLandscapeSelectMethod(themeColor)
                        : _buildPortraitSelectMethod(themeColor),
                  ),
                ] else ...[
                  Expanded(child: _buildWaitingPhase(themeColor)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitSelectMethod(Color themeColor) {
    if (_isFullPaid) {
      return _buildFullPaidView();
    }

    return LayoutBuilder(builder: (context, box) {
    final byH = box.maxHeight / 650, byW = box.maxWidth / 420;
    _f = (byH < byW ? byH : byW).clamp(1.0, 2.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * _f),
      child: Column(
        children: [
          SizedBox(height: 10 * _f),
          _buildSummaryCard(themeColor),
          SizedBox(height: 16 * _f),

          // Toggle modalidad
          _buildModalidadToggle(themeColor),
          SizedBox(height: 16 * _f),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Selecciona método de pago",
              style: TextStyle(
                fontSize: 15 * _f,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(height: 10 * _f),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 16 * _f),
              child: _buildMethodsList(themeColor),
            ),
          ),
          _buildGradientConfirmButton(),
          SizedBox(height: 16 * _f),
        ],
      ),
    );
    });
  }

  Widget _buildModalidadToggle(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MODALIDAD',
          style: TextStyle(
            fontSize: 11 * _f,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8 * _f),
        Container(
          width: double.infinity,
          height: 46 * _f,
          padding: EdgeInsets.all(4 * _f),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: _isFullPayment
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _isFullPayment = true),
                      child: Center(
                        child: Text(
                          'Pago completo',
                          style: TextStyle(
                            fontSize: 13 * _f,
                            fontWeight: FontWeight.w700,
                            color: _isFullPayment
                                ? textColorForGradient(themeColor, themeColor)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _isFullPayment = false),
                      child: Center(
                        child: Text(
                          'Pago parcial',
                          style: TextStyle(
                            fontSize: 13 * _f,
                            fontWeight: FontWeight.w700,
                            color: !_isFullPayment
                                ? textColorForGradient(themeColor, themeColor)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeSelectMethod(Color themeColor) {
    if (_isFullPaid) {
      return _buildFullPaidView();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          // Izquierda — summary
          Expanded(
            flex: 45,
            child: Center(child: _buildSummaryCard(themeColor)),
          ),

          const SizedBox(width: 20),

          // Derecha — modalidad + métodos + confirmar
          Expanded(
            flex: 55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle modalidad
                _buildModalidadToggle(themeColor),
                const SizedBox(height: 12),

                Text(
                  "Selecciona método de pago",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _buildMethodsList(themeColor),
                ),
                const SizedBox(height: 12),
                _buildGradientConfirmButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPaidView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline_rounded,
                  color: Colors.green.shade600, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pago completado',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'El valor ha sido cubierto en su totalidad.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 55,
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
                  onTap: _autorizarConAbono,
                  child: Center(
                    child: Text(
                      'Autorizar despacho',
                      style: TextStyle(
                        color: textColorForGradient(_accentColor, _secondaryColor),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * _f, vertical: 10 * _f),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
            iconSize: 30,
            padding: EdgeInsets.all(14 * _f),
            onPressed: () {
              if (_phase == _PaymentPhase.waitingPayment) {
                setState(() => _phase = _PaymentPhase.selectMethod);
              } else if (_amountPaid > 0) {
                _mostrarDialogAutorizarAbono();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          _logoUrl != null
              ? Image.network(
                  _logoUrl!,
                  height: 40 * _f,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : SizedBox(height: 40 * _f),
                  errorBuilder: (_, __, ___) =>
                      Image.asset('assets/images/logo_insepet_blanco.png', height: 40),
                )
              : Image.asset('assets/images/logo_insepet_blanco.png', height: 40),
          ClockWidget(color: Colors.black87, fontSize: 13 * _f, autoScale: false),
        ],
      ),
    );
  }

  void _mostrarDialogAutorizarAbono() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
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
          const Text(
            '¿Autorizar con lo abonado?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tienes ${_formatCurrency(_amountPaid)} abonados. '
            'Puedes autorizar el despacho por ese valor o continuar pagando.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Valor a despachar',
                    style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                Text(
                  _formatCurrency(_amountPaid),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          children: [
            // Autorizar con lo abonado
            Container(
              width: double.infinity,
              height: 50,
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
                    _autorizarConAbono();
                  },
                  child: Center(
                    child: Text(
                      'Sí, autorizar con lo abonado',
                      style: TextStyle(
                          color: textColorForGradient(_accentColor, _secondaryColor),
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Continuar pagando
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                side: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              child: const Text('Continuar pagando',
                  style: TextStyle(
                      color: Color(0xFF888888), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            // Salir sin autorizar
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.maybePop(context);
              },
              child: const Text(
                'Salir sin autorizar',
                style: TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _autorizarConAbono() async {
  setState(() => _isLoading = true);

  final ok = await PaymentService.authorizeProgramming(
    clientId: widget.customer.id,
    programmingId: widget.programmingId,
  );

  setState(() => _isLoading = false);

  if (!mounted) return;

  if (ok) {
    // Escucha el socket — el surtidor responderá con sync para ir a instructions
    showAppNotice(context, 'Autorización enviada. Esperando surtidor...', kind: NoticeKind.info, accent: _primaryColor);
    // El socket ya está escuchando en _configurarEscuchaAutorizacion; esto
    // es solo un respaldo por si el evento se demora o se pierde.
    _startStatusPolling();
  } else {
    _showTemporaryError('No se pudo autorizar. Intenta de nuevo.');
  }
}

/// Respaldo por REST del estado del surtidor: consulta el estado real cada
/// 2s para detectar si ya pasó a "Autorizado" (levantar manguera) o directo
/// a "Surtiendo", sin depender únicamente del socket — se usa tanto tras
/// "autorizar con lo abonado" como tras un pago normal (el socket de pagos
/// puede confirmar el pago pero el de autorización demorarse o perderse).
void _startStatusPolling() {
  _statusPollTimer?.cancel();
  _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
    if (_navegoPorEstadoSurtidor) return;
    try {
      final status = await PumpService.getStatusPosition(widget.hose.nsxPositionId);
      if (!mounted || _navegoPorEstadoSurtidor) return;

      switch (status.data.estadoSurtidor) {
        case PumpStatus.surtiendo:
          _irPorEstadoSurtidor('/dispensing');
          break;
        case PumpStatus.autorizado:
        case PumpStatus.listo:
          _irPorEstadoSurtidor('/instructions');
          break;
        default:
          // Sigue esperando: nada que hacer todavía.
          break;
      }
    } catch (_) {
      // Error puntual de la consulta; se reintenta en el próximo ciclo.
    }
  });
}

void _irPorEstadoSurtidor(String ruta) {
  if (_navegoPorEstadoSurtidor || !mounted) return;
  _navegoPorEstadoSurtidor = true;
  _statusPollTimer?.cancel();

  if (ruta == '/dispensing') {
    context.push('/dispensing', extra: {
      'hose': widget.hose,
      'customer': widget.customer,
      'programmingValue': widget.programmingValue,
      'programmingType': widget.programmingType,
    });
  } else {
    // El payload solo se usa por compatibilidad con la firma de
    // InstructionsScreen — internamente esa pantalla vuelve a escuchar el
    // socket y a consultar el estado por su cuenta.
    context.push('/instructions', extra: {
      'payload': const <String, dynamic>{},
      'hose': widget.hose,
      'customer': widget.customer,
      'programmingValue': widget.programmingValue,
      'programmingType': widget.programmingType,
    });
  }
}

  Widget _buildSummaryCard(Color themeColor) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Color de la manguera
    Color hoseColor = themeColor;
    try {
      hoseColor = Color(
        int.parse(widget.hose.color.replaceAll('#', 'FF'), radix: 16),
      );
    } catch (_) {}

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20 * _f),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Producto + badge programación
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.hose.product.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14 * _f,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10 * _f, vertical: 4 * _f),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.programmingType == ProgrammingType.volumen
                      ? "${widget.programmingValue.toStringAsFixed(2)} Gal"
                      : _formatCurrency(_totalCashAmount),
                  style: TextStyle(
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12 * _f,
                  ),
                ),
              ),
            ],
          ),

          // Info extra solo en landscape
          if (isLandscape) ...[
            SizedBox(height: 14 * _f),

            // Barra de color + producto
            Row(
              children: [
                Container(
                  width: 4, height: 44 * _f,
                  decoration: BoxDecoration(
                    color: hoseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(width: 12 * _f),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.hose.product,
                        style: TextStyle(
                          fontSize: 15 * _f,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Manguera #${widget.hose.hoseNumber} · ${_sideLabel(widget.hose.side)}',
                        style: TextStyle(fontSize: 11 * _f, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12 * _f),
            Divider(height: 1, color: Color(0xFFEEEEEE)),
            SizedBox(height: 12 * _f),

            // Precio por galón
            _summaryRow(
              Icons.local_gas_station_outlined,
              'Precio por ${widget.hose.unitOfMeasurement == 'G' ? 'galón' : 'litro'}',
              _formatCurrency(double.tryParse(widget.hose.price) ?? 0),
            ),
            SizedBox(height: 8 * _f),

            // Aproximado en galones
            _summaryRow(
              Icons.speed_outlined,
              'Aproximadamente',
              '${(widget.programmingType == ProgrammingType.volumen
                  ? widget.programmingValue
                  : _remainingAmount / (double.tryParse(widget.hose.price) ?? 1))
                  .toStringAsFixed(2)} ${widget.hose.unitOfMeasurement == 'G' ? 'gal' : 'lt'}',
            ),

            SizedBox(height: 12 * _f),
            Divider(height: 1, color: Color(0xFFEEEEEE)),
          ],

          // Ya pagado
          if (_amountPaid > 0) ...[
            SizedBox(height: 8 * _f),
            Container(
              width: double.infinity,
              padding:
                  EdgeInsets.symmetric(horizontal: 12 * _f, vertical: 8 * _f),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ya pagado',
                      style: TextStyle(
                          fontSize: 13 * _f, color: Colors.green.shade700)),
                  Text(
                    _formatCurrency(_amountPaid),
                    style: TextStyle(
                      fontSize: 13 * _f,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 12 * _f),
          Text(
            _amountPaid > 0 ? 'Saldo pendiente' : 'Total a pagar',
            style: TextStyle(fontSize: 14 * _f, color: Colors.black54),
          ),
          SizedBox(height: 4 * _f),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(_remainingAmount),
              style: TextStyle(
                fontSize: 42 * _f,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
      ],
    );
  }

  String _sideLabel(String side) {
    switch (side.toUpperCase()) {
      case 'I': return 'Izquierda';
      case 'D': return 'Derecha';
      case 'M': return 'Centro';
      default: return side;
    }
  }

  Widget _buildMethodsList(Color themeColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = widget.methodPayments.length;
        final spacing = 12.0 * _f;
        final totalSpacing = spacing * (count - 1);
        
        // La altura real de cada card ocupa todo el espacio disponible
        final itemHeight = (constraints.maxHeight - totalSpacing) / count;

        // Tamaños con límites razonables — escalan con el card pero no se pasan
        // Por alto de la tarjeta y por su ancho (el menor manda), sin topes fijos: crecen con la pantalla
        double byBoth(double ofHeight, double ofWidth, double min) {
          final v = ofHeight < ofWidth ? ofHeight : ofWidth;
          return v < min ? min : v;
        }
        final w = constraints.maxWidth;
        final iconSize = byBoth(itemHeight * 0.52, w * 0.18, 44.0);
        final fontSize = byBoth(itemHeight * 0.20, w * 0.055, 16.0);
        final radioSize = byBoth(itemHeight * 0.28, w * 0.07, 26.0);
        final hPadding = byBoth(itemHeight * 0.08, w * 0.04, 16.0);

        return Column(
          children: List.generate(count, (i) {
            final m = widget.methodPayments[i];
            final isSelected = _selectedMethodId == m.idMethodPayment;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i < count - 1 ? spacing : 0),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedMethodId = m.idMethodPayment),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: hPadding),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? themeColor.withOpacity(0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? themeColor
                            : Colors.grey.shade200,
                        width: isSelected ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? themeColor.withOpacity(0.12)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: isSelected ? 14 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Ícono
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? themeColor.withOpacity(0.1)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? themeColor.withOpacity(0.25)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: _buildMethodIcon(
                                m, themeColor, isSelected, iconSize),
                          ),
                        ),
                        SizedBox(width: hPadding * 0.8),

                        // Nombre
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                m.name,
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? themeColor
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (itemHeight > 80) ...[
                                SizedBox(height: fontSize * 0.25),
                                Text(
                                  isSelected ? 'Seleccionado ✓' : 'Toca para seleccionar',
                                  style: TextStyle(
                                    fontSize: (fontSize * 0.60).clamp(12, double.infinity),
                                    color: isSelected
                                        ? themeColor.withOpacity(0.7)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Radio
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: radioSize,
                          height: radioSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? themeColor
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? themeColor
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: radioSize * 0.55,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMethodIcon(MethodPayment m, Color themeColor, bool isSelected, [double size = 60.0]) {
    final fallbackIcon = Icon(
      m.name.toLowerCase().contains('cash') || m.name.toLowerCase().contains('efectivo')
          ? Icons.payments_rounded
          : m.name.toLowerCase().contains('qr') || m.name.toLowerCase().contains('vuelto')
              ? Icons.qr_code_rounded
              : Icons.credit_card_rounded,
      color: isSelected ? themeColor : Colors.grey.shade500,
      size: size * 0.58, // <- más grande
    );

    final String? resolvedUrl = _methodImageUrls[m.idMethodPayment];

    if (!_imagesLoaded) return _buildImageShimmer(size, themeColor);

    if (resolvedUrl == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: fallbackIcon),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(size * 0.1), // margen interno proporcional
        child: Image.network(
          resolvedUrl,
          width: size * 0.8,
          height: size * 0.8,
          fit: BoxFit.contain,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: frame == null
                  ? _buildImageShimmer(size, themeColor)
                  : child,
            );
          },
          errorBuilder: (_, error, __) {
            debugPrint('⚠️ Error cargando logo [${m.name}]: $error');
            return Center(child: fallbackIcon);
          },
        ),
      ),
    );
  }

  Widget _buildImageShimmer(double size, Color themeColor) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: themeColor.withOpacity(0.35),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientConfirmButton() {
    bool isEnabled = _selectedMethodId != null && !_isLoading;
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 55 * _f,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: isEnabled
                ? LinearGradient(
                    colors: [_accentColor, _secondaryColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: isEnabled ? null : Colors.grey.shade300,
            boxShadow: isEnabled
                ? [BoxShadow(
                    color: _secondaryColor.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: isEnabled ? _handleConfirmButtonClick : null,
              child: Center(
                child: _isLoading
                    ? SizedBox(
                        height: 24 * _f, width: 24,
                        child: CircularProgressIndicator(
                            color: textColorForBackground(Colors.grey.shade300),
                            strokeWidth: 2.5),
                      )
                    : Text(
                        'Confirmar pago',
                        style: TextStyle(
                            color: isEnabled
                                ? textColorForGradient(_accentColor, _secondaryColor)
                                : textColorForBackground(Colors.grey.shade300),
                            fontSize: 18 * _f,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ),
        if (_amountPaid > 0) ...[
          SizedBox(height: 8 * _f),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _mostrarDialogAutorizarAbono,
              icon: Icon(Icons.local_gas_station_outlined,
                  color: _primaryColor, size: 18 * _f),
              label: Text(
                'Autorizar con ${_formatCurrency(_amountPaid)} abonados',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 13 * _f,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWaitingPhase(Color themeColor) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            // Izquierda — spinner o QR
            Expanded(
              flex: 45,
              child: Center(
                child: _selectedMethodId == 2 && _qrData != null
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black12, blurRadius: 20)
                          ],
                        ),
                        child: QrImageView(
                          data: _qrData!,
                          version: QrVersions.auto,
                          size: 180.0,
                          eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: themeColor),
                        ),
                      )
                    : SizedBox(
                        height: 100, width: 100,
                        child: CircularProgressIndicator(
                          color: themeColor,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 20),

            // Derecha — estado + imagen instrucción + cancelar
            Expanded(
              flex: 55,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Monto a pagar: ${_formatCurrency(_currentPaymentAmount)}",
                    style: TextStyle(
                        fontSize: 16,
                        color: themeColor,
                        fontWeight: FontWeight.bold),
                  ),

                  if (_mostrarInstruccionDatafono && _instruccionImageUrl != null) ...[
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _instruccionImageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _phase = _PaymentPhase.selectMethod;
                      _qrData = null;
                      _mostrarInstruccionDatafono = false;
                      _instruccionTimer?.cancel();
                    }),
                    icon: const Icon(Icons.cancel_outlined,
                        color: Colors.redAccent),
                    label: const Text(
                      "Cancelar Transacción",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Portrait — igual que antes
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_selectedMethodId == 2 && _qrData != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20)
                ],
              ),
              child: QrImageView(
                data: _qrData!,
                version: QrVersions.auto,
                size: 250.0,
                eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: themeColor),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 120, width: 120,
              child: CircularProgressIndicator(
                color: themeColor,
                strokeWidth: 10,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
          ],
          const SizedBox(height: 30),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Text(
            "Monto a pagar: ${_formatCurrency(_currentPaymentAmount)}",
            style: TextStyle(
                fontSize: 18,
                color: themeColor,
                fontWeight: FontWeight.bold),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: _mostrarInstruccionDatafono
                ? Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.orange.shade200, width: 1),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.touch_app_outlined,
                                  color: Colors.orange.shade700, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Finaliza la transacción en el datáfono',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (_instruccionImageUrl != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _instruccionImageUrl!,
                                fit: BoxFit.contain,
                                height: 160,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => setState(() {
              _phase = _PaymentPhase.selectMethod;
              _qrData = null;
              _mostrarInstruccionDatafono = false;
              _instruccionTimer?.cancel();
            }),
            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
            label: const Text(
              "Cancelar Transacción",
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _PagoOpcionModal extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final double totalBalance;
  final Function(bool isFullPayment) onNext;

  const _PagoOpcionModal({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.totalBalance,
    required this.onNext,
  });

  @override
  State<_PagoOpcionModal> createState() => _PagoOpcionModalState();
}

class _PagoOpcionModalState extends State<_PagoOpcionModal> {
  bool _isFullPayment = true;



  String _formatPrice(double value) {
    final str = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '\$${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Opción de pago',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '¿Cómo deseas pagar?',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade400),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const Divider(height: 28, color: Color(0xFFEEEEEE)),

            // Opción: Pago completo
            _buildOptionTile(
              title: 'Pago completo',
              subtitle: 'Pagar el saldo total ahora',
              icon: Icons.payments_rounded,
              isSelected: _isFullPayment,
              onTap: () => setState(() => _isFullPayment = true),
            ),
            const SizedBox(height: 12),

            // Opción: Pago parcial
            _buildOptionTile(
              title: 'Pago parcial',
              subtitle: 'Abonar un monto menor',
              icon: Icons.pie_chart_rounded,
              isSelected: !_isFullPayment,
              onTap: () => setState(() => _isFullPayment = false),
            ),

            const SizedBox(height: 24),

            // Total
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saldo pendiente',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _formatPrice(widget.totalBalance),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Botón continuar
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [widget.accentColor, widget.secondaryColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.secondaryColor.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => widget.onNext(_isFullPayment),
                  child: Center(
                    child: Text(
                      'Continuar',
                      style: TextStyle(
                        color: textColorForGradient(widget.accentColor, widget.secondaryColor),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? widget.primaryColor : const Color(0xFFDDDDDD),
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(
                  color: widget.primaryColor.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? widget.primaryColor.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? widget.primaryColor : Colors.grey.shade500,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? widget.primaryColor : const Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? widget.primaryColor : const Color(0xFFCCCCCC),
                  width: 2,
                ),
                color: isSelected ? widget.primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}