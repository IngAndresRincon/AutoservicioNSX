import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../../services/service.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../widgets/widgets.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController = TextEditingController();
  
  bool _modoKiosco = false;

  String deviceSerial = "Cargando...";
  Map<String, String> networkMacs = {}; // MAC de cada interfaz (eth0, wlan0...): el serial usa siempre la cableada si existe
  String deviceIp = "Cargando...";
  int? screenNumber;
  bool isSyncing = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    cargarDatos();
    _cargarVersion();
    _cargarModoKiosco();
  }

  Future<void> cargarDatos() async {
    // 1. Cargar lo que ya está en Storage
    String? ip = await StorageService.getServerIp();
    int? port = await StorageService.getServerPort();
    int? savedScreen = await StorageService.getScreenNumber();

    // 2. Obtener datos reales del hardware para mostrar en los Labels
    final deviceInfo = DeviceInfoPlugin();
    final networkInfo = NetworkInfo();
    
    if (Platform.isAndroid) {
      await Permission.phone.request();
    }

    String serial = "Desconocido";
    serial = await StorageService.getDeviceSerial();
    final macs = await StorageService.getNetworkMacs();


    String? currentIp = await networkInfo.getWifiIP();
    currentIp = await getDeviceIp();

    setState(() {
      if (ip != null) ipController.text = ip;
      if (port != null) portController.text = port.toString();
      deviceSerial = serial;
      networkMacs = macs;
      deviceIp = currentIp ?? "0.0.0.0";
      screenNumber = savedScreen;
    });
  }

  Future<void> _cargarVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = 'v${info.version} (${info.buildNumber})');
  }

  Future<void> _cargarModoKiosco() async {
    final val = await StorageService.getModoKiosco();
    setState(() => _modoKiosco = val);
  }

  Future<String> getDeviceIp() async {
    try {
      // Listamos todas las interfaces de red del dispositivo
      final interfaces = await NetworkInterface.list(
        includeLoopback: false, 
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        // En Android, la interfaz de Ethernet suele llamarse 'eth0' o 'en0'
        // Pero para ser genéricos, tomamos la primera que no sea wifi o loopback
        // si es que el dispositivo está conectado por cable.
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print("Error obteniendo IP: $e");
    }
    return "0.0.0.0";
  }

  Future<void> sincronizarPantalla() async {
    setState(() => isSyncing = true);

    try {
      await StorageService.setServerIp(ipController.text);
      await StorageService.setServerPort(int.parse(portController.text));

      final configService = ConfigurationService(); 
      final result = await configService.synchronizeScreen(deviceSerial, deviceIp);

      if (result != null && result['isError'] == false) {
        final content = result['content'];
        
        if (content != null && content['screenId'] != null) {
          int num = content['screenId'];
          await StorageService.setScreenNumber(num);
          setState(() => screenNumber = num);

          // Primero guarda, luego conecta en background sin bloquear
          LocalApiServer.start();
          SocketService.connect();
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Éxito: ${result['message']} (ID: $num)"),
              backgroundColor: Colors.green,
            ),
          );
          
          // Mapping en background, no bloquea UI
          PumpService.getMapping(screenId: num).catchError((e) {
            debugPrint('⚠️ Error cargando mapping: $e');
          });
        }
      }
      else if (result != null && result['isError'] == true)
      {
        throw Exception(result['message'] ?? "Error desconocido");
      }
      else {
        throw Exception(result?['message'] ?? "Error desconocido");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }
  
  Future<void> cargarConfiguracion() async {
    String? ip = await StorageService.getServerIp();
    int? port = await StorageService.getServerPort();

    if (ip != null) ipController.text = ip;
    if (port != null) portController.text = port.toString();
  }

  Future<void> guardarConfiguracion() async {
    await StorageService.setServerIp(ipController.text);
    await StorageService.setServerPort(int.parse(portController.text));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Configuración guardada")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuración de Terminal")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECCIÓN DE IDENTIDAD DEL HARDWARE ---
            Card(
              color: Colors.blueGrey[50],
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _infoRow("Serial Hardware:", deviceSerial),
                    for (final entry in networkMacs.entries) _infoRow("MAC ${entry.key}:", entry.value),
                    _infoRow("IP Local:", deviceIp),
                    const Divider(),
                    _infoRow(
                      "Número de Pantalla:", 
                      screenNumber == null ? "No asignado" : "#$screenNumber",
                      isBold: true
                    ),
                    const Divider(),
                    _infoRow("Versión:", _version, isBold: true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            const Text("Configuración de Red", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            TextField(
              controller: ipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "IP Servidor (Ej: 192.168.1.100)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Puerto",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
            ),

            const SizedBox(height: 30),

            const SizedBox(height: 25),
            const Text("Modo Kiosco", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              color: _modoKiosco ? Colors.green.shade50 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Aplicación como launcher',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              _modoKiosco ? 'Activo — app arranca con el dispositivo' : 'Inactivo',
                              style: TextStyle(
                                fontSize: 12,
                                color: _modoKiosco ? Colors.green.shade700 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _modoKiosco,
                          activeColor: Colors.green,
                          onChanged: (val) => _toggleModoKiosco(val),
                        ),
                      ],
                    ),
                    if (_modoKiosco) ...[
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _abrirConfiguracionAndroid,
                              icon: const Icon(Icons.settings_outlined, size: 16),
                              label: const Text('Ajustes Android', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _abrirSelectLauncher,
                              icon: const Icon(Icons.home_outlined, size: 16),
                              label: const Text('Cambiar launcher', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    // La lista de versiones puede crecer bastante — se deja
                    // desplazable en vez de dejar que se recorte o desborde.
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDDDDD),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const UpdateWidget(),
                        ],
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.system_update_outlined),
                label: const Text('Gestionar actualizaciones'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Colors.blueAccent),
                  foregroundColor: Colors.blueAccent,
                ),
              ),
            ),
            
            const SizedBox(height: 25),
            // --- BOTÓN DE ACCIÓN ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isSyncing ? null : sincronizarPantalla,
                icon: isSyncing 
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Icon(Icons.sync),
                label: Text(isSyncing ? "Sincronizando..." : "Sincronizar y Guardar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _toggleModoKiosco(bool activar) async {
    await StorageService.setModoKiosco(activar);
    setState(() => _modoKiosco = activar);

    if (activar) {
      _abrirSelectLauncher();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo kiosco desactivado. Cambia el launcher desde Android.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _abrirSelectLauncher() {
    const AndroidIntent(
      action: 'android.settings.HOME_SETTINGS',
    ).launch();
  }

  void _abrirConfiguracionAndroid() {
    const intent = AndroidIntent(
      action: 'android.settings.SETTINGS',
    );
    intent.launch();
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          SelectableText(
            value, 
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.blue[900] : Colors.black87
            )
          ),
        ],
      ),
    );
  }
}