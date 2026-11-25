import 'package:flutter/material.dart';
import 'package:gnesys_as/utils/color_utils.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/models.dart';
import '../../../services/service.dart';
import '../../widgets/widgets.dart';
// Ajusta tus imports según corresponda

class PositionsScreen extends StatefulWidget {
  final CustomerModel customer;
  const PositionsScreen({
    super.key,
    required this.customer,
  });

  @override
  State<PositionsScreen> createState() => _PositionsScreenState();
}

class _PositionsScreenState extends State<PositionsScreen> {
  MappingModel? _mapping;
  int _screenId = 0;
  bool _isLoading = true;
  String? _error;
  String? _logo;

  Color _primaryColor = const Color(0xFF1E88E5);
  Color _secondaryColor = const Color(0xFF2F80ED);
  Color _accentColor = const Color(0xFF56CCF2);

  @override
  void initState() {
    super.initState();
    print("Atendiendo a cliente ${widget.customer.name}");
    _cargarColores();
    _inicializar();
    _playProductAudio();
  }

  void _playProductAudio() {
    AudioService.playTransition('combustible.mp3');
  }

  Future<void> _inicializar() async {
    try {
      setState(() { _isLoading = true; _error = null; });

      final id = await StorageService.getScreenNumber();
      final mapping = await PumpService.getMappingWithFallback(id ?? 1);

      if (!mounted) return;

      if (mapping == null) {
        setState(() {
          _error = "No se pudo obtener el mapeo. Verifica la conexión.";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _screenId = id ?? 0;
        _mapping = mapping;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error inesperado: $e";
        _isLoading = false;
      });
    }
  }
  
  Future<void> _cargarColores() async {
    final primary = await StorageService.getPrimaryColor();
    final secondary = await StorageService.getSecondaryColor();
    final accent = await StorageService.getAccentColor();
    final logoy = await StorageService.getLogoUrl();
    if (!mounted) return;
    setState(() {
      _primaryColor = primary;
      _secondaryColor = secondary;
      _accentColor = accent;
      _logo = logoy;
    });
  }

  List<ProductHose> get _activeHoses {
    if (_mapping == null) return [];
    return _mapping!.productHoses
        .where((h) => h.activeHose && h.activePosition)
        .toList();
  }

  String _formatPrice(String price) {
    final valor = double.tryParse(price);
    if (valor == null) return price;
    final partes = valor.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < partes.length; i++) {
      if (i > 0 && (partes.length - i) % 3 == 0) buffer.write('.');
      buffer.write(partes[i]);
    }
    return '\$${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. CABECERA LIMPIA
            SizedBox(
              height: 80,
              child: _buildHeader(),
            ),

            // 2. CUERPO BLANCO REDONDEADO
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
                child: Column(
                  children: [
                    const SizedBox(height: 25),
                    
                    // Cuadrícula de Tarjetas
                    Expanded(
                      child: _buildBody(),
                    ),

                    // Área Inferior (Ayuda y Botón)
                    _buildBottomActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // LOGO DESDE SERVIDOR CON FALLBACK LOCAL
        _logo != null
          ? Image.network(
              _logo!,
              height: 40,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, loadingProgress) =>
                  loadingProgress == null ? child : const SizedBox(width: 40),
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/logo_insepet_blanco.png',
                height: 40,
                fit: BoxFit.contain,
              ),
            )
          : Image.asset(
              'assets/images/logo_insepet_blanco.png',
              height: 40,
              fit: BoxFit.contain,
            ),
        const ClockWidget(color: Colors.black87, fontSize: 13),
        // SELECTOR DE IDIOMA — oculto temporalmente
        // Container(
        //   decoration: BoxDecoration(
        //     color: const Color(0xFF0D47A1),
        //     borderRadius: BorderRadius.circular(25),
        //   ),
        //   child: Row(
        //     mainAxisSize: MainAxisSize.min,
        //     children: [
        //       Container(
        //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        //         decoration: BoxDecoration(
        //           color: const Color(0xFFFFD700),
        //           borderRadius: BorderRadius.circular(25),
        //         ),
        //         child: const Row(
        //           children: [
        //             Text("🇺🇸", style: TextStyle(fontSize: 16)),
        //             SizedBox(width: 4),
        //             Text("EN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        //           ],
        //         ),
        //       ),
        //       const Padding(
        //         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        //         child: Text("ES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    ),
  );
}

  

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 20),
            Text('Obteniendo Productos...', style: TextStyle(color: Colors.black54, fontSize: 18)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _inicializar,
              icon: const Icon(Icons.refresh),
              label: const Text("Reintentar"),
            ),
          ],
        ),
      );
    }

    final hoses = _activeHoses;
    if (hoses.isEmpty) {
      return const Center(
        child: Text(
          "No hay productos activos disponibles.",
          style: TextStyle(color: Colors.black54, fontSize: 18),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        if (isLandscape) {
          // Landscape — fila horizontal ordenada izq → der
          final sortedHoses = List<ProductHose>.from(hoses)
            ..sort((a, b) {
              const order = {'I': 0, 'M': 1, 'D': 2};
              final aOrder = order[a.side.toUpperCase()] ?? 99;
              final bOrder = order[b.side.toUpperCase()] ?? 99;
              return aOrder.compareTo(bOrder);
            });

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: sortedHoses.asMap().entries.map((entry) {
                final i = entry.key;
                final hose = entry.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: i < sortedHoses.length - 1 ? 15 : 0),
                    child: _ProductCard(
                      hose: hose,
                      formattedPrice: _formatPrice(hose.price),
                      onTap: () => context.push(
                        "/preset",
                        extra: {
                          "hose": hose,
                          "speedDial": _mapping!.speedDial,
                          "methodPayments": _mapping!.methodPayment,
                          "customer": widget.customer,
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }

        // Portrait — una tarjeta por fila, ocupando todo el ancho
        final sortedHoses = List<ProductHose>.from(hoses)
          ..sort((a, b) {
            const order = {'I': 0, 'M': 1, 'D': 2};
            final aOrder = order[a.side.toUpperCase()] ?? 99;
            final bOrder = order[b.side.toUpperCase()] ?? 99;
            return aOrder.compareTo(bOrder);
          });

        // Cada tarjeta se reparte el alto disponible en partes iguales;
        // _ProductCard escala su contenido a lo que reciba, así que nunca
        // hace falta scroll ni se recorta nada (ideal para un kiosko).
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: sortedHoses.asMap().entries.map((entry) {
              final i = entry.key;
              final hose = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: i < sortedHoses.length - 1 ? 15 : 0),
                  child: _ProductCard(
                    hose: hose,
                    formattedPrice: _formatPrice(hose.price),
                    onTap: () => context.push(
                      "/preset",
                      extra: {
                        "hose": hose,
                        "speedDial": _mapping!.speedDial,
                        "methodPayments": _mapping!.methodPayment,
                        "customer": widget.customer,
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, top: 10, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ROBOT DE AYUDA ("Need Help?") — oculto temporalmente
          // Align(
          //   alignment: Alignment.centerRight,
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       Container(
          //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          //         decoration: BoxDecoration(
          //           color: Colors.white,
          //           border: Border.all(color: _primaryColor, width: 1.5),
          //           borderRadius: BorderRadius.circular(20),
          //         ),
          //         child: const Text("Need Help?", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          //       ),
          //       const SizedBox(width: 8),
          //       const Icon(Icons.smart_toy, size: 50, color: Colors.blueAccent),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 20),
          _buildGradientCancelButton(),
        ],
      ),
    );
  }

  // --- NUEVO WIDGET DEL BOTÓN ---
  Widget _buildGradientCancelButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [_accentColor, _secondaryColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: _secondaryColor.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent, 
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => context.pop(),
          child: Center(
            child: Text(
              "Cancelar",
              style: TextStyle(
                color: textColorForGradient(_accentColor, _secondaryColor),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// ---------------------------------------------------------------------------

class _ProductCard extends StatefulWidget {
  final ProductHose hose;
  final String formattedPrice;
  final VoidCallback onTap;

  const _ProductCard({
    required this.hose,
    required this.formattedPrice,
    required this.onTap,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  // Animación continua y muy sutil (la pistola "flota" un poco y el punto
  // de "Disponible" respira) para que la tarjeta se sienta viva, sin
  // distraer ni verse exagerada.
  late final AnimationController _lifeController;

  @override
  void initState() {
    super.initState();
    _lifeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lifeController.dispose();
    super.dispose();
  }

  ProductHose get hose => widget.hose;

  Color get _cardColor {
    try {
      final hex = hose.color?.replaceAll('#', '') ?? '';
      final padded = hex.padLeft(8, 'F');
      return Color(int.parse(padded, radix: 16));
    } catch (_) {
      return const Color(0xFF009EBF);
    }
  }

  // Versión oscura/profunda del color del producto para el header, en vez
  // del tono pastel que se usaba antes (cada producto conserva su color).
  Color get _headerColor {
    final hsl = HSLColor.fromColor(_cardColor);
    return hsl.withLightness((hsl.lightness * 0.7).clamp(0.1, double.infinity)).toColor();
  }

  String get _positionLabel {
    switch (hose.side) {
      case 'I': return "IZQ";
      case 'D': return "DER";
      case 'M': return "MED";
      default: return hose.side ?? "-";
    }
  }

  IconData get _positionIcon {
    switch (hose.side) {
      case 'I': return Icons.keyboard_double_arrow_left_rounded;
      case 'D': return Icons.keyboard_double_arrow_right_rounded;
      case 'M': return Icons.swap_vert_rounded;
      default: return Icons.local_gas_station_rounded;
    }
  }

  // Color vivo/saturado para "pintar" el forro de la pistola.
  Color get _vividTint {
    final hsl = HSLColor.fromColor(_cardColor);
    return hsl.withSaturation(1.0).withLightness(0.55).toColor();
  }

  // Filtro que tiñe el forro con el color vivo del producto conservando algo
  // del sombreado de la foto. Se hace con ColorFilter.matrix (no con
  // ColorFilter.mode + BlendMode) porque los blend modes tipo
  // "color/hue/luminosity" fuerzan alfa=1 en toda la caja de la imagen e
  // ignoran la transparencia real del PNG — con la matriz el canal alfa se
  // conserva intacto pixel por pixel.
  ColorFilter get _vividBodyFilter {
    final tint = _vividTint;
    const double k = 0.2; // qué tanto pesa el sombreado de la foto
    const double c = 0.8; // piso de color: que resalte incluso en sombras
    final double cr = (tint.red / 255.0) * k;
    final double cg = (tint.green / 255.0) * k;
    final double cb = (tint.blue / 255.0) * k;
    final double or_ = tint.red * c;
    final double og = tint.green * c;
    final double ob = tint.blue * c;
    return ColorFilter.matrix(<double>[
      cr, 0, 0, 0, or_,
      0, cg, 0, 0, og,
      0, 0, cb, 0, ob,
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final unit = hose.unitOfMeasurement == 'G' ? "gal" : "L";

    return GestureDetector(
      onTap: widget.onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Escala todo el contenido según el alto disponible, usando 210
          // como el alto "ideal" de referencia. Así la tarjeta siempre cabe
          // completa sea 1, 2 o varios productos — sin recortarse ni
          // necesitar scroll (indispensable en un kiosko).
          // Se usa el menor entre la escala por alto y por ancho (360 de ancho "ideal"), sin tope superior
          // fijo: en pantallas grandes el contenido, la pistola y el encabezado crecen con la tarjeta.
          final double byHeight = constraints.hasBoundedHeight ? constraints.maxHeight / 210.0 : 1.0;
          final double byWidth = constraints.hasBoundedWidth ? constraints.maxWidth / 360.0 : 1.0;
          final double s = (byHeight < byWidth ? byHeight : byWidth).clamp(0.5, double.infinity);
          final double headerHeight = 100 * s;

          // Contenido de la tarjeta: se arma una sola vez y no se reconstruye
          // en cada tick de la animación (va como "child" del AnimatedBuilder
          // de abajo); el flote de la pistola y el punto de "Disponible"
          // igual siguen animando porque tienen su propio AnimatedBuilder.
          final cardContent = Stack(
              clipBehavior: Clip.none,
              children: [
                // --- FONDOS: header oscuro arriba, blanco el resto ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: headerHeight, color: _headerColor),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),

                // --- PISTOLA: se superpone al header y al cuerpo blanco,
                // con un flote muy sutil para que se sienta viva. ---
                Positioned(
                  right: 14 * s,
                  top: headerHeight * 0.36,
                  child: AnimatedBuilder(
                    animation: _lifeController,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(_lifeController.value);
                      final bob = -5 * s * t; // flote vertical sutil
                      return Transform.translate(
                        offset: Offset(0, bob),
                        child: child,
                      );
                    },
                    child: SizedBox(
                      height: headerHeight * 1.5,
                      child: Stack(
                        fit: StackFit.passthrough,
                        children: [
                          // Base: la pistola tal cual (cromado, resorte,
                          // palanca) sin ningún tinte.
                          Image.asset(
                            'assets/images/pist.png',
                            fit: BoxFit.contain,
                          ),
                          // Encima, en la misma posición: solo el cuerpo/forro
                          // plástico, pintado vivo con el color del producto —
                          // el cromado de abajo se sigue viendo intacto.
                          ColorFiltered(
                            colorFilter: _vividBodyFilter,
                            child: Image.asset(
                              'assets/images/pist_forro.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- Nombre del producto (sobre el header) ---
                Positioned(
                  left: 14 * s,
                  top: 12 * s,
                  right: 95 * s,
                  height: headerHeight - 20 * s,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hose.product,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: (19 * s).clamp(13.0, double.infinity),
                        height: 1.2,
                      ),
                    ),
                  ),
                ),

                // --- Pill "Posición X" (sobre el header) ---
                Positioned(
                  right: 10 * s,
                  top: 10 * s,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 11 * s, vertical: 6 * s),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _positionIcon,
                          color: Colors.white,
                          size: (13 * s).clamp(10.0, double.infinity),
                        ),
                        SizedBox(width: 3 * s),
                        Text(
                          'Posición $_positionLabel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: (12 * s).clamp(9.0, double.infinity),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- CUERPO BLANCO (precio + disponibilidad) ---
                Positioned(
                  left: 16 * s,
                  right: 16 * s,
                  top: headerHeight,
                  bottom: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.formattedPrice,
                            style: TextStyle(
                              fontSize: (38 * s).clamp(24.0, double.infinity),
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 4 * s),
                          Padding(
                            padding: EdgeInsets.only(bottom: 6.0 * s),
                            child: Text(
                              "/$unit",
                              style: TextStyle(
                                fontSize: (16 * s).clamp(11.0, double.infinity),
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8 * s),
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _lifeController,
                            builder: (context, child) {
                              final t = Curves.easeInOut
                                  .transform(_lifeController.value);
                              return Opacity(
                                opacity: 0.55 + 0.45 * t, // respira sutil
                                child: child,
                              );
                            },
                            child: Container(
                              width: (8 * s).clamp(6.0, double.infinity),
                              height: (8 * s).clamp(6.0, double.infinity),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7D32),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          SizedBox(width: 6 * s),
                          Text(
                            'Disponible',
                            style: TextStyle(
                              fontSize: (12 * s).clamp(9.0, double.infinity),
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

          // Resplandor sutil que pulsa alrededor de la tarjeta (invita a
          // elegirla) sin mover ni escalar nada — nada de "mareo".
          return AnimatedBuilder(
            animation: _lifeController,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_lifeController.value);
              return Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: _cardColor.withOpacity(0.10 + 0.18 * t),
                      blurRadius: 16 + 8 * t,
                      spreadRadius: 1 * t,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: cardContent,
          );
        },
      ),
    );
  }
}

