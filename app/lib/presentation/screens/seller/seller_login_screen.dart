import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gnesys_as/presentation/widgets/numeric_keypad.dart';
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/services/pump_service.dart';
import 'package:gnesys_as/services/seller_service.dart';
import 'package:gnesys_as/services/storage_service.dart';

/// Inicio de sesion del vendedor de paso: documento y clave numericos.
class SellerLoginScreen extends StatefulWidget {
  const SellerLoginScreen({super.key});

  @override
  State<SellerLoginScreen> createState() => _SellerLoginScreenState();
}

class _SellerLoginScreenState extends State<SellerLoginScreen> {
  static const int _maxDocument = 15;
  static const int _maxPassword = 12;

  AppColors _colors = const AppColors();
  String _document = '';
  String _password = '';
  bool _editingPassword = false;
  bool _loading = false;
  String? _error;

  bool get _canSubmit => _document.length >= 5 && _password.isNotEmpty;

  @override
  void initState() {
    super.initState();
    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
  }

  void _onKey(String key) {
    setState(() {
      _error = null;
      if (_editingPassword) {
        if (_password.length < _maxPassword) _password += key;
      } else if (_document.length < _maxDocument) {
        _document += key;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _error = null;
      if (_editingPassword) {
        if (_password.isNotEmpty) _password = _password.substring(0, _password.length - 1);
      } else if (_document.isNotEmpty) {
        _document = _document.substring(0, _document.length - 1);
      }
    });
  }

  Future<void> _offerOpenShift() async {
    final open = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Turno', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('No tiene un turno abierto. ¿Desea abrirlo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir turno')),
        ],
      ),
    );
    if (open != true || !mounted) return;

    try {
      final screenId = await StorageService.getScreenNumber() ?? 1;
      final mapping = await PumpService.getMappingWithFallback(screenId);
      final position = mapping?.productHoses.where((hose) => hose.hybrid && hose.activePosition).firstOrNull;
      if (position == null) throw SellerException('Este equipo no tiene posición híbrida');

      await SellerService.openShift(positionId: position.positionId, password: _password);
      if (mounted) {
        showSellerNotice(context, 'Turno abierto');
      }
    } on SellerException catch (e) {
      if (mounted) {
        showSellerNotice(context, e.message, error: true);
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SellerService.login(_document, _password);
      if (!mounted) return;
      // Sin turno abierto se pregunta si abrirlo: la clave que acaba de digitar es la misma, no se pide otra vez
      if (SellerService.shiftId.value == null) await _offerOpenShift();
      if (!mounted) return;
      context.go('/seller/menu');
    } on SellerException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _password = '';
        _editingPassword = e.statusCode == 401 ? true : _editingPassword;
        _loading = false;
      });
    }
  }

  Widget _buildForm({double gap = 14}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ingreso de vendedor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Escriba su documento y su clave.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        SizedBox(height: gap),
        ValueBox(
          label: 'Documento',
          value: _document,
          color: _colors.primary,
          active: !_editingPassword,
          onTap: () => setState(() => _editingPassword = false),
        ),
        SizedBox(height: gap * 0.7),
        ValueBox(
          label: 'Clave',
          value: _password,
          masked: true,
          color: _colors.primary,
          active: _editingPassword,
          onTap: () => setState(() => _editingPassword = true),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
        ],
        SizedBox(height: gap),
        GradientButton(
          label: 'Ingresar',
          colors: _colors,
          loading: _loading,
          onTap: _canSubmit ? _submit : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SellerScaffold(
      colors: _colors,
      onBack: () => context.canPop() ? context.pop() : context.go('/'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: isLandscape
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: SingleChildScrollView(child: _buildForm())),
                  const SizedBox(width: 20),
                  Expanded(child: NumericKeypad(accentColor: _colors.primary, onKey: _onKey, onBackspace: _onBackspace)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // El formulario ocupa la parte alta y queda centrado; el teclado, la baja: sin huecos entre ambos
                  Expanded(
                    flex: 42,
                    child: LayoutBuilder(
                      builder: (context, box) => Center(
                        child: SingleChildScrollView(child: _buildForm(gap: (box.maxHeight * 0.07).clamp(14.0, 36.0))),
                      ),
                    ),
                  ),
                  Expanded(flex: 58, child: NumericKeypad(accentColor: _colors.primary, onKey: _onKey, onBackspace: _onBackspace)),
                ],
              ),
      ),
    );
  }
}
