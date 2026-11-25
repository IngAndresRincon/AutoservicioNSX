import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gnesys_as/data/models/models.dart';
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:gnesys_as/utils/responsive.dart';

/// Datos para abrir el tiquete de una venta del turno: producto y color salen del mapeo.
Future<Map<String, dynamic>?> sellerSaleSummaryArgs(SellerShiftSale sale, {bool openInvoice = false}) async {
  final nsxId = sale.presetNsxId;
  if (nsxId == null) return null;

  final screenId = await StorageService.getScreenNumber() ?? 1;
  final mapping = await PumpService.getMappingWithFallback(screenId);
  final hose = (mapping?.productHoses ?? const <ProductHose>[])
      .where((h) => h.nsxPositionId == sale.nsxPositionId && h.hoseNumber == sale.hoseNumber)
      .firstOrNull;

  return {
    'presetNsxId': nsxId,
    'product': hose?.product ?? 'Manguera ${sale.hoseNumber}',
    'hoseColor': hose?.color ?? '',
    'nsxPositionId': sale.nsxPositionId ?? 0,
    'openInvoice': openInvoice,
    'isCredit': sale.isCredit,
  };
}

/// Ventas del vendedor en su turno abierto: para completar la forma de pago, la factura o el recibo.
class SellerSalesScreen extends StatefulWidget {
  const SellerSalesScreen({super.key});

  @override
  State<SellerSalesScreen> createState() => _SellerSalesScreenState();
}

class _SellerSalesScreenState extends State<SellerSalesScreen> {
  final _money = NumberFormat('\$#,##0', 'es_CO');
  final _gallons = NumberFormat('#,##0.##', 'es_CO');

  AppColors _colors = const AppColors();
  List<SellerShiftSale> _sales = [];
  List<ProductHose> _hoses = [];
  bool _loading = true;
  String? _error;
  // Dinero y volumen reales de cada venta (id de venta -> valores); el listado solo trae lo programado
  final Map<int, ({double money, double volume})> _real = {};

  @override
  void initState() {
    super.initState();
    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final screenId = await StorageService.getScreenNumber() ?? 1;
      final mapping = await PumpService.getMappingWithFallback(screenId);
      final sales = await SellerService.getShiftSales();
      if (!mounted) return;
      setState(() {
        _hoses = mapping?.productHoses ?? [];
        _sales = sales;
        _loading = false;
      });
      _loadReal(sales);
    } on SellerException catch (e) {
      if (!mounted) return;
      if (e.sessionExpired) {
        context.go('/seller/login');
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  // Trae de NSX el valor real de cada venta, de a 4, y los va mostrando a medida que llegan
  Future<void> _loadReal(List<SellerShiftSale> sales) async {
    final pending = sales.where((s) => s.presetNsxId != null && !_real.containsKey(s.saleId)).toList();
    for (int i = 0; i < pending.length; i += 4) {
      await Future.wait(pending.skip(i).take(4).map((s) async {
        try {
          final data = await SellerService.getSale(s.presetNsxId!);
          if (!mounted) return;
          setState(() => _real[s.saleId] = (money: (data['dinero'] ?? 0).toDouble(), volume: (data['volumen'] ?? 0).toDouble()));
        } catch (_) {
          // Sin el dato se queda lo programado
        }
      }));
      if (!mounted) return;
    }
  }

  Color _hoseColor(ProductHose? hose) {
    try {
      return Color(int.parse((hose?.color ?? '').replaceAll('#', '').padLeft(8, 'F'), radix: 16));
    } catch (_) {
      return _colors.primary;
    }
  }

  ProductHose? _hoseOf(SellerShiftSale sale) =>
      _hoses.where((h) => h.nsxPositionId == sale.nsxPositionId && h.hoseNumber == sale.hoseNumber).firstOrNull;

  String _programmed(SellerShiftSale sale) {
    if (sale.type == 1) return 'LLENO';
    if (sale.type == 3) return '${_gallons.format(sale.value)} gal';
    return _money.format(sale.value);
  }

  Future<void> _open(SellerShiftSale sale) async {
    final args = await sellerSaleSummaryArgs(sale);
    if (args == null || !mounted) return;
    await context.push('/seller/summary', extra: args);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (SellerService.session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/seller/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return SellerScaffold(
      colors: _colors,
      onBack: () => context.canPop() ? context.pop() : context.go('/seller/menu'),
      child: ScaleUp(
        reference: const Size(420, 760),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Ventas del turno', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                IconButton(onPressed: _loading ? null : _load, icon: Icon(Icons.refresh_rounded, color: _colors.primary)),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)));
    }
    if (_sales.isEmpty) {
      return Center(child: Text('Aún no hay ventas en este turno.', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)));
    }

    return ListView.separated(
      itemCount: _sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _tile(_sales[i]),
    );
  }

  Widget _tile(SellerShiftSale sale) {
    final hose = _hoseOf(sale);
    final time = sale.date != null ? DateFormat('hh:mm a').format(sale.date!) : '--';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(sale),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6EBF2))),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _colors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.receipt_long_outlined, color: _colors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: _hoseColor(hose), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Venta ${sale.saleId} · ${hose?.product ?? 'Manguera ${sale.hoseNumber}'}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Lo real de la venta, grande, para ubicarla de un vistazo; mientras llega se ve lo programado
                    if (_real[sale.saleId] != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(_money.format(_real[sale.saleId]!.money), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _colors.primary)),
                          const SizedBox(width: 8),
                          Text('${_gallons.format(_real[sale.saleId]!.volume)} gal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.grey.shade700)),
                        ],
                      )
                    else
                      Text(_programmed(sale), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.grey.shade500)),
                    Text('$time · Pos ${sale.nsxPositionId ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (_real[sale.saleId] != null) _chip('Programado ${_programmed(sale)}', Colors.blueGrey),
                        if (sale.isCredit)
                          _chip('Crédito', Colors.orange)
                        else
                          _chip(sale.paid > 0 ? 'Pago ${_money.format(sale.paid)} anclado' : 'Efectivo', sale.paid > 0 ? Colors.green : Colors.grey),
                        if (sale.invoiced) _chip('Factura', Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, MaterialColor color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color.shade700)),
      );
}
