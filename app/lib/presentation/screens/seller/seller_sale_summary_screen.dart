import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gnesys_as/data/models/models.dart';
import 'package:gnesys_as/presentation/screens/transaction/transactions_screen.dart' show FacturaModal;
import 'package:gnesys_as/presentation/widgets/numeric_keypad.dart';
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/presentation/widgets/app_notice.dart';
import 'package:gnesys_as/presentation/widgets/fidelity_brand.dart';
import 'package:gnesys_as/utils/responsive.dart';
import 'package:gnesys_as/utils/color_utils.dart';
import 'package:gnesys_as/services/service.dart';

/// Fin de venta del vendedor: el mismo resumen de transaccion del cliente.
class SellerSaleSummaryScreen extends StatefulWidget {
  final int presetNsxId;
  final String product;
  final String hoseColor;
  final int nsxPositionId;
  final bool openInvoice; // abre de una vez el modal de factura (acceso directo del menu)
  final bool isCredit; // venta a cuenta de un cliente: sin formas de pago, factura ni fidelidad desde aqui

  const SellerSaleSummaryScreen({
    super.key,
    this.isCredit = false,
    required this.presetNsxId,
    required this.product,
    required this.hoseColor,
    required this.nsxPositionId,
    this.openInvoice = false,
  });

  @override
  State<SellerSaleSummaryScreen> createState() => _SellerSaleSummaryScreenState();
}

class _SellerSaleSummaryScreenState extends State<SellerSaleSummaryScreen> {
  static const int _maxAttempts = 6;

  AppColors _colors = const AppColors();
  Map<String, dynamic>? _sale;
  bool _loading = true;

  bool _isGnesys = false;
  FidelityProgram? _program; // por ahora se usa el primero de la estacion
  final ScrollController _bodyScroll = ScrollController(); // para ajustar la escala al contenido
  FidelityBrand? _brand; // logo y color del programa, sacados de su imagen en la Orange
  bool _accumulatedNow = false;
  String? _pointsNow;

  final _money = NumberFormat('\$#,##0', 'es_CO');
  final _volume = NumberFormat('#,##0.000', 'es_CO');
  final _points = NumberFormat('#,##0.##', 'es_CO');

  static const int _commodoId = 3;
  static const int _phoneCode = 10;
  static const Map<String, int> _documentTypes = {
    'Cédula de ciudadanía': 13,
    'Cédula de extranjería': 22,
    'Pasaporte': 41,
  };

  @override
  void initState() {
    super.initState();
    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
    _loadProgram();
    _load();
  }

  Future<void> _loadProgram() async {
    final screenId = await StorageService.getScreenNumber() ?? 1;
    final mapping = await PumpService.getMappingWithFallback(screenId);
    final programs = mapping?.fidelity ?? <FidelityProgram>[];
    if (mounted) {
      setState(() {
        _program = programs.firstOrNull;
        _isGnesys = mapping?.station.data.flag == 'GNESYS';
      });
    }
    final program = programs.firstOrNull;
    if (program != null) {
      final brand = await FidelityBrandService.load(
        program.fidelityName,
        alternateFiles: program.nsxFidelityId == 1 ? const ['puntoscolombia.png'] : const [],
      );
      if (brand != null && mounted) setState(() => _brand = brand);
    }
  }

  // --- Factura electronica (el mismo modal del autoservicio) ---

  String get _invoiceNumber => ((_sale?['fElectronica'] as String?) ?? '').trim();

  // Apenas se envia se muestra como enviada, aunque el numero de factura tarde en llegar a la venta
  bool _invoiceSentNow = false;
  String _invoiceEmail = '';

  bool get _hasInvoice => _invoiceNumber.isNotEmpty || _invoiceSentNow;

  void _openInvoice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FacturaModal(
        primaryColor: _colors.primary,
        secondaryColor: _colors.secondary,
        accentColor: _colors.accent,
        customer: null,
        onConfirm: (documentType, documentNumber, name, email) async {
          Navigator.pop(context);
          await _generateInvoice(documentType, documentNumber, name, email);
        },
      ),
    );
  }

  Future<void> _generateInvoice(String documentType, String documentNumber, String name, String email) async {
    final saleId = _saleId;
    if (saleId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _colors.primary, strokeWidth: 3),
            const SizedBox(height: 20),
            const Text('Enviando factura...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Por favor espera un momento', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );

    final ok = await CustomerService().generarFactura(
      saleId: saleId,
      documentNumber: documentNumber,
      documentType: documentType,
      companyName: name,
      email: email,
      isGnesys: _isGnesys,
    );

    if (!mounted) return;
    Navigator.pop(context); // cierra el dialogo de carga

    showAppNotice(
      context,
      ok ? 'La factura electrónica se envió a $email' : 'No se pudo generar la factura. Intenta de nuevo.',
      title: ok ? '¡Factura enviada!' : 'No se generó la factura',
      kind: ok ? NoticeKind.success : NoticeKind.error,
    );

    if (ok) {
      setState(() {
        _invoiceSentNow = true;
        _invoiceEmail = email;
      });
      _refreshSale();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _refreshSale();
      });
    }
  }

  // --- Fidelidad ---

  Map<String, dynamic>? get _loyalty {
    final value = _sale?['fidelizacion'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  bool get _alreadyAccumulated => _accumulatedNow || (_loyalty?['acumulo'] == true);

  String? get _accumulatedPoints {
    if (_pointsNow != null && _pointsNow!.isNotEmpty) return _pointsNow;
    final value = _loyalty?['acumulado'];
    return value is num && value > 0 ? _points.format(value) : null;
  }

  Future<void> _openLoyaltySheet() async {
    final program = _program;
    if (program == null || _alreadyAccumulated) return;

    final result = await showModalBottomSheet<(FidelityResult, int, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LoyaltySheet(
        colors: _colors,
        program: program,
        accent: _brandButton,
        isPhoneOnly: program.nsxFidelityId == _commodoId,
        documentTypes: _documentTypes,
        phoneCode: _phoneCode,
        onValidate: (type, number) => FidelityService.validateCustomer(
          fidelityTypeId: program.nsxFidelityId,
          documentType: type,
          documentNumber: number,
        ),
      ),
    );

    if (result == null || !mounted || !result.$1.success) return;
    final name = (result.$1.data?['nombre'] as String?)?.trim();
    _confirmAccumulate(name: name, type: result.$2, number: result.$3);
  }

  void _confirmAccumulate({required String? name, required int type, required String number}) {
    final shownName = (name != null && name.isNotEmpty) ? name : 'este cliente';
    final program = _program!;
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
              decoration: BoxDecoration(color: _brandBase.withOpacity(0.12), shape: BoxShape.circle),
              child: _brandIcon(36),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Desea acumular puntos de ${program.fidelityName} para $shownName con esta compra?',
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
            child: const Text('No, gracias', style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _accumulate(type: type, number: number, name: name);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _brandButton,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text('Sí, acumular', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textColorForBackground(_brandButton))),
          ),
        ],
      ),
    );
  }

  Future<void> _accumulate({required int type, required String number, String? name}) async {
    final saleId = _saleId;
    final program = _program;
    if (saleId == null || program == null) return;

    showAppNotice(context, 'Acumulando puntos en ${program.fidelityName}...', kind: NoticeKind.loading, accent: _brandButton);

    final result = await FidelityService.accumulate(
      fidelityTypeId: program.nsxFidelityId,
      saleId: saleId,
      documentType: type,
      documentNumber: number,
      customerName: name,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _accumulatedNow = true;
        _pointsNow = result.data?['puntosAcumulados'] as String?;
      });
      _refreshSale();
    }

    if (!mounted) return;
    showAppNotice(
      context,
      result.success ? 'Acumulaste puntos en ${program.fidelityName}' : result.message,
      title: result.success ? '¡Puntos acumulados!' : 'No se acumularon los puntos',
      kind: result.success ? NoticeKind.success : NoticeKind.error,
    );
  }

  // Vuelve a leer la venta para mostrar los puntos que quedaron guardados
  Future<void> _refreshSale() async {
    try {
      final sale = await SellerService.getSale(widget.presetNsxId);
      if (mounted) setState(() => _sale = sale);
    } on SellerException {
      // Se conserva lo que ya se muestra
    }
  }

  Color get _brandBase => _brand?.color ?? Colors.purple.shade600;
  Color get _brandButton => _brand?.button ?? Colors.purple.shade600;

  Widget _brandIcon(double size) {
    final url = _brand?.logoUrl;
    if (url == null) return Icon(Icons.star_rounded, color: _brandBase, size: size);
    return Image.network(url, width: size, height: size, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.star_rounded, color: _brandBase, size: size));
  }

  Widget _buildLoyaltyCard() {
    final program = _program;
    if (program == null || widget.isCredit) return const SizedBox.shrink();

    if (_alreadyAccumulated) {
      final points = _accumulatedPoints;
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
                  Text('Fidelidad ya acumulada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.green.shade700)),
                  Text(
                    points != null ? '${program.fidelityName} · $points puntos' : program.fidelityName,
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
        gradient: LinearGradient(colors: [_brandBase.withOpacity(0.08), _brandBase.withOpacity(0.18)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _brandBase.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: _brandBase.withOpacity(0.25))),
            child: _brandIcon(22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.fidelityName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _brand?.dark ?? Colors.purple.shade700)),
                Text('Identifícate para acumular con esta compra', style: TextStyle(fontSize: 11, color: _brand?.mid ?? Colors.purple.shade400)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openLoyaltySheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: _brandButton, borderRadius: BorderRadius.circular(20)),
              child: Text('Acumular', style: TextStyle(color: textColorForBackground(_brandButton), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // La venta puede tardar un instante en estar disponible tras el fin del despacho
  Future<void> _load() async {
    setState(() => _loading = true);
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final sale = await SellerService.getSale(widget.presetNsxId);
        if (!mounted) return;
        setState(() {
          _sale = sale;
          _loading = false;
        });
        if (widget.openInvoice && !_hasInvoice) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openInvoice();
          });
        }
        return;
      } on SellerException {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  int? get _saleId => _sale?['idVenta'] as int?;

  Future<void> _print() async {
    final saleId = _saleId;
    if (saleId == null) return;

    final ok = await CustomerService().imprimirRecibo(saleId: saleId);
    if (!mounted) return;
    showAppNotice(
      context,
      ok ? 'El recibo se envió a imprimir' : 'No fue posible imprimir el recibo',
      kind: ok ? NoticeKind.success : NoticeKind.error,
    );
  }

  List<SellerPayLine> _savedPayments(Map<String, dynamic> sale) {
    final payments = sale['formasPago'];
    if (payments is! List) return [];
    return [for (final p in payments) if (p is Map) SellerPayLine.fromSale(Map<String, dynamic>.from(p))];
  }

  // Lo que no se ancla a otra forma sigue siendo efectivo
  Map<String, dynamic>? _client(Map<String, dynamic> sale) {
    final value = sale['cliente'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  String _paymentLabel(Map<String, dynamic> sale) {
    if (widget.isCredit) {
      final client = _client(sale);
      final name = ((client?['empresa'] ?? client?['cuenta']) ?? '').toString().trim();
      return name.isEmpty ? 'A cuenta del cliente' : 'A cuenta: $name';
    }

    final saved = _savedPayments(sale);
    if (saved.isEmpty) return 'Pago: Efectivo';

    final names = saved.map((p) => p.name).where((n) => n.isNotEmpty).toList();
    final cash = (sale['dinero'] ?? 0).round() - saved.fold<int>(0, (sum, p) => sum + p.amount);
    if (cash > 0) names.add('Efectivo');
    return names.isEmpty ? 'Pago registrado' : 'Pago: ${names.join(' + ')}';
  }

  Future<void> _openPayments() async {
    final sale = _sale;
    final saleId = _saleId;
    if (sale == null || saleId == null) return;

    final changed = await context.push<bool>('/seller/payments', extra: {
      'saleId': saleId,
      'total': (sale['dinero'] ?? 0).round(),
      'nsxPositionId': widget.nsxPositionId,
      'saved': _savedPayments(sale),
    });
    if (changed == true) _refreshSale();
  }

  @override
  Widget build(BuildContext context) {
    if (SellerService.session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/seller/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SellerService.touch(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        // Todo el contenido se amplia de forma uniforme al espacio disponible
        body: ScaleUp(
          reference: MediaQuery.of(context).orientation == Orientation.landscape ? const Size(780, 420) : const Size(420, 780),
          minScale: 0.6,
          fitControllers: [_bodyScroll],
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_sale == null ? _buildMissing() : _buildBody(_sale!)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final session = SellerService.session;
    final shiftId = SellerService.shiftId.value;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 16, left: 20, right: 20),
      decoration: BoxDecoration(color: _colors.primary),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('TRANSACCIÓN EXITOSA', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                Text(
                  '${session?.name ?? ''}${shiftId != null ? ' · Turno $shiftId' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                ),
              ],
            ),
          ),
          _colors.logoUrl != null
              ? Image.network(_colors.logoUrl!, height: 28, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Image.asset('assets/images/logo_insepet_blanco.png', height: 28))
              : Image.asset('assets/images/logo_insepet_blanco.png', height: 28),
        ],
      ),
    );
  }

  Widget _buildMissing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            const Text('Aún no está disponible la venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('El despacho terminó, pero la venta no se ha registrado todavía.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 18),
            GradientButton(label: 'Reintentar', colors: _colors, height: 48, onTap: _load),
            TextButton(onPressed: () => context.go('/seller/menu'), child: const Text('Volver al menú', style: TextStyle(color: Colors.black))),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> sale) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SingleChildScrollView(controller: _bodyScroll, child: _buildDetails(sale))),
            const SizedBox(width: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTotalCard(sale),
                    const SizedBox(height: 8),
                    _buildLoyaltyCard(),
                    const SizedBox(height: 10),
                    _buildTicketEnd(),
                    _buildButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: _bodyScroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        children: [
          _buildDetails(sale),
          const SizedBox(height: 10),
          _buildTotalCard(sale),
          const SizedBox(height: 8),
          _buildLoyaltyCard(),
          const SizedBox(height: 8),
          _buildTicketEnd(),
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildDetails(Map<String, dynamic> sale) {
    DateTime? date;
    try {
      date = DateTime.parse(sale['fechaVenta'].toString());
    } catch (_) {}

    final volume = (sale['volumen'] ?? 0).toDouble();
    final price = (sale['precioVenta'] ?? 0).toInt();
    final programmed = (sale['valorProgramado'] ?? 0).toDouble();
    final type = (sale['tipoProgramacion'] ?? 2).toInt();
    final byVolume = type == 3;
    final hose = sale['numeroManguera'] ?? '--';

    return Column(
      children: [
        Row(
          children: [
            _MetaChip(icon: Icons.calendar_today_outlined, label: 'Fecha', value: date != null ? DateFormat('dd/MM/yy').format(date) : '--'),
            const SizedBox(width: 8),
            _MetaChip(icon: Icons.access_time_outlined, label: 'Hora', value: date != null ? DateFormat('hh:mm a').format(date) : '--'),
            const SizedBox(width: 8),
            _MetaChip(icon: Icons.hive_outlined, label: 'Manguera', value: '#$hose'),
          ],
        ),
        const SizedBox(height: 10),
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
                  Text('TRANSACCIÓN #${_saleId ?? '---'}', style: TextStyle(color: _colors.primary, fontSize: 13, fontWeight: FontWeight.w800)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      type == 1 ? 'Lleno' : (byVolume ? 'Por volumen' : 'Por pesos'),
                      style: TextStyle(color: _colors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16, color: Color(0xFFEEEEEE)),
              if (widget.product.trim().isNotEmpty) _detailRow('Producto', widget.product),
              if (widget.isCredit && _client(sale) != null) ...[
                if (((_client(sale)!['empresa'] ?? '') as Object).toString().trim().isNotEmpty) _detailRow('Cliente', _client(sale)!['empresa'].toString().trim()),
                if (((_client(sale)!['cuenta'] ?? '') as Object).toString().trim().isNotEmpty) _detailRow('Cuenta', _client(sale)!['cuenta'].toString().trim()),
                if (((_client(sale)!['placa'] ?? '') as Object).toString().trim().isNotEmpty) _detailRow('Placa', _client(sale)!['placa'].toString().trim()),
              ],
              _detailRow('Precio por galón', _money.format(price)),
              _detailRow('Volumen despachado', '${_volume.format(volume)} gal'),
              if (type != 1) _detailRow(byVolume ? 'Volumen programado' : 'Monto programado', byVolume ? '${_volume.format(programmed)} gal' : _money.format(programmed)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 15)),
          Flexible(child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111111), fontSize: 17, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildTotalCard(Map<String, dynamic> sale) {
    final total = _money.format((sale['dinero'] ?? 0).toInt());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(width: 4, height: 60, decoration: BoxDecoration(color: _colors.primary, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VALOR DE VENTA', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(total, style: const TextStyle(color: Color(0xFF111111), fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1)),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text(_paymentLabel(sale), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green.shade700)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _colors.primary.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.local_gas_station_rounded, color: _colors.primary, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketEnd() {
    return Column(
      children: [
        const SizedBox(height: 16, width: double.infinity, child: CustomPaint(painter: _JaggedPainter())),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('TRANSACCIÓN #${_saleId ?? '---'}', style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    if (widget.isCredit) return _buildCreditButtons();
    final hasInvoice = _hasInvoice;

    return Column(
      children: [
        if (hasInvoice) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade100)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
                  child: Icon(Icons.verified_outlined, color: Colors.green.shade700, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_invoiceNumber.isNotEmpty ? 'Factura electrónica generada' : 'Factura electrónica enviada', style: TextStyle(fontSize: 11, color: Colors.green.shade600, fontWeight: FontWeight.w500)),
                      Text(
                        _invoiceNumber.isNotEmpty ? _invoiceNumber : (_invoiceEmail.isNotEmpty ? 'Enviada a $_invoiceEmail' : 'Enviada'),
                        style: TextStyle(fontSize: 14, color: Colors.green.shade800, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: _openPayments,
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
          label: const Text('Forma de pago', style: TextStyle(fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            foregroundColor: _colors.primary,
            side: BorderSide(color: _colors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
        const SizedBox(height: 10),
        _buildActionRow(),
        if (!hasInvoice)
          TextButton.icon(
            onPressed: _print,
            icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF666666)),
            label: const Text('Imprimir recibo', style: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  // Credito: la venta queda a cuenta del cliente; solo se vuelve o se imprime el recibo
  Widget _buildCreditButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.go('/seller/menu'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              side: const BorderSide(color: Color(0xFFCCCCCC)),
            ),
            child: const Text('Volver', style: TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: GradientButton(label: 'Imprimir recibo', colors: _colors, height: 50, onTap: _print)),
      ],
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.go('/seller/menu'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              side: const BorderSide(color: Color(0xFFCCCCCC)),
            ),
            child: const Text('Volver', style: TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
        // Con factura ya generada el boton imprime el recibo, como en el autoservicio
        Expanded(
          flex: 2,
          child: _hasInvoice
              ? GradientButton(label: 'Imprimir recibo', colors: _colors, height: 50, onTap: _print)
              : GradientButton(label: 'Factura electrónica', colors: _colors, height: 50, onTap: _openInvoice),
        ),
      ],
    );
  }
}

/// Captura del celular (Commodo) o del documento y lo valida; devuelve el resultado, el tipo y el numero.
class _LoyaltySheet extends StatefulWidget {
  final AppColors colors;
  final FidelityProgram program;
  final Color accent;
  final bool isPhoneOnly;
  final Map<String, int> documentTypes;
  final int phoneCode;
  final Future<FidelityResult> Function(int type, String number) onValidate;

  const _LoyaltySheet({
    required this.colors,
    required this.program,
    required this.accent,
    required this.isPhoneOnly,
    required this.documentTypes,
    required this.phoneCode,
    required this.onValidate,
  });

  @override
  State<_LoyaltySheet> createState() => _LoyaltySheetState();
}

class _LoyaltySheetState extends State<_LoyaltySheet> {
  String _number = '';
  late String _type = widget.documentTypes.keys.first;
  bool _validating = false;
  String? _error;

  int get _maxLength => widget.isPhoneOnly ? 10 : 15;

  void _onKey(String key) {
    if (_validating || _number.length >= _maxLength) return;
    setState(() {
      _number += key;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_validating || _number.isEmpty) return;
    setState(() {
      _number = _number.substring(0, _number.length - 1);
      _error = null;
    });
  }

  Future<void> _validate() async {
    if (widget.isPhoneOnly && _number.length != 10) {
      setState(() => _error = 'El celular debe tener 10 dígitos');
      return;
    }
    if (_number.isEmpty) {
      setState(() => _error = 'Ingresa el número de documento');
      return;
    }

    setState(() {
      _validating = true;
      _error = null;
    });

    final code = widget.isPhoneOnly ? widget.phoneCode : widget.documentTypes[_type]!;
    final result = await widget.onValidate(code, _number);
    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context, (result, code, _number));
      return;
    }
    setState(() {
      _validating = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.accent;
    // Todo crece con el ancho de la pantalla; el alto sale del contenido (sin hueco entre el campo y el teclado)
    final k = (MediaQuery.of(context).size.width / 420).clamp(1.0, 2.0);

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(20 * k, 14 * k, 20 * k, 20 * k),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.star_rounded, color: primary, size: 22 * k),
              SizedBox(width: 10 * k),
              Text('Acumular ${widget.program.fidelityName}', style: TextStyle(color: primary, fontSize: 18 * k, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.isPhoneOnly ? 'Ingresa el celular del cliente para validarlo' : 'Ingresa el documento del cliente para validarlo',
            style: TextStyle(color: const Color(0xFF999999), fontSize: 13 * k),
          ),
          SizedBox(height: 12 * k),
          if (!widget.isPhoneOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final type in widget.documentTypes.keys)
                    ChoiceChip(
                      label: Text(type, style: TextStyle(fontSize: 12 * k, fontWeight: FontWeight.w700)),
                      selected: _type == type,
                      onSelected: _validating ? null : (_) => setState(() => _type = type),
                    ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16 * k, vertical: 12 * k),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: primary, width: 2)),
            child: Text(
              _number.isEmpty ? (widget.isPhoneOnly ? 'Número de celular' : 'Número de documento') : _number,
              style: TextStyle(fontSize: 26 * k, fontWeight: FontWeight.w800, color: _number.isEmpty ? const Color(0xFFBBBBBB) : Colors.black),
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
          SizedBox(height: 10 * k),
          Flexible(child: NumericKeypad(accentColor: primary, onKey: _onKey, onBackspace: _onBackspace)),
          SizedBox(height: 10 * k),
          SizedBox(
            height: 50 * k,
            child: FilledButton(
              onPressed: _validating ? null : _validate,
              style: FilledButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: _validating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Validar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16 * k, color: textColorForBackground(primary))),
            ),
          ),
        ],
      ),
    );
  }
}

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
                Text(label, style: const TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _JaggedPainter extends CustomPainter {
  const _JaggedPainter();

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
