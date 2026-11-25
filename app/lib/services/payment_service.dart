import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gnesys_as/config/api_config.dart';
import 'package:gnesys_as/data/models/payment_result.dart';
import 'package:gnesys_as/services/service.dart';

import '../data/models/models.dart';
import '../data/enums/enums.dart'; // ajusta el import según tu estructura


class PaymentService {

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  static Future<String> _baseUrl() async {
    final ip   = await StorageService.getServerIp();
    final port = await StorageService.getServerPort();
    return "http://$ip:$port";
  }

  static Future<int?> _screenId() async {
    return await StorageService.getScreenNumber();
  }

  // -------------------------------------------------------------------------
  // POST /nsx-autoservice-api/V1/programming
  // -------------------------------------------------------------------------
  static Future<ProgrammingResult> createProgramming({
    required ProductHose hose,
    required double programmingValue,
    required ProgrammingType type,
    required CustomerModel customer,
  }) async {
    try {
      final baseUrl = await _baseUrl();
      int? screendId = await _screenId();

      final int programmingTypeInt;
      switch (type) {
        case ProgrammingType.dinero:
          programmingTypeInt = 2;
          break;
        case ProgrammingType.volumen:
          programmingTypeInt = 3;
          break;
        case ProgrammingType.full:
          programmingTypeInt = 1;
          break;
      }

      final body = {
        "clientId":         customer.id,
        "positionId":       hose.positionId,
        "hoseId":           hose.hoseId,
        "productId":        hose.productId,
        "price":            double.parse(hose.price),
        "programmingValue": programmingValue,
        "programmingType":  programmingTypeInt,
        "screendId":        screendId,
      };

      debugPrint("📡 [Programming] Body: $body");

      final response = await _dio.post(
        "$baseUrl/nsx-autoservice-api/V1/programming",
        data: body,
        options: Options(
          headers: {"x-api-key": ApiConfig.apiKey},
          validateStatus: (status) => status! < 600,
        ),
      );

      debugPrint("📡 [Programming] Response ${response.statusCode}: ${response.data}");

      if (response.statusCode != 200 && response.statusCode != 201) {
        final msg = response.data?['details'] 
            ?? response.data?['message'] 
            ?? 'Error al crear programación';
        throw Exception(msg);
      }

      return ProgrammingResult.fromJson(response.data);

    } on DioException catch (e) {
      debugPrint('❌ [Programming] DioException: ${e.message}');
      debugPrint('❌ [Programming] Response: ${e.response?.data}');
      throw Exception(e.response?.data?['message'] ?? 'Error de conexión al programar');
    } catch (e) {
      debugPrint('❌ [Programming] Error inesperado: $e');
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // POST /nsx-autoservice-api/V1/payment
  // -------------------------------------------------------------------------
  static Future<PaymentResult> createPayment({
    required int programmingId,
    required double totalAmount,
    required double amountToPay,
    required int paymentMethodId,
    String? qrData,
  }) async {
    final baseUrl = await _baseUrl();

    final body = {
      "programmingId": programmingId,
      "totalamount": totalAmount,
      "amounttopay": amountToPay,
      "paymentmethodId": paymentMethodId,
      "reference": qrData,
    };

    debugPrint("💳 [Payment] Body: $body");

    try {
      final response = await _dio.post(
        "$baseUrl/nsx-autoservice-api/V1/programming/create-payment",
        data: body,
        options: Options(headers: {"x-api-key": ApiConfig.apiKey}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final isError = response.data['isError'] as bool? ?? true;
        final message = response.data['message'] as String? ?? "Respuesta desconocida";
        
        int? id;
        if (!isError && response.data['content'] != null) {
          // Ajustado para acceder correctamente al objeto payment del JSON
          id = response.data['content']['payment']['id'];
        }

        return PaymentResult(
          success: !isError, 
          message: message, 
          paymentId: id
        );
      }
      
      // Retorno de seguridad si el status no es 200/201
      return PaymentResult(success: false, message: "Error de servidor: ${response.statusCode}");

    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? "Error de conexión";
      return PaymentResult(success: false, message: msg.toString());
    } catch (e) {
      // Retorno para cualquier otro error inesperado
      return PaymentResult(success: false, message: "Error inesperado: $e");
    }
  }

  static Future<bool> enviarVueltos({
    required int presetId,
    required double amount,
    required int methodPaymentId,
    String? contact,
  }) async {
    try {
      final baseUrl = await _baseUrl();

      final String contactValue = (contact == null || contact.isEmpty) ? '' : contact;

      final body = {
        'presetId': presetId,
        'amount': amount.toInt(),
        'methodPaymentId': methodPaymentId,
        'contact': contactValue,
      };

      debugPrint('💰 Enviando vueltos: ${jsonEncode(body)}');

      final response = await _dio.post(
        '$baseUrl/nsx-autoservice-api/V1/nsx/change',
        data: body,
        options: Options(
          headers: {'x-api-key': ApiConfig.apiKey},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data['isError'] == false) {
        debugPrint('✅ Vueltos enviados correctamente');
        return true;
      }

      debugPrint('⚠️ Respuesta inesperada vueltos: ${response.data}');
      return false;
    } on DioException catch (e) {
      debugPrint('❌ Error DIO enviarVueltos: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error inesperado enviarVueltos: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getPendingAuthorization({
    required int userId,
  }) async {
    try {
      final baseUrl = await _baseUrl();
      final response = await _dio.get(
        '$baseUrl/nsx-autoservice-api/V1/programming/pending-authorization',
        queryParameters: {'userId': userId},
        options: Options(headers: {'x-api-key': ApiConfig.apiKey}),
      );
      if (response.statusCode == 200 && response.data['isError'] == false) {
        return response.data['content']['authorization'] as Map<String, dynamic>?;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ getPendingAuthorization: ${e.message}');
      return null;
    }
  }

  static Future<bool> resendAuthorization({required int authorizationId}) async {
    try {
      final baseUrl = await _baseUrl();
      final response = await _dio.patch(
        '$baseUrl/nsx-autoservice-api/V1/programming/resend-authorization',
        queryParameters: {'authorizationId': authorizationId},
        options: Options(headers: {'x-api-key': ApiConfig.apiKey}),
      );
      return response.statusCode == 200 && response.data['isError'] == false;
    } on DioException catch (e) {
      debugPrint('❌ resendAuthorization: ${e.message}');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> validateQRCode({
    required String code,
  }) async {
    try {
      final baseUrl = await _baseUrl();
      final response = await _dio.get(
        '$baseUrl/nsx-autoservice-api/V1/nsx/change/$code',
        options: Options(headers: {'x-api-key': ApiConfig.apiKey}),
      );

      if (response.statusCode == 200 && response.data['isError'] == false) {
        return response.data['content'] as Map<String, dynamic>?;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ validateQRCode: ${e.message}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getPendingProgramming({
    required int userId,
  }) async {
    try {
      final baseUrl = await _baseUrl();
      final response = await _dio.get(
        '$baseUrl/nsx-autoservice-api/V1/programming/pending-programming',
        queryParameters: {'userId': userId},
        options: Options(
          headers: {'x-api-key': ApiConfig.apiKey},
          validateStatus: (status) => status! < 500,
        ),
      );
      if (response.statusCode == 200 && response.data['isError'] == false) {
        return response.data['content']['programming'] as Map<String, dynamic>?;
      }
      return null; // 204 o sin datos
    } on DioException catch (e) {
      debugPrint('❌ getPendingProgramming: ${e.message}');
      return null;
    }
  }

  static Future<bool> authorizeProgramming({
    required int clientId,
    required int programmingId,
  }) async {
    try {
      final baseUrl = await _baseUrl();
      final response = await _dio.patch(
        '$baseUrl/nsx-autoservice-api/V1/programming/authorize-programming/$clientId/$programmingId',
        options: Options(headers: {'x-api-key': ApiConfig.apiKey}),
      );
      return response.statusCode == 200 &&
          (response.data['isError'] == false || response.data['success'] == true);
    } on DioException catch (e) {
      debugPrint('❌ authorizeProgramming: ${e.message}');
      return false;
    }
  }
}