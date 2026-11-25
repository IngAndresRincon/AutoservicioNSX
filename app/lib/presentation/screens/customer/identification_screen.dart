import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gnesys_as/data/enums/programing_type.dart';
import 'package:gnesys_as/utils/color_utils.dart';
import 'package:gnesys_as/presentation/widgets/app_notice.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/models/models.dart';
import '../../../services/service.dart';

class CustomerIdentificationScreen extends StatefulWidget {
  const CustomerIdentificationScreen({super.key});

  @override
  State<CustomerIdentificationScreen> createState() => _CustomerIdentificationScreenState();
}

class _CustomerIdentificationScreenState extends State<CustomerIdentificationScreen> {
  // Escala del formulario segun el alto disponible (el contenido natural mide unos 310)
  double _f = 1.0;
  String input = "";
  bool _isLoading = false;
  String? _error;
  String? _logoUrl;
  Color _primaryColor = const Color(0xFF1E88E5);
  Color _secondaryColor = const Color(0xFF2F80ED);
  Color _accentColor = const Color(0xFF56CCF2);
  CustomerModel? _clienteIdentificado;
  bool _modoCodigoTrazabilidad = false;
  bool _navegando = false;
  bool _mostrarBanner = false;
  int _maximumChangeAmount = 0;
  String? _stationFlag;
  // positionId (local, no el nsxPositionId) asociado a este equipo, para el
  // llamado de impresión de código — todas las mangueras del mapeo
  // comparten la misma posición física.
  int? _positionId;

  @override
  void initState() {
    super.initState();
    _playWelcomeAudio();
    _cargarColores();
    _cargarMapping();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _mostrarBanner) {
          setState(() => _mostrarBanner = false);
        }
      });
    });
  }

  void _playWelcomeAudio() {
    AudioService.playTransition('documento.mp3');
  }

  Future<void> _cargarColores() async {
  final primary = await StorageService.getPrimaryColor();
  final secondary = await StorageService.getSecondaryColor();
  final accent = await StorageService.getAccentColor();
  final logo = await StorageService.getLogoUrl();
  setState(() {
    _primaryColor = primary;
    _secondaryColor = secondary;
    _accentColor = accent;
    _logoUrl = logo;
  });
}

  Future<void> _cargarMapping() async {
    final id = await StorageService.getScreenNumber();
    final mapping = await PumpService.getMappingWithFallback(id ?? 1);
    if (!mounted) return;
    final amount = mapping?.station.data.maximumChangeAmount ?? 0;
    setState(() {
      _maximumChangeAmount = amount;
      _stationFlag = mapping?.station.data.flag;
      // La primera manguera del mapeo: todas comparten la misma posición
      // física en este equipo.
      _positionId = mapping != null && mapping.productHoses.isNotEmpty
          ? mapping.productHoses.first.positionId
          : null;
      // Solo muestra el banner si hay monto configurado
      _mostrarBanner = amount > 0;
    });
  }

  @override
  void dispose() {
    AudioService.stop(); 
    super.dispose();
  }

  

  bool get _isValidLength => input.length >= 5 && input.length <= 10;

  void _onKeyPress(String value) {
    if (input.isEmpty && value == "0") return;
    if (input.length < 10) {
      setState(() {
        input += value;
        _error = null;
      });
    }
  }

  void _onBackspace() {
    if (input.isNotEmpty) {
      setState(() {
        input = input.substring(0, input.length - 1);
        _error = null;
      });
    }
  }

  Future<void> _onContinue() async {
  if (input.isEmpty) return;

  setState(() { _isLoading = true; _error = null; });

  try {
    // ── MODO CÓDIGO DE TRAZABILIDAD ───────────────────────────────────
    if (_modoCodigoTrazabilidad) {
      final customerService = CustomerService();
      final clientData = await customerService.validateClient(input);

      if (clientData == null) {
        setState(() { _isLoading = false; _error = "Código no encontrado."; });
        return;
      }

      final finalCustomer = CustomerModel(
        id: clientData['id'] as int,
        identifier: input,
        name: clientData['nombre'] as String? ?? "Cliente",
        documentType: clientData['tipo_documento'] as String?,
        email: clientData['correo'] as String?,
        isAnonymous: false,
        licensePlate: clientData['placa'] as String?,
        km: (clientData['km'] as num?)?.toInt(),
      );

      // 1. Verificar autorización pendiente
      final pending = await PaymentService.getPendingAuthorization(
        userId: finalCustomer.id,
      );

      if (pending != null) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        _mostrarDialogPendiente(finalCustomer, pending);
        return;
      }

      // 2. Verificar programación pendiente
      final pendingProg = await PaymentService.getPendingProgramming(
        userId: finalCustomer.id,
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (pendingProg != null) {
        _mostrarDialogProgramacionPendiente(finalCustomer, pendingProg);
      } else {
        setState(() { _clienteIdentificado = finalCustomer; _navegando = false; });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || _navegando) return;
        _navegando = true;
        await context.push('/positions', extra: {'customer': finalCustomer});
        if (mounted) {
          setState(() { _clienteIdentificado = null; _navegando = false; input = ""; });
        }
      }
      return;
    }

    // ── MODO DOCUMENTO NORMAL ─────────────────────────────────────────
    final customerService = CustomerService();
    CustomerModel? finalCustomer;

    // 1. Primero local
    final clientData = await customerService.validateClient(input);
    if (clientData != null && clientData['nombre'] != null) {
      finalCustomer = CustomerModel(
        id: clientData['id'] as int,
        identifier: input,
        name: clientData['nombre'] as String?,
        documentType: clientData['tipo_documento'] as String?,
        email: clientData['correo'] as String?,
        isAnonymous: false,
        licensePlate: clientData['placa'] as String?,
        km: (clientData['km'] as num?)?.toInt(),
      );
    } else {
      // 2. Si no tiene datos completos, va a DIAN
      final clientDian = await customerService.validateClientDIAN(input);
      if (clientDian != null && clientDian is Map<String, dynamic>) {
        finalCustomer = CustomerModel.fromDianJson(clientDian);
      } else if (clientData != null) {
        // Tiene ID local pero sin datos en DIAN — cliente registrado sin info completa
        finalCustomer = CustomerModel(
          id: clientData['id'] as int,
          identifier: input,
          name: null,
          documentType: null,
          email: null,
          isAnonymous: false,
          licensePlate: clientData['placa'] as String?,
          km: (clientData['km'] as num?)?.toInt(),
        );
      }
    }

      // No encontrado en absoluto, o encontrado localmente pero sin datos
      // completos (DIAN no respondió con nombre/correo).
      final bool esClienteIncompleto = finalCustomer == null || finalCustomer.name == null;

      if (esClienteIncompleto) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        if (_stationFlag == 'GNESYS') {
          _mostrarClienteNoRegistrado();
          return;
        }
        if (finalCustomer == null) {
          setState(() => _error = "Documento no registrado.");
          return;
        }
        // No es GNESYS y el cliente existe con datos incompletos: continúa el flujo normal
      }

      // 1. Verificar autorización pendiente
      final pending = await PaymentService.getPendingAuthorization(
        userId: finalCustomer.id,
      );

      if (pending != null) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        _mostrarDialogPendiente(finalCustomer, pending);
        return;
      }

      // 2. Verificar programación pendiente
      final pendingProg = await PaymentService.getPendingProgramming(
        userId: finalCustomer.id,
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (pendingProg != null) {
        _mostrarDialogProgramacionPendiente(finalCustomer, pendingProg);
      } else {
        setState(() { _clienteIdentificado = finalCustomer; _navegando = false; });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || _navegando) return;
        _navegando = true;
        await context.push('/positions', extra: {'customer': finalCustomer});
        if (mounted) {
          setState(() { _clienteIdentificado = null; _navegando = false; input = ""; });
        }
      }

    } catch (e) {
      setState(() { _isLoading = false; _error = "Error de conexión"; });
    }
  }

  void _onSkip() async{
    setState(() => _isLoading = true);

    try {
      final customerService = CustomerService();
      final result = await customerService.validateClient(
        "222222222222",
        cfClient: true,
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (result != null) {
        final codigoTrazabilidad = result['identificador'] as String? ?? '';
        final clientId = result['id'] as int? ?? 1;

        // Mostrar código al cliente antes de navegar
        _mostrarCodigoConsumidorFinal(codigoTrazabilidad, () {
          context.push('/positions', extra: {
            'customer': CustomerModel(
              id: clientId,
              identifier: codigoTrazabilidad,
              name: "CONSUMIDOR FINAL",
              documentType: "NIT",
              isAnonymous: true,
            ),
          });
        });
      } else {
        // Fallback sin código
        context.push('/positions', extra: {
          'customer': CustomerModel.anonymous(),
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      context.push('/positions', extra: {
        'customer': CustomerModel.anonymous(),
      });
    }
  }

  void _mostrarClienteNoRegistrado() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
              child: Icon(Icons.person_off_outlined,
                  color: Colors.orange.shade600, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cliente no registrado en la estación',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Si necesitas factura electrónica debes registrarte primero. '
              'Si continúas con la venta, se facturará a Consumidor Final.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Botón principal: Reintentar con otro documento (lo que debe
          // hacer un cliente normal).
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
              boxShadow: [
                BoxShadow(
                  color: _secondaryColor.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() { input = ""; _error = null; });
                },
                child: Center(
                  child: Text(
                    'Reintentar',
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
          const SizedBox(height: 4),
          // Secundario respecto a "Reintentar", pero visible: dispara el
          // mismo flujo de código de trazabilidad que "Omitir" en la
          // pantalla principal (antes dejaba continuar sin generar nada).
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() { input = ""; _error = null; });
              _onSkip();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              side: const BorderSide(color: Color(0xFFCCCCCC)),
            ),
            child: const Text(
              'Continuar como Consumidor Final',
              style: TextStyle(
                color: Color(0xFF888888),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarCodigoConsumidorFinal(String codigo, VoidCallback onContinuar) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool imprimiendo = false;
        return StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_outlined, color: _primaryColor, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tu código de trazabilidad',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Guarda este código. Te permitirá hacer seguimiento a tu transacción ante cualquier eventualidad.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primaryColor.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Código',
                    style: TextStyle(
                      fontSize: 12,
                      color: _primaryColor.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    codigo,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _primaryColor,
                      letterSpacing: 3,
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
          Text(
            '¿Deseas imprimir este código?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: imprimiendo
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          onContinuar();
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    side: const BorderSide(color: Color(0xFFCCCCCC)),
                  ),
                  child: const Text('No imprimir',
                      style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
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
                      onTap: imprimiendo
                          ? null
                          : () async {
                              setLocalState(() => imprimiendo = true);

                              final positionId = _positionId;
                              final ok = positionId != null
                                  ? await CustomerService().imprimirCodigo(
                                      positionId: positionId,
                                      code: codigo,
                                    )
                                  : false;

                              if (!mounted) return;

                              if (!ok) {
                                showAppNotice(context, 'No se pudo imprimir el código, pero puedes continuar', kind: NoticeKind.error);
                                await Future.delayed(const Duration(milliseconds: 900));
                              }

                              if (!mounted) return;
                              Navigator.pop(ctx);
                              onContinuar();
                            },
                      child: Center(
                        child: imprimiendo
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Sí, imprimir',
                                style: TextStyle(
                                  color: textColorForGradient(_accentColor, _secondaryColor),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
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
      },
    );
  }

  void _mostrarDialogProgramacionPendiente(
  CustomerModel customer,
  Map<String, dynamic> prog,
) {
  final currencyFmt = NumberFormat('\$#,##0', 'es_CO');
  final double valorProgramado = double.tryParse(prog['valor_programado'] ?? '0') ?? 0;
  final double valorAbonado = double.tryParse(prog['valor_abonado'] ?? '0') ?? 0;
  final double valorPendiente = valorProgramado - valorAbonado;
  final int programmingId = prog['idprogramacion'] as int;
  final int posicionId = prog['posicion_id'] as int;
  final double precio = double.tryParse(prog['precio'] ?? '0') ?? 0;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payments_outlined,
                color: Colors.blue.shade600, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            '¡Hola, ${customer.name ?? customer.identifier}!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Tienes un pago pendiente por completar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _pendingRow('Total programado', currencyFmt.format(valorProgramado)),
                const SizedBox(height: 4),
                _pendingRow('Ya abonado', currencyFmt.format(valorAbonado),
                    valueColor: Colors.green.shade600),
                const Divider(height: 16, color: Color(0xFFE0E0E0)),
                _pendingRow('Saldo pendiente', currencyFmt.format(valorPendiente),
                    valueColor: Colors.orange.shade700),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¿Deseas continuar con este pago?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        OutlinedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            setState(() => _clienteIdentificado = customer);
            await context.push('/positions', extra: {'customer': customer});
            if (mounted) {
              setState(() {
                _clienteIdentificado = null;
                _navegando = false;
                input = "";
              });
            }
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            side: const BorderSide(color: Color(0xFFCCCCCC)),
          ),
          child: const Text('No, ir a productos',
              style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
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
            boxShadow: [
              BoxShadow(
                color: _secondaryColor.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                Navigator.pop(ctx);
                _continuarPagoPendiente(customer, prog);
              },
              child: Center(
                child: Text(
                  'Sí, continuar pago',
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
      ],
    ),
  );
}

  Future<void> _continuarPagoPendiente(
    CustomerModel customer,
    Map<String, dynamic> prog,
  ) async {
    final int programmingId = prog['idprogramacion'] as int;
    final double valorProgramado = double.tryParse(prog['valor_programado'] ?? '0') ?? 0;
    final double valorAbonado = double.tryParse(prog['valor_abonado'] ?? '0') ?? 0;
    final int tipoProg = prog['tipo_programacion'] as int? ?? 2;

    // Necesitamos el mapping para obtener la hose y los métodos de pago
    setState(() => _isLoading = true);
    final id = await StorageService.getScreenNumber();
    final mapping = await PumpService.getMappingWithFallback(id ?? 1);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (mapping == null) {
      showAppNotice(context, 'No se pudo obtener la configuración', kind: NoticeKind.error);
      return;
    }

    // Busca la hose que coincide con la posición del programming
    final posicionId = prog['posicion_id'] as int;
    final hose = mapping.productHoses.firstWhere(
      (h) => h.positionId == posicionId && h.activeHose,
      orElse: () => mapping.productHoses.first,
    );

    
    final programmingType = tipoProg == 3
        ? ProgrammingType.volumen
        : ProgrammingType.dinero;

    context.push('/payment', extra: {
      'hose': hose,
      'programmingId': programmingId,
      'programmingValue': valorProgramado,
      'programmingType': programmingType,
      'methodPayments': mapping.methodPayment,
      'customer': customer,
      'amountAlreadyPaid': valorAbonado, // <- nuevo parámetro
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _primaryColor;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: themeColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── CONTENIDO PRINCIPAL ────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header
                SizedBox(
                  height: isLandscape
                      ? MediaQuery.of(context).size.height * 0.14
                      : MediaQuery.of(context).size.height * 0.12,
                  child: _buildHeader(),
                ),

                // Body
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: isLandscape
                        ? _buildLandscapeBody(themeColor)
                        : _buildPortraitBody(themeColor),
                  ),
                ),
              ],
            ),
          ),

          // ── OVERLAY LOADING ────────────────────────────────────────────
          if (_isLoading && _clienteIdentificado == null)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // ── OVERLAY SALUDO ─────────────────────────────────────────────
          if (_clienteIdentificado != null)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 400),
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 80 : 32,
                    ),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (_clienteIdentificado!.name ??
                                      _clienteIdentificado!.identifier)
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '¡Bienvenido!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _clienteIdentificado!.name ??
                              _clienteIdentificado!.identifier,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _clienteIdentificado!.identifier,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.grey.shade200,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(_primaryColor),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Preparando tu experiencia...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── BANNER INFORMATIVO ─────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset:
                  _mostrarBanner ? Offset.zero : const Offset(0, -1.5),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _mostrarBanner ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: _mostrarBanner
                    ? GestureDetector(
                        onTap: () =>
                            setState(() => _mostrarBanner = false),
                        child: Container(
                          color: Colors.black.withOpacity(0.75),
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isLandscape ? 60 : 24,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0D1B2A),
                                      Color(0xFF1B2838)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.6),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      right: -20, top: -20,
                                      child: Container(
                                        width: 120, height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _primaryColor
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(
                                          isLandscape ? 20 : 28),
                                      child: isLandscape
                                          ? Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .all(16),
                                                  decoration: BoxDecoration(
                                                    color: _primaryColor
                                                        .withOpacity(0.15),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: _primaryColor
                                                          .withOpacity(0.3),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.payments_rounded,
                                                    color: _primaryColor,
                                                    size: 32,
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        '¿Sabe cómo funcionan los vueltos?',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 8),
                                                      RichText(
                                                        text: TextSpan(
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                            color: Colors
                                                                .white60,
                                                            height: 1.5,
                                                          ),
                                                          children: [
                                                            const TextSpan(
                                                              text:
                                                                  'Si tanquea menos de lo que pagó, el vendedor de isla le devuelve el saldo en efectivo para montos de hasta ',
                                                            ),
                                                            TextSpan(
                                                              text: _formatChangeAmount(
                                                                  _maximumChangeAmount),
                                                              style: TextStyle(
                                                                color:
                                                                    _accentColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                            const TextSpan(
                                                                text: '.'),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 16),
                                                      Container(
                                                        height: 44,
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      30),
                                                          gradient:
                                                              LinearGradient(
                                                            colors: [
                                                              _accentColor,
                                                              _secondaryColor
                                                            ],
                                                          ),
                                                        ),
                                                        child: Material(
                                                          color: Colors
                                                              .transparent,
                                                          child: InkWell(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        30),
                                                            onTap: () => setState(
                                                                () => _mostrarBanner =
                                                                    false),
                                                            child: Center(
                                                              child: Text(
                                                                'Entendido, continuar',
                                                                style: TextStyle(
                                                                  color: textColorForGradient(
                                                                      _accentColor,
                                                                      _secondaryColor),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(
                                                          18),
                                                  decoration: BoxDecoration(
                                                    color: _primaryColor
                                                        .withOpacity(0.15),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: _primaryColor
                                                          .withOpacity(0.3),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.payments_rounded,
                                                    color: _primaryColor,
                                                    size: 40,
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                const Text(
                                                  '¿Sabe cómo funcionan\nlos vueltos?',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    height: 1.3,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                RichText(
                                                  textAlign: TextAlign.center,
                                                  text: TextSpan(
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      color: Colors.white60,
                                                      height: 1.6,
                                                    ),
                                                    children: [
                                                      const TextSpan(
                                                        text:
                                                            'Si tanquea menos de lo que pagó, el vendedor de isla le devuelve el saldo en efectivo\npara montos de hasta ',
                                                      ),
                                                      TextSpan(
                                                        text: _formatChangeAmount(
                                                            _maximumChangeAmount),
                                                        style: TextStyle(
                                                          color: _accentColor,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 20,
                                                        ),
                                                      ),
                                                      const TextSpan(
                                                          text: '.'),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 28),
                                                Container(
                                                  width: double.infinity,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30),
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        _accentColor,
                                                        _secondaryColor
                                                      ],
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                    ),
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              30),
                                                      onTap: () => setState(
                                                          () => _mostrarBanner =
                                                              false),
                                                      child: Center(
                                                        child: Text(
                                                          'Entendido, continuar',
                                                          style: TextStyle(
                                                            color: textColorForGradient(
                                                                _accentColor,
                                                                _secondaryColor),
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                    Positioned(
                                      top: 8, right: 8,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _mostrarBanner = false),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            color: Colors.white54,
                                            size: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ── PORTRAIT ────────────────────────────────────────────────────────────────
Widget _buildPortraitBody(Color themeColor) {
  return Column(
    children: [
      Expanded(
        flex: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              _f = (h * 0.9 / 310).clamp(1.0, 1.8);
              // Si el contenido no cabe (mensajes, texto legal en dos lineas) se reduce para no desbordar
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _modoCodigoTrazabilidad
                        ? "Ingresa tu código de trazabilidad"
                        : "Ingresa tu número de identificación",
                    style: TextStyle(
                      fontSize: 24 * _f,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: h * 0.06),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomDisplay(themeColor),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 5, left: 5),
                          child: Text(_error!,
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 15 * _f,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                      if (input.isNotEmpty && input.length < 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 5, left: 5),
                          child: Text("Mínimo 5 dígitos",
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 15 * _f,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                    ],
                  ),
                  SizedBox(height: h * 0.06),
                  _buildGradientConfirmButton(),
                  SizedBox(height: h * 0.03),
                  _buildSkipButton(),
                ],
              ),
                ),
              );
            },
          ),
        ),
      ),
      Expanded(
        flex: 55,
        child: _buildCustomKeypad(),
      ),
    ],
  );
}

// ── LANDSCAPE ───────────────────────────────────────────────────────────────
Widget _buildLandscapeBody(Color themeColor) {
  return Row(
    children: [
      // Izquierda — formulario
      Expanded(
        flex: 60,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 20, 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              _f = (h * 0.9 / 310).clamp(1.0, 1.8);
              // Si el contenido no cabe (mensajes, texto legal en dos lineas) se reduce para no desbordar
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _modoCodigoTrazabilidad
                        ? "Ingresa tu código de trazabilidad"
                        : "Ingresa tu número de identificación",
                    style: TextStyle(
                      fontSize: 22 * _f,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: h * 0.06),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomDisplay(themeColor),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 5, left: 5),
                          child: Text(_error!,
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13 * _f,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                      if (input.isNotEmpty && input.length < 5)
                        Padding(
                          padding: EdgeInsets.only(top: 5, left: 5),
                          child: Text("Mínimo 5 dígitos",
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 13 * _f,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                    ],
                  ),
                  SizedBox(height: h * 0.06),
                  _buildGradientConfirmButton(),
                  SizedBox(height: h * 0.03),
                  _buildSkipButton(),
                ],
              ),
                ),
              );
            },
          ),
        ),
      ),

      // Divisor
      Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: 16),
        color: Colors.grey.shade200,
      ),

      // Derecha — teclado
      Expanded(
        flex: 55,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: _buildCustomKeypad(),
        ),
      ),
    ],
  );
}

String _formatChangeAmount(int value) {
  final str = value.toString();
  final buffer = StringBuffer('\$');
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
  }
  return buffer.toString();
}

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            child: Material(
              color: Colors.white.withOpacity(0.15),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(14.0),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
          _logoUrl != null
              ? Image.network(
                  _logoUrl!,
                  height: 45,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const SizedBox(height: 45),
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/logo_insepet_blanco.png',
                    height: 45,
                    fit: BoxFit.contain,
                  ),
                )
              : Image.asset(
                  'assets/images/logo_insepet_blanco.png',
                  height: 45,
                  fit: BoxFit.contain,
                ),
          Positioned(
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() {
                _modoCodigoTrazabilidad = !_modoCodigoTrazabilidad;
                input = "";
                _error = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _modoCodigoTrazabilidad
                      ? Colors.white
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _modoCodigoTrazabilidad
                          ? Icons.badge_outlined
                          : Icons.qr_code_outlined,
                      color: _modoCodigoTrazabilidad
                          ? _primaryColor
                          : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _modoCodigoTrazabilidad ? 'Documento' : 'Código',
                      style: TextStyle(
                        color: _modoCodigoTrazabilidad
                            ? _primaryColor
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCustomDisplay(Color themeColor) {
    bool isEmpty = input.isEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 18 * _f, horizontal: 16 * _f),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isEmpty ? Colors.grey.shade300 : themeColor,
          width: isEmpty ? 1.5 : 2,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Text(
            isEmpty
                ? (_modoCodigoTrazabilidad
                    ? "Ingresa tu código de trazabilidad"
                    : "Ingrese el número de identificación")
                : input,
            style: TextStyle(
              fontSize: isEmpty ? 17 * _f : (constraints.maxWidth * 0.07 * _f).clamp(20.0, 30.0 * _f),
              color: isEmpty ? Colors.grey : Colors.black,
              fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
              letterSpacing: isEmpty ? 0 : 3,
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradientConfirmButton() {
    bool isEnabled = _isValidLength;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 52 * _f,
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
                ? [
                    BoxShadow(
                      color: _secondaryColor.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: isEnabled ? _onContinue : null,
              child: Center(
                child: Text(
                  "Confirmar",
                  style: TextStyle(
                    color: isEnabled
                        ? textColorForGradient(_accentColor, _secondaryColor)
                        : textColorForBackground(Colors.grey.shade300),
                    fontSize: 18 * _f,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 10 * _f),
        // Habeas data
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4 * _f),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 12 * _f,
                color: Color(0xFF8A8A8A),
                height: 1.4,
              ),
              children: [
                const TextSpan(
                  text: 'Al continuar, acepta el ',
                ),
                TextSpan(
                  text: 'tratamiento de sus datos personales',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(
                  text: ' conforme a nuestra política de privacidad '
                      'y la Ley 1581 de 2012.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkipButton() {
    return Padding(
      padding: EdgeInsets.only(top: 6 * _f),
      child: SizedBox(
        width: double.infinity,
        height: 50 * _f,
        child: OutlinedButton(
          onPressed: _onSkip,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            side: const BorderSide(color: Color(0xFFCCCCCC)),
          ),
          child: Text(
            "Continuar como Consumidor Final",
            style: TextStyle(
              color: textColorForBackground(Colors.white),
              fontWeight: FontWeight.w600,
              fontSize: 15 * _f,
            ),
          ),
        ),
      ),
    );
  }

  // TECLADO CON FONDO SUTILMENTE GRIS (Y bordes curvos para separarlo del formulario)
  Widget _buildCustomKeypad() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10, top: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA), // Un gris ultra ligero para que se note la división sutil
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Expanded(child: _buildKeypadRow(["1", "2", "3"])),
          Expanded(child: _buildKeypadRow(["4", "5", "6"])),
          Expanded(child: _buildKeypadRow(["7", "8", "9"])),
          Expanded(child: _buildKeypadRow(["", "0", "BACKSPACE"])),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: keys.map((key) => Expanded(child: _buildKeypadKey(key))).toList(),
    );
  }

  Widget _buildKeypadKey(String label) {
    if (label.isEmpty) {
      return const Padding(padding: EdgeInsets.all(3.0));
    }

    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          splashColor: _primaryColor.withOpacity(0.15),
          highlightColor: _primaryColor.withOpacity(0.08),
          onTap: () {
            HapticFeedback.lightImpact();
            if (label == "BACKSPACE") {
              _onBackspace();
            } else {
              _onKeyPress(label);
            }
          },
          child: Center(
            child: label == "BACKSPACE"
                ? LayoutBuilder(
                    builder: (context, constraints) => Icon(
                      Icons.backspace_outlined,
                      size: (constraints.maxHeight * 0.4).clamp(22.0, 36.0),
                      color: Colors.black.withOpacity(0.6),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => Text(
                      label,
                      style: TextStyle(
                        fontSize: (constraints.maxHeight * 0.45).clamp(24.0, 42.0),
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
  void _mostrarDialogPendiente(
    CustomerModel customer,
    Map<String, dynamic> pending,
  ) {
    final int authId = pending['idautorizacion'];
    final String estado = pending['estado'] ?? 'Pendiente';
    final double valorProgramado =
        double.tryParse(pending['valor_programado'] ?? '0') ?? 0;
    final currencyFmt =
        NumberFormat('\$#,##0', 'es_CO');

    showDialog(
      context: context,
      barrierDismissible: false,
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
              child: Icon(Icons.pending_actions_outlined,
                  color: Colors.orange.shade600, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Hola, ${customer.name ?? customer.identifier}!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Tienes una autorización pendiente por finalizar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _pendingRow('Estado', estado,
                      valueColor: estado == 'Rechazado'
                          ? Colors.red.shade600
                          : Colors.orange.shade700),
                  const SizedBox(height: 4),
                  _pendingRow('Valor programado',
                      currencyFmt.format(valorProgramado)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Deseas reintentar esta autorización?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Botón: No, continuar normal
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _clienteIdentificado = customer);
              await context.push('/positions', extra: {'customer': customer});
              if (mounted) {
                setState(() {
                  _clienteIdentificado = null;
                  _navegando = false;
                  input = "";
                });
              }
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              side: const BorderSide(color: Color(0xFFCCCCCC)),
            ),
            child: const Text('No, continuar normalmente',
                style: TextStyle(
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          // Botón: Sí, reintentar
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
              boxShadow: [
                BoxShadow(
                  color: _secondaryColor.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.pop(ctx);
                  _reenviarYEscuchar(customer, pending);
                },
                child: Center(
                  child: Text(
                    'Sí, reintentar',
                    style: TextStyle(
                        color: textColorForGradient(_accentColor, _secondaryColor),
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF888888))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF222222))),
      ],
    );
  }

  Future<void> _reenviarYEscuchar(
    CustomerModel customer,
    Map<String, dynamic> pending,
  ) async {
    final int authId = pending['idautorizacion'];
    final int positionId = pending['posicion_id'];

    // Mostrar loading
    setState(() => _isLoading = true);

    final ok = await PaymentService.resendAuthorization(
        authorizationId: authId);

    setState(() => _isLoading = false);

    if (!ok) {
      if (mounted) {
        showAppNotice(context, 'No se pudo reenviar la autorización', kind: NoticeKind.error);
      }
      return;
    }

    if (!mounted) return;

    // Navegar a PendingAuthScreen que escucha el socket
    context.push('/pending-auth', extra: {
      'customer': customer,
      'authorization': pending,
    });
  }
}