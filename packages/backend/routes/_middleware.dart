import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/services/storage_service.dart';
import 'package:backend/services/websocket_service.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/middleware/audit_logger.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as cors;

// Create a single permanent instance of services.
final _postgresService = PostgresService();
final _authService = AuthService();
final _storageService = StorageService();


Handler middleware(Handler handler) {
  // Inject the services into every request, apply security headers and audit logging.
  return handler
      .use(auditLogger())
      .use(provider<PostgresService>((_) => _postgresService))
      .use(provider<WebsocketService>((_) => WebsocketService()))
      .use(provider<AuthService>((_) => _authService))
      .use(provider<StorageService>((_) => _storageService))
      .use(_securityHeaders())
      .use(fromShelfMiddleware(cors.corsHeaders(
        headers: {
          cors.ACCESS_CONTROL_ALLOW_ORIGIN: '*',
          cors.ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
          cors.ACCESS_CONTROL_ALLOW_HEADERS: 'Origin, Content-Type, Accept, Authorization',
        },
      )));
}

Middleware _securityHeaders() {
  return (handler) {
    return (context) async {
      final response = await handler(context);
      return response.copyWith(
        headers: {
          ...response.headers,
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
        },
      );
    };
  };
}

