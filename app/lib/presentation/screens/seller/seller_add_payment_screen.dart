import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gnesys_as/data/models/models.dart';
import 'package:gnesys_as/presentation/screens/seller/seller_payments_screen.dart' show paymentIcon;
import 'package:gnesys_as/presentation/widgets/numeric_keypad.dart';
import 'package:gnesys_as/presentation/widgets/qr_scanner.dart';
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:gnesys_as/utils/responsive.dart';

enum _Share { rest, half, other }

/// Agrega una forma de pago a la lista: se toca la forma y el monto ya viene sugerido con lo que falta.
/// Con QR (bono de vueltos) se escanea el codigo y el monto es el valor del bono.
class SellerAddPaymentScreen extends StatefulWidget {
  final int remaining;
  final List<String> usedCodes; // bonos que ya estan en la lista o en la venta

  const SellerAddPaymentScreen({super.key, required this.remaining, this.usedCodes = const []});

  @override
  State<SellerAddPaymentScreen> createState() => _SellerAddPaymentScreenState();
}

class _SellerAddPaymentScreenState extends State<SellerAddPaymentScreen> {
  final _pesos = NumberFormat('\$#,##0', 'es_CO');

  AppColors _colors = const AppColors();
  List<SellerPaymentMethod> _methods = [];
  bool _loading = true;
  SellerPaymentMethod? _method;
  _Share _share = _Share.rest;
  String _other = '';
  String _reference = '';
  bool _showReference = false;
  String? _bonoCode;
  int _bonoAmount = 0;
  String? _bonoError;
  bool _validatingBono = false;

  bool get _isQr {
    final n = (_method?.name ?? '').toLowerCase();
    return n.contains('qr') || n.contains('vuelto');
  }

  int get _amount {
    if (_isQr) return _bonoAmount;
    switch (_share) {
      case _Share.rest:
        return widget.remaining;
      case _Share.half:
        return (widget.remaining / 2).round();
      case _Share.other:
        return int.tryParse(_other) ?? 0;
    }
  }

  bool get _valid => _method != null && _amount > 0 && _amount <= widget.remaining && (!_isQr || _bonoCode != null);

  Future<void> _scanBono() async {
    if (_validatingBono) return;
    await QrScannerSheet.show(
      context,
      accentColor: _colors.primary,
      title: 'Escanear bono',
      subtitle: 'Apunta la cámara al código QR del bono',
      onScanned: _validateBono,
    );
  }

  // Igual que el autoservicio: solo vale un bono en estado Creado, por su valor
  Future<void> _validateBono(String code) async {
    final clean = code.trim();
    if (widget.usedCodes.contains(clean)) {
      setState(() => _bonoError = 'Ese bono ya está en la venta');
      return;
    }

    setState(() {
      _validatingBono = true;
      _bonoError = null;
      _bonoCode = null;
      _bonoAmount = 0;
    });

    final result = await PaymentService.validateQRCode(code: clean);
    if (!mounted) return;

    String? error;
    int amount = 0;
    if (result == null || result['data'] is! Map) {
      error = 'Código QR inválido o expirado.';
    } else {
      final status = (result['data']['idEstadoVuelto'] as num?)?.toInt() ?? 0;
      amount = ((result['data']['valor'] as num?) ?? 0).round();
      if (status != 1) {
        error = 'Código QR inválido. ${result['message'] ?? ''}'.trim();
      } else if (amount <= 0) {
        error = 'El bono no tiene valor.';
      } else if (amount > widget.remaining) {
        error = 'El bono (${_pesos.format(amount)}) supera lo que falta (${_pesos.format(widget.remaining)}).';
      }
    }

    setState(() {
      _validatingBono = false;
      _bonoError = error;
      if (error == null) {
        _bonoCode = clean;
        _bonoAmount = amount;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    final screenId = await StorageService.getScreenNumber() ?? 1;
    final mapping = await PumpService.getMappingWithFallback(screenId);
    if (!mounted) return;
    setState(() {
      _methods = mapping?.sellerPaymentMethods ?? [];
      _loading = false;
    });
  }

  void _onKey(String key) {
    String next = key == '000' ? (_other.isEmpty ? '' : '${_other}000') : (_other == '0' ? key : '$_other$key');
    if (next.length > 9 || (int.tryParse(next) ?? 0) > widget.remaining) return;
    setState(() => _other = next);
  }

  void _onBackspace() {
    if (_other.isEmpty) return;
    setState(() => _other = _other.substring(0, _other.length - 1));
  }

  void _confirm() {
    final method = _method;
    if (method == null || !_valid) return;
    context.pop(SellerPayLine(
      paymentId: method.nsxPaymentId,
      name: method.name,
      amount: _amount,
      reference: _isQr ? (_bonoCode ?? '') : _reference.trim(),
    ));
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
                const Expanded(child: Text('Agregar forma de pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text('Por asignar ${_pesos.format(widget.remaining)}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildMethods()),
            if (_method != null) _buildAmountPanel(),
            const SizedBox(height: 8),
            GradientButton(label: 'Agregar a la lista', colors: _colors, height: 50, onTap: _valid ? _confirm : null),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMethods() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_methods.isEmpty) {
      return const Center(child: Text('No hay formas de pago habilitadas para el vendedor.', textAlign: TextAlign.center));
    }

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.15,
      children: [
        for (final method in _methods)
          GestureDetector(
            onTap: () => setState(() {
              if (_method?.nsxPaymentId != method.nsxPaymentId) {
                _bonoCode = null;
                _bonoAmount = 0;
                _bonoError = null;
              }
              _method = method;
            }),
            child: Container(
              decoration: BoxDecoration(
                color: _method?.nsxPaymentId == method.nsxPaymentId ? _colors.primary.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _method?.nsxPaymentId == method.nsxPaymentId ? _colors.primary : const Color(0xFFE6EBF2),
                  width: _method?.nsxPaymentId == method.nsxPaymentId ? 2.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PaymentLogo(name: method.name, size: 34, color: _colors.primary, fallback: paymentIcon(method.name)),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(method.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // QR de vueltos: el monto es el valor del bono, que se valida al escanearlo
  Widget _buildBonoPanel() {
    final scanned = _bonoCode != null;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE6EBF2))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bono de vueltos', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          if (scanned) ...[
            Text(_pesos.format(_bonoAmount), textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            Text('Código $_bonoCode', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w700)),
          ] else
            Text(
              'Escanea el QR del bono para validarlo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          if (_bonoError != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_bonoError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _validatingBono ? null : _scanBono,
            icon: _validatingBono
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.qr_code_scanner_rounded, size: 22),
            label: Text(scanned ? 'Escanear otro bono' : 'Escanear bono', style: const TextStyle(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              foregroundColor: _colors.primary,
              side: BorderSide(color: _colors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPanel() {
    Widget chip(String label, _Share share) {
      final on = _share == share;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _share = share),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: on ? _colors.primary : _colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: on ? Colors.white : _colors.primary))),
          ),
        ),
      );
    }

    if (_isQr) return _buildBonoPanel();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE6EBF2))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Monto con ${_method!.name}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
              GestureDetector(
                onTap: () => setState(() => _showReference = !_showReference),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9D3E0)), borderRadius: BorderRadius.circular(20)),
                  child: Text(_reference.isEmpty ? 'Referencia' : 'Ref. $_reference', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          if (_showReference)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextField(
                autofocus: true,
                maxLength: 30,
                onChanged: (v) => setState(() => _reference = v),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Número de comprobante o celular (opcional)',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            _pesos.format(_amount),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: _amount > widget.remaining ? Colors.redAccent : Colors.black),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              chip('Resto', _Share.rest),
              const SizedBox(width: 6),
              chip('½', _Share.half),
              const SizedBox(width: 6),
              chip('Otro monto', _Share.other),
            ],
          ),
          if (_share == _Share.other) ...[
            const SizedBox(height: 8),
            SizedBox(height: 220, child: NumericKeypad(accentColor: _colors.primary, extraKey: '000', onKey: _onKey, onBackspace: _onBackspace)),
          ],
        ],
      ),
    );
  }
}
