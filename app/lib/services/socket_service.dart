import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:gnesys_as/config/api_config.dart';
import 'package:gnesys_as/services/service.dart';

/// Canales de Postgres que la Orange reenvia por Socket.IO.
class SocketChannels {
  static const String payment = 'notify_event_transaction_payment';
  static const String authorization = 'notify_event_authorization';
  static const String sellerPreset = 'notify_event_preset_vendedor';
  static const String clientPreset = 'notify_event_preset_cliente';
}

/// Estados (`sync` del evento) segun la tabla `estado` de la Orange.
class PresetSync {
  static const int confirmed = 2; // NSX creo el preset
  static const int rejected = 3;
  static const int reported = 4; // hay venta (saleid)
  static const int cancelled = 5;
  static const int zeroSale = 6;
  static const int dispensing = 8;
}

/// Suscripcion devuelta por [SocketService.listen]; hay que cancelarla al salir de la pantalla.
class SocketSubscription {
  final void Function() _cancel;
  SocketSubscription._(this._cancel);
  void cancel() => _cancel();
}

class _Listener {
  final String channel;
  final int? positionId;
  final int? presetId;
  final void Function(Map<String, dynamic> payload) onEvent;
  _Listener(this.channel, this.positionId, this.presetId, this.onEvent);
}

class SocketService {
  static IO.Socket? _socket;
  static String? _connectedUrl;
  static String? _connectedSerial;
  static bool _hasConnectedBefore = false;
  static bool _sessionReplaced = false;

  // API anterior (una sola pantalla escuchando a la vez)
  static Function(Map<String, dynamic>)? _onPaymentUpdate;
  static Function(Map<String, dynamic>)? _onAuthorizationUpdate;
  static final List<Map<String, dynamic>> _eventQueue = [];
  static Map<String, dynamic>? _lastAuthorizationEvent;

  // API nueva: varias suscripciones, filtradas por serial, posicion e id del preset
  static final List<_Listener> _listeners = [];
  static final Map<String, Map<String, dynamic>> _lastPresetEvents = {};
  static final List<void Function()> _reconnectCallbacks = [];

  static const int _maxQueuedPayments = 30;
  static const int _maxPresetEvents = 20;

  /// Avisa cuando otra instancia con el mismo serial se conecto y el servidor cerro esta sesion.
  static final ValueNotifier<bool> sessionReplaced = ValueNotifier<bool>(false);

  static bool get isConnected => _socket?.connected ?? false;

  static void _log(String message) {
    if (kDebugMode) {
      final now = DateTime.now().toUtc().add(const Duration(hours: -5)); // Colombia UTC-5
      final time = now.toIso8601String().substring(11, 23);
      debugPrint('[$time] $message');
    }
  }

  /// Diagnostico: se imprime tambien en release (visible con `adb logcat -s flutter`).
  static void _diag(String message) {
    final now = DateTime.now().toUtc().add(const Duration(hours: -5)); // Colombia UTC-5
    final time = now.toIso8601String().substring(11, 23);
    debugPrint('[SocketDiag][$time] $message');
  }

  /// El contenido llega como mapa; si el servidor no pudo leerlo llega como texto y se descarta.
  static Map<String, dynamic>? _payloadOf(dynamic data) {
    if (data is Map) {
      final payload = data['payload'];
      if (payload is Map) return Map<String, dynamic>.from(payload);
    }
    _diag('Evento descartado, formato inesperado: ${data.runtimeType} $data');
    return null;
  }

  static Future<void> connect() async {
    final ip = await StorageService.getServerIp();
    final port = await StorageService.getServerPort();
    final serial = await StorageService.getDeviceSerial();

    if (ip == null || port == null) {
      _log('Datos null, no se abre socket io');
      return;
    }

    final url = 'http://$ip:$port';

    // Si cambio la IP, el puerto o el serial se abre una conexion nueva
    if (_socket != null) {
      if (_connectedUrl == url && _connectedSerial == serial && !_sessionReplaced) {
        if (_socket!.connected) return;
        _socket!.connect();
        return;
      }
      _socket!.dispose();
      _socket = null;
      _hasConnectedBefore = false;
    }

    _sessionReplaced = false;
    sessionReplaced.value = false;
    _connectedUrl = url;
    _connectedSerial = serial;
    _log('🔌 [Socket] Conectando a $url serial $serial');
    _diag('Conectando a $url con serial "$serial"');

    final socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'x-api-key': ApiConfig.socketApiKey})
          .setAuth({'serial': serial})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(9999)
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _log('✅ [Socket] Conectado');
      _diag('Conectado, id ${socket.id}');
      // Lo ocurrido mientras no habia conexion no se repite: las pantallas deben consultar el estado
      if (_hasConnectedBefore) {
        for (final callback in List.of(_reconnectCallbacks)) {
          callback();
        }
      }
      _hasConnectedBefore = true;
    });

    socket.onConnectError((data) {
      _log('❌ [Socket] Error de conexión: $data');
      _diag('Error de conexion: $data');
    });
    socket.onError((e) {
      _log('❌ [Socket] Error: $e');
      _diag('Error: $e');
    });

    // Otra instancia con el mismo serial desplazo a esta: no se reconecta (se echarian en bucle)
    socket.on('session_replaced', (_) {
      _log('⚠️ [Socket] Sesión reemplazada por otra instancia');
      _sessionReplaced = true;
      sessionReplaced.value = true;
    });

    socket.onDisconnect((reason) {
      _log('⚠️ [Socket] Desconectado: $reason');
      _diag('Desconectado: $reason');
      if (reason == 'io server disconnect' && !_sessionReplaced) {
        socket.connect();
      }
    });

    // Todo lo que llegue del servidor, con su contenido crudo, aunque la app no lo escuche
    socket.onAny((event, data) => _diag('Evento recibido: $event ${data.runtimeType} $data'));

    socket.on(SocketChannels.payment, _onPaymentEvent);
    socket.on(SocketChannels.authorization, _onAuthorizationEvent);
    socket.on(SocketChannels.sellerPreset, (data) => _onPresetEvent(SocketChannels.sellerPreset, data));
    socket.on(SocketChannels.clientPreset, (data) => _onPresetEvent(SocketChannels.clientPreset, data));

    socket.connect();
  }

  // ---------------------------------------------------------------------------
  // Eventos entrantes

  static void _onPaymentEvent(dynamic data) {
    final payload = _payloadOf(data);
    if (payload == null) return;

    _log('💰 [Socket] Pago ${payload['paymentid']} estado ${payload['statuspaymentid']}');
    final event = Map<String, dynamic>.from(data as Map);
    if (_onPaymentUpdate != null) {
      _diag('Pago ${payload['paymentid']} entregado al listener activo');
      _onPaymentUpdate!(event);
    } else {
      // Nadie escucha: se guardan solo los ultimos, para no crecer sin limite
      _diag('Pago ${payload['paymentid']} sin listener, queda en cola');
      _eventQueue.add(event);
      if (_eventQueue.length > _maxQueuedPayments) {
        _eventQueue.removeAt(0);
      }
    }
  }

  static void _onAuthorizationEvent(dynamic data) {
    final payload = _payloadOf(data);
    if (payload == null) return;

    _log('⛽ [Socket] Autorización sync ${payload['sync']}');
    final event = Map<String, dynamic>.from(data as Map);
    if (_onAuthorizationUpdate != null) {
      _onAuthorizationUpdate!(event);
    } else {
      _lastAuthorizationEvent = event;
    }
  }

  static String _presetIdField(String channel) =>
      channel == SocketChannels.sellerPreset ? 'sellerpresetid' : 'clientpresetid';

  static bool _matches(_Listener listener, String channel, Map<String, dynamic> payload) {
    if (listener.channel != channel) return false;
    if ((payload['serial'] ?? '').toString().trim() != (_connectedSerial ?? '').trim()) return false;
    if (listener.positionId != null && payload['positionid'] != listener.positionId) return false;
    if (listener.presetId != null && payload[_presetIdField(channel)] != listener.presetId) return false;
    return true;
  }

  static void _onPresetEvent(String channel, dynamic data) {
    final payload = _payloadOf(data);
    if (payload == null) return;

    _log('⛽ [Socket] $channel preset ${payload[_presetIdField(channel)]} sync ${payload['sync']}');

    // Se recuerda el ultimo evento de cada preset para quien se suscriba despues
    final key = '$channel:${payload[_presetIdField(channel)]}';
    _lastPresetEvents.remove(key);
    _lastPresetEvents[key] = payload;
    if (_lastPresetEvents.length > _maxPresetEvents) {
      _lastPresetEvents.remove(_lastPresetEvents.keys.first);
    }

    for (final listener in List.of(_listeners)) {
      if (_matches(listener, channel, payload)) {
        listener.onEvent(payload);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // API nueva

  /// Escucha un canal de preset (vendedor o cliente identificado). Filtra por el serial de esta pantalla y,
  /// si se indican, por posicion e id del preset. Si el preset ya tuvo un evento, se entrega de inmediato.
  /// Devuelve la suscripcion: hay que llamar a `cancel()` al salir de la pantalla.
  static SocketSubscription listen({
    required String channel,
    int? positionId,
    int? presetId,
    required void Function(Map<String, dynamic> payload) onEvent,
  }) {
    final listener = _Listener(channel, positionId, presetId, onEvent);
    _listeners.add(listener);

    if (presetId != null) {
      final last = _lastPresetEvents['$channel:$presetId'];
      if (last != null && _matches(listener, channel, last)) {
        onEvent(last);
      }
    }

    return SocketSubscription._(() => _listeners.remove(listener));
  }

  /// Se llama cada vez que el socket se reconecta despues de una caida. Devuelve la funcion para quitarlo.
  static void Function() addReconnectListener(void Function() callback) {
    _reconnectCallbacks.add(callback);
    return () => _reconnectCallbacks.remove(callback);
  }

  // ---------------------------------------------------------------------------
  // API anterior (se mantiene tal cual para las pantallas actuales)

  static void setPaymentListener(int paymentId, Function(Map<String, dynamic>) callback) {
    _log('📝 Registrando listener para el pago ID: $paymentId');

    _onPaymentUpdate = (data) {
      final payload = data['payload'];
      if (payload is Map && payload['paymentid'].toString() == paymentId.toString()) {
        callback(Map<String, dynamic>.from(payload));
      } else {
        _diag('Pago descartado: esperaba $paymentId y llego ${payload is Map ? payload['paymentid'] : payload}');
      }
    };

    _eventQueue.removeWhere((event) {
      final p = event['payload'];
      if (p is Map && p['paymentid'].toString() == paymentId.toString()) {
        callback(Map<String, dynamic>.from(p));
        return true; // ya se entrego
      }
      return false;
    });
  }

  static void setAuthorizationListener({
    required String deviceSerial,
    required int positionId,
    required Function(Map<String, dynamic>) callback,
  }) {
    _onAuthorizationUpdate = (data) {
      final payload = data['payload'];
      if (payload is! Map) return;

      final String incomingSerial = payload['serial'] ?? '';
      final int incomingPosition = payload['positionid'] ?? -1;

      if (incomingSerial == deviceSerial && incomingPosition == positionId) {
        _log('✅ [Socket Auth] Validado sync: ${payload['sync']}');
        _lastAuthorizationEvent = data;
        callback(Map<String, dynamic>.from(payload));
      }
    };

    // Al registrarse, entrega el ultimo evento guardado si aplica
    final payload = _lastAuthorizationEvent?['payload'];
    if (payload is Map) {
      final String incomingSerial = payload['serial'] ?? '';
      final int incomingPosition = payload['positionid'] ?? -1;

      if (incomingSerial == deviceSerial && incomingPosition == positionId) {
        _log('📬 Entregando último sync guardado: ${payload['sync']}');
        callback(Map<String, dynamic>.from(payload));
        // No se limpia aqui: el siguiente listener tambien puede necesitarlo
      }
    }
  }

  static void stopListeningPayment() {
    _onPaymentUpdate = null;
  }

  static void stopListeningAuthorization() {
    _onAuthorizationUpdate = null;
    _lastAuthorizationEvent = null;
  }

  static void clearAuthorizationState() {
    _onAuthorizationUpdate = null;
    _lastAuthorizationEvent = null;
  }

  static void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectedUrl = null;
    _connectedSerial = null;
    _hasConnectedBefore = false;
  }
}
