import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gnesys_as/data/models/models.dart';
import 'package:gnesys_as/presentation/widgets/numeric_keypad.dart';
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:gnesys_as/utils/responsive.dart';

/// Credito, paso 1: identificar al cliente (iButton que lee el surtidor, codigo y clave, o placa).
/// Primero se elige como; la lectura del iButton solo arranca al elegirlo.
/// Luego sigue producto y valor en la pantalla de venta.
class SellerCreditScreen extends StatefulWidget {
  const SellerCreditScreen({super.key});

  @override
  State<SellerCreditScreen> createState() => _SellerCreditScreenState();
}

class _SellerCreditScreenState extends State<SellerCreditScreen> {
  AppColors _colors = const AppColors();
  List<IdentifierType> _types = [];
  int? _positionId;
  int? _type; // null: todavia no se eligio como identificar
  bool _loading = true;

  String _serial = '';
  String _key = '';
  final TextEditingController _codeController = TextEditingController();
  bool _reading = false;
  int _readToken = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
    _loadMapping();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMapping() async {
    final screenId = await StorageService.getScreenNumber() ?? 1;
    final mapping = await PumpService.getMappingWithFallback(screenId);
    final hybrid = mapping?.productHoses.where((hose) => hose.hybrid && hose.activePosition).firstOrNull;
    final types = mapping?.identifiers ?? <IdentifierType>[];

    if (!mounted) return;
    setState(() {
      _positionId = hybrid?.positionId;
      _types = types;
      _loading = false;
    });
    // Con un solo tipo habilitado no hay nada que elegir
    if (types.length == 1) _choose(types.first.id);
  }

  void _choose(int type) {
    _readToken++; // descarta una lectura en curso
    _codeController.clear();
    setState(() {
      _type = type;
      _serial = '';
      _key = '';
      _reading = false;
      _error = null;
    });
    if (type == IdentifierType.iButton) _read();
  }

  void _backToChooser() {
    _readToken++;
    _codeController.clear();
    setState(() {
      _type = null;
      _serial = '';
      _key = '';
      _reading = false;
      _error = null;
    });
  }

  Future<void> _read() async {
    final positionId = _positionId;
    if (positionId == null || _reading) return;

    final token = ++_readToken;
    setState(() {
      _reading = true;
      _serial = '';
      _error = null;
    });

    try {
      // La lectura se manda a una posicion libre de la cara: una que surte rechazaria la lectura
      var readPosition = positionId;
      try {
        final positions = await SellerService.getPositions(await StorageService.getScreenNumber() ?? 1);
        final free = positions.where((p) => p.isFree).toList();
        if (free.isNotEmpty && !free.any((p) => p.positionId == positionId)) readPosition = free.first.positionId;
      } on SellerException {
        // Sin la lectura de posiciones se usa la de siempre
      }
      final serial = await SellerService.readIdentifier(positionId: readPosition, type: IdentifierType.iButton);
      if (!mounted || token != _readToken) return;
      setState(() {
        _serial = serial;
        _reading = false;
      });
    } on SellerException catch (e) {
      if (!mounted || token != _readToken) return;
      setState(() {
        _error = e.message;
        _reading = false;
      });
      if (e.sessionExpired) context.go('/seller/login');
    }
  }

  // El teclado numerico es solo para la clave; el codigo del cliente lleva letras y numeros
  void _onKey(String key) {
    setState(() {
      _error = null;
      if (_key.length < 12) _key += key;
    });
  }

  void _onBackspace() {
    setState(() {
      _error = null;
      if (_key.isNotEmpty) _key = _key.substring(0, _key.length - 1);
    });
  }

  bool get _canContinue {
    if (_type == null || _reading || _serial.trim().isEmpty) return false;
    if (_type == IdentifierType.keyboard) return _key.isNotEmpty;
    if (_type == IdentifierType.plate) return _serial.trim().length >= 5;
    return true;
  }

  void _continue() {
    context.push('/seller/sale', extra: {
      'credit': SellerCredit(identifierType: _type!, serial: _serial.trim(), key: _type == IdentifierType.keyboard ? _key : null),
    });
  }

  // El identificador del chip es como una clave: solo se ven los 2 primeros y los 2 ultimos caracteres
  String _mask(String serial) {
    if (serial.length <= 4) return '•' * serial.length;
    return '${serial.substring(0, 2)}${'•' * (serial.length - 4)}${serial.substring(serial.length - 2)}';
  }

  IconData _typeIcon(int id) {
    switch (id) {
      case IdentifierType.iButton:
        return Icons.sensors_rounded;
      case IdentifierType.keyboard:
        return Icons.dialpad_rounded;
      default:
        return Icons.directions_car_outlined;
    }
  }

  String _typeHint(int id) {
    switch (id) {
      case IdentifierType.iButton:
        return 'Acerque la llave al lector del surtidor';
      case IdentifierType.keyboard:
        return 'Código y clave del cliente';
      default:
        return 'Placa del vehículo';
    }
  }

  String _typeName(IdentifierType type) {
    switch (type.id) {
      case IdentifierType.iButton:
        return 'iButton';
      case IdentifierType.keyboard:
        return 'Código y clave';
      case IdentifierType.plate:
        return 'Placa';
      default:
        return type.name;
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
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_positionId == null || _types.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Este equipo no tiene identificadores de cliente habilitados.', textAlign: TextAlign.center),
                  ),
                )
              : ScaleUp(
                  reference: const Size(420, 760),
                  child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Crédito', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      _buildSteps(),
                      const SizedBox(height: 10),
                      Expanded(child: _type == null ? _buildChooser() : _buildSelected()),
                      if (_type != null) ...[
                        const SizedBox(height: 8),
                        GradientButton(label: 'Continuar', colors: _colors, height: 50, onTap: _canContinue ? _continue : null),
                      ],
                    ],
                  ),
                  ),
                )),
    );
  }

  Widget _buildSteps() {
    Widget step(String label, bool on) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(color: on ? _colors.primary : _colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Colors.white : _colors.primary))),
          ),
        );

    return Row(children: [step('Cliente', true), const SizedBox(width: 6), step('Producto', false), const SizedBox(width: 6), step('Valor', false)]);
  }

  // Elegir como identificar al cliente: una opcion grande por tipo, con su imagen
  Widget _buildChooser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Cómo identifica al cliente?', style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        for (final type in _types)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: _colors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => _choose(type.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: _colors.primary.withOpacity(0.25))),
                    child: Row(
                      children: [
                        PaymentLogo(name: type.name, size: 58, color: _colors.primary, fallback: _typeIcon(type.id)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_typeName(type), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _colors.primary)),
                              Text(_typeHint(type.id), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: _colors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelected() {
    final type = _types.firstWhere((t) => t.id == _type, orElse: () => IdentifierType(id: _type!, name: ''));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PaymentLogo(name: type.name, size: 30, color: _colors.primary, fallback: _typeIcon(type.id)),
            const SizedBox(width: 8),
            Expanded(child: Text(_typeName(type), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            if (_types.length > 1) TextButton(onPressed: _reading ? null : _backToChooser, child: const Text('Cambiar')),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _type == IdentifierType.keyboard ? _buildKeyboard() : (_type == IdentifierType.plate ? _buildPlate() : _buildIButton()),
        ),
      ],
    );
  }

  Widget _buildIButton() {
    final read = _serial.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE6EBF2))),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_reading) SizedBox(width: 78, height: 78, child: CircularProgressIndicator(strokeWidth: 4, color: _colors.primary)),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _colors.primary.withOpacity(0.1)),
                    child: Icon(read ? Icons.check_rounded : Icons.sensors_rounded, color: read ? Colors.green.shade600 : _colors.primary, size: 32),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                read ? 'iButton leído' : (_reading ? 'Acerque el iButton al surtidor…' : 'No se ha leído el iButton'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
            ],
          ),
        ),
        if (read) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6EBF2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Identificador del cliente', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                FittedBox(fit: BoxFit.scaleDown, child: Text(_mask(_serial), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _reading ? null : _read,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            side: BorderSide(color: _reading ? Colors.grey.shade300 : const Color(0xFFC9D3E0)),
          ),
          child: const Text('Volver a leer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildKeyboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 20,
          onChanged: (value) => setState(() {
            _serial = value.trim().toUpperCase();
            _error = null;
          }),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1),
          decoration: InputDecoration(
            labelText: 'Código del cliente',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 8),
        ValueBox(label: 'Clave (solo números)', value: _key, masked: true, color: _colors.primary, active: true, onTap: () {}),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
        const SizedBox(height: 8),
        Expanded(child: NumericKeypad(accentColor: _colors.primary, onKey: _onKey, onBackspace: _onBackspace)),
      ],
    );
  }

  Widget _buildPlate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Escriba la placa del vehículo', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 7,
          onChanged: (value) => setState(() => _serial = value.trim().toUpperCase()),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 2),
          decoration: InputDecoration(
            labelText: 'Placa',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}
