import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gnesys_as/config/api_config.dart';
import 'package:gnesys_as/data/models/seller_models.dart';
import 'package:gnesys_as/services/storage_service.dart';

class SellerException implements Exception {
  final String message;
  final int? statusCode;
  final bool sessionExpired;

  SellerException(this.message, {this.statusCode, this.sessionExpired = false});

  @override
  String toString() => message;
}

/// Vendedor de paso: sesion (token en memoria, 8 h) y llamadas a /seller de la Orange.
class SellerService {
  static SellerSession? _session;
  static DateTime _lastActivity = DateTime.now();

  /// Sin tocar la pantalla durante este tiempo se cierra la sesion (el turno no se cierra)
  static const Duration inactivityLimit = Duration(minutes: 5);

  /// Ultimas combinaciones programadas en este turno (mas reciente primero) y la ultima eleccion
  static final List<SellerRecent> recents = [];
  static int? lastHoseNumber;
  static int? lastHoseId;
  static int lastType = 2;

  static void addRecent(SellerRecent recent) {
    recents.remove(recent);
    recents.insert(0, recent);
    if (recents.length > 3) recents.removeLast();
  }

  /// idTurno de NSX del turno abierto en esta sesion (null si no se ha abierto)
  static final ValueNotifier<int?> shiftId = ValueNotifier<int?>(null);

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (_) => true,
    ),
  );

  static SellerSession? get session {
    if (_session != null && (_session!.isExpired || DateTime.now().difference(_lastActivity) > inactivityLimit)) {
      logout();
    }
    return _session;
  }

  /// Se llama en cada toque de pantalla del vendedor
  static void touch() => _lastActivity = DateTime.now();

  static bool get isLoggedIn => session != null;

  static void logout() {
    _session = null;
    shiftId.value = null;
    recents.clear();
  }

  static Future<String> _baseUrl() async {
    final ip = await StorageService.getServerIp();
    final port = await StorageService.getServerPort();
    return 'http://$ip:$port/nsx-autoservice-api/V1';
  }

  /// Devuelve `content` de la respuesta o lanza [SellerException] con el motivo real
  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    Duration? timeout,
  }) async {
    final headers = <String, dynamic>{'x-api-key': ApiConfig.apiKey};
    if (auth) {
      final current = session;
      if (current == null) {
        throw SellerException('La sesión del vendedor expiró, inicie sesión de nuevo', statusCode: 401, sessionExpired: true);
      }
      headers['Authorization'] = 'Bearer ${current.token}';
    }

    try {
      final response = await _dio.request(
        '${await _baseUrl()}$path',
        data: body,
        options: Options(method: method, headers: headers, receiveTimeout: timeout),
      );

      final data = response.data;
      final status = response.statusCode ?? 0;
      final message = data is Map ? (data['message'] as String? ?? 'Error desconocido') : 'Error desconocido';

      if (status >= 200 && status < 300 && data is Map && data['isError'] == false) {
        return Map<String, dynamic>.from((data['content'] as Map?) ?? {});
      }

      final expired = auth && status == 401;
      if (expired) {
        logout();
      }
      throw SellerException(message, statusCode: status, sessionExpired: expired);
    } on DioException catch (e) {
      debugPrint('❌ [Seller] $path: ${e.message}');
      throw SellerException('No fue posible comunicarse con el servidor');
    }
  }

  static Future<SellerSession> login(String document, String password) async {
    final content = await _request(
      'POST',
      '/seller/login',
      body: {'document': document, 'password': password},
      auth: false,
    );
    _session = SellerSession.fromContent(content);
    _lastActivity = DateTime.now();
    // Si ya tiene turno abierto en NSX (en este u otro equipo) se toma de una vez, sin pedirlo de nuevo
    final shift = content['shift'];
    shiftId.value = shift is Map ? (shift['nsxShiftId'] as num?)?.toInt() : null;
    return _session!;
  }

  static Future<void> openShift({required int positionId, required String password}) async {
    final content = await _request(
      'POST',
      '/seller/shift/open',
      body: {'positionId': positionId, 'password': password},
    );
    shiftId.value = (content['idTurno'] as num?)?.toInt();
  }

  static Future<void> closeShift({required int positionId, required String password}) async {
    await _request(
      'POST',
      '/seller/shift/close',
      body: {'positionId': positionId, 'password': password},
    );
    shiftId.value = null;
    recents.clear();
  }

  static Future<List<SellerPosition>> getPositions(int screenId) async {
    final content = await _request('GET', '/seller/positions?screenId=$screenId');
    return (content['positions'] as List<dynamic>? ?? [])
        .map((e) => SellerPosition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<SellerPreset> getPreset(int id) async =>
      SellerPreset.fromJson(await _request('GET', '/seller/preset/$id'));

  /// Espera a que el surtidor lea el tag (iButton o teclado) y devuelve el serial; falla si no se lee a tiempo
  static Future<String> readIdentifier({required int positionId, required int type, int timeoutSeconds = 30}) async {
    final content = await _request(
      'POST',
      '/client/identifier/read',
      body: {'positionId': positionId, 'type': type, 'timeoutSeconds': timeoutSeconds},
      timeout: Duration(seconds: timeoutSeconds + 15),
    );
    final serial = content['serial'];
    if (serial == null || serial.toString().isEmpty) throw SellerException('No se leyó el identificador');
    return serial.toString();
  }

  /// Autoriza al cliente de credito y programa el surtidor; la venta queda en el turno del vendedor
  static Future<SellerPreset> authorizeCredit({
    required int positionId,
    required int hoseNumber,
    required int programmingType,
    required double value,
    required SellerCredit credit,
    int? km,
  }) async {
    final content = await _request(
      'POST',
      '/client/authorize',
      body: {
        'positionId': positionId,
        'hoseNumber': hoseNumber,
        'programmingType': programmingType,
        'value': value,
        'identifierType': credit.identifierType,
        'serial': credit.serial,
        if (credit.key != null && credit.key!.isNotEmpty) 'key': credit.key,
        if (km != null) 'km': km,
      },
      timeout: const Duration(seconds: 40),
    );
    return SellerPreset.fromJson(content);
  }

  static Future<SellerPreset> getClientPreset(int id) async =>
      SellerPreset.fromJson(await _request('GET', '/client/preset/$id'));

  /// Ventas del vendedor en su turno abierto, la mas reciente primero
  static Future<List<SellerShiftSale>> getShiftSales() async {
    final content = await _request('GET', '/seller/sales');
    return (content['sales'] as List<dynamic>? ?? [])
        .map((e) => SellerShiftSale.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Venta del preset (por el id del preset en NSX): dinero, volumen, precio, formas de pago, fidelidad
  static Future<Map<String, dynamic>> getSale(int presetNsxId) async {
    final content = await _request('GET', '/nsx/sale/preset/$presetNsxId', auth: false);
    final data = content['data'];
    if (data is! Map) throw SellerException('No se encontró la venta');
    return Map<String, dynamic>.from(data);
  }

  /// Agrega formas de pago a una venta del vendedor; lo que no se ancla queda en efectivo
  static Future<void> savePayments(int saleId, List<SellerPayLine> lines) async {
    await _request('POST', '/seller/sale/payments', body: {
      'saleId': saleId,
      'paymentMethods': [
        for (final line in lines)
          {
            'paymentMethodId': line.paymentId,
            'amount': line.amount,
            if (line.reference.isNotEmpty) 'reference': line.reference,
          },
      ],
    });
  }

  static Future<void> cancelPreset(int positionId) async {
    await _request('POST', '/seller/preset/cancel', body: {'positionId': positionId});
  }

  /// programmingType: 1 lleno, 2 dinero, 3 volumen
  static Future<SellerPreset> createPreset({
    required int positionId,
    required int hoseNumber,
    required int programmingType,
    required double value,
    String? plate,
    int? km,
  }) async {
    final content = await _request('POST', '/seller/preset', body: {
      'positionId': positionId,
      'hoseNumber': hoseNumber,
      'programmingType': programmingType,
      'value': value,
      if (plate != null && plate.isNotEmpty) 'plate': plate,
      if (km != null) 'km': km,
    });
    return SellerPreset.fromJson(content);
  }
}
