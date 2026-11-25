import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gnesys_as/services/storage_service.dart';

class QrScannerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final void Function(String code) onScanned;

  const QrScannerSheet({
    super.key,
    this.title = "Escanea tu código",
    this.subtitle = "Coloca el código QR dentro del marco",
    this.accentColor = const Color(0xFF00E5FF),
    required this.onScanned,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(String code) onScanned,
    String? title,
    String? subtitle,
    Color accentColor = const Color(0xFF00E5FF),
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrScannerSheet(
        onScanned: onScanned,
        title: title ?? "Escanea tu código",
        subtitle: subtitle ?? "Coloca el código QR dentro del marco",
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet> {
  // Orden de auto-detección (sin preguntarle nada al usuario): trasera, para
  // equipos con cámara integrada → frontal, porque en varios de estos
  // equipos la cámara USB se registra ante Android como "frontal" → externa,
  // para los pocos casos donde sí se reconoce como cámara USB real.
  static const List<CameraFacing> _facingOrder = [
    CameraFacing.back,
    CameraFacing.front,
    CameraFacing.external,
  ];

  // Compartido entre instancias de esta hoja: si la anterior todavía está
  // soltando la cámara (MobileScannerController.dispose() es async y de
  // verdad toma tiempo en liberar el hardware), la siguiente espera a que
  // termine antes de intentar arrancar la suya. Esto evita el error de
  // "cámara ocupada"/"controller was used after it was disposed" al
  // reabrir el escáner justo después de cerrarlo.
  static Future<void>? _liberandoCamaraAnterior;

  bool _scanned = false;
  bool _switching = false;
  bool _cerrando = false;
  bool _sinCamaraDisponible = false;
  bool _listo = false;
  int _facingIndex = 0;
  CameraFacing _currentFacing = CameraFacing.back;
  late MobileScannerController _controller;

  // Rotación de la vista (0-3 cuartos de vuelta). 3 = 270° horario = 90° a
  // la izquierda, que es como venía fijo antes; ahora es ajustable y se
  // recuerda por equipo (ver botón de rotar junto al título).
  int _quarterTurns = 3;

  MobileScannerController _buildController(CameraFacing facing) {
    return MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      cameraResolution: const Size(640, 480),
      facing: facing,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = _buildController(_currentFacing);
    _controller.addListener(_onControllerState);
    _prepararYAbrir();
  }

  Future<void> _prepararYAbrir() async {
    final anterior = _liberandoCamaraAnterior;
    if (anterior != null) {
      await anterior;
    }
    if (!mounted) return;
    final rotacionGuardada = await StorageService.getQrCameraRotation();
    if (!mounted) return;
    setState(() {
      _listo = true;
      if (rotacionGuardada != null) _quarterTurns = rotacionGuardada;
    });
    _loadCamaraGuardada();
  }

  void _rotar() {
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
    StorageService.setQrCameraRotation(_quarterTurns);
  }

  Future<void> _loadCamaraGuardada() async {
    final rawFacing = await StorageService.getQrCameraFacing();
    if (!mounted || rawFacing == null) return;
    final facing = CameraFacing.fromRawValue(rawFacing);
    if (facing != CameraFacing.unknown && facing != _currentFacing) {
      _switchTo(facing);
    }
  }

  /// Escucha el estado real del controller (sin depender de la UI del
  /// plugin) para decidir solo, sin intervención del usuario, si hay que
  /// probar la siguiente cámara o si ya quedó lista.
  void _onControllerState() {
    if (_switching || !mounted) return;
    final value = _controller.value;

    if (value.error != null) {
      _avanzarSiguienteCamara();
      return;
    }

    if (value.isInitialized) {
      // Cámara funcionando: se recuerda para abrir directo con ella la
      // próxima vez, sin volver a probar las demás.
      StorageService.setQrCameraFacing(_currentFacing.rawValue);
    }
  }

  void _avanzarSiguienteCamara() {
    if (_facingIndex >= _facingOrder.length - 1) {
      if (mounted) setState(() => _sinCamaraDisponible = true);
      return;
    }
    _switching = true;
    _facingIndex++;
    _switchTo(_facingOrder[_facingIndex]);
  }

  /// Cambia de cámara: crea un controller nuevo y lo asigna con una Key
  /// distinta, para que Flutter desmonte el MobileScanner anterior (que
  /// detiene su cámara solo) y monte uno nuevo desde cero.
  void _switchTo(CameraFacing facing) {
    final oldController = _controller;
    oldController.removeListener(_onControllerState);

    final newController = _buildController(facing);
    newController.addListener(_onControllerState);

    setState(() {
      _currentFacing = facing;
      _controller = newController;
      _sinCamaraDisponible = false;
      _switching = false;
    });

    // Se dispone el controller anterior en el siguiente frame, una vez que
    // Flutter ya desmontó su MobileScanner (que llama a stop() por su cuenta).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
    });
  }

  void _reintentarDesdeElInicio() {
    _facingIndex = 0;
    _switchTo(_facingOrder.first);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerState);
    if (!_cerrando) {
      // No se puede esperar el dispose async acá (State.dispose() es
      // síncrono); se guarda la Future para que la PRÓXIMA hoja la espere
      // antes de arrancar su propia cámara.
      _liberandoCamaraAnterior = _controller.dispose();
    }
    super.dispose();
  }

  void _cerrar([String? code]) {
    if (_cerrando) return;
    _cerrando = true;
    _controller.removeListener(_onControllerState);
    _liberandoCamaraAnterior = _controller.dispose();
    Navigator.of(context).pop();
    if (code != null) {
      widget.onScanned(code);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null) {
      _scanned = true;
      StorageService.setQrCameraFacing(_currentFacing.rawValue);
      _cerrar(code);
    }
  }

  /// La cámara puede quedar montada físicamente girada según el equipo;
  /// esto la endereza sin afectar la detección (mobile_scanner analiza el
  /// frame original, esto solo rota lo que se ve en pantalla). El giro es
  /// ajustable con el botón de rotar (ver `_rotar`) y se recuerda por
  /// equipo — 90°/270° necesitan invertir alto/ancho, 0°/180° no.
  Widget _buildRotatedCamera() {
    final camera = MobileScanner(
      key: ObjectKey(_controller),
      controller: _controller,
      onDetect: _onDetect,
      placeholderBuilder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      ),
      errorBuilder: (context, error) => const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      ),
    );

    if (_quarterTurns.isEven) {
      return RotatedBox(quarterTurns: _quarterTurns, child: camera);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return OverflowBox(
          // Se fija también el mínimo (igual al máximo) para que quede una
          // restricción "tight" y consistente tras invertir alto/ancho —
          // si no, hereda el mínimo original (sin invertir) del padre y
          // puede quedar mínimo > máximo ("non-normalized constraints"),
          // lo que hace que esta parte no se pinte.
          minWidth: constraints.maxHeight,
          maxWidth: constraints.maxHeight,
          minHeight: constraints.maxWidth,
          maxHeight: constraints.maxWidth,
          child: RotatedBox(
            quarterTurns: _quarterTurns,
            child: SizedBox(
              width: constraints.maxHeight,
              height: constraints.maxWidth,
              child: camera,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rotar vista de la cámara',
                    onPressed: _rotar,
                    icon: const Icon(Icons.rotate_90_degrees_ccw_rounded,
                        color: Colors.white54),
                  ),
                  IconButton(
                    onPressed: () => _cerrar(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Cámara: se detecta y se acomoda sola, sin pedirle nada al usuario.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: !_listo
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      )
                    : _sinCamaraDisponible
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.no_photography_outlined,
                                color: Colors.white54, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No se pudo acceder a la cámara',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _reintentarDesdeElInicio,
                              child: const Text('Reintentar',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _buildRotatedCamera(),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner_rounded,
                      color: widget.accentColor.withOpacity(0.7), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Apunta al código QR',
                    style: TextStyle(
                      color: widget.accentColor.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
