import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gnesys_as/services/service.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class ResourceService {
  // Singleton para acceso global
  static Future<String> _baseMediaUrl() async {
    final ip = await StorageService.getServerIp();
    final port = await StorageService.getServerPort();
    // Centralizamos la ruta de la carpeta de medios
    return "http://$ip:$port";
  }

  static Future<String> _baseServerUrl() async {
    return "http://nsx2.insepet.com:82/AutoService";
  }

  static Future<String> getVideoUrl(String fileName) async {
    final baseUrl = await _baseMediaUrl();
    return "$baseUrl/mediav/$fileName";
  }

  /// Retorna la URL para imágenes/logos hospedados en el servidor
  static Future<String> getImageUrl(String imageName) async {
    final baseUrl = await _baseMediaUrl();
    return "$baseUrl/mediai/$imageName";
  }

  /// Retorna la URL para audios hospedados en el servidor
  static Future<String> getAudioUrl(String imageName) async {
    final baseUrl = await _baseMediaUrl();
    return "$baseUrl/media/$imageName";
  }

  static Future<String> getApkUrl() async {
    final baseUrl = await _baseMediaUrl();
    return '$baseUrl/mediav/app.apk';
  }

  static Future<bool> descargarEInstalarActualizacion({
    required Function(double progreso) onProgress,
  }) async {
    try {
      final apkUrl = await getApkUrl();
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/app_update.apk';

      final dio = Dio();
      await dio.download(
        apkUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received / total);
        },
      );

      final result = await OpenFile.open(apkPath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('❌ descargarActualizacion: $e');
      return false;
    }
  }

  static Future<String> getVersionsUrl() async {
    final baseUrl = await _baseServerUrl();
    return '$baseUrl/versions.json';
  }

  static Future<String> fetchVersionsJson(String url) async {
    final dio = Dio();
    final response = await dio.get(url);
    return jsonEncode(response.data);
  }

  static Future<bool> descargarEInstalarDesdeUrl({
    required String url,
    required Function(double) onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/update.apk';
      final dio = Dio();
      await dio.download(url, apkPath, onReceiveProgress: (r, t) {
        if (t > 0) onProgress(r / t);
      });
      final result = await OpenFile.open(apkPath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('❌ descargarEInstalarDesdeUrl: $e');
      return false;
    }
  }
}