import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gnesys_as/data/models/seller_models.dart';
import 'package:gnesys_as/presentation/screens/seller/seller_sales_screen.dart' show sellerSaleSummaryArgs;
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/services/pump_service.dart';
import 'package:gnesys_as/services/resource_service.dart';
import 'package:gnesys_as/services/seller_service.dart';
import 'package:gnesys_as/services/socket_service.dart';
import 'package:gnesys_as/services/storage_service.dart';
import 'package:gnesys_as/utils/responsive.dart';
import 'package:gnesys_as/utils/color_utils.dart';

/// Menu del vendedor: las opciones de la HMI como tarjetas, factura electronica y las ventas en curso.
class SellerMenuScreen extends StatefulWidget {
  const SellerMenuScreen({super.key});

  @override
  State<SellerMenuScreen> createState() => _SellerMenuScreenState();
}

class _SellerMenuScreenState extends State<SellerMenuScreen> {
  AppColors _colors = const AppColors();
  int _screenId = 1;
  int? _positionId; // posicion hibrida de esta pantalla (para abrir y cerrar turno)
  int? _nsxPositionId;
  List<SellerPosition> _positions = [];
  Timer? _refreshTimer;
  SocketSubscription? _socketSubscription;
  bool _busy = false;

  // Imagenes de los botones en la Orange (/mediai): se busca <nombre>.png y, si no esta, se muestra el icono
  static const List<String> _imageNames = ['efectivo', 'credito', 'forma_pago', 'otras_opciones', 'factura_electronica'];
  final Map<String, String> _imageUrls = {};

  @override
  void initState() {
    super.initState();
    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
    _init();
    _loadImageUrls();

    // Respaldo del aviso por socket; tambien detecta la sesion vencida por inactividad
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    _socketSubscription = SocketService.listen(
      channel: SocketChannels.sellerPreset,
      onEvent: (_) => _refreshPositions(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socketSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadImageUrls() async {
    final urls = <String, String>{};
    for (final name in _imageNames) {
      urls[name] = await ResourceService.getImageUrl('$name.png');
    }
    if (mounted) setState(() => _imageUrls.addAll(urls));
  }

  Future<void> _init() async {
    _screenId = await StorageService.getScreenNumber() ?? 1;
    final mapping = await PumpService.getMappingWithFallback(_screenId);
    final hybrid = mapping?.productHoses.where((hose) => hose.hybrid);
    if (mounted && hybrid != null && hybrid.isNotEmpty) {
      setState(() {
        _positionId = hybrid.first.positionId;
        _nsxPositionId = hybrid.first.nsxPositionId;
      });
    }
    _refreshPositions();
  }

  // Todas las posiciones de esta pantalla ocupadas: no se puede programar otra venta
  bool get _allBusy => _positions.isNotEmpty && _positions.every((p) => !p.isFree);

  void _tick() {
    if (!mounted) return;
    if (SellerService.session == null) {
      context.go('/');
      return;
    }
    _refreshPositions();
  }

  Future<void> _refreshPositions() async {
    try {
      final positions = await SellerService.getPositions(_screenId);
      if (mounted) setState(() => _positions = positions);
    } on SellerException catch (e) {
      if (e.sessionExpired && mounted) context.go('/seller/login');
    }
  }

  void _snack(String message, {bool error = false}) {
    showSellerNotice(context, message, error: error);
  }

  /// Pide la clave y abre (o reutiliza) el turno del vendedor. Devuelve true si quedo abierto.
  Future<bool> _openShift() async {
    final positionId = _positionId;
    if (positionId == null) return false;

    final password = await showSellerPasswordDialog(context, _colors, title: 'Clave para abrir turno');
    if (password == null || !mounted) return false;

    setState(() => _busy = true);
    try {
      await SellerService.openShift(positionId: positionId, password: password);
      if (mounted) _snack('Turno abierto');
      return true;
    } on SellerException catch (e) {
      if (!mounted) return false;
      _snack(e.message, error: true);
      if (e.sessionExpired) context.go('/seller/login');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Vender y credito exigen un turno abierto en esta sesion
  Future<bool> _requireShift() async {
    if (SellerService.shiftId.value != null) return true;
    return _openShift();
  }

  Future<void> _onSell() async {
    if (!await _requireShift() || !mounted) return;

    // Sin bloqueo aqui: en hibrido cada manguera va por su posicion y el servidor rechaza si esa posicion esta ocupada
    context.push('/seller/sale');
  }

  // Forma de pago y factura trabajan sobre la ultima venta del turno (si quiere otra, "Otras opciones > Ventas del turno")
  Future<void> _openLastSale({bool invoice = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Las ventas de credito van a cuenta del cliente: no llevan forma de pago ni factura desde aqui
      final sales = (await SellerService.getShiftSales()).where((sale) => !sale.isCredit).toList();
      if (!mounted) return;
      if (sales.isEmpty) {
        _snack('Aún no hay ventas en efectivo en este turno', error: true);
        return;
      }
      final args = await sellerSaleSummaryArgs(sales.first, openInvoice: invoice);
      if (args == null || !mounted) return;
      context.push('/seller/summary', extra: args);
    } on SellerException catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true);
      if (e.sessionExpired) context.go('/seller/login');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onCredit() async {
    if (!await _requireShift() || !mounted) return;

    context.push('/seller/credit');
  }

  void _logout() {
    SellerService.logout();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final session = SellerService.session;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/seller/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SellerScaffold(
      colors: _colors,
      onBack: _logout,
      // El contenido se amplia de forma uniforme al espacio disponible: tarjetas, imagenes, textos y botones
      child: ScaleUp(
        reference: isLandscape ? const Size(780, 380) : const Size(420, 700),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: isLandscape
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSellerRow(session),
                        const SizedBox(height: 12),
                        Expanded(child: SingleChildScrollView(child: _buildInProgress())),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [Expanded(child: _buildGrid()), const SizedBox(height: 10), _buildInvoiceButton()],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSellerRow(session),
                  const SizedBox(height: 12),
                  Expanded(child: _buildGrid()),
                  const SizedBox(height: 10),
                  _buildInvoiceButton(),
                  const SizedBox(height: 10),
                  _buildInProgress(),
                ],
              ),
      ),
      ),
    );
  }

  // Etiqueta del turno en el encabezado; sin turno abierto se toca para abrirlo
  Widget _buildShiftChip() {
    return ValueListenableBuilder<int?>(
      valueListenable: SellerService.shiftId,
      builder: (_, shiftId, __) {
        final open = shiftId != null;
        return GestureDetector(
          onTap: (open || _busy) ? null : _openShift,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: open ? _colors.accent : _colors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: open ? null : Border.all(color: _colors.primary.withOpacity(0.5)),
            ),
            child: Text(
              open ? 'Turno $shiftId' : 'Abrir turno',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: open ? textColorForBackground(_colors.accent) : _colors.primary),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSellerRow(SellerSession session) {
    return Row(
      children: [
        Icon(Icons.person_outline, color: _colors.primary, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Row(
                children: [
                  _buildShiftChip(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _nsxPositionId != null ? 'Pos $_nsxPositionId · Híbrido' : 'Híbrido',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _Pill(label: 'Cerrar sesión', onTap: _logout),
      ],
    );
  }

  Widget _buildGrid() {
    final cards = [
      _HmiCard(label: 'EFECTIVO', subtitle: 'Vender', icon: Icons.payments_outlined, imageUrl: _imageUrls['efectivo'], tone: _colors.primary, onTap: (_busy || _allBusy) ? null : _onSell),
      _HmiCard(label: 'CRÉDITO', subtitle: 'Cliente a cuenta', icon: Icons.credit_card_outlined, imageUrl: _imageUrls['credito'], tone: const Color(0xFFF2A33A), onTap: (_busy || _allBusy) ? null : _onCredit),
      _HmiCard(label: 'FORMA DE PAGO', subtitle: 'Última venta', icon: Icons.account_balance_wallet_outlined, imageUrl: _imageUrls['forma_pago'], tone: const Color(0xFF3CB878), onTap: _busy ? null : _openLastSale),
      _HmiCard(label: 'OTRAS OPCIONES', subtitle: 'Recibo, ventas…', icon: Icons.more_horiz, imageUrl: _imageUrls['otras_opciones'], tone: const Color(0xFF7B68EE), onTap: _busy ? null : () => context.push('/seller/options')),
    ];

    return Column(
      children: [
        Expanded(child: Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])])),
        const SizedBox(height: 10),
        Expanded(child: Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])])),
      ],
    );
  }

  Widget _buildInvoiceButton() {
    // Factura electronica de la ultima venta del turno
    return Opacity(
      opacity: _busy ? 0.45 : 1,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(colors: [_colors.accent, _colors.secondary], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _busy ? null : () => _openLastSale(invoice: true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInvoiceIcon(),
                const SizedBox(width: 8),
                Text('Factura electrónica', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColorForGradientOf(_colors))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceIcon() {
    final fallback = Icon(Icons.receipt_long_outlined, color: textColorForGradientOf(_colors), size: 22);
    final url = _imageUrls['factura_electronica'];
    if (url == null) return fallback;

    return SizedBox(
      width: 28,
      height: 28,
      child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback),
    );
  }

  Widget _buildInProgress() {
    final busy = _positions.where((p) => !p.isFree).toList();

    Widget row(String text, Color dot) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_positions.isEmpty)
          row('Sin información de posiciones', Colors.grey)
        else ...[
          for (final position in busy) row('En curso · ${_positionText(position)}', position.own ? Colors.redAccent : Colors.orange),
          if (_positions.any((p) => p.isFree))
            row(
              _positions.where((p) => p.isFree).length == 1
                  ? 'Posición ${_positions.firstWhere((p) => p.isFree).nsxPositionId} libre'
                  : 'Posiciones ${_positions.where((p) => p.isFree).map((p) => p.nsxPositionId).join(' y ')} libres',
              Colors.green,
            ),
        ],
      ],
    );
  }

  String _positionText(SellerPosition position) {
    final money = position.value != null ? ' \$${position.value!.toStringAsFixed(0)}' : '';
    switch (position.status) {
      case 'autoservice':
        return 'Pos ${position.nsxPositionId} · Cliente (autoservicio)';
      case 'client':
        return 'Pos ${position.nsxPositionId} · ${position.own ? 'Crédito$money' : 'Cliente identificado'}';
      default:
        if (!position.own) return 'Pos ${position.nsxPositionId} · Otro vendedor';
        return 'Pos ${position.nsxPositionId} · ${position.sync == 8 ? 'Surtiendo' : 'Autorizado'}$money';
    }
  }

}

class _HmiCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _HmiCard({required this.label, required this.subtitle, required this.icon, required this.tone, required this.onTap, this.imageUrl});

  // Circulo con el icono: es lo que se ve mientras carga la imagen o si no existe en la Orange
  Widget _iconBadge() => Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(color: tone.withOpacity(0.14), shape: BoxShape.circle),
        child: Icon(icon, color: tone, size: 30),
      );

  Widget _buildImage() {
    final url = imageUrl;
    if (url == null) return _iconBadge();

    return SizedBox(
      width: 74,
      height: 74,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null ? child : Center(child: _iconBadge()),
        errorBuilder: (_, __, ___) => Center(child: _iconBadge()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE9EDF3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildImage(),
                  const SizedBox(height: 8),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                  const SizedBox(height: 2),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _Pill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
