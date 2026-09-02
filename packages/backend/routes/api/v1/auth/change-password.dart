import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/auth_helper.dart';

/// POST /api/v1/auth/change-password
/// Body: { "current_password": "old123", "new_password": "new456" }
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  // Inline auth
  final (user, authError) = await AuthHelper.authenticate(context);
  if (user == null) return authError!;

  final body = await request.json() as Map<String, dynamic>;
  final currentPassword = body['current_password'] as String?;
  final newPassword = body['new_password'] as String?;

  if (currentPassword == null || newPassword == null) {
    return ApiResponse.error(
      message: 'current_password and new_password are required',
    );
  }

  if (newPassword.length < 6) {
    return ApiResponse.error(
      message: 'New password must be at least 6 characters',
    );
  }

  final db = context.read<PostgresService>();
  final authService = context.read<AuthService>();

  // Fetch the current password hash
  final result = await db.query(
    'SELECT password_hash FROM users WHERE id = @userId LIMIT 1',
    substitutionValues: {'userId': user.id},
  );

  if (result.isEmpty) {
    return ApiResponse.error(
      message: 'User not found',
      statusCode: HttpStatus.notFound,
    );
  }

  final currentHash = result.first.toColumnMap()['password_hash'] as String?;

  if (currentHash == null || !authService.verifyPassword(currentPassword, currentHash)) {
    return ApiResponse.error(
      message: 'Current password is incorrect',
      statusCode: HttpStatus.unauthorized,
    );
  }

  // Hash and save the new password
  final newHash = authService.hashPassword(newPassword);

  await db.query(
    'UPDATE users SET password_hash = @hash, updated_at = NOW() WHERE id = @userId',
    substitutionValues: {
      'hash': newHash,
      'userId': user.id,
    },
  );

  return ApiResponse.success(message: 'Password changed successfully');
}
