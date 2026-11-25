import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gnesys_as/config/api_config.dart';
import 'package:gnesys_as/services/service.dart';

import '../data/models/models.dart';

class PumpService {

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  static Future<String> _baseUrl() async{
    final ip = await StorageService.getServerIp();
    final port = await StorageService.getServerPort();
    return "http://$ip:$port";
  }

  static Future<Estado> getEstado(int idPosicion) async {

    final baseUrl = await _baseUrl();

    final response = await _dio.get(
      "$baseUrl/api/Estado",
      queryParameters: {
        "NumPosicion": idPosicion
      }
    );

    return Estado.fromJson(response.data);
  }

  /// Obtiene el mapping desde el nuevo endpoint y lo guarda localmente.
  /// [screenId] corresponde al parámetro `screenid` del query (por defecto 1).
  static Future<MappingModel?> getMapping({int screenId = 1}) async {
    final baseUrl = await _baseUrl();
    final response = await _dio.get(
      "$baseUrl/nsx-autoservice-api/V1/mapping",
      queryParameters: {"screenid": screenId},
      options: Options(headers: {"x-api-key": ApiConfig.apiKey}),
    );
    
    if (response.statusCode != 200) {
      debugPrint("⚠️ [Mapping] Status inesperado: ${response.statusCode}");
      return null;
    }

    final mapping = MappingModel.fromJson(response.data);
    await StorageService.saveMapping(mapping);
    
    // Guarda colores y logo automáticamente
    await StorageService.saveStationColors(mapping.station.colors);
    String urllog = await ResourceService.getImageUrl('logo.png');
    await StorageService.saveLogoUrl(urllog);

    return mapping;
  }
 
  /// Devuelve el mapping guardado localmente sin hacer una llamada de red.
  /// Útil como fallback si el servidor no está disponible.
  static Future<MappingModel?> getCachedMapping() async {
    return StorageService.loadMapping();
  }
 
  /// Intenta obtener el mapping desde el servidor; si falla, usa el caché local.
  static Future<MappingModel?> getMappingWithFallback(int screenId ) async {
    try {
      return await getMapping(screenId: screenId) ?? StorageService.loadMapping();
    } on DioException {
      
      return StorageService.loadMapping();
    }
  }

  /// Consulta el estado actual del surtidor asociado a la posición NSX indicada.
  static Future<StatusPositionModel> getStatusPosition(int nsxPositionId) async {
    final baseUrl = await _baseUrl();

    final response = await _dio.get(
      "$baseUrl/nsx-autoservice-api/V1/nsx/status-position/$nsxPositionId",
      options: Options(headers: {"x-api-key": ApiConfig.apiKey}),
    );

    return StatusPositionModel.fromJson(response.data);
  }

  static Future<List<Mapeo>> getMapeo() async {
    
    final baseUrl = await _baseUrl();


    final response = await _dio.get("$baseUrl/api/Mapeo");

    final mapping = Mapeo.fromJsonList(response.data);

    return mapping;
  }

  List<int> obtenerPosiciones(List<Mapeo> mapping) {

    return mapping
        .map((e) => e.posicion)
        .toSet()
        .toList()
      ..sort();
  }

  


}