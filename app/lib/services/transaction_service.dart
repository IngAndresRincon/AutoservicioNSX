import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gnesys_as/config/api_config.dart';

import 'service.dart';

class TransactionService {

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

  static Future<Map<String, dynamic>?> getSaleData(int authorizationId) async {
    try {
      final baseUrl = await _baseUrl();
      final url = "$baseUrl/nsx-autoservice-api/V1/sale";
      
      debugPrint("📡 Consultando datos de venta para AuthID: $authorizationId");

      final response = await _dio.get(
        url,
        queryParameters: {'authorizationId': authorizationId},
        options: Options(headers: {"x-api-key": ApiConfig.apiKey})
      );

      if (response.statusCode == 200) {
        final resData = response.data;
        
        // Validamos la estructura del JSON que nos enviaste
        if (resData['isError'] == false && resData['content']['success'] == true) {
          debugPrint("✅ Datos de venta recuperados con éxito");
          return resData['content']['data']['venta'];
        }
      }
      
      return null;
    } on DioException catch (e) {
      debugPrint("❌ Error en TransactionService (getSaleData): ${e.message}");
      return null;
    } catch (e) {
      debugPrint("❌ Error inesperado: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getLastSale({
    required int dispenserId,
    required int sideId,
  }) async {
    try {
      final baseUrl = await _baseUrl();
      final url = "$baseUrl/nsx-autoservice-api/V1/nsx/last-sale/$dispenserId/$sideId";

      debugPrint("📡 Consultando última venta — dispenser: $dispenserId, side: $sideId");

      final response = await _dio.get(
        url,
        options: Options(headers: {"x-api-key": ApiConfig.apiKey}),
      );

      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData['isError'] == false && resData['content']['success'] == true) {
          debugPrint("✅ Última venta recuperada con éxito");
          return resData['content']['data'] as Map<String, dynamic>;
        }
      }

      return null;
    } on DioException catch (e) {
      debugPrint("❌ Error en TransactionService (getLastSale): ${e.message}");
      return null;
    } catch (e) {
      debugPrint("❌ Error inesperado: $e");
      return null;
    }
  }
}