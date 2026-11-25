import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../../../data/models/models.dart';
import '../../../data/enums/enums.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:gnesys_as/utils/color_utils.dart';
import 'package:gnesys_as/presentation/widgets/app_notice.dart';

class PresetScreen extends StatefulWidget {
  final ProductHose hose;
  final List<SpeedDial> speedDialList;
  final List<MethodPayment> methodPaymentList;
  final CustomerModel customer;
  final double maxValue; // Se añade maxValue como parámetro opcional

  const PresetScreen({
    super.key,
    required this.hose,
    required this.speedDialList,
    required this.methodPaymentList,
    required this.customer,
    this.maxValue = 999999.0, // Default igual al keypad
  });

  @override
  State<PresetScreen> createState() => _PresetScreenState();
}

class _PresetScreenState extends State<PresetScreen> {
  bool isMoneyMode = true;
  // Factor de escala de la pantalla: crece con el espacio disponible para que nada quede chico en pantallas grandes
  double _f = 1.0;
  bool _isConfirming = false;
  String currentInput = "";

  // Datos opcionales del vehículo, capturados desde "Agregar placa".
  String? _placa;
  int? _km;

  // Colores con fallback
  Color _primaryColor = const Color(0xFF1E88E5);
  Color _secondaryColor = const Color(0xFF2F80ED);
  Color _accentColor = const Color(0xFF56CCF2);
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _playWelcomeAudio();
    _cargarColores();
    // Si el cliente ya tiene placa/km registrados, se precargan para
    // ahorrarle el paso — igual quedan editables desde "Agregar placa".
    _placa = widget.customer.licensePlate;
    _km = widget.customer.km;
  }

  void _playWelcomeAudio() {
    AudioService.playTransition('modo_tanqueo.mp3');
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

  // --- LÓGICA DE NEGOCIO RECUPERADA DEL KEYPAD ---

  double get _hosePrice => double.tryParse(widget.hose.price) ?? 1.0;

  double get calculatedMax {
    if (isMoneyMode) return widget.hose.maxvalor; 

    // Si es volumen, calcula el máximo basado en el maxValue de dinero
    double rawMaxVol = (widget.hose.maxvalor / _hosePrice) - 0.001;
    int decimals = _parseVolumeFormat(widget.hose.volumeFormat);
    num factor = pow(10, decimals);
    double formattedMax = ((rawMaxVol * factor).truncateToDouble()) / factor;
    return formattedMax;
  }

  int _parseVolumeFormat(dynamic format) {
    if (format is int) return format;
    if (format is String && format.contains('.')) {
      return format.split('.')[1].length;
    }
    return 2; 
  }

  bool get _hasValidInput {
    if (currentInput.isEmpty) return false;
    double? currentVal = double.tryParse(currentInput);
    if (currentVal == null) return false;

    // Validación de Mínimo
    if (isMoneyMode) {
      return currentVal >= (_hosePrice * 0.1); // Mínimo = 10% del precio de un galón/litro
    } else {
      return currentVal > 0.1; // Mínimo volumen
    }
  }

  // --- LÓGICA DEL TECLADO ---
  void _onKeyPress(String value) {
    if (!isMoneyMode) {
      // Modo Volumen (Permite decimales)
      if (value == "." && currentInput.contains(".")) return;
      if (value == "." && currentInput.isEmpty) {
        setState(() => currentInput = "0.");
        return;
      }
      
      String nextInput = currentInput + value;
      
      if (nextInput.contains(".")) {
        final decimalPart = nextInput.split(".")[1];
        int maxAllowedDecimals = _parseVolumeFormat(widget.hose.volumeFormat);
        if (decimalPart.length > maxAllowedDecimals) return;
      }

      double? nextValue = double.tryParse(nextInput);
      if (nextValue != null && nextValue <= calculatedMax) {
        setState(() => currentInput = nextInput);
      }
      return;
    }

    // Modo Dinero (Relleno con "00")
    String nextInput;
    if (currentInput.isEmpty) {
      nextInput = "${value}00"; 
    } else {
      String base = currentInput.substring(0, currentInput.length - 2);
      nextInput = "$base$value" + "00";
    }

    double? nextValue = double.tryParse(nextInput);
    if (nextValue != null && nextValue <= calculatedMax) {
      setState(() => currentInput = nextInput);
    }
  }

  void _onBackspace() {
    if (currentInput.isEmpty) return;

    setState(() {
      if (isMoneyMode) {
        if (currentInput.length <= 3) {
          currentInput = "";
        } else {
          String base = currentInput.substring(0, currentInput.length - 3);
          currentInput = base + "00";
        }
      } else {
        currentInput = currentInput.substring(0, currentInput.length - 1);
      }
    });
  }

  void _onPresetTap(double value) {
    // Validar si el preset excede el máximo permitido antes de setearlo
    if (value <= calculatedMax) {
      setState(() {
        currentInput = value == value.toInt() ? value.toInt().toString() : value.toString();
      });
    } else {
      // Opcional: Mostrar un snackbar diciendo que el preset excede el máximo
      showAppNotice(context, 'El valor máximo permitido es ${calculatedMax}', kind: NoticeKind.error);
    }
  }

  void _onToggleMode(bool toMoney) {
    if (isMoneyMode == toMoney) return;
    setState(() {
      isMoneyMode = toMoney;
      currentInput = ""; 
    });
  }

  

  String _formatPrice(String price) {
    final valor = double.tryParse(price);
    if (valor == null) return price;
    final str = valor.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '\$${buffer.toString()}';
  }

  // --- LÓGICA DE CONFIRMACIÓN ---
  // --- REEMPLAZA TU _onConfirm ACTUAL CON ESTO ---
  void _onConfirm() {
    if (!_hasValidInput) return;
    final type = isMoneyMode ? ProgrammingType.dinero : ProgrammingType.volumen;
    final double value = double.parse(currentInput);
    _ejecutarProgramacion(value, type);
  }

  Future<void> _ejecutarProgramacion(double value, ProgrammingType type) async {
    setState(() => _isConfirming = true);

    try {
      final result = await PaymentService.createProgramming(
        hose: widget.hose,
        programmingValue: value,
        type: type,
        customer: widget.customer,
      );

      if (!mounted) return;

      context.push('/payment', extra: {
        'hose': widget.hose,
        'programmingId': result.id,
        'programmingValue': value,
        'programmingType': type,
        'methodPayments': widget.methodPaymentList,
        'customer': widget.customer,
      });
    } catch (e) {
      if (mounted) {
        showAppNotice(context, "Error al programar: $e", kind: NoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  // --- PLACA / KILOMETRAJE (OPCIONAL) ---

  void _abrirAgregarPlaca() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlacaKmSheet(
        placaInicial: _placa,
        kmInicial: _km,
        primaryColor: _primaryColor,
        secondaryColor: _secondaryColor,
        accentColor: _accentColor,
        onGuardar: (placa, km) async {
          final error = await CustomerService().addAdditionalInformation(
            clientId: widget.customer.id,
            licensePlate: placa,
            km: km,
          );

          if (error != null) {
            if (mounted) {
              showAppNotice(context, error, kind: NoticeKind.error);
            }
            return false;
          }

          if (mounted) {
            setState(() {
              _placa = placa;
              _km = km;
            });
          }
          return true;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.hose.unitOfMeasurement == 'G' ? "Galones" : "Litros";
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor.withOpacity(0.3), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: isLandscape
                ? _buildLandscapeLayout(unit)
                : _buildPortraitLayout(unit),
          ),

          if (_isConfirming)
            Container(
              color: Colors.black54,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(String unit) {
    return LayoutBuilder(builder: (context, box) {
    final byH = box.maxHeight / 700, byW = box.maxWidth / 420;
    _f = (byH < byW ? byH : byW).clamp(1.0, 2.0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: _buildHeader(_primaryColor),
        ),
        Expanded(
          flex: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInputCard(_primaryColor, unit),
                _buildPresetButtons(_primaryColor),
                _buildConfirmRow(),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 50,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 15, bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: _buildKeypad(),
          ),
        ),
      ],
    );
    });
  }

  Widget _buildLandscapeLayout(String unit) {
    return LayoutBuilder(builder: (context, box) {
    final byH = box.maxHeight / 480, byW = box.maxWidth / 1000;
    _f = (byH < byW ? byH : byW).clamp(1.0, 2.0);
    return Row(
      children: [
        // Izquierda — toggle + formulario
        Expanded(
          flex: 55,
          child: Column(
            children: [
              // Solo el botón atrás arriba
              Align(
                alignment: Alignment.centerLeft,
                child: _buildBackButton(),
              ),
              // Todo el contenido centrado verticalmente
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.5,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Toggle aquí dentro del formulario
                          _buildToggleSwitch(_primaryColor),
                          _buildInputCard(_primaryColor, unit),
                          _buildPresetButtons(_primaryColor),
                          _buildConfirmRow(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Divisor
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 12),
          color: _primaryColor.withOpacity(0.15),
        ),

        // Derecha — teclado
        Expanded(
          flex: 45,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
                maxWidth: MediaQuery.of(context).size.width * 0.38,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildKeypad(),
              ),
            ),
          ),
        ),
      ],
    );
    });
  }

  Widget _buildHeader(Color themeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildBackButton(),
        _buildToggleSwitch(themeColor),
        SizedBox(width: 48 * _f),
      ],
    );
  }

  // Ícono y área de toque más grandes que el IconButton por defecto — antes
  // costaba notar si se había tocado o no.
  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
      iconSize: 30 * _f,
      padding: EdgeInsets.all(14 * _f),
      onPressed: () => Navigator.maybePop(context),
    );
  }

  // --- WIDGET EXTRACTO PARA EL TOGGLE ---
  Widget _buildToggleSwitch(Color themeColor) {
    return Container(
      width: 250 * _f, // Ancho total de la pastilla blanca
      height: 50 * _f,
      padding: const EdgeInsets.all(4), // Este padding crea el margen blanco alrededor de la selección azul
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          // 1. La pastilla azul que se desliza
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            // Cambia la alineación dependiendo del modo seleccionado
            alignment: isMoneyMode ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 120 * _f, // Aproximadamente la mitad del espacio interno
              height: double.infinity,
              decoration: BoxDecoration(
                color: themeColor, // El azul de tu producto
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          
          // 2. Los textos estáticos por encima
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // Para que todo el área sea clickeable
                  onTap: () => _onToggleMode(true),
                  child: Center(
                    child: Text(
                      "Dinero",
                      style: TextStyle(
                        color: isMoneyMode ? textColorForBackground(themeColor) : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * _f,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onToggleMode(false),
                  child: Center(
                    child: Text(
                      "Volumen",
                      style: TextStyle(
                        color: !isMoneyMode ? textColorForBackground(themeColor) : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * _f,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(Color themeColor, String unit) {
    double currentVal = double.tryParse(currentInput) ?? 0.0;
    double approxVal = isMoneyMode 
        ? (currentVal / _hosePrice) 
        : (currentVal * _hosePrice);
        
    String approxText = isMoneyMode
        ? "≈ ${approxVal.toStringAsFixed(2)} $unit"
        : "≈ ${_formatPrice(approxVal.toStringAsFixed(0))}";

    // Hint visual del máximo permitido
    String maxHintText = isMoneyMode 
        ? "Máx: ${_formatPrice(calculatedMax.toString())}" 
        : "Máx: ${calculatedMax} $unit";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20 * _f),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMoneyMode ? "Ingresa el monto" : "Ingresa el volumen",
                    style: TextStyle(color: Colors.grey, fontSize: 16 * _f, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    maxHintText,
                    style: TextStyle(color: themeColor.withOpacity(0.8), fontSize: 12 * _f, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 10 * _f),
              
              Row(
                children: [
                  Text(
                    isMoneyMode ? "\$ " : "",
                    style: TextStyle(fontSize: 32 * _f, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  Text(
                    currentInput.isEmpty ? "0" : (isMoneyMode ? _formatPrice(currentInput).replaceAll('\$', '') : currentInput),
                    style: TextStyle(fontSize: 38 * _f, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  Text(
                    !isMoneyMode ? " $unit" : "",
                    style: TextStyle(fontSize: 20 * _f, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  Container(
                    margin: EdgeInsets.only(left: 5 * _f),
                    width: 3 * _f,
                    height: 35 * _f,
                    color: themeColor,
                  )
                ],
              ),
              
              SizedBox(height: 15 * _f),
              
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * _f, vertical: 6 * _f),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  approxText,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14 * _f),
                ),
              ),
            ],
          ),
          
          Positioned(
            right: 0,
            bottom: 0,
            child: _logoUrl != null
              ? Image.network(
                  _logoUrl!,
                  height: 35 * _f,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/logo_insepet_blanco.png',
                    height: 35 * _f,
                  ),
                )
              : Image.asset('assets/images/logo_insepet_blanco.png', height: 35 * _f),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButtons(Color themeColor) {
    final presets = widget.speedDialList.take(3).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: presets.map((sd) {
        final double value = isMoneyMode ? sd.moneyValue.toDouble() : sd.volumeValue.toDouble();
        String valStr = value == value.toInt() ? value.toInt().toString() : value.toString();
        bool isSelected = currentInput == valStr;
        
        String label = isMoneyMode 
                        ? _formatPrice(sd.moneyValue.toStringAsFixed(0))
                        : "${sd.volumeValue}";

        // Si el preset supera el máximo, lo deshabilitamos visualmente
        bool isDisabled = value > calculatedMax;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: isDisabled ? null : () => _onPresetTap(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 50 * _f,
                decoration: BoxDecoration(
                  color: isDisabled ? Colors.grey.shade200 : (isSelected ? Colors.black : Colors.white),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: isSelected 
                    ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
                    : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDisabled ? Colors.grey : (isSelected ? Colors.white : Colors.black87),
                    fontSize: 18 * _f,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConfirmRow() {
    return Row(
      children: [
        // Proporción del ancho disponible en vez de un tamaño fijo en
        // píxeles, para que se acomode en cualquier tamaño de pantalla.
        Expanded(flex: 1, child: _buildPlacaButton()),
        SizedBox(width: 10 * _f),
        Expanded(flex: 2, child: _buildGradientConfirmButton()),
      ],
    );
  }

  Widget _buildPlacaButton() {
    final bool tieneDatos = _placa != null || _km != null;
    final Color color = tieneDatos ? _primaryColor : Colors.grey.shade700;

    return GestureDetector(
      onTap: _isConfirming ? null : _abrirAgregarPlaca,
      child: Container(
        height: 55 * _f,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: tieneDatos ? _primaryColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: tieneDatos ? _primaryColor : Colors.grey.shade300,
            width: tieneDatos ? 1.5 : 1,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Tamaño de letra según el ancho real que le tocó al botón (no
            // un valor fijo), así crece/encoge con la pantalla sin romper
            // el tamaño del botón en sí.
            final double w = constraints.maxWidth;
            final double fontUnico = (w * 0.13).clamp(11.0 * _f, 15.0 * _f);
            final double fontDosLineas = (w * 0.11).clamp(10.0 * _f, 13.5 * _f);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car_filled_rounded,
                  size: (w * 0.16).clamp(15.0 * _f, 20.0 * _f),
                  color: tieneDatos ? _primaryColor : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: !tieneDatos
                      ? Text(
                          "Agregar placa",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: fontUnico,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Placa: ${_placa ?? '—'}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: fontDosLineas,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              "Km: ${_km?.toString() ?? '—'}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: fontDosLineas,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGradientConfirmButton() {
    bool isEnabled = _hasValidInput;
    
    return Container(
      width: double.infinity,
      height: 55 * _f,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: isEnabled 
            ? LinearGradient(
                colors: [_accentColor, _secondaryColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: isEnabled ? null : Colors.grey.shade300,
        boxShadow: isEnabled ? [
          BoxShadow(
            color: _secondaryColor.withOpacity(0.4), 
            blurRadius: 10, 
            offset: const Offset(0, 5),
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent, 
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: isEnabled ? _onConfirm : null,
          child: Center(
            child: Text(
              "Confirmar",
              style: TextStyle(
                color: isEnabled
                    ? textColorForGradient(_accentColor, _secondaryColor)
                    : textColorForBackground(Colors.grey.shade300),
                fontSize: 18 * _f,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Expanded(child: _buildKeypadRow(["1", "2", "3"])),
        Expanded(child: _buildKeypadRow(["4", "5", "6"])),
        Expanded(child: _buildKeypadRow(["7", "8", "9"])),
        Expanded(child: _buildKeypadRow([isMoneyMode ? "" : ".", "0", "BACKSPACE"])),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: keys.map((key) => Expanded(child: _buildKeypadKey(key))).toList(),
    );
  }

  Widget _buildKeypadKey(String label) {
    if (label.isEmpty) return const SizedBox(); // Botón vacío para dinero

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: label == "BACKSPACE" ? _onBackspace : () => _onKeyPress(label),
          borderRadius: BorderRadius.circular(15), 
          child: LayoutBuilder(
            builder: (context, cell) {
              // Tamano proporcional a la tecla (alto), con un minimo legible
              final double size = (cell.maxHeight * 0.42).clamp(32.0, double.infinity);
              return Center(
                child: label == "BACKSPACE"
                    ? Icon(Icons.backspace_outlined, size: size * 0.95, color: Colors.black.withOpacity(0.6))
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: size,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet para capturar placa/kilometraje (ambos opcionales).
// ---------------------------------------------------------------------------

class _PlacaKmSheet extends StatefulWidget {
  final String? placaInicial;
  final int? kmInicial;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  // Retorna true si se guardó bien (el sheet se cierra solo); false si
  // falló (el sheet se queda abierto para reintentar).
  final Future<bool> Function(String? placa, int? km) onGuardar;

  const _PlacaKmSheet({
    required this.placaInicial,
    required this.kmInicial,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.onGuardar,
  });

  @override
  State<_PlacaKmSheet> createState() => _PlacaKmSheetState();
}

class _PlacaKmSheetState extends State<_PlacaKmSheet> {
  late final TextEditingController _placaController;
  late final TextEditingController _kmController;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _placaController = TextEditingController(text: widget.placaInicial ?? '');
    _kmController = TextEditingController(text: widget.kmInicial?.toString() ?? '');
  }

  @override
  void dispose() {
    _placaController.dispose();
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _onGuardarTap() async {
    final placa = _placaController.text.trim();
    final kmText = _kmController.text.trim();

    if (placa.isEmpty && kmText.isEmpty) {
      setState(() => _error = 'Ingresa al menos la placa o el kilometraje');
      return;
    }

    int? km;
    if (kmText.isNotEmpty) {
      km = int.tryParse(kmText);
      if (km == null) {
        setState(() => _error = 'Kilometraje inválido');
        return;
      }
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final ok = await widget.onGuardar(placa.isEmpty ? null : placa, km);

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Row(
              children: [
                Icon(Icons.directions_car_filled_rounded,
                    color: widget.primaryColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Datos del vehículo',
                  style: TextStyle(
                    color: widget.primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Placa y kilometraje son opcionales',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Placa
            TextField(
              controller: _placaController,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Placa (ej. ABC123)',
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                prefixIcon: const Icon(Icons.directions_car_outlined,
                    size: 18, color: Color(0xFFBBBBBB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),

            // Kilometraje
            TextField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              maxLength: 7,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Kilometraje',
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                prefixIcon: const Icon(Icons.speed_outlined,
                    size: 18, color: Color(0xFFBBBBBB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],

            const SizedBox(height: 20),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      side: const BorderSide(color: Color(0xFFCCCCCC)),
                    ),
                    child: const Text('Omitir',
                        style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        colors: [widget.accentColor, widget.secondaryColor],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: _guardando ? null : _onGuardarTap,
                        child: Center(
                          child: _guardando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Guardar',
                                  style: TextStyle(
                                    color: textColorForGradient(
                                        widget.accentColor, widget.secondaryColor),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
