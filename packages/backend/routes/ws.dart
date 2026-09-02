import 'package:backend/services/auth_service.dart';
import 'package:backend/services/websocket_service.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final token = request.uri.queryParameters['token'];

  if (token == null) {
    return Response.json(
      statusCode: 401,
      body: {'message': 'Missing token query parameter'},
    );
  }

  // Authenticate the user from the token passed via query param
  final authService = context.read<AuthService>();
  final jwt = authService.verifyToken(token);

  if (jwt == null) {
    return Response.json(
      statusCode: 401,
      body: {'message': 'Invalid token'},
    );
  }
  
  final payload = jwt.payload as Map<String, dynamic>;
  final userId = payload['user_id'] as String;

  final wsService = context.read<WebsocketService>();
  final handler = webSocketHandler((channel, protocol) {
    // Add the user to our tracked websocket clients
    wsService.addClient(userId, channel);

    // Initial greeting event
    channel.sink.add('{"event": "status", "payload": {"status": "connected", "user_id": "$userId"}}');

    channel.stream.listen(
      (message) {
        // Here we could handle incoming client-to-server WS messages
      },
      onDone: () => print('Client $userId disconnected'),
      onError: (e) => print('Error from $userId: $e'),
    );
  });

  return handler(context);
}
