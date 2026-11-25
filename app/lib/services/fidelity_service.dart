import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gnesys_as/config/api_config.dart';

import 'service.dart';

/// Resultado de una llamada al servicio de fidelización (Puntos Colombia,
/// etc.) — unifica el caso de éxito y de error, ya que el backend responde
/// con formas distintas para cada uno (`content` vs `details`).
class FidelityResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  FidelityResult({
    required this.success,
    required this.message,
    this.data,
  });
}

class FidelityService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Future<String> _baseUrl() async {
    final ip = await StorageService.getServerIp();
    final port = await StorageService.getServerPort();
    return "http://$ip:$port";
  }

  static Future<FidelityResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final baseUrl = await _baseUrl();

      debugPrint('⭐ [Fidelity] POST $path: $body');

      final response = await _dio.post(
        '$baseUrl$path',
        data: body,
        options: Options(
          headers: {'x-api-key': ApiConfig.apiKey},
          // El backend puede responder con un status de error (ej. 502) y
          // aun así traer el detalle útil (isError/details.message) en el
          // body — se acepta cualquier status para no perder ese mensaje
          // por culpa de que Dio lo convierta en excepción.
          validateStatus: (status) => true,
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return FidelityResult(
          success: false,
          message: 'Respuesta inesperada del servidor (${response.statusCode})',
        );
      }

      final bool isError = data['isError'] as bool? ?? true;

      if (!isError) {
        final content = data['content'] as Map<String, dynamic>?;
        return FidelityResult(
          success: content?['success'] as bool? ?? true,
          message: content?['message'] as String? ??
              data['message'] as String? ??
              'Operación exitosa',
          data: content?['data'] as Map<String, dynamic>?,
        );
      }

      // Error: el mensaje útil para mostrarle al cliente viene en details.message.
      final details = data['details'] as Map<String, dynamic>?;
      return FidelityResult(
        success: false,
        message: details?['message'] as String? ??
            data['message'] as String? ??
            'No se pudo completar la operación',
      );
    } on DioException catch (e) {
      debugPrint('❌ [Fidelity] ($path): ${e.message}');
      return FidelityResult(success: false, message: 'Error de conexión');
    } catch (e) {
      debugPrint('❌ [Fidelity] ($path) inesperado: $e');
      return FidelityResult(success: false, message: 'Error inesperado');
    }
  }

  /// Valida si el documento ya está registrado en el programa de
  /// fidelización, sin acumular puntos todavía (el backend espera
  /// `saleId: 0` para esta consulta).
  static Future<FidelityResult> validateCustomer({
    required int fidelityTypeId,
    required int documentType,
    required String documentNumber,
  }) {
    return _post('/nsx-autoservice-api/V1/nsx/fidelity/validate-customer', {
      'fidelityTypeId': fidelityTypeId,
      'saleId': 0,
      'documentType': documentType,
      'documentNumber': documentNumber,
    });
  }

  /// Acumula los puntos de la venta indicada para el documento dado.
  static Future<FidelityResult> accumulate({
    required int fidelityTypeId,
    required int saleId,
    required int documentType,
    required String documentNumber,
    String? customerName,
  }) {
    return _post('/nsx-autoservice-api/V1/nsx/fidelity', {
      'fidelityTypeId': fidelityTypeId,
      'saleId': saleId,
      'documentType': documentType,
      'documentNumber': documentNumber,
      if (customerName != null && customerName.isNotEmpty) 'customerName': customerName,
    });
  }
}
