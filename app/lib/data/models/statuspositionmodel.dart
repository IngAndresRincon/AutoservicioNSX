/// Estados posibles del surtidor devueltos por
/// `nsx-autoservice-api/V1/nsx/status-position/{posicion}`.
enum PumpStatus {
  espera,
  surtiendo,
  autorizado,
  listo,
  error,
  inactivo,
  listoTotales,
  ventaZero,
  esperandoId,
  reporte,
  desconocido;

  static PumpStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'espera':
        return PumpStatus.espera;
      case 'surtiendo':
        return PumpStatus.surtiendo;
      case 'autorizado':
        return PumpStatus.autorizado;
      case 'listo':
        return PumpStatus.listo;
      case 'error':
        return PumpStatus.error;
      case 'inactivo':
        return PumpStatus.inactivo;
      case 'listototales':
        return PumpStatus.listoTotales;
      case 'ventazero':
        return PumpStatus.ventaZero;
      case 'esperandoid':
        return PumpStatus.esperandoId;
      case 'reporte':
        return PumpStatus.reporte;
      default:
        return PumpStatus.desconocido;
    }
  }

  /// Descripción legible del estado, útil para logs o mensajes al usuario.
  String get description {
    switch (this) {
      case PumpStatus.espera:
        return 'El equipo está disponible';
      case PumpStatus.surtiendo:
        return 'El dispensador está surtiendo combustible';
      case PumpStatus.autorizado:
        return 'El dispensador está esperando que levanten la manguera';
      case PumpStatus.listo:
        return 'Se levantó la manguera';
      case PumpStatus.error:
        return 'Hay un problema de comunicación con el dispensador';
      case PumpStatus.inactivo:
        return 'El dispensador no se encuentra disponible';
      case PumpStatus.listoTotales:
        return 'El dispensador pidió totales';
      case PumpStatus.ventaZero:
        return 'Se venció la autorización';
      case PumpStatus.esperandoId:
        return 'El dispensador está leyendo el chip';
      case PumpStatus.reporte:
        return 'El dispensador está reportando la venta';
      case PumpStatus.desconocido:
        return 'Estado desconocido';
    }
  }

  /// El cliente sólo puede iniciar una nueva operación cuando el
  /// surtidor está disponible (Espera) o recién liberado (Listo).
  bool get canContinue => this == PumpStatus.espera || this == PumpStatus.listo;
}

class StatusPositionData {
  final PumpStatus estadoSurtidor;
  final num dinero;
  final num volumen;
  final int grado;
  final int gradoPreset;

  StatusPositionData({
    required this.estadoSurtidor,
    required this.dinero,
    required this.volumen,
    required this.grado,
    required this.gradoPreset,
  });

  factory StatusPositionData.fromJson(Map<String, dynamic> json) => StatusPositionData(
        estadoSurtidor: PumpStatus.fromString(json['estadoSurtidor'] as String? ?? ''),
        dinero: json['dinero'] as num? ?? 0,
        volumen: json['volumen'] as num? ?? 0,
        grado: json['grado'] as int? ?? 0,
        gradoPreset: json['gradoPreset'] as int? ?? 0,
      );
}

class StatusPositionModel {
  final bool isError;
  final String message;
  final bool success;
  final String contentMessage;
  final StatusPositionData data;

  StatusPositionModel({
    required this.isError,
    required this.message,
    required this.success,
    required this.contentMessage,
    required this.data,
  });

  factory StatusPositionModel.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>;
    return StatusPositionModel(
      isError: json['isError'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      success: content['success'] as bool? ?? false,
      contentMessage: content['message'] as String? ?? '',
      data: StatusPositionData.fromJson(content['data'] as Map<String, dynamic>),
    );
  }
}
