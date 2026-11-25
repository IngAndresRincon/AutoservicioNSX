import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:gnesys_as/config/api_config.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'service.dart';

class ConfigurationService {
  
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final NetworkInfo _networkInfo = NetworkInfo();

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

  Future<String> getPersistentHardwareId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        // El ID de Android sobrevive a la limpieza de datos/caché. 
        // Solo cambia si se restablece el equipo a valores de fábrica.
        return androidInfo.id; 
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        // En iOS, esto es único por proveedor. 
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      }
    } catch (e) {
      return 'fallback_id_${DateTime.now().millisecondsSinceEpoch}';
    }
    return 'unsupported_platform';
  }
  static Future <String> getDeviceSerial() async {
  try {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id ?? 'Desconocido';
    }

    return 'No soportado';
  } catch (e) {
    return 'Error obteniendo serial';
  }
}

  Future<String> getDeviceIp() async {
    String? ip = await _networkInfo.getWifiIP();
    return ip ?? '0.0.0.0';
  }

  Future<Map<String, dynamic>?> synchronizeScreen(String serial, String ip) async {
    try
    {
      print("Enviando al servidor - ID: $serial, IP: $ip");
      ip = ip + ':8080';
      final body = {
        "serial":   serial,
        "ip":       ip,
      };
      final baseUrl = await _baseUrl();

      final response = await _dio.post(
        "$baseUrl/nsx-autoservice-api/V1/system/synchronize-screen",
        data: body,
        options: Options(headers: {"x-api-key": ApiConfig.apiKey}),
      );
      if(response.statusCode == 200)
      {
        return response.data;
      }
    }
    on DioException catch (e) {
      print("Error en la petición: ${e.message}");
      if (e.response != null) {
        print("Data del error: ${e.response?.data}");
        // El mensaje del servidor (p. ej. "No se encuentra pantalla asociada al sistema") llega a la pantalla en vez de "Error desconocido"
        final data = e.response?.data;
        if (data is Map && data['message'] is String) {
          return {'isError': true, 'message': data['message']};
        }
      }
      if (e.response == null) {
        return {'isError': true, 'message': 'No se pudo conectar con el servidor (${e.message ?? 'sin respuesta'})'};
      }
    } catch (e) {
      print("Error inesperado: $e");
    }
    return null;
  }
}