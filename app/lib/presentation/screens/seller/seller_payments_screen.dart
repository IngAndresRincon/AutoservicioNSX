import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gnesys_as/data/models/seller_models.dart';
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:gnesys_as/utils/responsive.dart';

final _pesos = NumberFormat('\$#,##0', 'es_CO');

IconData paymentIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('efectivo')) return Icons.payments_outlined;
  if (n.contains('nequi') || n.contains('daviplata') || n.contains('celular')) return Icons.smartphone_rounded;
  if (n.contains('datafono') || n.contains('datáfono') || n.contains('visa') || n.contains('master') || n.contains('debito') || n.contains('débito') || n.contains('credito') || n.contains('crédito') || n.contains('tarjeta')) {
    return Icons.credit_card_rounded;
  }
  return Icons.account_balance_wallet_outlined;
}

/// Formas de pago de la venta: lo ya guardado, lo nuevo por guardar y el resto en efectivo.
class SellerPaymentsScreen extends StatefulWidget {
  final int saleId;
  final int total;
  final int nsxPositionId;
  final List<SellerPayLine> saved;

  const SellerPaymentsScreen({
    super.key,
    required this.saleId,
    required this.total,
    required this.nsxPositionId,
    required this.saved,
  });

  @override
  State<SellerPaymentsScreen> createState() => _SellerPaymentsScreenState();
}

class _SellerPaymentsScreenState extends State<SellerPaymentsScreen> {
  static const Color _savedColor = Color(0xFF7FCF9F);
  static const Color _cashColor = Color(0xFFC9D3E2);

  AppColors _colors = const AppColors();
  final List<SellerPayLine> _pending = [];
  bool _saving = false;

  int get _savedSum => widget.saved.fold(0, (sum, line) => sum + line.amount);
  int get _pendingSum => _pending.fold(0, (sum, line) => sum + line.amount);
  int get _remaining => (widget.total - _savedSum - _pendingSum).clamp(0, widget.total);

  @override
  void initState() {
    super.initState();
    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
  }

  Future<void> _add() async {
    if (_remaining <= 0) {
      showSellerNotice(context, 'La venta ya está cubierta', error: true);
      return;
    }
    final usedCodes = [...widget.saved, ..._pending].map((line) => line.reference).where((ref) => ref.isNotEmpty).toList();
    final line = await context.push<SellerPayLine>('/seller/payments/add', extra: {'remaining': _remaining, 'usedCodes': usedCodes});
    if (line != null && mounted) setState(() => _pending.add(line));
  }

  Future<void> _save() async {
    if (_pending.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await SellerService.savePayments(widget.saleId, _pending);
      if (!mounted) return;
      context.pop(true);
    } on SellerException catch (e) {
      if (!mounted) return;
      showSellerNotice(context, e.message, error: true);
      if (e.sessionExpired) context.go('/seller/login');
    } finally {
      if (mounted) setState(() => _saving = false);
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
            const Text('Forma de pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _buildSummaryCard(),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.saved.isNotEmpty) ...[
                      _sectionLabel('YA GUARDADAS'),
                      for (final line in widget.saved) _lineTile(line, saved: true),
                    ],
                    if (_pending.isNotEmpty) ...[
                      _sectionLabel('POR GUARDAR'),
                      for (int i = 0; i < _pending.length; i++) _lineTile(_pending[i], onRemove: () => setState(() => _pending.removeAt(i))),
                    ],
                    _sectionLabel('LO QUE QUEDA'),
                    _cashTile(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : _add,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                foregroundColor: _colors.primary,
                side: BorderSide(color: _colors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('+ Agregar forma de pago', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            GradientButton(
              label: _pending.isEmpty ? 'Guardar' : 'Guardar (${_pending.length})',
              colors: _colors,
              height: 50,
              loading: _saving,
              onTap: _pending.isEmpty ? null : _save,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF2)),
      ),
      child: Column(
        children: [
          Text('Venta ${widget.saleId} · Pos ${widget.nsxPositionId}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(_pesos.format(widget.total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (_savedSum > 0) Expanded(flex: _savedSum, child: Container(color: _savedColor)),
                  if (_pendingSum > 0) Expanded(flex: _pendingSum, child: Container(color: _colors.secondary)),
                  if (_remaining > 0) Expanded(flex: _remaining, child: Container(color: _cashColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Colors.grey)),
      );

  Widget _lineTile(SellerPayLine line, {bool saved = false, VoidCallback? onRemove}) {
    final color = saved ? Colors.green.shade600 : _colors.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          saved
              ? Icon(Icons.check_circle_rounded, color: color, size: 22)
              : PaymentLogo(name: line.name, size: 26, color: color, fallback: paymentIcon(line.name)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(
                  saved ? 'Guardada${line.reference.isNotEmpty ? ' · Ref. ${line.reference}' : ''}' : (line.reference.isNotEmpty ? 'Ref. ${line.reference}' : 'Por guardar'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(_pesos.format(line.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          if (onRemove != null)
            IconButton(visualDensity: VisualDensity.compact, onPressed: onRemove, icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _cashTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cashColor, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: Colors.grey.shade600, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Efectivo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text('lo que queda', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(_pesos.format(_remaining), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}
