class MappingModel {
  final Station station; // <-- nuevo
  final List<ProductHose> productHoses;
  final List<MethodPayment> methodPayment;
  final List<SpeedDial> speedDial;
  final List<FidelityProgram> fidelity;
  final List<IdentifierType> identifiers; // tipos de identificador habilitados (iButton, teclado, placa)
  final List<SellerPaymentMethod> sellerPaymentMethods; // formas de pago que ancla el vendedor
  final RealtimeConfig realtime; // tiempo real de esta pantalla mientras surte

  MappingModel({
    required this.station,
    required this.productHoses,
    required this.methodPayment,
    required this.speedDial,
    this.fidelity = const [],
    this.identifiers = const [],
    this.sellerPaymentMethods = const [],
    this.realtime = const RealtimeConfig(),
  });

  // Alguna posicion es de un dispensador hibrido: la app ofrece el acceso de vendedor
  bool get hasHybrid => productHoses.any((hose) => hose.hybrid);

  bool isIdentifierEnabled(int type) => identifiers.any((item) => item.id == type);

  factory MappingModel.fromJson(Map<String, dynamic> json) {
    // La respuesta del servidor trae `content`; el cache local guarda solo `mapping`
    final root = (json['content'] as Map<String, dynamic>?) ?? json;
    final mapping = root['mapping'] as Map<String, dynamic>;
    return MappingModel(
      station: Station.fromJson(mapping['station'] as Map<String, dynamic>),
      productHoses: (mapping['productHoses'] as List<dynamic>)
          .map((e) => ProductHose.fromJson(e as Map<String, dynamic>))
          .toList(),
      methodPayment: (mapping['methodPayment'] as List<dynamic>)
          .map((e) => MethodPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
      speedDial: (mapping['speedDial'] as List<dynamic>)
          .map((e) => SpeedDial.fromJson(e as Map<String, dynamic>))
          .toList(),
      fidelity: (mapping['fidelity'] as List<dynamic>? ?? [])
          .map((e) => FidelityProgram.fromJson(e as Map<String, dynamic>))
          .toList(),
      identifiers: (mapping['identifiers'] as List<dynamic>? ?? [])
          .map((e) => IdentifierType.fromJson(e as Map<String, dynamic>))
          .toList(),
      sellerPaymentMethods: (mapping['sellerPaymentMethods'] as List<dynamic>? ?? [])
          .map((e) => SellerPaymentMethod.fromJson(e as Map<String, dynamic>))
          .toList(),
      realtime: RealtimeConfig.fromJson(mapping['realtime'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
    'mapping': {
      'station': station.toJson(),
      'productHoses': productHoses.map((e) => e.toJson()).toList(),
      'methodPayment': methodPayment.map((e) => e.toJson()).toList(),
      'speedDial': speedDial.map((e) => e.toJson()).toList(),
      'fidelity': fidelity.map((e) => e.toJson()).toList(),
      'identifiers': identifiers.map((e) => e.toJson()).toList(),
      'sellerPaymentMethods': sellerPaymentMethods.map((e) => e.toJson()).toList(),
      'realtime': realtime.toJson(),
    },
  };

  @override
  String toString() =>
      'MappingModel(station: $station, productHoses: $productHoses, methodPayment: $methodPayment, speedDial: $speedDial, fidelity: $fidelity)';
}

// ---------------------------------------------------------------------------

/// Tiempo real de la pantalla (se configura en la Orange por serial): valor y avance mientras surte
class RealtimeConfig {
  final bool enabled;
  final int intervalMs; // cada cuanto se consulta el estado del surtidor
  final String style;

  const RealtimeConfig({this.enabled = false, this.intervalMs = 500, this.style = 'carrito'});

  factory RealtimeConfig.fromJson(Map<String, dynamic>? json) => json == null
      ? const RealtimeConfig()
      : RealtimeConfig(
          enabled: json['enabled'] == true,
          intervalMs: ((json['intervalMs'] as num?)?.toInt() ?? 500).clamp(200, 5000),
          style: json['style'] as String? ?? 'carrito',
        );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'intervalMs': intervalMs, 'style': style};
}

class StationData {
  final int id;
  final String name;
  final int flagId;
  final String flag;
  final int maximumChangeAmount;
  final bool hospitality; // la venta se cobra a la tarjeta: no hay vueltos

  StationData({
    required this.id,
    required this.name,
    required this.flagId,
    required this.flag,
    this.maximumChangeAmount = 0,
    this.hospitality = false,
  });

  factory StationData.fromJson(Map<String, dynamic> json) => StationData(
        id: json['id'] as int,
        name: json['name'] as String,
        flagId: json['flagid'] as int,
        flag: json['flag'] as String,
        maximumChangeAmount: json['maximum_change_amount'] as int? ?? 0,
        hospitality: json['hospitality'] == true || json['hospitality'] == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'flagid': flagId,
        'flag': flag,
        'maximum_change_amount': maximumChangeAmount,
        'hospitality': hospitality,
      };

  @override
  String toString() => 'StationData(id: $id, name: $name, flag: $flag)';
}

class Station {
  final StationData data;
  final List<String> colors; // lista de hex strings

  Station({
    required this.data,
    required this.colors,
  });

  factory Station.fromJson(Map<String, dynamic> json) => Station(
        data: StationData.fromJson(json['data'] as Map<String, dynamic>),
        colors: (json['colors'] as List<dynamic>)
            .map((e) => (e as Map<String, dynamic>)['color'] as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'data': data.toJson(),
        'colors': colors.map((c) => {'color': c}).toList(),
      };

  @override
  String toString() => 'Station(data: $data, colors: $colors)';
}

class ProductHose {
  final int dispenserId;
  final int dispenserSide;
  final int positionId;
  final int nsxPositionId;
  final int hoseId;
  final int hoseNumber;
  final int productId;
  final int nsxProductId;
  final String product;
  final String price;
  final int moneyFormat;
  final int priceFormat;
  final int volumeFormat;
  final String side;
  final String unitOfMeasurement;
  final String color;
  final double maxvalor;
  final String codigotankio;
  final bool activeHose;
  final bool activePosition;
  final bool hybrid; // el dispensador admite vendedor de paso
  final String? publicPrice; // precio del nivel configurado en la manguera (el que cobra la venta del vendedor); null si no se conoce
  final double? maxMoney; // mayor valor en dinero que acepta el surtidor de la posicion (6 o 7 digitos); null si no se conoce

  ProductHose({
    required this.dispenserId,
    required this.dispenserSide,
    required this.positionId,
    required this.nsxPositionId,
    required this.hoseId,
    required this.hoseNumber,
    required this.productId,
    required this.nsxProductId,
    required this.product,
    required this.price,
    required this.moneyFormat,
    required this.priceFormat,
    required this.volumeFormat,
    required this.side,
    required this.unitOfMeasurement,
    required this.color,
    required this.maxvalor,
    required this.codigotankio,
    required this.activeHose,
    required this.activePosition,
    this.hybrid = false,
    this.maxMoney,
    this.publicPrice,
  });

  factory ProductHose.fromJson(Map<String, dynamic> json) => ProductHose(
        dispenserId:  json['dispenserid'] as int,
        dispenserSide: json['dispenserside'] as int,
        positionId: json['positionid'] as int,
        nsxPositionId: json['nsxpositionid'] as int,
        hoseId: json['hoseid'] as int,
        hoseNumber: json['hosenumber'] as int,
        productId: json['productid'] as int,
        nsxProductId: json['nsxproductid'] as int,
        product: json['product'] as String,
        price: json['price'] as String,
        moneyFormat: json['moneyformat'] as int,
        priceFormat: json['priceformat'] as int,
        volumeFormat: json['volumeformat'] as int,
        side: json['side'] as String,
        unitOfMeasurement: json['unitofmeasurement'] as String,
        color: json['color'] as String,
        maxvalor: ((json['max_valor'] ?? json['maxvalor']) as num?)?.toDouble() ?? 999900.0,
        // El cache guardaba maxvalor y codigotankio con otro nombre: se aceptan ambos
        codigotankio: (json['codigo_tankio'] ?? json['codigotankio']) as String,
        activeHose: json['activehose'] as bool,
        activePosition: json['activeposition'] as bool,
        hybrid: json['hybrid'] as bool? ?? false,
        maxMoney: double.tryParse((json['maxmoney'] ?? json['maxMoney'] ?? '').toString()),
        publicPrice: json['publicprice']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'dispenserid': dispenserId,
        'dispenserside': dispenserSide,
        'positionid': positionId,
        'nsxpositionid': nsxPositionId,
        'hoseid': hoseId,
        'hosenumber': hoseNumber,
        'productid': productId,
        'nsxproductid': nsxProductId,
        'product': product,
        'price': price,
        'moneyformat': moneyFormat,
        'priceformat': priceFormat,
        'volumeformat': volumeFormat,
        'side': side,
        'unitofmeasurement': unitOfMeasurement,
        'color': color,
        'max_valor': maxvalor,
        'codigo_tankio': codigotankio,
        'activehose': activeHose,
        'activeposition': activePosition,
        'hybrid': hybrid,
        'maxmoney': maxMoney,
        'publicprice': publicPrice,
      };

  /// Precio con el que vende el vendedor: el de la manguera; si no esta, el de autoservicio
  String get sellerPrice => (publicPrice != null && (double.tryParse(publicPrice!) ?? 0) > 0) ? publicPrice! : price;

  @override
  String toString() =>
      'ProductHose(hoseId: $hoseId, product: $product, price: $price, side: $side, activeHose: $activeHose)';
}

// ---------------------------------------------------------------------------

class MethodPayment {
  final int idMethodPayment;
  final int nxsPaymentId;
  final String name;
  final String? logo;

  MethodPayment({
    required this.idMethodPayment,
    required this.nxsPaymentId,
    required this.name,
    this.logo,
  });

  factory MethodPayment.fromJson(Map<String, dynamic> json) => MethodPayment(
        idMethodPayment: json['idmethopayment'] as int,
        nxsPaymentId: json['nxspaymentid'] as int,
        name: json['name'] as String,
        logo: json['logo'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'idmethopayment': idMethodPayment,
        'nxspaymentid': nxsPaymentId,
        'name': name,
        if (logo != null) 'logo': logo,
      };

  @override
  String toString() => 'MethodPayment(id: $idMethodPayment, name: $name, logo: $logo)';
}
// ---------------------------------------------------------------------------

class SpeedDial {
  final int idSpeedDial;
  final double moneyValue;
  final double volumeValue;

  SpeedDial({
    required this.idSpeedDial,
    required this.moneyValue,
    required this.volumeValue,
  });

  factory SpeedDial.fromJson(Map<String, dynamic> json) => SpeedDial(
      idSpeedDial: json['idspeeddial'] as int,
      moneyValue: (json['moneyvalue'] as num).toDouble(),
      volumeValue: (json['volumevalue'] as num).toDouble(),
    );

  Map<String, dynamic> toJson() => {
        'idspeeddial': idSpeedDial,
        'moneyvalue': moneyValue,
        'volumevalue': volumeValue,
      };

  @override
  String toString() =>
      'SpeedDial(id: $idSpeedDial, moneyValue: $moneyValue, volumeValue: $volumeValue)';
}

class FidelityProgram {
  final int fidelityId;
  final int nsxFidelityId;
  final String fidelityName;

  FidelityProgram({
    required this.fidelityId,
    required this.nsxFidelityId,
    required this.fidelityName,
  });

  factory FidelityProgram.fromJson(Map<String, dynamic> json) => FidelityProgram(
    fidelityId: json['fidelity_id'] as int,
    nsxFidelityId: json['nsx_fidelity_id'] as int,
    fidelityName: json['fidelity_name'] as String,
  );

  Map<String, dynamic> toJson() => {
    'fidelity_id': fidelityId,
    'nsx_fidelity_id': nsxFidelityId,
    'fidelity_name': fidelityName,
  };

  @override
  String toString() => 'FidelityProgram(id: $fidelityId, name: $fidelityName)';
}

// Tipos de identificador del cliente: 1 iButton, 2 Teclado, 3 Placa
class IdentifierType {
  static const int iButton = 1;
  static const int keyboard = 2;
  static const int plate = 3;

  final int id;
  final String name;

  IdentifierType({required this.id, required this.name});

  factory IdentifierType.fromJson(Map<String, dynamic> json) => IdentifierType(
        id: json['identifierid'] as int,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'identifierid': id, 'name': name};

  @override
  String toString() => 'IdentifierType(id: $id, name: $name)';
}

// Forma de pago que el vendedor puede anclar a una venta
class SellerPaymentMethod {
  final int nsxPaymentId;
  final String name;

  SellerPaymentMethod({required this.nsxPaymentId, required this.name});

  factory SellerPaymentMethod.fromJson(Map<String, dynamic> json) => SellerPaymentMethod(
        nsxPaymentId: json['nsxpaymentid'] as int,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'nsxpaymentid': nsxPaymentId, 'name': name};

  @override
  String toString() => 'SellerPaymentMethod(id: $nsxPaymentId, name: $name)';
}