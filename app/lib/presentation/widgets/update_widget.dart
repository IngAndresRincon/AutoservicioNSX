import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/service.dart';
import 'package:package_info_plus/package_info_plus.dart';


class UpdateWidget extends StatefulWidget {
  const UpdateWidget({super.key});

  @override
  State<UpdateWidget> createState() => _UpdateWidgetState();
}

class _UpdateWidgetState extends State<UpdateWidget>
    with SingleTickerProviderStateMixin {
  List<_VersionInfo> _versions = [];
  bool _loadingVersions = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadingVersion;
  String? _currentVersion;
  String? _error;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _cargarVersiones();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarVersiones() async {
    setState(() { _loadingVersions = true; _error = null; });
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;

      final url = await ResourceService.getVersionsUrl();
      final response = await ResourceService.fetchVersionsJson(url);
      final data = jsonDecode(response) as Map<String, dynamic>;
      final list = (data['versions'] as List)
          .map((v) => _VersionInfo.fromJson(v))
          .where((v) => v.stable)
          .toList()
        ..sort((a, b) {
          // Más reciente primero por fecha (formato ISO "YYYY-MM-DD", así
          // que comparar como texto ya da el orden cronológico correcto).
          // Si dos versiones salieron el mismo día, se desempata por
          // número de versión (más alta primero) para que ambas aparezcan
          // en un orden consistente.
          final porFecha = b.date.compareTo(a.date);
          if (porFecha != 0) return porFecha;
          return _compareVersions(b.version, a.version);
        });

      setState(() => _versions = list);
    } catch (e) {
      setState(() => _error = 'No se pudo cargar la lista de versiones');
    } finally {
      if (mounted) setState(() => _loadingVersions = false);
    }
  }

  Future<void> _descargar(_VersionInfo version) async {
    final permiso = await Permission.requestInstallPackages.request();
    if (!permiso.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permite la instalación de apps desconocidas en Ajustes'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadingVersion = version.version;
    });

    try {
      final ok = await ResourceService.descargarEInstalarDesdeUrl(
        url: version.url,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );

      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al instalar. Intenta de nuevo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingVersion = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Actualizaciones',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (!_loadingVersions)
              GestureDetector(
                onTap: _cargarVersiones,
                child: const Icon(Icons.refresh_rounded,
                    size: 20, color: Colors.blueAccent),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_loadingVersions)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_error != null)
          _buildError()
        else if (_versions.isEmpty)
          _buildEmpty()
        else
          ..._versions.map((v) => _buildVersionCard(v)),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.red.shade400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
          TextButton(
            onPressed: _cargarVersiones,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: Colors.green.shade600, size: 20),
          const SizedBox(width: 10),
          Text(
            'La aplicación está al día',
            style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(_VersionInfo v) {
    final isCurrent = v.version == _currentVersion;
    final isDownloadingThis = _isDownloading && _downloadingVersion == v.version;
    final isLatest = _versions.isNotEmpty && _versions.first.version == v.version;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent
                ? Colors.green.shade300
                : isLatest
                    ? Colors.blueAccent.withOpacity(0.4)
                    : Colors.grey.shade200,
            width: isCurrent || isLatest ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Badge versión
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.green.shade100
                          : isLatest
                              ? Colors.blue.shade50
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v${v.version}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isCurrent
                            ? Colors.green.shade700
                            : isLatest
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Instalada',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    )
                  else if (isLatest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Más reciente',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    v.date,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF999999)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                v.changelog,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF666666), height: 1.4),
              ),

              // Barra de progreso o botón
              if (isDownloadingThis) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blueAccent),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Descargando ${(_downloadProgress * 100).toStringAsFixed(0)}%...',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.blueAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else if (!isCurrent) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : () => _descargar(v),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text('Instalar v${v.version}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isLatest ? Colors.blueAccent : Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionInfo {
  final String version;
  final int buildNumber;
  final String url;
  final String changelog;
  final String date;
  final bool stable;

  _VersionInfo({
    required this.version,
    required this.buildNumber,
    required this.url,
    required this.changelog,
    required this.date,
    required this.stable,
  });

  factory _VersionInfo.fromJson(Map<String, dynamic> json) => _VersionInfo(
        version: json['version'] as String,
        buildNumber: json['buildNumber'] as int,
        url: json['url'] as String,
        changelog: json['changelog'] as String,
        date: json['date'] as String,
        stable: json['stable'] as bool? ?? true,
      );
}

/// Compara dos versiones semánticas ("1.0.10" vs "1.0.2") número por número
/// en vez de como texto — así "1.0.10" queda correctamente después de
/// "1.0.2" (una comparación de texto simple los pondría al revés).
int _compareVersions(String a, String b) {
  final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final maxLen = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < maxLen; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}