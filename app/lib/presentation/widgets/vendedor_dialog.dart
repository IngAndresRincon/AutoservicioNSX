import 'package:flutter/material.dart';
import '../../services/service.dart';
import '../../utils/color_utils.dart';

class VendedorDialog extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final VoidCallback onValidado;
  final VoidCallback onCancelar;

  const VendedorDialog({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.onValidado,
    required this.onCancelar,
  });

  @override
  State<VendedorDialog> createState() => VendedorDialogState();
}

class VendedorDialogState extends State<VendedorDialog> {
  final _docController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool get _formValido =>
      _docController.text.trim().isNotEmpty &&
      _passController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _docController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _validar() async {
    setState(() { _isLoading = true; _error = null; });

    final ok = await CustomerService().validarVendedor(
      document: _docController.text.trim(),
      password: _passController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      widget.onValidado();
    } else {
      setState(() => _error = 'Documento o contraseña incorrectos.');
      _passController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 60 : 40,
        vertical: isLandscape ? 16 : 40,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: isLandscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Izquierda — ícono + descripción
                    Expanded(
                      flex: 40,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.badge_outlined,
                                color: Colors.orange.shade600, size: 36),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Gestión de vueltos',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Esta transacción tiene vueltos pendientes. Contacta al vendedor de isla para habilitarlos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Derecha — campos + botones
                    Expanded(
                      flex: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCampos(),
                          const SizedBox(height: 16),
                          _buildBotones(),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.badge_outlined,
                          color: Colors.orange.shade600, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gestión de vueltos',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esta transacción tiene vueltos pendientes. Contacta al vendedor de isla para habilitarlos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    _buildCampos(),
                    const SizedBox(height: 16),
                    _buildBotones(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCampos() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _docController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Documento del vendedor',
            hintStyle:
                const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
            prefixIcon: const Icon(Icons.person_outline,
                size: 18, color: Color(0xFFBBBBBB)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: widget.primaryColor, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passController,
          keyboardType: TextInputType.number,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_formValido && !_isLoading) _validar();
          },
          decoration: InputDecoration(
            hintText: 'Contraseña',
            hintStyle:
                const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline,
                size: 18, color: Color(0xFFBBBBBB)),
            errorText: _error,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: widget.primaryColor, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBotones() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : widget.onCancelar,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              side: const BorderSide(color: Color(0xFFCCCCCC)),
            ),
            child: const Text('Cancelar',
                style: TextStyle(
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: _formValido && !_isLoading
                  ? LinearGradient(
                      colors: [widget.accentColor, widget.secondaryColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
              color: _formValido && !_isLoading
                  ? null
                  : const Color(0xFFEEEEEE),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: _formValido && !_isLoading ? _validar : null,
                child: Center(
                  child: _isLoading
                      ? SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: textColorForBackground(const Color(0xFFEEEEEE))),
                        )
                      : Text('Validar',
                          style: TextStyle(
                              color: (_formValido && !_isLoading)
                                  ? textColorForGradient(widget.accentColor, widget.secondaryColor)
                                  : textColorForBackground(const Color(0xFFEEEEEE)),
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}