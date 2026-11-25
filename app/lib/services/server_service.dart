import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'storage_service.dart'; // Ajusta tu import

class LocalApiServer {
  static HttpServer? _server;

  static Future<void> start() async {
    final app = shelf_router.Router();

    // Endpoint: POST /api/config/videos
    app.post('/api/config/videos', (Request request) async {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);

        if (data.containsKey('standby_video')) {
          await StorageService.setStandbyVideo(data['standby_video']);
        }
        
        if (data.containsKey('dispensing_video')) {
          await StorageService.setDispensingVideo(data['dispensing_video']);
        }

        return Response.ok(jsonEncode({
          "status": "success",
          "message": "Configuración de videos actualizada"
        }), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({"error": e.toString()}));
      }
    });

    try {
      // 1. Ahora sí usamos await porque la función es asíncrona
      String ip = await getDeviceIp();
      
      // 2. Escuchamos en anyIPv4 (para estabilidad), pero mostramos tu IP real en consola
      _server = await io.serve(app.call, InternetAddress.anyIPv4, 8080);
      debugPrint('🚀 Servidor REST Local escuchando peticiones en: http://$ip:${_server!.port}');
    } catch (e) {
      debugPrint('❌ Error iniciando servidor local: $e');
    }
  }

  static void stop() {
    _server?.close(force: true);
    debugPrint('🛑 Servidor REST Local detenido');
  }

  // 3. Volvimos esta función estática para poder llamarla desde start()
  static Future<String> getDeviceIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false, 
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint("Error obteniendo IP: $e");
    }
    return "127.0.0.1"; // Fallback por si acaso
  }
}