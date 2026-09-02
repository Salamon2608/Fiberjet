import 'dart:convert';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';

class WebsocketService {
  WebsocketService._();
  static final WebsocketService _instance = WebsocketService._();
  factory WebsocketService() => _instance;

  // Map of userId to a list of WebSocketChannels to support multiple devices
  final Map<String, List<WebSocketChannel>> _clients = {};

  void addClient(String userId, WebSocketChannel channel) {
    _clients.putIfAbsent(userId, () => []).add(channel);

    // Clean up when channel closes
    channel.stream.listen(
      (message) {},
      onDone: () => _removeChannel(userId, channel),
      onError: (_) => _removeChannel(userId, channel),
    );
  }

  void _removeChannel(String userId, WebSocketChannel channel) {
    _clients[userId]?.remove(channel);
    if (_clients[userId]?.isEmpty ?? false) {
      _clients.remove(userId);
    }
  }

  void dispatchEvent(String userId, String event, Map<String, dynamic> payload) {
    final channels = _clients[userId];
    if (channels != null) {
      final message = jsonEncode({
        'event': event,
        'payload': payload,
      });
      for (final channel in channels) {
        channel.sink.add(message);
      }
    }
  }
}
