import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/models.dart';
import '../../../data/enums/enums.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:gnesys_as/utils/color_utils.dart';

class PartialPaymentScreen extends StatefulWidget {
  final double totalValue;
  final ProductHose hose;
  final ProgrammingType programmingType;
  final List<MethodPayment> methodPaymentList;
  final CustomerModel customer;

  const PartialPaymentScreen({
    super.key,
    required this.totalValue,
    required this.hose,
    required this.programmingType,
    required this.methodPaymentList,
    required this.customer,
  });

  @override
  State<PartialPaymentScreen> createState() => _PartialPaymentScreenState();
}

class _PartialPaymentScreenState extends State<PartialPaymentScreen> {
  String currentInput = "";
  bool _isConfirming = false;
  // Colores de la estacion (los mismos de las demas pantallas) y factor de escala segun el espacio disponible
  Color _primaryColor = const Color(0xFF1E88E5);
  Color _secondaryColor = const Color(0xFF2F80ED);
  Color _accentColor = const Color(0xFF56CCF2);
  String? _logoUrl;
  double _f = 1.0;
  List<double> dynamicPresets = [];

  double get _hosePrice => double.tryParse(widget.hose.price) ?? 1.0;

  // 2. Corregimos el mínimo: 10% del PPU (no del total)
  double get minAllowed => _hosePrice * 0.1; 
  
  double get maxAllowed => widget.totalValue;

  @override
  void initState() {
    super.initState();
    _cargarColores();
    _generateDynamicPresets();
  }

  // Lógica para generar "números cerrados" basados en el total
  void _generateDynamicPresets() {
    // Dividimos el total en cuartos para tener referencias
    double step = (widget.totalValue / 5).floorToDouble();

    // Redondeamos el step a números "bonitos" (cerrados)
    if (step >= 10000) {
      step = (step / 5000).round() * 5000.0; // Saltos de 5k o 10k
    } else if (step >= 1000) {
      step = (step / 1000).round() * 1000.0; // Saltos de 1k
    } else if (step >= 100) {
      step = (step / 100).round() * 100.0; // Saltos de 100
    } else {
      step = widget.totalValue / 4; 
    }

    List<double> presets = [];
    for (int i = 1; i <= 4; i++) {
      double val = step * i;
      // Solo agregamos si es mayor al mínimo y menor estricto al total (para que tenga sentido que sea "parcial")
      if (val >= minAllowed && val < widget.totalValue) {
        presets.add(val);
      }
    }
    
    // Si la matemática dejó el array corto, aseguramos tener opciones válidas
    if (presets.isEmpty) {
      presets = [minAllowed.ceilToDouble()];
    }

    setState(() {
      dynamicPresets = presets.take(4).toList();
    });
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

  bool get _hasValidInput {
    double? val = double.tryParse(currentInput);
    if (val == null) return false;
    return val >= minAllowed && val <= maxAllowed;
  }

  void _onKeyPress(String value) {
    String nextInput;
    if (currentInput.isEmpty) {
      nextInput = "${value}00"; 
    } else {
      String base = currentInput.substring(0, currentInput.length - 2);
      nextInput = "$base$value" + "00";
    }

    double? nextValue = double.tryParse(nextInput);
    if (nextValue != null && nextValue <= maxAllowed) {
      setState(() => currentInput = nextInput);
    }
  }

  void _onBackspace() {
    if (currentInput.isEmpty) return;
    setState(() {
      if (currentInput.length <= 3) {
        currentInput = "";
      } else {
        String base = currentInput.substring(0, currentInput.length - 3);
        currentInput = base + "00";
      }
    });
  }

  void _onPresetTap(double value) {
    setState(() {
      currentInput = value == value.toInt() ? value.toInt().toString() : value.toString();
    });
  }

  void _onConfirm() {
    if (!_hasValidInput) return;
    final double partialValue = double.parse(currentInput);
    // Solo retorna el valor, no crea programación
    context.pop(partialValue.toString());
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _primaryColor;
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
                ? _buildLandscapeLayout(themeColor)
                : _buildPortraitLayout(themeColor),
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

  Widget _buildPortraitLayout(Color themeColor) {
    return LayoutBuilder(builder: (context, box) {
    final byH = box.maxHeight / 700, byW = box.maxWidth / 420;
    _f = (byH < byW ? byH : byW).clamp(1.0, 2.0);
    return Column(
      children: [
        Expanded(
          flex: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHeader(),
                _buildInputCard(themeColor),
                _buildPresetButtons(),
                _buildGradientConfirmButton(),
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

  Widget _buildLandscapeLayout(Color themeColor) {
    return LayoutBuilder(builder: (context, box) {
    final byH = box.maxHeight / 480, byW = box.maxWidth / 1000;
    _f = (byH < byW ? byH : byW).clamp(1.0, 2.0);
    return Row(
      children: [
        // Izquierda — formulario
        Expanded(
          flex: 55,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: _buildHeader(),
              ),
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
                          _buildInputCard(themeColor),
                          _buildPresetButtons(),
                          _buildGradientConfirmButton(),
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
          color: _primaryColor.withOpacity(0.5),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          iconSize: 30 * _f,
          padding: EdgeInsets.all(14 * _f),
          onPressed: () => Navigator.maybePop(context),
        ),
        _buildLogo(40 * _f),
        SizedBox(width: 48 * _f), // Spacer
      ],
    );
  }

  Widget _buildLogo(double height) {
    const fallback = 'assets/images/logo_insepet_blanco.png';
    if (_logoUrl == null) return Image.asset(fallback, height: height);
    return Image.network(_logoUrl!, height: height, errorBuilder: (_, __, ___) => Image.asset(fallback, height: height));
  }

  Widget _buildInputCard(Color themeColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20 * _f),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Ingresa el pago parcial", style: TextStyle(color: Colors.grey, fontSize: 16 * _f, fontWeight: FontWeight.w500)),
                  // Píldora de Total Balance
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * _f, vertical: 5 * _f),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Saldo total: ${_formatPrice(widget.totalValue.toString())}",
                      style: TextStyle(fontSize: 12 * _f, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10 * _f),
              
              Row(
                children: [
                  Text("\$ ", style: TextStyle(fontSize: 32 * _f, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(
                    currentInput.isEmpty ? "0" : _formatPrice(currentInput).replaceAll('\$', ''),
                    style: TextStyle(fontSize: 38 * _f, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  Container(margin: EdgeInsets.only(left: 5 * _f), width: 3 * _f, height: 35 * _f, color: themeColor),
                ],
              ),
              
              SizedBox(height: 15 * _f),
              
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * _f, vertical: 6 * _f),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
                child: Text(
                  "Mínimo permitido: ${_formatPrice(minAllowed.toString())}",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14 * _f),
                ),
              ),
            ],
          ),
          
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildLogo(35 * _f),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: dynamicPresets.map((val) {
        String valStr = val == val.toInt() ? val.toInt().toString() : val.toString();
        bool isSelected = currentInput == valStr;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: () => _onPresetTap(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 45 * _f,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  _formatPrice(val.toString()), // Formatea ej: $10.000
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 16 * _f,
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

  Widget _buildGradientConfirmButton() {
    bool isEnabled = _hasValidInput;
    return Container(
      width: double.infinity,
      height: 55 * _f,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: isEnabled 
            ? LinearGradient(colors: [_accentColor, _secondaryColor], begin: Alignment.topCenter, end: Alignment.bottomCenter)
            : null,
        color: isEnabled ? null : Colors.grey.shade300,
        boxShadow: isEnabled ? [BoxShadow(color: _secondaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))] : [],
      ),
      child: Material(
        color: Colors.transparent, 
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: isEnabled ? _onConfirm : null,
          child: Center(child: Text("Confirmar", style: TextStyle(color: isEnabled ? textColorForGradient(_accentColor, _secondaryColor) : textColorForBackground(Colors.grey.shade300), fontSize: 18 * _f, fontWeight: FontWeight.bold))),
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
        Expanded(child: _buildKeypadRow(["", "0", "BACKSPACE"])),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: keys.map((k) => Expanded(child: _buildKeypadKey(k))).toList());
  }

  Widget _buildKeypadKey(String label) {
    if (label.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: label == "BACKSPACE" ? _onBackspace : () => _onKeyPress(label),
          borderRadius: BorderRadius.circular(15), 
          child: LayoutBuilder(
            builder: (context, cell) {
              final double size = (cell.maxHeight * 0.42).clamp(32.0, double.infinity);
              return Center(
                child: label == "BACKSPACE"
                    ? Icon(Icons.backspace_outlined, size: size * 0.95, color: Colors.black.withOpacity(0.6))
                    : Text(label, style: TextStyle(fontSize: size, fontWeight: FontWeight.w400, color: Colors.black)),
              );
            },
          ),
        ),
      ),
    );
  }
}