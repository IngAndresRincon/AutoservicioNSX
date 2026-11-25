import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gnesys_as/config/api_config.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'service.dart';

class CustomerService {
  
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final NetworkInfo _networkInfo = NetworkInfo();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Future<String> _baseUrl() async{
    final ip = await StorageService.getServerIp();
    final port = await StorageService.getServerPort();
    return "http://$ip:$port";
  }

  Future<Map<String, dynamic>?> validateClient(String identifier, {bool cfClient = false}) async {
  try {
    final baseUrl = await _baseUrl();
    final screenId = await StorageService.getScreenNumber();

    final body = {
      "screenId": screenId,
      "identifier": identifier,
      "cf_client": cfClient,
    };

    final response = await _dio.post(
      "$baseUrl/nsx-autoservice-api/V1/client/validation",
      data: body,
      options: Options(
        headers: {"x-api-key": ApiConfig.apiKey},
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    if (response.statusCode == 200 && response.data['isError'] == false) {
      final content = response.data['content']['clientId'];

      if (cfClient) {
        // Retorna objeto completo
        return content as Map<String, dynamic>?;
      } else {
        // Retorna entero — lo envolvemos en un Map para unificar la interfaz
        if (content is int) {
          return {'id': content};
        } else if (content is Map) {
          return Map<String, dynamic>.from(content);
        }
      }
    }
  } catch (e) {
    debugPrint("Error validación interna: $e");
  }
  return null;
}

  Future<Map<String, dynamic>?> validateClientDIAN(String identifier) async {
    try {
      final baseUrl = await _baseUrl();
      
      final response = await _dio.get(
        "$baseUrl/nsx-autoservice-api/V1/client/validation-dian",
        queryParameters: {"identifier": identifier},
        options: Options(
          headers: {
            "x-api-key": ApiConfig.apiKey,
          },
          // 2. Opcional: Evita que Dio lance excepción en 403 para ver qué responde el server
          validateStatus: (status) => status! < 500, 
        ),
      );

      if (response.statusCode == 200) {
        if (response.data['isError'] == false) {
          return response.data['content']['clientId'];
        }
      }
      else if (response.statusCode == 404)
      {
        if (response.data['isError'] == true) {
          return response.data['message'];
        }
      }
      
    } catch (e) {
      print("Error inesperado: $e");
    }
    return null;
  }

  static const Map<String, int> _tipoDocDian = {
    'Cédula de ciudadanía': 13,
    'Cédula de extranjería': 22,
    'NIT': 31,
    'Pasaporte': 41,
  };

  Future<bool> generarFactura({
    required int saleId,
    required String documentNumber,
    required String documentType,
    required String companyName,
    required String email,
    bool isGnesys = false,
  }) async {
    try {
      final baseUrl = await _baseUrl();

      dynamic tipoDocValue;
      if (isGnesys) {
        // Si el tipo de documento no tiene un código DIAN reconocido, se
        // envía cédula de ciudadanía (13) por defecto en vez de mandar el
        // texto crudo (ej. "NIT") o fallar — GNESYS no debe bloquear la
        // factura por esto.
        tipoDocValue = _tipoDocDian[documentType] ?? 13;
      } else {
        final int? tipoDocCod = _tipoDocDian[documentType];
        if (tipoDocCod == null) {
          debugPrint('❌ Tipo de documento no reconocido: $documentType');
          return false;
        }
        tipoDocValue = tipoDocCod;
      }

      final body = {
        'saleId': saleId,
        'documentNumber': int.tryParse(documentNumber) ?? documentNumber,
        'documentType': tipoDocValue,
        'companyName': companyName,
        'email': email,
      };

      debugPrint('📄 Generando factura: $body');

      final response = await _dio.post(
        '$baseUrl/nsx-autoservice-api/V1/sale/bill',
        data: body,
        options: Options(
          headers: {'x-api-key': ApiConfig.apiKey},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data['isError'] == false) {
        debugPrint('✅ Factura generada correctamente');
        return true;
      }

      debugPrint('⚠️ Respuesta inesperada: ${response.data}');
      return false;
    } on DioException catch (e) {
      debugPrint('❌ Error DIO generarFactura: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error inesperado generarFactura: $e');
      return false;
    }
  }

  Future<bool> imprimirRecibo({required int saleId}) async {
  try {
    final baseUrl = await _baseUrl();
    final response = await _dio.get(
      '$baseUrl/nsx-autoservice-api/V1/nsx/print-sale',
      queryParameters: {'saleId': saleId},
      options: Options(
        headers: {'x-api-key': ApiConfig.apiKey},
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (status) => status! < 500, // acepta 2xx y 4xx sin lanzar excepción
      ),
    );

    final statusOk = (response.statusCode ?? 0) >= 200 && 
                     (response.statusCode ?? 0) < 300;
    
    if (!statusOk) return false;

    // Valida el body si existe
    if (response.data != null && response.data is Map) {
      final isError = response.data['isError'];
      final success = response.data['success'];
      if (isError == true) return false;
      if (success == false) return false;
    }

    return true;
  } on DioException catch (e) {
    debugPrint('❌ imprimirRecibo: ${e.message}');
    return false;
  } catch (e) {
    debugPrint('❌ imprimirRecibo inesperado: $e');
    return false;
  }
}

  Future<bool> validarVendedor({
    required String document,
    required String password,
  }) async {
    try {
      final baseUrl = await _baseUrl();
      final response = await _dio.post(
        '$baseUrl/nsx-autoservice-api/V1/nsx/shift/validate-seller',
        data: {'document': document, 'password': password},
        options: Options(
          headers: {'x-api-key': ApiConfig.apiKey},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (status) => status! < 500,
        ),
      );
      return response.statusCode == 200 &&
          (response.data['isError'] == false || response.data['success'] == true);
    } on DioException catch (e) {
      debugPrint('❌ validarVendedor: ${e.message}');
      return false;
    }
  }

  /// Guarda placa/kilometraje del vehículo para el cliente activo en sesión.
  /// Ambos datos son opcionales para el flujo — se puede omitir el sheet
  /// y el despacho continúa normal sin ellos.
  ///
  /// Retorna `null` si se guardó correctamente, o un mensaje de error para
  /// mostrarle al usuario (ej. en un SnackBar) si falló.
  Future<String?> addAdditionalInformation({
    required int clientId,
    String? licensePlate,
    int? km,
  }) async {
    try {
      final baseUrl = await _baseUrl();

      final body = {
        'clientId': clientId,
        'licensePlate': (licensePlate == null || licensePlate.trim().isEmpty)
            ? null
            : licensePlate.trim(),
        'km': km,
      };

      debugPrint('🚗 Guardando información adicional: $body');

      final response = await _dio.post(
        '$baseUrl/nsx-autoservice-api/V1/client/additional-information',
        data: body,
        options: Options(
          headers: {'x-api-key': ApiConfig.apiKey},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 && response.data['isError'] == false) {
        debugPrint('✅ Información adicional guardada');
        return null;
      }

      final msg = response.data?['message'] as String? ??
          'No se pudo guardar la información del vehículo';
      debugPrint('⚠️ Respuesta inesperada additional-information: ${response.data}');
      return msg;
    } on DioException catch (e) {
      debugPrint('❌ addAdditionalInformation: ${e.message}');
      return e.response?.data?['message'] as String? ?? 'Error de conexión';
    } catch (e) {
      debugPrint('❌ addAdditionalInformation inesperado: $e');
      return 'Error inesperado: $e';
    }
  }

  /// Manda a imprimir el código de trazabilidad de un cliente consumidor
  /// final en la impresora de la posición NSX indicada. Nota: este endpoint
  /// usa una API key distinta a la del resto de la app.
  Future<bool> imprimirCodigo({
    required int positionId,
    required String code,
  }) async {
    try {
      final baseUrl = await _baseUrl();

      final body = {
        'positionId': positionId,
        'code': code,
      };

      debugPrint('🖨️ Imprimiendo código: $body');

      final response = await _dio.post(
        '$baseUrl/nsx-autoservice-api/V1/system/print-code',
        data: body,
        options: Options(
          headers: {
            'x-api-key': ApiConfig.socketApiKey,
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status! < 500,
        ),
      );

      final statusOk = (response.statusCode ?? 0) >= 200 &&
          (response.statusCode ?? 0) < 300;
      if (!statusOk) {
        debugPrint('⚠️ Respuesta inesperada print-code: ${response.data}');
        return false;
      }

      if (response.data is Map && response.data['isError'] == true) {
        debugPrint('⚠️ print-code isError: ${response.data}');
        return false;
      }

      debugPrint('✅ Código enviado a imprimir');
      return true;
    } on DioException catch (e) {
      debugPrint('❌ imprimirCodigo: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ imprimirCodigo inesperado: $e');
      return false;
    }
  }
}