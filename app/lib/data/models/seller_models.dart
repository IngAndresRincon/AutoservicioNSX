class SellerSession {
  final String token;
  final String document;
  final String name;
  final DateTime expiresAt;

  SellerSession({
    required this.token,
    required this.document,
    required this.name,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory SellerSession.fromContent(Map<String, dynamic> content) {
    final seller = content['seller'] as Map<String, dynamic>;
    final hours = (content['expiresInHours'] as num?)?.toInt() ?? 8;
    return SellerSession(
      token: content['token'] as String,
      document: seller['document'] as String,
      name: seller['name'] as String,
      expiresAt: DateTime.now().add(Duration(hours: hours)),
    );
  }
}

/// Estado de una posicion segun la Orange: libre o con un despacho activo.
class SellerPosition {
  final int positionId;
  final int nsxPositionId;
  final String status; // free | autoservice | seller | client
  final bool own; // el despacho es del vendedor que consulta
  final int? presetId;
  final int? sync; // estado del preset: 0 registrado, 2 autorizado, 8 surtiendo
  final double? value;

  SellerPosition({
    required this.positionId,
    required this.nsxPositionId,
    required this.status,
    required this.own,
    this.presetId,
    this.sync,
    this.value,
  });

  bool get isFree => status == 'free';

  factory SellerPosition.fromJson(Map<String, dynamic> json) => SellerPosition(
        positionId: json['positionId'] as int,
        nsxPositionId: json['nsxPositionId'] as int,
        status: json['status'] as String,
        own: json['own'] as bool? ?? false,
        presetId: json['presetId'] as int?,
        sync: json['sync'] as int?,
        value: (json['value'] as num?)?.toDouble(),
      );
}

/// Preset del vendedor en la Orange (preset_vendedor).
class SellerPreset {
  final int id;
  final int sync; // 2 autorizado, 3 rechazado, 4 con venta, 5 anulado, 6 venta cero, 8 surtiendo
  final int? presetNsxId;
  final int? saleId;
  final String? message;
  final int pumpGrade; // grado (manguera) levantado segun el surtidor; 0 si no hay dato
  final int presetGrade; // grado programado en el surtidor; 0 si no hay dato

  SellerPreset({
    required this.id,
    required this.sync,
    this.presetNsxId,
    this.saleId,
    this.message,
    this.pumpGrade = 0,
    this.presetGrade = 0,
  });

  /// Se levanto una manguera distinta a la programada
  bool get hoseMismatch => pumpGrade > 0 && presetGrade > 0 && pumpGrade != presetGrade;

  factory SellerPreset.fromJson(Map<String, dynamic> json) {
    final pump = json['bomba'] as Map<String, dynamic>?;
    return SellerPreset(
      id: json['id'] as int,
      sync: json['sincronizado'] as int,
      presetNsxId: json['id_presetnsx'] as int?,
      saleId: json['id_venta'] as int?,
      message: json['mensaje'] as String?,
      pumpGrade: (pump?['gradoReal'] as num?)?.toInt() ?? 0,
      presetGrade: (pump?['gradoPreset'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Cliente de credito ya identificado: tipo de identificador (1 iButton, 2 teclado, 3 placa), serial y clave (teclado).
class SellerCredit {
  final int identifierType;
  final String serial;
  final String? key;

  const SellerCredit({required this.identifierType, required this.serial, this.key});

  // El serial del chip no se muestra completo: solo 2 caracteres de cada extremo
  String get label {
    if (identifierType == 3) return 'Placa $serial';
    if (identifierType == 2) return 'Código $serial';
    final masked = serial.length <= 4 ? '••••' : '${serial.substring(0, 2)}••••${serial.substring(serial.length - 2)}';
    return 'iButton $masked';
  }
}

/// Venta del vendedor en su turno abierto (lista de ventas del turno).
class SellerShiftSale {
  final int presetId;
  final int saleId;
  final int? presetNsxId;
  final int? nsxPositionId;
  final int hoseNumber;
  final int type; // 1 lleno, 2 dinero, 3 volumen
  final double value; // lo programado
  final DateTime? date;
  final double paid; // lo anclado a otras formas de pago; el resto es efectivo
  final bool invoiced;
  final bool isCredit; // venta a cuenta de un cliente: sin formas de pago

  SellerShiftSale({
    required this.presetId,
    required this.saleId,
    required this.presetNsxId,
    required this.nsxPositionId,
    required this.hoseNumber,
    required this.type,
    required this.value,
    required this.date,
    required this.paid,
    required this.invoiced,
    this.isCredit = false,
  });

  factory SellerShiftSale.fromJson(Map<String, dynamic> json) => SellerShiftSale(
        presetId: json['presetId'] as int,
        saleId: json['saleId'] as int,
        presetNsxId: json['presetNsxId'] as int?,
        nsxPositionId: json['nsxPositionId'] as int?,
        hoseNumber: (json['hoseNumber'] as num?)?.toInt() ?? 0,
        type: (json['type'] as num?)?.toInt() ?? 2,
        value: (json['value'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse((json['date'] ?? '').toString())?.toLocal(),
        paid: (json['paid'] as num?)?.toDouble() ?? 0,
        invoiced: json['invoiced'] as bool? ?? false,
        isCredit: json['credit'] as bool? ?? false,
      );
}

/// Forma de pago de una venta: ya guardada (viene de la venta) o por guardar.
class SellerPayLine {
  final int paymentId; // id de la forma de pago en NSX
  final String name;
  final int amount;
  final String reference;

  SellerPayLine({required this.paymentId, required this.name, required this.amount, this.reference = ''});

  factory SellerPayLine.fromSale(Map<String, dynamic> json) => SellerPayLine(
        paymentId: (json['idFormaPago'] as num?)?.toInt() ?? 0,
        name: (json['nombre'] ?? '').toString(),
        amount: ((json['valor'] as num?) ?? 0).round(),
        reference: (json['identificador'] ?? '').toString(),
      );
}

/// Combinacion programada en el turno (para repetirla con un toque).
class SellerRecent {
  final int hoseNumber;
  final String product;
  final int type; // 1 lleno, 2 dinero, 3 volumen
  final double value;

  SellerRecent({required this.hoseNumber, required this.product, required this.type, required this.value});

  @override
  bool operator ==(Object other) =>
      other is SellerRecent && other.hoseNumber == hoseNumber && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(hoseNumber, type, value);
}
