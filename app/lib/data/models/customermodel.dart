class CustomerModel {
  final int id;
  final String identifier;
  final String? name;
  final String? documentType;
  final String? email;
  final bool isAnonymous;
  // Placa/kilometraje ya registrados para este cliente (si los hay), para
  // no volver a pedirlos en el preset — igual quedan editables ahí.
  final String? licensePlate;
  final int? km;

  CustomerModel({
    required this.id,
    required this.identifier,
    this.name,
    this.documentType,
    this.email,
    this.isAnonymous = false,
    this.licensePlate,
    this.km,
  });

  // Un factory por si quieres crearlo desde el JSON de la DIAN
  factory CustomerModel.fromDianJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'],
      identifier: json['identificador'] ?? '',
      name: json['nombre'],
      documentType: json['tipo_documento'],
      email: json['correo'],
      isAnonymous: false,
      licensePlate: json['placa'] as String?,
      km: (json['km'] as num?)?.toInt(),
    );
  }

  // Factory para cliente anónimo rápido
  factory CustomerModel.anonymous() {
    return CustomerModel(
      id: 1, // ID de Consumidor Final
      identifier: "222222222222",
      name: "CONSUMIDOR FINAL",
      documentType: "NIT",
      isAnonymous: true,
    );
  }
}