import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/enums/enums.dart';
import '../../../data/models/models.dart';
import '../../../services/service.dart';
import '../../../utils/color_utils.dart';
import '../../../utils/responsive.dart';

class PendingAuthScreen extends StatefulWidget {
  final CustomerModel customer;
  final Map<String, dynamic> authorization;

  const PendingAuthScreen({
    super.key,
    required this.customer,
    required this.authorization,
  });

  @override
  State<PendingAuthScreen> createState() => _PendingAuthScreenState();
}

class _PendingAuthScreenState extends State<PendingAuthScreen> {
  String? _deviceSerial;
  Color _primaryColor = const Color(0xFF1565C0);
  Color _secondaryColor = const Color(0xFF2F80ED);
  Color _accentColor = const Color(0xFF56CCF2);
  String? _logoUrl;
  String _statusMessage = 'Esperando respuesta del surtidor...';

  @override
  void initState() {
    super.initState();
    _cargarColores();
    _iniciarEscucha();
  }

  Future<void> _cargarColores() async {
    final primary = await StorageService.getPrimaryColor();
    final secondary = await StorageService.getSecondaryColor();
    final accent = await StorageService.getAccentColor();
    final logo = await StorageService.getLogoUrl();
    if (!mounted) return;
    setState(() {
      _primaryColor = primary;
      _secondaryColor = secondary;
      _accentColor = accent;
      _logoUrl = logo;
    });
  }

  // Mismo parseo que usa identification_screen.dart para el mapa de
  // programación pendiente (misma estructura de datos del backend).
  double get _valorProgramado =>
      double.tryParse(widget.authorization['valor_programado']?.toString() ?? '0') ?? 0;

  ProgrammingType get _tipoProgramacion {
    final tipo = widget.authorization['tipo_programacion'] as int? ?? 2;
    return tipo == 3 ? ProgrammingType.volumen : ProgrammingType.dinero;
  }

  Future<void> _iniciarEscucha() async {
    _deviceSerial = await StorageService.getDeviceSerial();
    if (_deviceSerial == null) return;

    final int positionId = widget.authorization['posicion_id'];

    SocketService.setAuthorizationListener(
      deviceSerial: _deviceSerial!,
      positionId: positionId,
      callback: (payload) {
        if (!mounted) return;

        final int? idPresetNsx = payload['id_presetnsx'];
        final int? saleId = payload['saleid'];
        final int sync = payload['sync'];

        debugPrint('✅ [PendingAuth] Sync: $sync');

        if (sync == 1 && idPresetNsx == null) {
          context.pushReplacement('/instructions', extra: {
            'payload': payload,
            'hose': _buildHoseFromAuth(),
            'customer': widget.customer,
            'programmingValue': _valorProgramado,
            'programmingType': _tipoProgramacion,
          });
        } else if (idPresetNsx != null && idPresetNsx > 0 && saleId == null) {
          if (sync == 8) {
            context.pushReplacement('/dispensing', extra: {
              'hose': _buildHoseFromAuth(),
              'customer': widget.customer,
              'programmingValue': _valorProgramado,
              'programmingType': _tipoProgramacion,
            });
          } else {
            context.pushReplacement('/instructions', extra: {
              'payload': payload,
              'hose': _buildHoseFromAuth(),
              'customer': widget.customer,
              'programmingValue': _valorProgramado,
              'programmingType': _tipoProgramacion,
            });
          }
        } else if (sync == 3) {
          setState(() => _statusMessage =
              'La autorización fue rechazada por el surtidor.');
          _mostrarError('Autorización rechazada. Intenta de nuevo.');
        } else if (sync == 6) {
          _mostrarError(
              'El surtidor no recibió respuesta. Intenta de nuevo.');
        } else if (saleId != null && saleId > 0) {
          context.go('/sale-summary', extra: {
            'sale': payload,
            'customer': widget.customer,
            'hose': _buildHoseFromAuth(),
          });
        }
      },
    );
  }

  // Construye un ProductHose mínimo desde los datos de la autorización
  // para poder navegar a instructions/dispensing
  ProductHose _buildHoseFromAuth() {
    final auth = widget.authorization;
    return ProductHose(
      dispenserId: 1,
      dispenserSide: 1,
      positionId: auth['posicion_id'] as int,
      nsxPositionId: auth['posicion_id'] as int,
      hoseId: auth['manguera_id'] as int,
      hoseNumber: auth['manguera_id'] as int,
      productId: auth['id_producto'] as int,
      nsxProductId: auth['id_producto'] as int,
      product: '',
      price: auth['precio'] ?? '0',
      moneyFormat: 0,
      priceFormat: 0,
      volumeFormat: 3,
      side: 'I',
      unitOfMeasurement: 'G',
      color: '#FF1565C0',
      maxvalor: 999900.0,
      codigotankio: '',
      activeHose: true,
      activePosition: true,
    );
  }

  void _mostrarError(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding:
            const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded,
                  color: Colors.red.shade600, size: 36),
            ),
            const SizedBox(height: 16),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333))),
          ],
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: [_accentColor, _secondaryColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/identification');
                },
                child: Center(
                  child: Text('Intentar de nuevo',
                      style: TextStyle(
                          color: textColorForGradient(_accentColor, _secondaryColor),
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    SocketService.stopListeningAuthorization();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor.withOpacity(0.12), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            // Se dibuja a un tamano de referencia y se amplia parejo a la pantalla
            child: ScaleUp(
              reference: const Size(420, 760),
              child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  _logoUrl != null
                      ? Image.network(_logoUrl!, height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/logo_insepet_blanco.png',
                              height: 40))
                      : Image.asset(
                          'assets/images/logo_insepet_blanco.png',
                          height: 40),

                  const SizedBox(height: 40),

                  // Spinner
                  SizedBox(
                    width: 80, height: 80,
                    child: CircularProgressIndicator(
                      color: _primaryColor,
                      strokeWidth: 6,
                      backgroundColor:
                          _primaryColor.withOpacity(0.1),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Estamos reactivando tu autorización anterior.\nPor favor no te alejes del surtidor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Cancelar
                  OutlinedButton(
                    onPressed: () => context.go('/'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      side: const BorderSide(
                          color: Color(0xFFCCCCCC)),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(
                            color: Color(0xFF888888),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}