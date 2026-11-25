import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gnesys_as/data/models/mappingmodel.dart';
import 'package:gnesys_as/data/models/seller_models.dart';
import 'package:gnesys_as/presentation/widgets/numeric_keypad.dart';
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/services/pump_service.dart';
import 'package:gnesys_as/services/seller_service.dart';
import 'package:gnesys_as/services/storage_service.dart';
import 'package:gnesys_as/utils/color_utils.dart';
import 'package:gnesys_as/utils/responsive.dart';

/// Venta del vendedor en una sola pantalla: producto, tipo (dinero, volumen, lleno), valor y programar.
/// Con [credit] (cliente ya identificado) la misma pantalla autoriza la venta a cuenta del cliente.
class SellerSaleScreen extends StatefulWidget {
  final SellerCredit? credit;

  const SellerSaleScreen({super.key, this.credit});

  @override
  State<SellerSaleScreen> createState() => _SellerSaleScreenState();
}

class _SellerSaleScreenState extends State<SellerSaleScreen> {
  static const int _full = 1;
  static const int _money = 2;
  static const int _volume = 3;

  AppColors _colors = const AppColors();
  MappingModel? _mapping;
  List<ProductHose> _hoses = [];
  ProductHose? _hose;
  int _type = SellerService.lastType;
  String _input = '';
  String? _plate;
  int? _km;
  bool _loading = true;
  bool _submitting = false;
  Set<int> _busyPositions = {};
  Timer? _busyTimer;
  final ScrollController _landscapeScroll = ScrollController();
  int _screenId = 1;

  @override
  void initState() {
    super.initState();
    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
    _loadMapping();
    _busyTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshBusy(),
    );
  }

  @override
  void dispose() {
    _busyTimer?.cancel();
    _landscapeScroll.dispose();
    super.dispose();
  }

  bool _isBusy(ProductHose hose) => _busyPositions.contains(hose.positionId);

  // Una posicion que ya surte (o tiene preset) no admite otra programacion: sus mangueras quedan bloqueadas
  Future<void> _refreshBusy() async {
    try {
      final positions = await SellerService.getPositions(_screenId);
      final busy = positions
          .where((p) => !p.isFree)
          .map((p) => p.positionId)
          .toSet();
      if (!mounted) return;
      setState(() {
        _busyPositions = busy;
        final current = _hose;
        if (current == null || _isBusy(current)) {
          _hose = _hoses.where((h) => !_isBusy(h)).firstOrNull ?? current;
        }
      });
    } on SellerException {
      // Sin la lectura no se bloquea: el servidor rechaza si la posicion esta ocupada
    }
  }

  Future<void> _loadMapping() async {
    final screenId = await StorageService.getScreenNumber() ?? 1;
    _screenId = screenId;
    final mapping = await PumpService.getMappingWithFallback(screenId);
    final hoses =
        (mapping?.productHoses ?? const <ProductHose>[])
            .where(
              (hose) => hose.hybrid && hose.activeHose && hose.activePosition,
            )
            .toList()
          ..sort((a, b) => _sideOrder(a.side).compareTo(_sideOrder(b.side)));

    if (!mounted) return;
    setState(() {
      _mapping = mapping;
      _hoses = hoses;
      _hose =
          hoses
              .where((h) => h.hoseId == SellerService.lastHoseId)
              .firstOrNull ??
          hoses.firstOrNull;
      _loading = false;
    });
    _refreshBusy();
  }

  static int _sideOrder(String side) =>
      const {'I': 0, 'M': 1, 'D': 2}[side.toUpperCase()] ?? 99;

  static String _sideLabel(String side) =>
      const {'I': 'IZQ', 'M': 'MED', 'D': 'DER'}[side.toUpperCase()] ??
      side.toUpperCase();

  // --- Valores y limites ---

  // El vendedor no tiene tope por transaccion: solo lo que acepta el surtidor, segun los digitos de la posicion
  // (el mapeo trae el maximo en dinero); sin ese dato se deja el largo del numero
  static const double _fallbackMaxMoney = 99999999;
  static const double _fallbackMaxVolume = 9999;

  double get _maxMoney => (_hose?.maxMoney != null && _hose!.maxMoney! > 0)
      ? _hose!.maxMoney!
      : _fallbackMaxMoney;

  // Igual que NSX: el volumen maximo es el dinero maximo entre el precio del galon
  double get _maxVolume => (_hose?.maxMoney != null && _price > 0)
      ? (_maxMoney / _price * 100).floorToDouble() / 100
      : _fallbackMaxVolume;

  double get _price => double.tryParse(_hose?.sellerPrice ?? '') ?? 0;
  bool get _isCredit => widget.credit != null;
  double get _value => double.tryParse(_input) ?? 0;

  // NSX exige un valor mayor al 10% del precio de un galon (dinero) o de 0,1 galon (volumen)
  double get _minMoney => (_price * 0.1).floorToDouble() + 1;
  double get _minVolume => 0.11;
  double get _min => _type == _money ? _minMoney : _minVolume;

  bool _belowMin(double value) => _type != _full && value > 0 && value < _min;

  bool get _valid {
    if (_hose == null || _isBusy(_hose!)) return false;
    if (_type == _full) return true;
    return _value >= _min &&
        _value <= (_type == _money ? _maxMoney : _maxVolume);
  }

  String _money$(double value) {
    final digits = value.toStringAsFixed(0);
    final buffer = StringBuffer('\$ ');
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _gallons(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} gal';

  String get _display {
    if (_type == _full) return 'LLENO';
    if (_input.isEmpty) return _type == _money ? '\$ 0' : '0 gal';
    return _type == _money
        ? _money$(_value)
        : '${_input.replaceAll('.', ',')} gal';
  }

  String get _approx {
    // En credito no se muestra el precio: tampoco lo que se deduce de el
    if (_isCredit || _type == _full || _value <= 0 || _price <= 0) return '';
    return _type == _money
        ? '≈ ${_gallons(_value / _price)}'
        : '≈ ${_money$(_value * _price)}';
  }

  // --- Teclado ---

  void _onKey(String key) {
    if (_type == _full) return;

    String next = _input;
    if (key == '.') {
      if (_type != _volume || next.contains('.')) return;
      next = next.isEmpty ? '0.' : '$next.';
    } else if (key == '000') {
      if (_type != _money || next.isEmpty) return;
      next = '${next}000';
    } else {
      if (next == '0') next = '';
      next = '$next$key';
    }

    final decimals = next.contains('.') ? next.split('.')[1].length : 0;
    final number = double.tryParse(next.endsWith('.') ? '${next}0' : next) ?? 0;
    final max = _type == _money ? _maxMoney : _maxVolume;
    if (decimals > 2 || number > max || next.length > 9) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _input = next);
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _setType(int type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _input = '';
    });
  }

  void _setQuick(double value) {
    if (value < _min || value > (_type == _money ? _maxMoney : _maxVolume)) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(
      () => _input = value == value.truncateToDouble()
          ? value.toStringAsFixed(0)
          : value.toString(),
    );
  }

  void _applyRecent(SellerRecent recent) {
    final hose = _hoses
        .where((h) => h.hoseNumber == recent.hoseNumber)
        .firstOrNull;
    if (hose == null) return;
    setState(() {
      _hose = hose;
      _type = recent.type;
      _input = recent.type == _full
          ? ''
          : (recent.value == recent.value.truncateToDouble()
                ? recent.value.toStringAsFixed(0)
                : recent.value.toString());
    });
  }

  // --- Programar ---

  Future<void> _submit() async {
    final hose = _hose;
    if (hose == null || !_valid || _submitting) return;

    setState(() => _submitting = true);
    try {
      final value = _type == _full ? 0.0 : _value;
      final credit = widget.credit;
      final SellerPreset preset;

      if (credit != null) {
        // Credito: se autoriza al cliente; el valor y el producto se ofrecen igual que en la venta
        preset = await SellerService.authorizeCredit(
          positionId: hose.positionId,
          hoseNumber: hose.hoseNumber,
          programmingType: _type,
          value: value,
          credit: credit,
          km: _km,
        );
      } else {
        preset = await SellerService.createPreset(
          positionId: hose.positionId,
          hoseNumber: hose.hoseNumber,
          programmingType: _type,
          value: value,
          plate: _plate,
          km: _km,
        );

        SellerService.lastHoseNumber = hose.hoseNumber;
        SellerService.lastHoseId = hose.hoseId;
        SellerService.lastType = _type;
        SellerService.addRecent(
          SellerRecent(
            hoseNumber: hose.hoseNumber,
            product: hose.product,
            type: _type,
            value: value,
          ),
        );
      }

      if (!mounted) return;
      context.go(
        '/seller/dispensing',
        extra: {
          'isCredit': credit != null,
          'presetId': preset.id,
          'positionId': hose.positionId,
          'nsxPositionId': hose.nsxPositionId,
          'product': hose.product,
          'hoseColor': hose.color,
          'programmingType': _type,
          'programmedValue': value,
          'programmed': _type == _full
              ? 'LLENO'
              : (_type == _money ? _money$(value) : _gallons(value)),
        },
      );
    } on SellerException catch (e) {
      if (!mounted) return;
      showSellerNotice(context, e.message, error: true);
      if (e.sessionExpired) context.go('/seller/login');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // --- Interfaz ---

  @override
  Widget build(BuildContext context) {
    final session = SellerService.session;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/seller/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SellerScaffold(
      colors: _colors,
      onBack: () =>
          context.canPop() ? context.pop() : context.go('/seller/menu'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_hoses.isEmpty
                ? const Center(
                    child: Text(
                      'Este equipo no tiene mangueras para el vendedor.',
                    ),
                  )
                // Todo se dibuja con un tamano de referencia y se amplia parejo a la pantalla (textos, tarjetas y teclado)
                : ScaleUp(
                    reference: isLandscape ? const Size(860, 480) : const Size(420, 760),
                    fitControllers: isLandscape ? [_landscapeScroll] : const [],
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: isLandscape
                          ? _buildLandscape(session)
                          : _buildPortrait(session),
                    ),
                  )),
    );
  }

  Widget _buildPortrait(SellerSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSellerLine(session),
        ..._buildRecents(),
        _buildHoses(),
        const SizedBox(height: 8),
        _buildTypeSwitch(),
        const SizedBox(height: 8),
        _buildValueCard(),
        const SizedBox(height: 8),
        _buildQuickValues(),
        const SizedBox(height: 8),
        Expanded(child: _buildKeypad()),
        const SizedBox(height: 6),
        _buildPlateButton(),
        const SizedBox(height: 8),
        _buildSubmit(),
      ],
    );
  }

  Widget _buildLandscape(SellerSession session) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            controller: _landscapeScroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSellerLine(session),
                ..._buildRecents(),
                _buildHoses(),
                const SizedBox(height: 8),
                _buildTypeSwitch(),
                const SizedBox(height: 8),
                _buildValueCard(),
                const SizedBox(height: 8),
                _buildQuickValues(),
                const SizedBox(height: 6),
                _buildPlateButton(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildKeypad()),
              const SizedBox(height: 8),
              _buildSubmit(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSellerLine(SellerSession session) {
    final credit = widget.credit;

    // El vendedor y su turno van en la primera linea; el credito, debajo y a lo ancho
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: _colors.primary, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  session.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<int?>(
                valueListenable: SellerService.shiftId,
                builder: (_, shiftId, __) => shiftId == null
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _colors.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Turno $shiftId',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: textColorForBackground(_colors.accent),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          if (credit != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2A33A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'CRÉDITO · ${credit.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildRecents() {
    final recents = SellerService.recents;
    if (recents.isEmpty || widget.credit != null) return [];

    return [
      const Text(
        'RECIENTES DE ESTE TURNO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          for (final recent in recents)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: _colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _applyRecent(recent),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 4,
                      ),
                      child: Column(
                        children: [
                          Text(
                            recent.product,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _colors.primary,
                            ),
                          ),
                          Text(
                            recent.type == _full
                                ? 'LLENO'
                                : (recent.type == _money
                                      ? _money$(recent.value)
                                      : _gallons(recent.value)),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
    ];
  }

  Color _hoseColor(ProductHose hose) {
    try {
      return Color(
        int.parse(hose.color.replaceAll('#', '').padLeft(8, 'F'), radix: 16),
      );
    } catch (_) {
      return _colors.primary;
    }
  }

  Widget _buildHoses() {
    return Row(
      children: [
        for (int i = 0; i < _hoses.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < _hoses.length - 1 ? 6 : 0),
              child: _HoseCard(
                hose: _hoses[i],
                color: _hoseColor(_hoses[i]),
                sideLabel: _sideLabel(_hoses[i].side),
                price: _isCredit ? '' : _money$(double.tryParse(_hoses[i].sellerPrice) ?? 0),
                selected: _hoses[i].hoseId == _hose?.hoseId,
                disabled: _isBusy(_hoses[i]),
                accent: _colors.primary,
                onTap: _isBusy(_hoses[i])
                    ? null
                    : () => setState(() {
                        _hose = _hoses[i];
                        _input = '';
                      }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeSwitch() {
    Widget item(String label, int type) {
      final on = _type == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setType(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? _colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: on
                      ? textColorForBackground(_colors.primary)
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _colors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          item('Dinero', _money),
          item('Volumen', _volume),
          item('Lleno', _full),
        ],
      ),
    );
  }

  Widget _buildValueCard() {
    final min = _type == _money ? _money$(_minMoney) : _gallons(_minVolume);
    final low = _belowMin(_value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: low ? Colors.orange.shade700 : _colors.primary,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                _display,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_approx.isNotEmpty)
                Text(
                  _approx,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_type != _full && _hose?.maxMoney != null)
                Text(
                  'Máx ${_type == _money ? _money$(_maxMoney) : _gallons(_maxVolume)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              if (_type != _full)
                Text(
                  'Mín $min',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: low ? FontWeight.w800 : FontWeight.w400,
                    color: low ? Colors.orange.shade800 : Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickValues() {
    if (_type == _full) return const SizedBox.shrink();

    final values = _type == _money
        ? (_mapping?.speedDial.map((s) => s.moneyValue).toList() ?? <double>[])
        : (_mapping?.speedDial.map((s) => s.volumeValue).toList() ??
              <double>[]);

    final shown = values.where((v) => v > 0).take(4).toList();

    return Row(
      children: [
        for (int i = 0; i < shown.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < shown.length - 1 ? 6 : 0),
              child: GestureDetector(
                onTap: () => _setQuick(shown[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _value == shown[i]
                        ? const Color(0xFF14213A)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _value == shown[i]
                          ? const Color(0xFF14213A)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _type == _money
                            ? _money$(shown[i])
                            : _gallons(shown[i]),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: shown[i] < _min
                              ? Colors.grey.shade400
                              : (_value == shown[i]
                                    ? Colors.white
                                    : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKeypad() {
    if (_type == _full) return _buildFullPanel();

    return NumericKeypad(
      accentColor: _colors.primary,
      extraKey: _type == _money ? '000' : '.',
      onKey: _onKey,
      onBackspace: _onBackspace,
    );
  }

  // "Lleno": sin valor que digitar; se muestra el producto con su color y lo que va a pasar
  Widget _buildFullPanel() {
    final hose = _hose;
    if (hose == null) return const SizedBox.shrink();
    final deep = _deepColor(_hoseColor(hose));

    Widget info(IconData icon, String text) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        // Con la franja de recientes el alto baja: se compacta para que no desborde
        final compact = box.maxHeight < 400;
        final tiny = box.maxHeight < 320;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.all(compact ? 10 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [deep, Color.lerp(deep, Colors.black, 0.22)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: deep.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Imagen del servidor (tanque_lleno.png); si no esta, el icono del surtidor
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: PaymentLogo(
                    name: 'tanque_lleno',
                    size: tiny ? 64 : (compact ? 88 : 116),
                    color: deep,
                    fallback: Icons.local_gas_station_rounded,
                  ),
                ),
              ),
              SizedBox(height: compact ? 8 : 14),
              Text(
                'LLENAR EL TANQUE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 19 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hose.product,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!_isCredit) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_money$(_price)} por galón',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              SizedBox(height: compact ? 10 : 18),
              Row(
                children: [
                  info(
                    Icons.stop_circle_outlined,
                    'El surtidor se detiene solo al llenar',
                  ),
                  const SizedBox(width: 8),
                  info(
                    Icons.speed_rounded,
                    hose.maxMoney != null
                        ? 'Hasta ${_money$(_maxMoney)} (≈ ${_gallons(_maxVolume)})'
                        : 'Sin valor que digitar',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlateButton() {
    final isCredit =
        widget.credit !=
        null; // en credito la placa es la de la cuenta: solo kilometraje
    final has = isCredit
        ? _km != null
        : ((_plate != null && _plate!.isNotEmpty) || _km != null);

    return GestureDetector(
      onTap: () async {
        final result = await showPlateKmSheet(
          context,
          _colors,
          plate: _plate,
          km: _km,
          showPlate: !isCredit,
        );
        if (result != null && mounted) {
          setState(() {
            _plate = result.$1;
            _km = result.$2;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: has ? _colors.primary : const Color(0xFFC9D3E0),
            style: has ? BorderStyle.solid : BorderStyle.solid,
          ),
          color: has ? _colors.primary.withOpacity(0.08) : Colors.transparent,
        ),
        child: Center(
          child: Text(
            isCredit
                ? (has ? 'Km $_km' : '+ Kilometraje (opcional)')
                : (has
                      ? 'Placa ${_plate ?? '-'} · Km ${_km ?? '-'}'
                      : '+ Placa y kilometraje (opcional)'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: has ? FontWeight.w700 : FontWeight.w500,
              color: has ? _colors.primary : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmit() {
    final action = widget.credit != null ? 'AUTORIZAR' : 'PROGRAMAR';
    final label = _type == _full
        ? '$action · LLENO'
        : (_valid
              ? '$action · ${_type == _money ? _money$(_value) : _gallons(_value)}'
              : action);
    return GradientButton(
      label: label,
      colors: _colors,
      height: 50,
      loading: _submitting,
      onTap: _valid ? _submit : null,
    );
  }
}

// Version profunda del color del producto (como las tarjetas del autoservicio)
Color _deepColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness * 0.7).clamp(0.1, 1.0)).toColor();
}

class _HoseCard extends StatelessWidget {
  final ProductHose hose;
  final Color color;
  final String sideLabel;
  final String price;
  final bool selected;
  final bool disabled;
  final Color accent;
  final VoidCallback? onTap;

  const _HoseCard({
    required this.hose,
    required this.color,
    required this.sideLabel,
    required this.price,
    required this.selected,
    this.disabled = false,
    required this.accent,
    required this.onTap,
  });

  // Igual que las tarjetas del autoservicio: version profunda del color del producto, no el tono pastel
  Color get _deep => _deepColor(color);

  @override
  Widget build(BuildContext context) {
    final deep = _deep;

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 3,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [deep, Color.lerp(deep, Colors.black, 0.18)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: deep.withOpacity(selected ? 0.45 : 0.2),
                  blurRadius: selected ? 10 : 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.24),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sideLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hose.product,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (price.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    price,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
