import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gnesys_as/presentation/widgets/seller_widgets.dart';
import 'package:gnesys_as/services/customer_service.dart';
import 'package:gnesys_as/services/pump_service.dart';
import 'package:gnesys_as/services/seller_service.dart';
import 'package:gnesys_as/services/storage_service.dart';
import 'package:gnesys_as/utils/color_utils.dart';
import 'package:gnesys_as/utils/responsive.dart';

/// Otras opciones del vendedor: recibo, turno y sesion.
class SellerOptionsScreen extends StatefulWidget {
  const SellerOptionsScreen({super.key});

  @override
  State<SellerOptionsScreen> createState() => _SellerOptionsScreenState();
}

class _SellerOptionsScreenState extends State<SellerOptionsScreen> {
  AppColors _colors = const AppColors();
  int? _positionId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppColors.load().then((colors) {
      if (mounted) setState(() => _colors = colors);
    });
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final screenId = await StorageService.getScreenNumber() ?? 1;
    final mapping = await PumpService.getMappingWithFallback(screenId);
    final hybrid = mapping?.productHoses.where((hose) => hose.hybrid);
    if (mounted && hybrid != null && hybrid.isNotEmpty) {
      setState(() => _positionId = hybrid.first.positionId);
    }
  }

  void _snack(String message, {bool error = false}) {
    showSellerNotice(context, message, error: error);
  }

  // Imprime el recibo de la ultima venta del turno
  Future<void> _printLast() async {
    setState(() => _busy = true);
    try {
      final sales = await SellerService.getShiftSales();
      if (!mounted) return;
      if (sales.isEmpty) {
        _snack('Aún no hay ventas en este turno', error: true);
        return;
      }
      final ok = await CustomerService().imprimirRecibo(saleId: sales.first.saleId);
      if (mounted) _snack(ok ? 'Recibo de la venta ${sales.first.saleId} enviado a imprimir' : 'No fue posible imprimir el recibo', error: !ok);
    } on SellerException catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true);
      if (e.sessionExpired) context.go('/seller/login');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shift({required bool open}) async {
    final positionId = _positionId;
    if (positionId == null) return;

    final password = await showSellerPasswordDialog(
      context,
      _colors,
      title: open ? 'Clave para abrir turno' : 'Clave para cerrar turno',
    );
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      if (open) {
        await SellerService.openShift(positionId: positionId, password: password);
      } else {
        await SellerService.closeShift(positionId: positionId, password: password);
      }
      if (mounted) _snack(open ? 'Turno abierto' : 'Turno cerrado');
    } on SellerException catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true);
      if (e.sessionExpired) context.go('/seller/login');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

    return SellerScaffold(
      colors: _colors,
      onBack: () => context.canPop() ? context.pop() : context.go('/seller/menu'),
      child: ScaleUp(
        reference: const Size(420, 760),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ValueListenableBuilder<int?>(
              valueListenable: SellerService.shiftId,
              builder: (_, shiftId, __) {
                final open = shiftId != null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(session.name, shiftId),
                    _section('VENTAS'),
                    Expanded(child: Row(
                      children: [
                        Expanded(
                          child: _OptionTile(
                            label: 'Recibo',
                            imageName: 'recibo',
                            subtitle: 'Imprimir la última venta',
                            icon: Icons.print_outlined,
                            tone: const Color(0xFF3CB878),
                            onTap: _busy ? null : _printLast,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OptionTile(
                            label: 'Ventas del turno',
                            imageName: 'ventas_del_turno',
                            subtitle: 'Pago, factura y recibo de cada venta',
                            icon: Icons.receipt_long_outlined,
                            tone: _colors.primary,
                            onTap: _busy ? null : () => context.push('/seller/sales'),
                          ),
                        ),
                      ],
                    )),
                    _section('TURNO Y SESIÓN'),
                    Expanded(child: Row(
                      children: [
                        Expanded(
                          child: _OptionTile(
                            label: open ? 'Cerrar turno' : 'Abrir turno',
                            imageName: open ? 'cerrar_turno' : 'abrir_turno',
                            subtitle: open ? 'Turno $shiftId' : 'Necesario para vender',
                            icon: open ? Icons.lock_outline : Icons.lock_open_outlined,
                            tone: open ? const Color(0xFFF2A33A) : const Color(0xFF3CB878),
                            onTap: (_busy || _positionId == null) ? null : () => _shift(open: !open),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OptionTile(
                            label: 'Cerrar sesión',
                            imageName: 'cerrar_sesion',
                            subtitle: 'No cierra el turno',
                            icon: Icons.logout_rounded,
                            tone: Colors.redAccent,
                            onTap: () {
                              SellerService.logout();
                              context.go('/');
                            },
                          ),
                        ),
                      ],
                    )),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(String name, int? shiftId) {
    return Row(
      children: [
        Icon(Icons.person_outline, color: _colors.primary, size: 22),
        const SizedBox(width: 6),
        Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        const SizedBox(width: 8),
        if (shiftId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: _colors.accent, borderRadius: BorderRadius.circular(20)),
            child: Text('Turno $shiftId', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textColorForBackground(_colors.accent))),
          ),
      ],
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.grey)),
      );
}

/// Opcion compacta: imagen del servidor (<imageName>.png; si no esta, el icono), titulo y una linea de apoyo.
class _OptionTile extends StatelessWidget {
  final String label;
  final String imageName;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final VoidCallback? onTap;

  const _OptionTile({required this.label, required this.imageName, required this.subtitle, required this.icon, required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              // Sin relleno ni sombra: solo la imagen, el texto y un contorno suave del color de la opcion
              border: Border.all(color: tone.withOpacity(0.35), width: 1.5),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                // Imagen y textos proporcionales a la tarjeta (el menor de su ancho y su alto)
                final u = box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight;
                final image = (u * 0.45).clamp(56.0, double.infinity);
                final titleSize = (u * 0.095).clamp(16.0, double.infinity);
                final subSize = (u * 0.062).clamp(11.0, double.infinity);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: PaymentLogo(name: imageName, size: image, color: tone, fallback: icon),
                      ),
                    ),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: subSize, color: Colors.grey.shade700, height: 1.25)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
