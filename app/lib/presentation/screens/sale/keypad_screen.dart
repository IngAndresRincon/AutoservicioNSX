import 'package:flutter/material.dart';
import '../../../data/models/models.dart';
import 'dart:math';

class CustomKeypadScreen extends StatefulWidget {
  final ProductHose hose;
  final bool isMoneyMode; // true para $, false para Galones
  final double maxValue;

  const CustomKeypadScreen({
    super.key,
    required this.hose,
    required this.isMoneyMode,
    this.maxValue = 999999.0,
  });

  @override
  State<CustomKeypadScreen> createState() => _CustomKeypadScreenState();
}

class _CustomKeypadScreenState extends State<CustomKeypadScreen> {
  String input = "";

  Color get _productColor {
    try {
      final hex = widget.hose.color?.replaceAll('#', '') ?? '009EBF';
      final padded = hex.padLeft(8, 'F');
      return Color(int.parse(padded, radix: 16));
    } catch (_) {
      return const Color(0xFF009EBF);
    }
  }

  double get calculatedMax {
    if (widget.isMoneyMode) return widget.maxValue; // Si es dinero, el límite es directo

    final price = double.tryParse(widget.hose.price) ?? 1.0;
    
    // 1. Calculamos el volumen bruto
    double rawMaxVol = (widget.maxValue / price) - 0.001;

    // 2. Obtenemos la precisión desde hose.volumeFormat
    int decimals = _parseVolumeFormat(widget.hose.volumeFormat);

    // 3. TRUNCAR (no redondear) para asegurar que no se pase del dinero máximo
    // Ejemplo: si rawMaxVol es 15.3789 y decimals es 2, queremos 15.37, no 15.38
    num factor = pow(10, decimals);
    double formattedMax = ((rawMaxVol * factor).truncateToDouble()) / factor;

    return formattedMax;
  }


  void _onKeyPress(String value) {
    if (!widget.isMoneyMode) {
      if (value == "." && input.contains(".")) return;
      if (value == "." && input.isEmpty) {
        setState(() => input = "0.");
        return;
      }
      
      String nextInput = input + value;
      
      if (nextInput.contains(".")) {
        final decimalPart = nextInput.split(".")[1];
        int maxAllowedDecimals = _parseVolumeFormat(widget.hose.volumeFormat);
        if (decimalPart.length > maxAllowedDecimals) return;
      }

      double? nextValue = double.tryParse(nextInput);
      if (nextValue != null && nextValue <= calculatedMax) {
        setState(() => input = nextInput);
      }
      return;
    }

    String nextInput;
    if (input.isEmpty) {
      nextInput = "${value}00"; // 1 -> 100
    } else {
      String base = input.substring(0, input.length - 2);
      nextInput = "$base$value" + "00";
    }

    double? nextValue = double.tryParse(nextInput);
    if (nextValue != null && nextValue <= calculatedMax) {
      setState(() => input = nextInput);
    }
  }

  int _parseVolumeFormat(dynamic format) {
    if (format is int) return format;
    if (format is String && format.contains('.')) {
      return format.split('.')[1].length;
    }
    return 2; // Default por si las moscas
  }

  int _getMaxDecimals(dynamic format) {
    if (format is int) return format;
    if (format is String) {
      if (format.contains(".")) {
        return format.split(".")[1].length; // De "0.000" extrae 3
      }
    }
    return 3; // Valor por defecto pro
  }

  void _onBackspace() {
    if (input.isEmpty) return;

    setState(() {
      if (widget.isMoneyMode) {
        // Si tenemos "100", al borrar debe quedar vacío
        if (input.length <= 3) {
          input = "";
        } else {
          String base = input.substring(0, input.length - 3);
          input = base + "00";
        }
      } else {
        input = input.substring(0, input.length - 1);
      }
    });
  }

  void _inputClear() {
    if (input.isNotEmpty) {
      setState(() => input = "");
    }
  }

  bool get _isValidToConfirm {
    if (input.isEmpty) return false;
    
    double? currentVal = double.tryParse(input);
    if (currentVal == null) return false;

    if (widget.isMoneyMode) {
      double price = double.tryParse(widget.hose.price) ?? 0.0;
      return currentVal >= (price * 0.1);
    } else {
      return currentVal > 0.1;
    }
  }

  String _getDisplayValue() {
    if (input.isEmpty) return widget.isMoneyMode ? "\$0" : "0";
    if (widget.isMoneyMode) {
      // Usar tu lógica de formateo de precio
      return _formatPrice(input);
    }
    return input;
  }

  String _formatPrice(String price) {
    final valor = double.tryParse(price);
    if (valor == null) return "\$$price";
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
    final color = _productColor;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/fondo_insepet.png', fit: BoxFit.cover),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  widget.isMoneyMode ? "¿Cuánto dinero?" : "¿Cuántos galones?",
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // --- VISOR CON BORRAR INMERSO ---
                _buildDisplay(color),

                const SizedBox(height: 10),

                // --- GRID DEL TECLADO ---
                _buildKeypad(),

                const SizedBox(height: 20),
                
                // Botón Cancelar
                _buildCancelButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplay(Color color) {
  final String maxHint = widget.isMoneyMode 
      ? _formatPrice(calculatedMax.toString()) 
       : "${calculatedMax} gal";

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 80), // Un poco más ancho para que luzca el row
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(50),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))
      ],
    ),
    child: Stack( // Usamos Stack para que el botón de borrar flote sin mover el texto
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- VALOR PRINCIPAL ---
            Expanded(
              child: Text(
                _getDisplayValue(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF003B5C)
                ),
              ),
            ),

            // --- SUGERENCIA (MAX HINT) PEQUEÑA A LA DERECHA ---
            if (input.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "MÁX",
                      style: TextStyle(color: Colors.black26, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      maxHint,
                      style: TextStyle(
                        color: color, // Color del producto sutil
                        fontSize: 18, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ],
                ),
              ),
              
            // Espacio fantasma para que el texto principal se mantenga centrado
            // si el icono de borrar no está
            if (input.isNotEmpty) const SizedBox(width: 40), 
          ],
        ),

        // --- BOTÓN BORRAR POSICIONADO ---
        if (input.isNotEmpty)
          Positioned(
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: IconButton(
                key: const ValueKey("del_btn"),
                icon: Icon(Icons.backspace_rounded, color: color, size: 28),
                onPressed: _onBackspace,
                onLongPress: _inputClear,
              ),
            ),
          ),
      ],
    ),
  );
}

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 70),
      child: Column(
        children: [
          _buildRow(["1", "2", "3"]),
          _buildRow(["4", "5", "6"]),
          _buildRow(["7", "8", "9"]),
          _buildRow([widget.isMoneyMode ? "" : ".", "0", "OK"]),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildKey(String label) {
    if (label == "") return const SizedBox(width: 45, height: 55);

    bool isOk = label == "OK";
    bool isDisabled = isOk && !_isValidToConfirm;
    final Color color = _productColor;
    Color btnColor = isOk ? const Color(0xFFD4E157) : Colors.white.withOpacity(0.2);
    
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: GestureDetector(
        onTapDown: (_) => setState(() {}), // Trigger para feedback visual si usaras animaciones de escala
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : () {
              if (isOk) {
                Navigator.pop(context, input);
              } else {
                _onKeyPress(label);
              }
            },
            borderRadius: BorderRadius.circular(100),
            splashColor: btnColor.withOpacity(0.8),
            highlightColor: btnColor.withOpacity(0.4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 50, // Tamaño simétrico y elegante
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: btnColor,
                border: Border.all(
                  color: Colors.white.withOpacity(0.5), 
                  width: 1
                ),
                boxShadow: [
                  if (isOk && !isDisabled) 
                    BoxShadow(
                      color: btnColor.withOpacity(0.9), 
                      blurRadius: 12, 
                      spreadRadius: 1
                    )
                ],
              ),
              alignment: Alignment.center,
              child: isOk
                  ? Icon(
                      Icons.check_circle_rounded, 
                      size: 35, 
                      color: isDisabled ? Colors.white24 : const Color(0xFF1A2E3D)
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 22, 
                        fontWeight: FontWeight.w300 // Fuente delgada = más premium
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Column(
      children: [
        Container(
          width: 150,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E3D),
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),

        const SizedBox(height: 15),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help, color: Color(0xFFD4E157), size: 20),
            SizedBox(width: 8),
            Text("¿Necesitas ayuda?", style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}