import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';

/// Middleware that checks for a valid JWT in the Authorization header.
/// If valid, it fetches the user from the DB and injects UserModel into the context.
Middleware jwtAuthGuard() {
  return (handler) {
    return (context) async {
      final request = context.request;
      final authHeader = request.headers['Authorization'] ?? request.headers['authorization'];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.json(statusCode: 401, body: {'error': 'Missing or invalid authentication token.'});
      }

      final token = authHeader.substring(7);
      final authService = context.read<AuthService>();
      final decoded = authService.verifyToken(token);

      if (decoded == null) {
        return Response.json(statusCode: 401, body: {'error': 'Token has expired or is invalid.'});
      }

      final userId = decoded.payload['user_id'] as String;

      final db = context.read<PostgresService>();
      final result = await db.query(
        '''
        SELECT u.*, r.name as role_name 
        FROM users u 
        LEFT JOIN roles r ON u.role_id = r.id 
        WHERE u.id = @id LIMIT 1
        ''', 
        substitutionValues: {'id': userId}
      );

      if (result.isEmpty) {
        return Response.json(statusCode: 401, body: {'error': 'User not found in system.'});
      }

      final row = result.first.toColumnMap();
      
      // Sanitize postgres driver types (UUID objects, POINT, etc.) into
      // plain Dart types that UserModel.fromJson can safely parse.
      // Keep DateTime and bool as-is; convert everything else to String.
      final sanitized = <String, dynamic>{};
      for (final entry in row.entries) {
        final v = entry.value;
        if (v == null || v is bool || v is DateTime || v is int || v is double) {
          sanitized[entry.key] = v;
        } else {
          sanitized[entry.key] = v.toString();
        }
      }

      // Parse user model — only catch parsing errors here
      UserModel user;
      try {
        user = UserModel.fromJson(sanitized);
      } catch (e) {
        return Response.json(
          statusCode: 401, 
          body: {'error': 'Malformed user data.', 'details': e.toString()}
        );
      }

      // Call handler OUTSIDE the try/catch so route errors propagate correctly
      return await handler.use(provider<UserModel>((_) => user)).call(context);
    };
  };
}
