import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';

/// Helper to extract and verify the authenticated user from a request.
/// Returns null and a 401 Response if authentication fails.
class AuthHelper {
  static Future<(UserModel?, Response?)> authenticate(RequestContext context) async {
    final authHeader = context.request.headers['Authorization'] 
        ?? context.request.headers['authorization'];

    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return (null, ApiResponse.error(
        message: 'Authentication required',
        statusCode: HttpStatus.unauthorized,
      ));
    }

    final token = authHeader.substring(7);
    final authService = context.read<AuthService>();
    final decoded = authService.verifyToken(token);

    if (decoded == null) {
      return (null, ApiResponse.error(
        message: 'Token has expired or is invalid',
        statusCode: HttpStatus.unauthorized,
      ));
    }

    final userId = decoded.payload['user_id'] as String;
    final db = context.read<PostgresService>();

    final result = await db.query(
      'SELECT u.*, r.name as role_name FROM users u JOIN roles r ON u.role_id = r.id WHERE u.id = @id LIMIT 1',
      substitutionValues: {'id': userId},
    );

    if (result.isEmpty) {
      return (null, ApiResponse.error(
        message: 'User not found',
        statusCode: HttpStatus.unauthorized,
      ));
    }

    final user = UserModel.fromJson(result.first.toColumnMap());
    return (user, null);
  }
}
