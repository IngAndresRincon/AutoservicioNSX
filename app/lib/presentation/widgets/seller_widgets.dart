import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gnesys_as/presentation/widgets/clock_widget.dart';
import 'package:gnesys_as/presentation/widgets/numeric_keypad.dart';
import 'package:gnesys_as/services/resource_service.dart';
import 'package:gnesys_as/services/seller_service.dart';
import 'package:gnesys_as/services/storage_service.dart';
import 'package:gnesys_as/presentation/widgets/app_notice.dart';
import 'package:gnesys_as/utils/color_utils.dart';

/// Colores y logo de la estacion (los tres del mapeo), como los usan las demas pantallas.
class AppColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final String? logoUrl;

  const AppColors({
    this.primary = const Color(0xFF1E88E5),
    this.secondary = const Color(0xFF2F80ED),
    this.accent = const Color(0xFF56CCF2),
    this.logoUrl,
  });

  static Future<AppColors> load() async {
    return AppColors(
      primary: await StorageService.getPrimaryColor(),
      secondary: await StorageService.getSecondaryColor(),
      accent: await StorageService.getAccentColor(),
      logoUrl: await StorageService.getLogoUrl(),
    );
  }
}

Color textColorForGradientOf(AppColors colors) => textColorForGradient(colors.accent, colors.secondary);

/// Fondo con el color principal, encabezado con logo y hoja blanca redondeada.
class SellerScaffold extends StatelessWidget {
  final AppColors colors;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;

  const SellerScaffold({
    super.key,
    required this.colors,
    required this.child,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final height = MediaQuery.of(context).size.height;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SellerService.touch(),
      child: Scaffold(
      backgroundColor: colors.primary,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              // Franja compacta: deja mas espacio al contenido
              height: (height * (isLandscape ? 0.11 : 0.085)).clamp(58.0, 96.0),
              child: _buildHeader(),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildHeader() {
    final logo = colors.logoUrl != null
        ? Image.network(
            colors.logoUrl!,
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset('assets/images/logo_insepet_blanco.png', height: 36),
          )
        : Image.asset('assets/images/logo_insepet_blanco.png', height: 36, fit: BoxFit.contain);

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Positioned(
              left: 16,
              child: Material(
                color: Colors.white.withOpacity(0.15),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.all(9.0),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          logo,
          Positioned(right: 16, child: trailing ?? const ClockWidget(fontSize: 14)),
        ],
      ),
    );
  }
}

/// Imagen de una forma de pago desde el servidor (`<nombre en minusculas>.png`, igual que las del autoservicio);
/// si no esta, un icono generico.
class PaymentLogo extends StatefulWidget {
  final String name;
  final double size;
  final Color color;
  final IconData fallback;

  const PaymentLogo({super.key, required this.name, required this.size, required this.color, required this.fallback});

  @override
  State<PaymentLogo> createState() => _PaymentLogoState();
}

class _PaymentLogoState extends State<PaymentLogo> {
  String? _url;

  @override
  void initState() {
    super.initState();
    // Los espacios del nombre van como guion bajo: "Bonos Sodexo" -> bonos_sodexo.png
    ResourceService.getImageUrl('${widget.name.trim().toLowerCase().replaceAll(' ', '_')}.png').then((url) {
      if (mounted) setState(() => _url = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.fallback, color: widget.color, size: widget.size);
    final url = _url;
    if (url == null) return SizedBox(width: widget.size, height: widget.size, child: icon);

    return Image.network(
      url,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) => progress == null ? child : SizedBox(width: widget.size, height: widget.size, child: icon),
      errorBuilder: (_, __, ___) => SizedBox(width: widget.size, height: widget.size, child: icon),
    );
  }
}

/// Boton con degradado acento-secundario y texto que se adapta al color.
class GradientButton extends StatelessWidget {
  final String label;
  final AppColors colors;
  final VoidCallback? onTap;
  final bool loading;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    required this.colors,
    required this.onTap,
    this.loading = false,
    this.height = 45,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final textColor = enabled
        ? textColorForGradient(colors.accent, colors.secondary)
        : textColorForBackground(Colors.grey.shade300);

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: enabled
            ? LinearGradient(
                colors: [colors.accent, colors.secondary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: enabled ? null : Colors.grey.shade300,
        boxShadow: enabled
            ? [BoxShadow(color: colors.secondary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: enabled ? onTap : null,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: textColorForGradient(colors.accent, colors.secondary)),
                  )
                : Text(label, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

/// Casilla de un valor numerico (documento, clave) que se selecciona al tocarla.
class ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final bool masked;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const ValueBox({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.masked = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final shown = masked ? '•' * value.length : value;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: active ? color : Colors.grey.shade300, width: active ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? color : Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(
              shown.isEmpty ? ' ' : shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: 2, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide la clave numerica del vendedor (abrir o cerrar turno). Devuelve null si se cancela.
Future<String?> showSellerPasswordDialog(BuildContext context, AppColors colors, {required String title}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordDialog(colors: colors, title: title),
  );
}

class _PasswordDialog extends StatefulWidget {
  final AppColors colors;
  final String title;
  const _PasswordDialog({required this.colors, required this.title});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  String _value = '';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape = size.width > size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.symmetric(horizontal: landscape ? 120 : 24, vertical: landscape ? 12 : 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: size.height * (landscape ? 0.92 : 0.7)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ValueBox(label: 'Clave', value: _value, masked: true, active: true, color: widget.colors.primary, onTap: () {}),
              const SizedBox(height: 10),
              Expanded(
                child: NumericKeypad(
                  accentColor: widget.colors.primary,
                  onKey: (key) => setState(() {
                    if (_value.length < 12) _value += key;
                  }),
                  onBackspace: () => setState(() {
                    if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GradientButton(
                      label: 'Confirmar',
                      colors: widget.colors,
                      height: 44,
                      onTap: _value.isEmpty ? null : () => Navigator.pop(context, _value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placa y kilometraje opcionales del vehiculo. Devuelve (placa, km) o null si se cancela.
/// [showPlate] false: solo kilometraje (en credito la placa es la de la cuenta)
Future<(String?, int?)?> showPlateKmSheet(BuildContext context, AppColors colors, {String? plate, int? km, bool showPlate = true}) {
  return showModalBottomSheet<(String?, int?)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _PlateKmSheet(colors: colors, plate: plate, km: km, showPlate: showPlate),
  );
}

class _PlateKmSheet extends StatefulWidget {
  final AppColors colors;
  final String? plate;
  final int? km;
  final bool showPlate;
  const _PlateKmSheet({required this.colors, this.plate, this.km, this.showPlate = true});

  @override
  State<_PlateKmSheet> createState() => _PlateKmSheetState();
}

class _PlateKmSheetState extends State<_PlateKmSheet> {
  late final TextEditingController _plate = TextEditingController(text: widget.plate ?? '');
  late final TextEditingController _km = TextEditingController(text: widget.km?.toString() ?? '');

  @override
  void dispose() {
    _plate.dispose();
    _km.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.showPlate ? 'Placa y kilometraje' : 'Kilometraje', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          if (widget.showPlate) ...[
            TextField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Placa', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
          ],
          TextField(
            controller: _km,
            keyboardType: TextInputType.number,
            maxLength: 7,
            decoration: const InputDecoration(labelText: 'Kilometraje', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          GradientButton(
            label: 'Guardar',
            colors: widget.colors,
            onTap: () => Navigator.pop(
              context,
              (_plate.text.trim().isEmpty ? null : _plate.text.trim().toUpperCase(), int.tryParse(_km.text.trim())),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso grande arriba de la pantalla (ver [showAppNotice]): rojo en error, verde si salio bien.
void showSellerNotice(BuildContext context, String message, {bool error = false}) =>
    showAppNotice(context, message, kind: error ? NoticeKind.error : NoticeKind.success);
