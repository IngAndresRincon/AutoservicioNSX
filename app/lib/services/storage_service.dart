import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gnesys_as/data/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class StorageService {

  static const String _serverIpKey = "server_ip";
  static const String _serverPortKey = "server_port";
  static const String _standbyVideoKey = "standby_video_name";
  static const String _dispensingVideoKey = "dispensing_video_name";
  static const _mappingKey = "pump_mapping";
  static const _kMappingKey = 'cached_mapping';
  static const String _primaryColorKey = 'station_color_primary';
  static const String _secondaryColorKey = 'station_color_secondary';
  static const String _accentColorKey = 'station_color_accent';
  static const String _logoUrlKey = 'logo.png';

  // Guardar IP
  static Future<void> setServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverIpKey, ip);
  }

  // Leer IP
  static Future<String?> getServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverIpKey);
  }

  // Guardar puerto
  static Future<void> setServerPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_serverPortKey, port);
  }

  // Leer puerto
  static Future<int?> getServerPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_serverPortKey);
  }

  static final ValueNotifier<String?> videoUpdateNotifier = ValueNotifier(null);

  static Future<void> setStandbyVideo(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_standbyVideoKey, name);

    videoUpdateNotifier.value = name;
  }

  static Future<String> getStandbyVideo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_standbyVideoKey) ?? 'video.mp4';
  }

  static Future<void> setDispensingVideo(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dispensingVideoKey, name);
  }

  static Future<String> getDispensingVideo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dispensingVideoKey) ?? 'video.mp4';
  }

  


  static Future<void> saveMapping(MappingModel mapping) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = jsonEncode(mapping.toJson());
  await prefs.setString(_kMappingKey, jsonString);

  
}
 
// Carga y deserializa el MappingModel guardado localmente.
// Retorna null si no hay ninguno guardado aún.
static Future<MappingModel?> loadMapping() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString(_kMappingKey);
  if (jsonString == null) return null;
  final Map<String, dynamic> json = jsonDecode(jsonString);
  return MappingModel.fromJson(json);
}
 
// Elimina el mapping guardado (útil al cerrar sesión o resetear config)
static Future<void> clearMapping() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kMappingKey);
}

  static Future<void> saveMapeo(List<Mapeo> mapeo) async {

    final prefs = await SharedPreferences.getInstance();

    final jsonList = mapeo.map((e) => e.toJson()).toList();

    await prefs.setString(
      _mappingKey,
      jsonEncode(jsonList)
    );
  }

  static Future<List<Mapeo>?> getMapeo() async {

    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_mappingKey);

    if(data == null) return null;

    final List decoded = jsonDecode(data);

    return Mapeo.fromJsonList(decoded);
  }

  static Future<void> setScreenNumber(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('screen_number', value);
  }

  static Future<int?> getScreenNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('screen_number');
  }

  static Future<void> saveStationColors(List<String> colors) async {
    final prefs = await SharedPreferences.getInstance();
    if (colors.isNotEmpty) await prefs.setString(_primaryColorKey, colors[0]);
    if (colors.length > 1) await prefs.setString(_secondaryColorKey, colors[1]);
    if (colors.length > 2) await prefs.setString(_accentColorKey, colors[2]);
  }

  static Future<Color> getPrimaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getString(_primaryColorKey)?.replaceAll('#', '') ?? 'FF1E88E5';
    return Color(int.parse(hex.padLeft(8, 'F'), radix: 16));
  }

  static Future<Color> getSecondaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getString(_secondaryColorKey)?.replaceAll('#', '') ?? 'FF2F80ED';
    return Color(int.parse(hex.padLeft(8, 'F'), radix: 16));
  }

  static Future<Color> getAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getString(_accentColorKey)?.replaceAll('#', '') ?? 'FF56CCF2';
    return Color(int.parse(hex.padLeft(8, 'F'), radix: 16));
  }

  static Future<void> saveLogoUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logoUrlKey, url);
  }

  static Future<String?> getLogoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_logoUrlKey);
  }

  static Future<bool> getModoKiosco() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('modo_kiosco') ?? false;
  }

  static Future<void> setModoKiosco(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modo_kiosco', value);
  }

  static Future<double> getVideoVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('video_volume') ?? 0.5;
  }

  static Future<void> setVideoVolume(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('video_volume', value);
  }

  /// MAC de cada interfaz de red (eth0, wlan0...) leida del sistema, este o no conectada
  static Future<Map<String, String>> getNetworkMacs() async {
    final macs = <String, String>{};
    final names = <String>{};
    try {
      final dir = Directory('/sys/class/net');
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          names.add(entity.path.split('/').last);
        }
      }
    } catch (e) {
      debugPrint('❌ Error listando interfaces: $e');
    }
    try {
      final interfaces = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
      names.addAll(interfaces.map((i) => i.name));
    } catch (e) {
      debugPrint('❌ Error listando interfaces con IP: $e');
    }

    for (final name in names.where((n) => n.startsWith('eth') || n.startsWith('wlan')).toList()..sort()) {
      try {
        final file = File('/sys/class/net/$name/address');
        if (!await file.exists()) continue;
        final mac = (await file.readAsString()).trim().toUpperCase().replaceAll(':', '');
        if (mac.isNotEmpty && mac != '000000000000') macs[name] = mac;
      } catch (_) {}
    }
    return macs;
  }

  /// Serial de la tablet = MAC de una interfaz, siempre la misma: la cableada (eth) si existe; si no, la ultima guardada;
  /// si nunca hubo cable, la Wi-Fi (wlan). Antes salia la primera interfaz con IP, y el serial cambiaba segun cual estuviera conectada.
  static Future<String> getDeviceSerial() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final macs = await getNetworkMacs();
      final eth = macs.entries.where((e) => e.key.startsWith('eth')).map((e) => e.value).firstOrNull;
      if (eth != null) {
        await prefs.setString('device_serial_mac', eth);
        debugPrint('[SocketDiag] Serial leido de la MAC cableada: $eth');
        return eth;
      }

      final saved = prefs.getString('device_serial_mac');
      if (saved != null) return saved;

      final wlan = macs.entries.where((e) => e.key.startsWith('wlan')).map((e) => e.value).firstOrNull;
      if (wlan != null) {
        await prefs.setString('device_serial_mac', wlan);
        debugPrint('[SocketDiag] Serial leido de la MAC Wi-Fi: $wlan');
        return wlan;
      }
    } catch (e) {
      debugPrint('❌ Error leyendo MAC: $e');
    }

    // Fallback: UUID persistente si no se puede leer la MAC
    String? serial = prefs.getString('device_serial');
    if (serial == null) {
      serial = const Uuid().v4().toUpperCase().replaceAll('-', '').substring(0, 12);
      await prefs.setString('device_serial', serial);
    }
    debugPrint('[SocketDiag] No se pudo leer la MAC, se usa serial de respaldo: $serial');
    return serial;
  }

  // Cámara del escáner QR que ya se comprobó que funciona en este equipo
  // (rawValue de CameraFacing: 0=front, 1=back, 2=external). Evita tener
  // que reintentar cámara por cámara cada vez que se abre el scanner.
  static const String _qrCameraFacingKey = 'qr_scanner_camera_facing';

  static Future<void> setQrCameraFacing(int rawFacing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_qrCameraFacingKey, rawFacing);
  }

  static Future<int?> getQrCameraFacing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_qrCameraFacingKey);
  }

  static Future<void> clearQrCameraFacing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_qrCameraFacingKey);
  }

  // Rotación (en cuartos de vuelta, 0-3) que endereza la vista de la cámara
  // del escáner QR en este equipo. La cámara puede quedar montada
  // físicamente girada de forma distinta según el hardware, así que en vez
  // de asumir un giro fijo, se deja que quien instala el equipo la ajuste
  // una vez (botón de rotar en la propia hoja) y se recuerda desde entonces.
  static const String _qrCameraRotationKey = 'qr_scanner_camera_rotation';

  static Future<void> setQrCameraRotation(int quarterTurns) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_qrCameraRotationKey, quarterTurns % 4);
  }

  static Future<int?> getQrCameraRotation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_qrCameraRotationKey);
  }
}