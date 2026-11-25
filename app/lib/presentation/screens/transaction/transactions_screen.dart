import 'package:gnesys_as/utils/responsive.dart';
import 'package:gnesys_as/presentation/widgets/fidelity_brand.dart';
import 'package:gnesys_as/presentation/widgets/app_notice.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:gnesys_as/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:gnesys_as/data/models/models.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:gnesys_as/utils/color_utils.dart';

class TransactionScreen extends StatefulWidget {
  final Map<String, dynamic> sale;
  final CustomerModel? customer;
  // Manguera/producto real que se usó para esta venta (viene desde
  // pago/instrucciones/surtiendo). Con esto mostramos el producto correcto
  // en vez de confiar únicamente en el número crudo que reporta el backend.
  final ProductHose? hose;

  const TransactionScreen({
    super.key,
    required this.sale,
    this.customer,
    this.hose,
  });

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  Color _primaryColor = const Color(0xFF1565C0);
  Color _secondaryColor = const Color(0xFF2F80ED);
  Color _accentColor = const Color(0xFF56CCF2);
  String? _logoUrl;
  bool _vueltosModalMostrado = false;
  bool _hospitality = false; // estacion con Hospitality: sin vueltos, la venta va a la tarjeta
  Timer? _autoReturnTimer;
  List<FidelityProgram> _fidelityPrograms = [];
  bool _fidelidadCargada = false;
  String? _stationFlag;
  bool _facturaAutoDisparada = false;
  // La facturación automática (GNESYS) espera a que el tema de vueltos (si
  // lo hay) quede resuelto, para no cruzar ambos flujos. Si esta venta no
  // tiene vueltos pendientes, arranca en true desde ya.
  bool _vueltosResueltos = true;

  // ── FIDELIDAD (solo estaciones que NO son GNESYS) ──────────────────────────
  bool _fidelidadValidando = false;
  // Si la venta ya viene marcada como acumulada (el backend ya la envió a
  // Puntos Colombia antes, ej. por un reintento de esta misma pantalla), se
  // arranca ya bloqueada — ni se valida sola ni se deja tocar "Acumular".
  late bool _fidelidadAcumulada =
      (widget.sale['acumulacionPuntosColombia'] as bool? ?? false) ||
      (widget.sale['fidelizacion'] is Map && widget.sale['fidelizacion']['acumulo'] == true);
  String? _puntosColombiaLogoUrl;
  final ScrollController _bodyScroll = ScrollController(); // para ajustar la escala al contenido (sin scroll para el cliente)
  // Imagen y color de marca por programa de fidelidad (id NSX), cargados desde la Orange
  final Map<int, FidelityBrand> _fidelityBrands = {};

  String? _logoFor(int nsxFidelityId) => _fidelityBrands[nsxFidelityId]?.logoUrl ?? (nsxFidelityId == 1 ? _puntosColombiaLogoUrl : null);

  @override
  void initState() {
    super.initState();
    final double vuelto = (widget.sale['vuelto'] ?? 0).toDouble();
    final bool vueltoRegistrado = widget.sale['vueltoRegistrado'] ?? false;
    _vueltosResueltos = vuelto <= 0 || vueltoRegistrado;
    _cargarColores();
    _cargarFidelidad();
    AudioService.playTransition('transaccion.mp3');
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVueltos());
    _autoReturnTimer = Timer(const Duration(minutes: 3), () {
      if (mounted) 
      {
        if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
      }
    });
  }

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVueltos() async {
    // Con Hospitality activo la venta se cobra a la tarjeta: no se gestionan vueltos, solo se avisa
    final screenId = await StorageService.getScreenNumber();
    final mapping = await PumpService.getMappingWithFallback(screenId ?? 1);
    if (!mounted) return;
    if (mapping?.station.data.hospitality ?? false) {
      setState(() => _hospitality = true);
      showAppNotice(
        context,
        'El valor de la venta se cobrará a su tarjeta.',
        title: 'Pago con tarjeta',
        kind: NoticeKind.info,
        accent: _primaryColor,
      );
      _marcarVueltosResueltosYFacturar();
      return;
    }

    final double vuelto = (widget.sale['vuelto'] ?? 0).toDouble();
    final bool vueltoRegistrado = widget.sale['vueltoRegistrado'] ?? false;
    if (vuelto <= 0 || vueltoRegistrado || _vueltosModalMostrado) return;

    _vueltosModalMostrado = true;

    // Si viene desde home (sin customer) → requiere validación de vendedor
    final bool requiereVendedor = widget.customer == null;

    if (requiereVendedor) {
      _mostrarValidacionVendedor(vuelto);
    } else {
      _mostrarModalVueltos(vuelto);
    }
  }

  void _mostrarValidacionVendedor(double vuelto) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => VendedorDialog(
        primaryColor: _primaryColor,
        secondaryColor: _secondaryColor,
        accentColor: _accentColor,
        onValidado: () {
          Navigator.pop(context);
          _mostrarModalVueltos(vuelto);
        },
        onCancelar: () {
          Navigator.pop(context);
          _marcarVueltosResueltosYFacturar();
        },
      ),
    );
  }

  void _mostrarModalVueltos(double vuelto) async {
    final currencyFmt = NumberFormat('\$#,##0', 'es_CO');

    // Cargamos el mapping cacheado
    final id = await StorageService.getScreenNumber();
    final mapping = await PumpService.getMappingWithFallback(id ?? 1);
    
    if (!mounted) return;

    // Filtramos datáfono — cualquier método con "datafono", "tarjeta", "credito", "debito"
    final metodosVueltos = (mapping?.methodPayment ?? []).where((m) {
      final nombre = m.name.toLowerCase();
      return !nombre.contains('datafono') &&
            !nombre.contains('datáfono');
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _VueltosModal(
        primaryColor: _primaryColor,
        secondaryColor: _secondaryColor,
        accentColor: _accentColor,
        vueltos: vuelto,
        vueltosFmt: currencyFmt.format(vuelto),
        metodos: metodosVueltos,
        onConfirm: (metodoPagoId, telefono) {
          Navigator.pop(context);
          _procesarVueltos(metodoPagoId, telefono, vuelto);
        },
        onSkip: () {
          Navigator.pop(context);
          _marcarVueltosResueltosYFacturar();
        },
      ),
    );
  }

  Future<void> _procesarVueltos(int metodoPagoId, String? telefono, double vuelto) async {
    final presetId = widget.sale['idProgramacion'] as int?;
    if (presetId == null) {
      if (mounted) {
        showAppNotice(context, 'No se pudo identificar la programación', kind: NoticeKind.error);
      }
      _marcarVueltosResueltosYFacturar();
      return;
    }

    // Loading
    if (mounted) {
      showAppNotice(context, 'Procesando vueltos...', kind: NoticeKind.loading, accent: _primaryColor);
    }

    final ok = await PaymentService.enviarVueltos(
      presetId: presetId,
      amount: vuelto,
      methodPaymentId: metodoPagoId,
      contact: telefono,
    );

    if (!mounted) return;

    showAppNotice(
      context,
      ok ? 'Los vueltos se enviaron correctamente' : 'No se pudieron procesar los vueltos. Intenta de nuevo.',
      title: ok ? '¡Vueltos enviados!' : 'No se enviaron los vueltos',
      kind: ok ? NoticeKind.success : NoticeKind.error,
    );

    // El tema de vueltos ya quedó resuelto (haya salido bien o mal); recién
    // ahora se deja avanzar la facturación automática, si aplica.
    _marcarVueltosResueltosYFacturar();
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

  Future<void> _cargarFidelidad() async {
    final id = await StorageService.getScreenNumber();
    final mapping = await PumpService.getMappingWithFallback(id ?? 1);
    if (!mounted) return;
    setState(() {
      _fidelityPrograms = mapping?.fidelity ?? [];
      _fidelidadCargada = true;
      _stationFlag = mapping?.station.data.flag;
    });
    _intentarFacturarAutomatico();
    _intentarValidarFidelidadAutomatico();

    // Logo de Puntos Colombia, servido igual que los logos de métodos de
    // pago (ResourceService), no como asset local.
    if (_fidelityPrograms.any((p) => p.nsxFidelityId == 1)) {
      final url = await ResourceService.getImageUrl('puntoscolombia.png');
      if (mounted) setState(() => _puntosColombiaLogoUrl = url);
    }

    // Cada programa con su imagen (<nombre>.png en la Orange): de ahi salen el logo y los colores de la tarjeta
    for (final program in _fidelityPrograms) {
      final brand = await FidelityBrandService.load(
        program.fidelityName,
        alternateFiles: program.nsxFidelityId == 1 ? const ['puntoscolombia.png'] : const [],
      );
      if (brand != null && mounted) setState(() => _fidelityBrands[program.nsxFidelityId] = brand);
    }
  }

  // ── AUTO-FACTURACIÓN (estaciones GNESYS) ────────────────────────────────────

  // Se llama cada vez que el tema de vueltos queda resuelto (se procesaron,
  // se omitieron, o no había para empezar) para recién ahí dejar avanzar la
  // facturación automática — evita que ambos flujos se crucen en pantalla.
  void _marcarVueltosResueltosYFacturar() {
    _vueltosResueltos = true;
    _intentarFacturarAutomatico();
  }

  Future<void> _intentarFacturarAutomatico() async {
    if (_facturaAutoDisparada) return;
    if (_stationFlag != 'GNESYS') return;
    if (!_vueltosResueltos) return; // se reintenta cuando vueltos se resuelva

    final String? fElectronica = widget.sale['fElectronica'] as String?;
    final bool tieneFactura = fElectronica != null && fElectronica.trim().isNotEmpty;
    if (tieneFactura) return;

    final customer = widget.customer;
    final bool tieneDatosCliente = customer != null &&
        !customer.isAnonymous &&
        (customer.email?.trim().isNotEmpty ?? false) &&
        (customer.documentType?.trim().isNotEmpty ?? false) &&
        (customer.name?.trim().isNotEmpty ?? false);

    // Sin cliente identificado (o con datos incompletos): se factura igual,
    // a Consumidor Final, en vez de dejar la venta sin factura.
    final String tipoDoc = tieneDatosCliente ? customer.documentType! : 'NIT';
    final String numeroDoc = tieneDatosCliente ? customer.identifier : '222222222222';
    final String nombre = tieneDatosCliente ? customer.name! : 'CONSUMIDOR FINAL';
    final String correo = tieneDatosCliente ? customer.email! : 'consumidor@final.com';

    _facturaAutoDisparada = true;
    if (!mounted) return;

    // El diálogo de carga se muestra desde YA, cubriendo tanto el margen de
    // espera como la llamada real a la API — no solo el tramo final.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildFacturaLoadingDialog(),
    );

    // Le da un margen a la venta de quedar reportada/confirmada en el
    // backend antes de intentar facturarla automáticamente.
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;

    await _generarFactura(
      tipoDoc, numeroDoc, nombre, correo,
      controlarDialogoCarga: false,
    );
  }

  Widget _buildFacturaLoadingDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _primaryColor, strokeWidth: 3),
          const SizedBox(height: 20),
          const Text(
            'Enviando factura...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Por favor espera un momento',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ── FACTURA ───────────────────────────────────────────────────────────────

  void _onImprimirRecibo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FacturaModal(
        primaryColor: _primaryColor,
        secondaryColor: _secondaryColor,
        accentColor: _accentColor,
        customer: widget.customer,
        onConfirm: (tipoDoc, numeroDoc, nombre, correo) async {
          Navigator.pop(context);
          await _generarFactura(tipoDoc, numeroDoc, nombre, correo);
        },
      ),
    );
  }

  // [controlarDialogoCarga]: cuando es true (caso normal, botón manual) esta
  // función abre y cierra su propio diálogo de carga. Cuando es false, es
  // porque quien llamó (el flujo automático) ya dejó uno abierto desde antes
  // (cubriendo también el margen de espera) — aquí solo se cierra al final.
  Future<void> _generarFactura(
    String tipoDoc, String numeroDoc, String nombre, String correo, {
    bool controlarDialogoCarga = true,
  }) async {
    final saleId = widget.sale['idVenta'] as int?;
    if (saleId == null) {
      if (mounted) {
        if (!controlarDialogoCarga) Navigator.pop(context);
        showAppNotice(context, 'No se pudo identificar la venta', kind: NoticeKind.error);
      }
      return;
    }

    // Loading bien visible (diálogo con progreso), no una notificación
    // pequeña abajo — así se nota claramente que está en curso.
    if (controlarDialogoCarga && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildFacturaLoadingDialog(),
      );
    }

    final customerService = CustomerService();
    final ok = await customerService.generarFactura(
      saleId: saleId,
      documentNumber: numeroDoc,
      documentType: tipoDoc,
      companyName: nombre,
      email: correo,
      isGnesys: _stationFlag == 'GNESYS',
    );

    if (!mounted) return;
    Navigator.pop(context); // cierra el diálogo de carga

    showAppNotice(
      context,
      ok ? 'La factura electrónica se envió a $correo' : 'No se pudo generar la factura. Intenta de nuevo.',
      title: ok ? '¡Factura enviada!' : 'No se generó la factura',
      kind: ok ? NoticeKind.success : NoticeKind.error,
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final dynamic fechaRaw = widget.sale['fechaVenta'];
    DateTime? fecha;
    try { fecha = DateTime.parse(fechaRaw.toString()); } catch (_) {}

    final dateFmt = DateFormat('dd/MM/yy');
    final timeFmt = DateFormat('hh:mm a');

    final int dinero = (widget.sale['dinero'] ?? 0).toInt();
    final double volumen = (widget.sale['volumen'] ?? 0).toDouble();
    final int precioVenta = (widget.sale['precioVenta'] ?? 0).toInt();
    final int valorProgramado = (widget.sale['valorProgramado'] ?? 0).toInt();
    // Preferimos la manguera real conocida desde pago/instrucciones/surtiendo
    // (cruzada con el mapeo) sobre el número crudo que reporta el backend.
    final int numeroManguera =
        widget.hose?.hoseNumber ?? (widget.sale['numeroManguera'] ?? 0).toInt();
    final int tipoProgramacion = (widget.sale['tipoProgramacion'] ?? 2).toInt();
    final bool esPorVolumen = tipoProgramacion == 3;
    final double vuelto = (widget.sale['vuelto'] ?? 0).toDouble();
    final bool vueltoRegistrado = widget.sale['vueltoRegistrado'] ?? false;
    final bool tieneVueltos = vuelto > 0 && !vueltoRegistrado && !_hospitality;
    final String? fElectronica = widget.sale['fElectronica'] as String?;
    final bool tieneFactura =
        fElectronica != null && fElectronica.trim().isNotEmpty;

    final currencyFmt = NumberFormat('\$#,##0', 'es_CO');
    final volumeFmt = NumberFormat('#,##0.000', 'es_CO');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      // Todo el contenido se amplia de forma uniforme al espacio disponible (referencia: telefono/tablet pequena)
      body: ScaleUp(
        reference: isLandscape ? const Size(780, 420) : const Size(420, 780),
        minScale: 0.6,
        fitControllers: [_bodyScroll],
        child: Column(
        children: [
          // Header siempre arriba
          _buildHeader(fecha, dateFmt, timeFmt, numeroManguera),

          // Body
          Expanded(
            child: isLandscape
                ? _buildLandscapeBody(
                    currencyFmt, volumeFmt, dinero, volumen,
                    precioVenta, valorProgramado, esPorVolumen,
                    tieneVueltos, vuelto, tieneFactura, fElectronica,
                  )
                : _buildPortraitBody(
                    currencyFmt, volumeFmt, dinero, volumen,
                    precioVenta, valorProgramado, esPorVolumen,
                    tieneVueltos, vuelto, tieneFactura, fElectronica,
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(DateTime? fecha, DateFormat dateFmt,
    DateFormat timeFmt, int numeroManguera) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(color: _primaryColor),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TRANSACCIÓN EXITOSA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Gracias por preferirnos',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Logo siempre a la derecha
          _logoUrl != null
              ? Image.network(_logoUrl!, height: 28, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo_insepet_blanco.png', height: 28))
              : Image.asset('assets/images/logo_insepet_blanco.png',
                  height: 28),
        ],
      ),
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPortraitBody(
    NumberFormat currencyFmt, NumberFormat volumeFmt,
    int dinero, double volumen, int precioVenta, int valorProgramado,
    bool esPorVolumen, bool tieneVueltos, double vuelto,
    bool tieneFactura, String? fElectronica,
  ) {
    return SingleChildScrollView(
      controller: _bodyScroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        children: [
          _buildMetaRow(currencyFmt, volumeFmt, dinero, volumen,
              precioVenta, valorProgramado, esPorVolumen),
          const SizedBox(height: 10),
          _buildTotalCard(currencyFmt.format(dinero)),
          const SizedBox(height: 8),
          if (tieneVueltos) _buildVueltosChip(currencyFmt.format(vuelto)),
          const SizedBox(height: 8),
          if (_fidelidadCargada && _fidelityPrograms.isNotEmpty)
            _buildFidelidadCard(),
          const SizedBox(height: 8),
          const _JaggedEdge(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'TRANSACCIÓN #${widget.sale['idVenta'] ?? '---'}',
              style: const TextStyle(
                color: Color(0xFFBBBBBB),
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _buildButtons(context),
        ],
      ),
    );
  }

  Widget _buildLandscapeBody(
    NumberFormat currencyFmt, NumberFormat volumeFmt,
    int dinero, double volumen, int precioVenta, int valorProgramado,
    bool esPorVolumen, bool tieneVueltos, double vuelto,
    bool tieneFactura, String? fElectronica,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          // Izquierda — detalles de la transacción
          Expanded(
            flex: 50,
            child: SingleChildScrollView(
              controller: _bodyScroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaRow(currencyFmt, volumeFmt, dinero, volumen,
                      precioVenta, valorProgramado, esPorVolumen),
                  const SizedBox(height: 10),
                  const _JaggedEdge(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'TRANSACCIÓN #${widget.sale['idVenta'] ?? '---'}',
                      style: const TextStyle(
                        color: Color(0xFFBBBBBB),
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildButtons(context),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Derecha — valor + vueltos + fidelidad
          Expanded(
            flex: 50,
            child: Column(
              children: [
                _buildTotalCard(currencyFmt.format(dinero)),
                const SizedBox(height: 10),
                if (tieneVueltos) ...[
                  _buildVueltosChip(currencyFmt.format(vuelto)),
                  const SizedBox(height: 10),
                ],
                if (_fidelidadCargada && _fidelityPrograms.isNotEmpty) ...[
                  _buildFidelidadCard(),
                  const SizedBox(height: 10),
                ],
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FIDELIDAD ────────────────────────────────────────────────────────────

  /// Si el cliente identificado trae cédula o cédula de extranjería, valida
  /// solo de una vez contra el programa de fidelidad — así, si ya existe,
  /// nos ahorramos pedirle el documento manualmente. Como acá no hay ningún
  /// bottom sheet de por medio, el diálogo de confirmación se puede mostrar
  /// directo apenas se sepa que existe.
  Future<void> _intentarValidarFidelidadAutomatico() async {
    if (_stationFlag == 'GNESYS') {
      debugPrint('🔶 [Fidelidad-Auto] omitido: estación GNESYS');
      return;
    }
    if (_fidelityPrograms.isEmpty) {
      debugPrint('🔶 [Fidelidad-Auto] omitido: sin programas de fidelidad en el mapping');
      return;
    }
    if (_fidelityPrograms.first.nsxFidelityId == _nsxCommodoId) {
      debugPrint('🔶 [Fidelidad-Auto] omitido: Commodo se identifica por celular');
      return;
    }
    if (_fidelidadAcumulada) {
      debugPrint('🔶 [Fidelidad-Auto] omitido: venta ya marcada como acumulada');
      return;
    }

    final customer = widget.customer;
    if (customer == null || customer.isAnonymous) {
      debugPrint('🔶 [Fidelidad-Auto] omitido: sin cliente identificado (customer=$customer)');
      return;
    }

    final codigoDoc = _codigoDocFidelidad(customer.documentType);
    debugPrint('🔶 [Fidelidad-Auto] documentType="${customer.documentType}" → código=$codigoDoc');
    if (codigoDoc != 13 && codigoDoc != 22) {
      debugPrint('🔶 [Fidelidad-Auto] omitido: tipo de documento no es CC/CE');
      return; // solo CC/CE
    }

    final numeroDoc = customer.identifier.trim();
    if (numeroDoc.isEmpty) {
      debugPrint('🔶 [Fidelidad-Auto] omitido: identifier vacío');
      return;
    }

    debugPrint('🔶 [Fidelidad-Auto] validando documento=$numeroDoc contra programa fidelidad...');
    final result = await _validarFidelidad(
      documentTypeCode: codigoDoc!,
      documentNumber: numeroDoc,
    );
    debugPrint('🔶 [Fidelidad-Auto] resultado: success=${result.success} message=${result.message}');
    if (!mounted || !result.success) return;

    final nombre = (result.data?['nombre'] as String?)?.trim();
    _mostrarConfirmarAcumularPuntos(
      nombre: (nombre != null && nombre.isNotEmpty) ? nombre : (customer.name ?? 'este cliente'),
      documentTypeCode: codigoDoc,
      documentNumber: numeroDoc,
    );
  }

  /// Solo valida el documento contra el programa de fidelidad — sin ningún
  /// efecto secundario de UI. Quien llama decide qué hacer con el resultado
  /// (mostrar el diálogo de confirmación, un error, etc.), y en qué momento,
  /// para no terminar mostrando un diálogo mientras todavía hay un bottom
  /// sheet abierto encima (eso hacía que "Sí, acumular" se cerrara solo,
  /// porque el pop terminaba cerrando el diálogo en vez del sheet).
  Future<FidelityResult> _validarFidelidad({
    required int documentTypeCode,
    required String documentNumber,
  }) async {
    final program = _fidelityPrograms.first;

    setState(() => _fidelidadValidando = true);
    final result = await FidelityService.validateCustomer(
      fidelityTypeId: program.nsxFidelityId,
      documentType: documentTypeCode,
      documentNumber: documentNumber,
    );
    if (mounted) setState(() => _fidelidadValidando = false);
    return result;
  }

  void _mostrarConfirmarAcumularPuntos({
    required String nombre,
    required int documentTypeCode,
    required String documentNumber,
  }) {
    final program = _fidelityPrograms.first;
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
                color: (_fidelityBrands[program.nsxFidelityId]?.color ?? Colors.purple.shade600).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: _iconoFidelidad(program.nsxFidelityId, _logoFor(program.nsxFidelityId),
                  color: _fidelityBrands[program.nsxFidelityId]?.color ?? Colors.purple.shade600, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Desea acumular puntos de ${program.fidelityName} para $nombre con esta compra?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              side: const BorderSide(color: Color(0xFFCCCCCC)),
            ),
            child: const Text('No, gracias',
                style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: _fidelityBrands[program.nsxFidelityId]?.button ?? Colors.purple.shade600,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.pop(ctx);
                  _acumularPuntosFidelidad(
                    documentTypeCode: documentTypeCode,
                    documentNumber: documentNumber,
                  );
                },
                child: const Center(
                  child: Text('Sí, acumular',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acumularPuntosFidelidad({
    required int documentTypeCode,
    required String documentNumber,
  }) async {
    final saleId = widget.sale['idVenta'] as int?;
    if (saleId == null) {
      if (mounted) {
        showAppNotice(context, 'No se pudo identificar la venta', kind: NoticeKind.error);
      }
      return;
    }

    final program = _fidelityPrograms.first;

    showAppNotice(context, 'Acumulando puntos en ${program.fidelityName}...', kind: NoticeKind.loading, accent: _fidelityBrands[program.nsxFidelityId]?.button ?? Colors.purple.shade600);

    final result = await FidelityService.accumulate(
      fidelityTypeId: program.nsxFidelityId,
      saleId: saleId,
      documentType: documentTypeCode,
      documentNumber: documentNumber,
    );

    if (!mounted) return;
    if (result.success) {
      setState(() => _fidelidadAcumulada = true);
    }

    final puntos = result.data?['puntosAcumulados'] as String?;
    showAppNotice(
      context,
      result.success
          ? (puntos != null ? 'Acumulaste $puntos puntos en ${program.fidelityName}' : 'Se acumularon los puntos en ${program.fidelityName}')
          : result.message,
      title: result.success ? '¡Puntos acumulados!' : 'No se acumularon los puntos',
      kind: result.success ? NoticeKind.success : NoticeKind.error,
    );
  }

  /// Formulario manual: se usa cuando el cliente no traía cédula/cédula
  /// extranjera identificada, o cuando la validación automática no lo
  /// encontró — deja elegir el documento e intentarlo de nuevo.
  ///
  /// El sheet solo valida y se cierra devolviendo el resultado; el diálogo
  /// de confirmación se muestra acá, ya con el sheet cerrado (nunca uno
  /// encima del otro).
  Future<void> _abrirFidelidadManual() async {
    if (_fidelidadAcumulada) return; // esta venta ya fue acumulada antes

    final resultado = await showModalBottomSheet<(FidelityResult, int, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FidelidadManualSheet(
        primaryColor: _fidelityBrands[_fidelityPrograms.first.nsxFidelityId]?.button ?? Colors.purple.shade600,
        nsxFidelityId: _fidelityPrograms.first.nsxFidelityId,
        logoUrl: _logoFor(_fidelityPrograms.first.nsxFidelityId),
        onValidar: (tipoDoc, numeroDoc) => _validarFidelidad(
          documentTypeCode: tipoDoc,
          documentNumber: numeroDoc,
        ),
      ),
    );

    if (resultado == null || !mounted) return;
    final (result, tipoDoc, numeroDoc) = resultado;
    if (!result.success) return;

    final nombre = (result.data?['nombre'] as String?)?.trim();
    _mostrarConfirmarAcumularPuntos(
      nombre: (nombre != null && nombre.isNotEmpty) ? nombre : 'este cliente',
      documentTypeCode: tipoDoc,
      documentNumber: numeroDoc,
    );
  }

  // Puntos de la acumulacion ya guardada en la venta (null si no hay dato)
  String? _puntosGuardados() {
    final fidelizacion = widget.sale['fidelizacion'];
    final value = fidelizacion is Map ? fidelizacion['acumulado'] : null;
    return value is num && value > 0 ? NumberFormat('#,##0.##', 'es_CO').format(value) : null;
  }

  Widget _buildFidelidadCard() {
    final program = _fidelityPrograms.first;
    final brand = _fidelityBrands[program.nsxFidelityId];
    final base = brand?.color ?? Colors.purple.shade600;
    final dark = brand?.dark ?? Colors.purple.shade700;
    final mid = brand?.mid ?? Colors.purple.shade400;
    final buttonColor = brand?.button ?? Colors.purple.shade600;

    if (_fidelidadAcumulada) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fidelidad ya acumulada',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.green.shade700),
                  ),
                  Text(
                    _puntosGuardados() != null
                        ? '${program.fidelityName} · ${_puntosGuardados()} puntos'
                        : program.fidelityName,
                    style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            base.withOpacity(0.08),
            base.withOpacity(0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: base.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: base.withOpacity(0.25)),
            ),
            child: _iconoFidelidad(program.nsxFidelityId, _logoFor(program.nsxFidelityId),
                color: base, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.fidelityName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: dark,
                  ),
                ),
                Text(
                  'Identifícate para acumular con esta compra',
                  style: TextStyle(
                    fontSize: 11,
                    color: mid,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_fidelidadValidando)
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: buttonColor),
            )
          else
            GestureDetector(
              onTap: _abrirFidelidadManual,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Acumular',
                  style: TextStyle(
                    color: textColorForBackground(buttonColor),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget _buildHeader(BuildContext context, String fecha, String hora, int manguera) {
  //   return Container(
  //     width: double.infinity,
  //     padding: EdgeInsets.only(
  //       top: MediaQuery.of(context).padding.top + 12,
  //       bottom: 16,
  //       left: 20,
  //       right: 20,
  //     ),
  //     decoration: BoxDecoration(color: _primaryColor),
  //     child: Row(
  //       children: [
  //         // Check + textos
  //         Expanded(
  //           child: Row(
  //             children: [
  //               Container(
  //                 padding: const EdgeInsets.all(8),
  //                 decoration: const BoxDecoration(
  //                   color: Color(0xFF2E7D32),
  //                   shape: BoxShape.circle,
  //                 ),
  //                 child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
  //               ),
  //               const SizedBox(width: 12),
  //               Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   const Text(
  //                     'TRANSACCIÓN EXITOSA',
  //                     style: TextStyle(
  //                       color: Colors.white,
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w900,
  //                       letterSpacing: 1.2,
  //                     ),
  //                   ),
  //                   Text(
  //                     'Gracias por preferirnos',
  //                     style: TextStyle(
  //                       color: Colors.white.withOpacity(0.7),
  //                       fontSize: 12,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //         // Logo
  //         _logoUrl != null
  //             ? Image.network(
  //                 _logoUrl!,
  //                 height: 28,
  //                 fit: BoxFit.contain,
  //                 loadingBuilder: (_, child, progress) =>
  //                     progress == null ? child : const SizedBox(height: 28),
  //                 errorBuilder: (_, __, ___) =>
  //                     Image.asset('assets/images/logo_insepet_blanco.png', height: 28),
  //               )
  //             : Image.asset('assets/images/logo_insepet_blanco.png', height: 28),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildMetaRow(String fecha, String hora, String manguera) {
  //   return Row(
  //     children: [
  //       _MetaChip(icon: Icons.calendar_today_outlined, label: 'Fecha', value: fecha),
  //       const SizedBox(width: 8),
  //       _MetaChip(icon: Icons.access_time_outlined, label: 'Hora', value: hora),
  //       const SizedBox(width: 8),
  //       _MetaChip(icon: Icons.local_gas_station_outlined, label: 'Manguera', value: '#$manguera'),
  //     ],
  //   );
  // }

  Widget _buildMetaRow(
    NumberFormat currencyFmt, NumberFormat volumeFmt,
    int dinero, double volumen, int precioVenta, int valorProgramado,
    bool esPorVolumen,
  ) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      children: [
        // Chips fecha/hora/manguera solo en portrait
        Row(
        children: [
          _MetaChip(
            icon: Icons.calendar_today_outlined,
            label: 'Fecha',
            value: widget.sale['fechaVenta'] != null
                ? DateFormat('dd/MM/yy')
                    .format(DateTime.parse(widget.sale['fechaVenta']))
                : '--',
          ),
          const SizedBox(width: 8),
          _MetaChip(
            icon: Icons.access_time_outlined,
            label: 'Hora',
            value: widget.sale['fechaVenta'] != null
                ? DateFormat('hh:mm a')
                    .format(DateTime.parse(widget.sale['fechaVenta']))
                : '--',
          ),
          const SizedBox(width: 8),
          _MetaChip(
            icon: Icons.hive_outlined,
            label: 'Manguera',
            value: '#${widget.hose?.hoseNumber ?? widget.sale['numeroManguera'] ?? '--'}',
          ),
        ],
      ),
      const SizedBox(height: 10),

        // Detalles
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRANSACCIÓN #${widget.sale['idVenta'] ?? '---'}',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      esPorVolumen ? 'Por volumen' : 'Por pesos',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16, color: Color(0xFFEEEEEE)),
              if ((widget.hose?.product.trim().isNotEmpty ?? false))
                _buildDetailRow('Producto', widget.hose!.product),
              _buildDetailRow('Precio por galón',
                  currencyFmt.format(precioVenta)),
              _buildDetailRow('Volumen despachado',
                  '${volumeFmt.format(volumen)} gal'),
              _buildDetailRow(
                esPorVolumen
                    ? 'Volumen programado'
                    : 'Monto programado',
                esPorVolumen
                    ? '${volumeFmt.format(valorProgramado)} gal'
                    : currencyFmt.format(valorProgramado),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductBadge(bool esPorVolumen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            'TRANSACCIÓN #${widget.sale['idVenta'] ?? ''}',
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              esPorVolumen ? 'Por volumen' : 'Por pesos',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(String total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Barra lateral de color
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VALOR DE VENTA',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    total,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Ícono decorativo
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_gas_station_rounded,
              color: _primaryColor,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVueltosChip(String vueltos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.currency_exchange_rounded, color: Color(0xFF388E3C), size: 18),
          const SizedBox(width: 8),
          const Text('Vueltos', style: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          Text(vueltos, style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    final String? fElectronica = widget.sale['fElectronica'] as String?;
    final bool tieneFactura = fElectronica != null && fElectronica.trim().isNotEmpty;
    // En estaciones GNESYS la factura se genera automáticamente al cerrar la
    // venta (no a petición): el botón solo debe permitir imprimir si ya existe.
    final bool botonFacturaDeshabilitado = _stationFlag == 'GNESYS' && !tieneFactura;

    return Column(
      children: [
        // Badge de factura existente
        if (tieneFactura) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified_outlined,
                      color: Colors.green.shade700, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Factura electrónica generada',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        fElectronica!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Botones
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _autoReturnTimer?.cancel();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                ),
                child: const Text('Volver',
                    style: TextStyle(
                        color: Color(0xFF444444), fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: botonFacturaDeshabilitado
                      ? null
                      : LinearGradient(
                          colors: [_accentColor, _secondaryColor],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                  color: botonFacturaDeshabilitado ? Colors.grey.shade300 : null,
                  boxShadow: botonFacturaDeshabilitado
                      ? []
                      : [
                          BoxShadow(
                            color: _secondaryColor.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: botonFacturaDeshabilitado
                        ? null
                        : (tieneFactura
                            ? _imprimirRecibo
                            : () => _onImprimirRecibo(context)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tieneFactura
                              ? Icons.print_outlined
                              : Icons.receipt_long_outlined,
                          color: botonFacturaDeshabilitado
                              ? Colors.grey.shade500
                              : textColorForGradient(_accentColor, _secondaryColor),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tieneFactura
                              ? 'Imprimir recibo'
                              : (botonFacturaDeshabilitado
                                  ? 'Factura automática'
                                  : 'Factura electrónica'),
                          style: TextStyle(
                            color: botonFacturaDeshabilitado
                                ? Colors.grey.shade500
                                : textColorForGradient(_accentColor, _secondaryColor),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _imprimirRecibo() async {
    final saleId = widget.sale['idVenta'] as int?;
    if (saleId == null) return;

    // Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primaryColor, strokeWidth: 3),
            const SizedBox(height: 20),
            const Text(
              'Enviando a imprimir...',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Por favor espera un momento',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );

    final ok = await CustomerService().imprimirRecibo(saleId: saleId);

    if (!mounted) return;
    Navigator.pop(context); // cierra loading

    // Resultado
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ok ? Colors.green.shade50 : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                ok ? Icons.print_rounded : Icons.print_disabled_rounded,
                color: ok ? Colors.green.shade600 : Colors.red.shade600,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ok ? '¡Impresión enviada!' : 'Error al imprimir',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              ok
                  ? 'El recibo fue enviado a la impresora correctamente.'
                  : 'No se pudo conectar con la impresora. Intenta de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: ok
                    ? [Colors.green.shade400, Colors.green.shade600]
                    : [_accentColor, _secondaryColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => Navigator.pop(context),
                child: Center(
                  child: Text(
                    ok ? 'Listo' : 'Cerrar',
                    style: TextStyle(
                      color: ok
                          ? textColorForGradient(Colors.green.shade400, Colors.green.shade600)
                          : textColorForGradient(_accentColor, _secondaryColor),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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

} // <- cierre de _TransactionScreenState

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: const Color(0xFF999999)),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.only(right: dashSpace),
              child: Container(width: dashWidth, height: 1.5, color: const Color(0xFFD0D0D0)),
            ),
          ),
        );
      },
    );
  }
}

class _JaggedEdge extends StatelessWidget {
  const _JaggedEdge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      width: double.infinity,
      child: CustomPaint(painter: _JaggedPainter()),
    );
  }
}

class _JaggedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, size.height / 2);
    const step = 12.0;
    bool up = true;
    for (double x = 0; x < size.width; x += step) {
      path.lineTo(x + step / 2, up ? 0 : size.height);
      path.lineTo(x + step, size.height / 2);
      up = !up;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class FacturaModal extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final CustomerModel? customer;
  final Function(String tipoDoc, String numeroDoc, String nombre, String correo) onConfirm;

  const FacturaModal({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.onConfirm,
    this.customer,
  });

  @override
  State<FacturaModal> createState() => _FacturaModalState();
}

class _FacturaModalState extends State<FacturaModal> {

  bool _usarClienteActual = true;
  bool _buscandoDian = false;
  final _nombreController = TextEditingController();
  final _docController = TextEditingController();
  final _correoController = TextEditingController();
  final _docFocusNode = FocusNode();
  String _tipoDoc = 'Cédula de ciudadanía';
  final List<String> _tiposDoc = ['Cédula de ciudadanía', 'Cédula de extranjería', 'NIT', 'Pasaporte'];

  @override
  void initState() {
    super.initState();
    _docFocusNode.addListener(() {
      if (!_docFocusNode.hasFocus) {
        _buscarEnDian();
      }
    });
    if (widget.customer != null && !widget.customer!.isAnonymous) {
      _docController.text = widget.customer!.identifier;
      _correoController.text = widget.customer!.email ?? '';
      _nombreController.text = widget.customer!.name ?? '';
      _tipoDoc = widget.customer!.documentType ?? 'Cédula de ciudadanía';
    }
    
  }

  @override
  void dispose() {
    _docFocusNode.dispose(); // <- agrega
    _docController.dispose();
    _correoController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  bool get _formValido =>
      _nombreController.text.trim().isNotEmpty &&
      _docController.text.trim().isNotEmpty &&
      _correoController.text.trim().contains('@');

  @override
  Widget build(BuildContext context) {
  final bool tieneCliente =
      widget.customer != null && !widget.customer!.isAnonymous;

  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Título
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: widget.primaryColor, size: 22),
              const SizedBox(width: 10),
              Text(
                'Factura electrónica',
                style: TextStyle(
                  color: widget.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresa los datos para generar tu factura',
            style: TextStyle(color: Color(0xFF999999), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Opciones si hay cliente identificado
          if (tieneCliente) ...[
            _buildOpcionTile(
              title: 'A nombre de ${widget.customer!.name ?? widget.customer!.identifier}',
              subtitle: widget.customer!.identifier,
              isSelected: _usarClienteActual,
              onTap: () => setState(() {
                _usarClienteActual = true;
                _docController.text = widget.customer!.identifier;
                _nombreController.text = widget.customer!.name ?? '';
                _correoController.text = widget.customer!.email ?? '';
                _tipoDoc = widget.customer!.documentType ?? 'Cédula de ciudadanía';
              }),
            ),
            const SizedBox(height: 10),
            _buildOpcionTile(
              title: 'A otro documento',
              subtitle: 'Ingresar manualmente',
              isSelected: !_usarClienteActual,
              onTap: () => setState(() {
                _usarClienteActual = false;
                _docController.clear();
                _nombreController.clear();
                _correoController.clear();
              }),
            ),
            const SizedBox(height: 16),
          ],

          // Tipo doc + número (solo si no hay cliente o eligió "otro")
          if (!tieneCliente || !_usarClienteActual) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _tipoDoc,
                      items: _tiposDoc
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _tipoDoc = v!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _docController,
                  keyboardType: TextInputType.number,
                  focusNode: _docFocusNode,
                  onChanged: (_) => setState(() {}),
                  // onEditingComplete: _buscarEnDian, // <- busca al salir del campo
                  decoration: InputDecoration(
                    hintText: 'Número de documento',
                    hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                    suffixIcon: _buscandoDian
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: widget.primaryColor,
                              ),
                            ),
                          )
                        : (_docController.text.length >= 5
                            ? Icon(Icons.search_rounded,
                                color: widget.primaryColor.withOpacity(0.5), size: 20)
                            : null),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),],
            ),
            const SizedBox(height: 10),

            // Nombre / Razón social
            TextField(
              controller: _nombreController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Nombre o razón social',
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                prefixIcon: const Icon(Icons.person_outline, size: 18, color: Color(0xFFBBBBBB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Correo (siempre visible)
          TextField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Correo electrónico',
              hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
              prefixIcon: const Icon(Icons.email_outlined, size: 18, color: Color(0xFFBBBBBB)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Botón generar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: _formValido
                    ? LinearGradient(
                        colors: [widget.accentColor, widget.secondaryColor],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: _formValido ? null : const Color(0xFFEEEEEE),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: _formValido
                      ? () => widget.onConfirm(
                            _tipoDoc,
                            _docController.text.trim(),
                            _nombreController.text.trim(),
                            _correoController.text.trim(),
                          )
                      : null,
                  child: Center(
                    child: Text(
                      'Generar factura',
                      style: TextStyle(
                        color: _formValido
                            ? textColorForGradient(widget.accentColor, widget.secondaryColor)
                            : const Color(0xFFAAAAAA),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ], // <- cierre children de Column
      ),
    ),
  );
}
  Widget _buildOpcionTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? widget.primaryColor : const Color(0xFFDDDDDD),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? widget.primaryColor : const Color(0xFFCCCCCC),
                  width: 2,
                ),
                color: isSelected ? widget.primaryColor : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? widget.primaryColor : const Color(0xFF333333),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buscarEnDian() async {
    final doc = _docController.text.trim();
    if (doc.length < 5) return;

    setState(() => _buscandoDian = true);

    try {
      final customerService = CustomerService();

      // 1. Primero busca localmente
      final localResult = await customerService.validateClient(doc);

      if (!mounted) return;

      if (localResult != null && localResult['nombre'] != null) {
        // Tiene datos completos localmente — los usa directo
        setState(() {
          if (localResult['nombre'] != null) {
            _nombreController.text = localResult['nombre'];
          }
          if (localResult['correo'] != null) {
            _correoController.text = localResult['correo'];
          }
          if (localResult['tipo_documento'] != null) {
            final tipoMap = {
              'CC': 'Cédula de ciudadanía',
              'CE': 'Cédula de extranjería',
              'NIT': 'NIT',
              'PA': 'Pasaporte',
            };
            final tipoMapeado = tipoMap[localResult['tipo_documento']];
            if (tipoMapeado != null) _tipoDoc = tipoMapeado;
          }
        });
        return;
      }

      final dianResult = await customerService.validateClientDIAN(doc);

      if (!mounted) return;

      if (dianResult != null && dianResult is Map<String, dynamic>) {
        final customer = CustomerModel.fromDianJson(dianResult);
        setState(() {
          if (customer.name != null && customer.name!.isNotEmpty) {
            _nombreController.text = customer.name!;
          }
          if (customer.email != null && customer.email!.isNotEmpty) {
            _correoController.text = customer.email!;
          }
          if (customer.documentType != null) {
            final tipoMap = {
              'CC': 'Cédula de ciudadanía',
              'CE': 'Cédula de extranjería',
              'NIT': 'NIT',
              'PA': 'Pasaporte',
            };
            final tipoMapeado = tipoMap[customer.documentType];
            if (tipoMapeado != null) _tipoDoc = tipoMapeado;
          }
        });
      }

    } catch (e) {
      debugPrint('⚠️ Error buscando cliente: $e');
    } finally {
      if (mounted) setState(() => _buscandoDian = false);
    }
  }
}

class _VueltosModal extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final double vueltos;
  final String vueltosFmt;
  final List<MethodPayment> metodos;
  final Function(int metodoPagoId, String? telefono) onConfirm;
  final VoidCallback onSkip;

  const _VueltosModal({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.vueltos,
    required this.vueltosFmt,
    required this.metodos,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  State<_VueltosModal> createState() => _VueltosModalState();
}

class _VueltosModalState extends State<_VueltosModal> {
  int? _metodoSeleccionado;
  final _telefonoController = TextEditingController();

  // Detecta por nombre si el método seleccionado requiere teléfono
  bool get _esBilletera {
    if (_metodoSeleccionado == null) return false;
    final metodo = widget.metodos
        .where((m) => m.idMethodPayment == _metodoSeleccionado)
        .firstOrNull;
    if (metodo == null) return false;
    return _esMetodoBilletera(metodo.name);
  }

  bool get _formValido {
    if (_metodoSeleccionado == null) return false;
    if (_esBilletera) {
      final tel = _telefonoController.text.trim();
      return tel.length == 10 && tel.startsWith('3');
    }
    return true;
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    super.dispose();
  }

  IconData _iconForMethod(String name) {
    final n = name.toLowerCase();
    if (n.contains('efectivo') || n.contains('cash')) {
      return Icons.payments_outlined;
    }
    if (n.contains('nequi') || n.contains('daviplata') ||
        n.contains('billetera') || n.contains('digital')) {
      return Icons.smartphone_outlined;
    }
    if (n.contains('transfer') || n.contains('pse')) {
      return Icons.account_balance_outlined;
    }
    return Icons.account_balance_wallet_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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

            // Header monto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.currency_exchange_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tienes vueltos',
                        style: TextStyle(
                          color: Color(0xFF388E3C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.vueltosFmt,
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              '¿Cómo deseas recibir tus vueltos?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 14),

            // Lista dinámica de métodos
            ...widget.metodos.map((m) {
              final isSelected = _metodoSeleccionado == m.idMethodPayment;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _metodoSeleccionado = m.idMethodPayment;
                    _telefonoController.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? widget.primaryColor : const Color(0xFFDDDDDD),
                        width: isSelected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? widget.primaryColor
                                  : const Color(0xFFCCCCCC),
                              width: 2,
                            ),
                            color: isSelected ? widget.primaryColor : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 12, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          _iconForMethod(m.name),
                          color: isSelected ? widget.primaryColor : const Color(0xFF888888),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? widget.primaryColor : const Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // Campo teléfono si aplica
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _esBilletera
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _telefonoController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '3XXXXXXXXX',
                          hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                          prefixIcon: const Icon(Icons.phone_outlined,
                              size: 18, color: Color(0xFFBBBBBB)),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
                          ),
                          errorText: _telefonoController.text.isNotEmpty &&
                                  (!_telefonoController.text.startsWith('3') ||
                                      _telefonoController.text.length < 10)
                              ? 'Debe ser de 10 dígitos e iniciar con 3'
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 6),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onSkip,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      side: const BorderSide(color: Color(0xFFCCCCCC)),
                    ),
                    child: const Text('Omitir',
                        style: TextStyle(
                            color: Color(0xFF888888),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: _formValido
                          ? LinearGradient(
                              colors: [widget.accentColor, widget.secondaryColor],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : null,
                      color: _formValido ? null : const Color(0xFFEEEEEE),
                      boxShadow: _formValido
                          ? [BoxShadow(
                              color: widget.secondaryColor.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )]
                          : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: _formValido
                            ? () => widget.onConfirm(
                                  _metodoSeleccionado!,
                                  _esBilletera
                                      ? _telefonoController.text.trim()
                                      : null,
                                )
                            : null,
                        child: Center(
                          child: Text(
                            'Confirmar',
                            style: TextStyle(
                              color: _formValido
                                  ? textColorForGradient(widget.accentColor, widget.secondaryColor)
                                  : const Color(0xFFAAAAAA),
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
          ],
        ),
      ),
    );
  }
}

/// Detecta por nombre si un método de pago es una billetera/transferencia
/// digital que necesita pedir un teléfono/cuenta de contacto (Nequi,
/// Daviplata, PSE, etc.) — a diferencia de "Efectivo", que no necesita nada
/// más para procesarse.
bool _esMetodoBilletera(String nombre) {
  final n = nombre.toLowerCase();
  return n.contains('billetera') ||
      n.contains('nequi') ||
      n.contains('daviplata') ||
      n.contains('digital') ||
      n.contains('transfer') ||
      n.contains('pse');
}

/// Ícono para un programa de fidelidad: Puntos Colombia (nsxFidelityId 1)
/// usa su logo real (servido por ResourceService, igual que los logos de
/// métodos de pago) en vez del ícono genérico de estrella. Si todavía no se
/// resolvió la URL (o es otro programa distinto), cae a la estrella.
Widget _iconoFidelidad(int nsxFidelityId, String? logoUrl, {required double size, Color? color}) {
  if (logoUrl != null) {
    return Image.network(
      logoUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.star_rounded, color: color, size: size),
    );
  }
  return Icon(Icons.star_rounded, color: color, size: size);
}

/// Códigos DIAN de tipo de documento usados por fidelidad — mismo mapeo que
/// usa la facturación electrónica, duplicado acá porque allá es privado.
// Commodo identifica al cliente solo por celular: no se pide tipo de documento
const int _nsxCommodoId = 3;
const int _codigoCelular = 10;

const Map<String, int> _tipoDocFidelidad = {
  'Cédula de ciudadanía': 13,
  'Cédula de extranjería': 22,
  'Pasaporte': 41,
};

/// Igual que [_tipoDocFidelidad] pero tolerante a como venga el texto desde
/// la base local (mayúsculas, sin tilde, abreviado "CC"/"CE", con espacios
/// de más, etc.) — la validación automática de fidelidad no tiene ningún
/// valor por defecto que tape un desajuste de texto, así que si esto no
/// matchea, simplemente nunca se dispara sin que se note el porqué.
int? _codigoDocFidelidad(String? tipoDocumento) {
  if (tipoDocumento == null) return null;
  final t = tipoDocumento
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('.', '')
      .replaceAll(RegExp(r'\s+'), ' ');

  if (t == 'cc' || t.contains('ciudadania')) return 13;
  if (t == 'ce' || t.contains('extranjeria')) return 22;
  if (t == 'pp' || t.contains('pasaporte')) return 41;
  return null;
}

// ---------------------------------------------------------------------------
// Formulario manual de fidelidad: se usa cuando no se pudo validar sola la
// cédula del cliente identificado (o no la traía) — deja elegir el tipo de
// documento e intentar de nuevo.
// ---------------------------------------------------------------------------

class _FidelidadManualSheet extends StatefulWidget {
  final Color primaryColor;
  final int nsxFidelityId;
  final String? logoUrl;
  // Retorna el resultado de la validación; si es exitosa, quien llama ya se
  // encarga de mostrar el diálogo de "¿desea acumular puntos?".
  final Future<FidelityResult> Function(int documentTypeCode, String documentNumber) onValidar;

  const _FidelidadManualSheet({
    required this.primaryColor,
    required this.nsxFidelityId,
    required this.logoUrl,
    required this.onValidar,
  });

  @override
  State<_FidelidadManualSheet> createState() => _FidelidadManualSheetState();
}

class _FidelidadManualSheetState extends State<_FidelidadManualSheet> {
  final _docController = TextEditingController();
  String _tipoDoc = 'Cédula de ciudadanía';
  bool _validando = false;
  String? _error;

  bool get _soloCelular => widget.nsxFidelityId == _nsxCommodoId;

  @override
  void dispose() {
    _docController.dispose();
    super.dispose();
  }

  Future<void> _onValidarTap() async {
    final numeroDoc = _docController.text.trim();
    if (numeroDoc.isEmpty) {
      setState(() => _error = _soloCelular ? 'Ingresa el número de celular' : 'Ingresa el número de documento');
      return;
    }
    if (_soloCelular && numeroDoc.length != 10) {
      setState(() => _error = 'El celular debe tener 10 dígitos');
      return;
    }

    setState(() {
      _validando = true;
      _error = null;
    });

    final tipoDocCode = _soloCelular ? _codigoCelular : _tipoDocFidelidad[_tipoDoc]!;
    final result = await widget.onValidar(tipoDocCode, numeroDoc);

    if (!mounted) return;

    if (result.success) {
      // Se cierra el sheet devolviendo el resultado — quien lo abrió
      // muestra el diálogo de confirmación después, ya sin el sheet
      // encima (evita que un pop termine cerrando el diálogo en vez del
      // sheet por quedar apilados).
      Navigator.pop(context, (result, tipoDocCode, numeroDoc));
      return;
    }

    setState(() {
      _validando = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _iconoFidelidad(widget.nsxFidelityId, widget.logoUrl,
                    color: widget.primaryColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Acumular puntos',
                  style: TextStyle(
                    color: widget.primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _soloCelular ? 'Ingresa el celular del cliente para validarlo' : 'Ingresa el documento del cliente para validarlo',
              style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (!_soloCelular) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _tipoDoc,
                      items: _tipoDocFidelidad.keys
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                      onChanged: _validando ? null : (v) => setState(() => _tipoDoc = v!),
                    ),
                  ),
                ),
                if (!_soloCelular) const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _docController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_soloCelular ? 10 : 15),
                    ],
                    enabled: !_validando,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      hintText: _soloCelular ? 'Número de celular' : 'Número de documento',
                      hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: widget.primaryColor,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _validando ? null : _onValidarTap,
                    child: Center(
                      child: _validando
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Validar',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
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
}

