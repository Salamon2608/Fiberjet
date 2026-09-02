import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/auth/reset-password
/// Body: { "phone": "9876543210", "code": "123456", "new_password": "newpass123" }
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final phone = body['phone'] as String?;
  final code = body['code'] as String?;
  final newPassword = body['new_password'] as String?;

  if (phone == null || code == null || newPassword == null) {
    return ApiResponse.error(
      message: 'phone, code, and new_password are required',
    );
  }

  if (newPassword.length < 6) {
    return ApiResponse.error(
      message: 'New password must be at least 6 characters',
    );
  }

  final db = context.read<PostgresService>();
  final authService = context.read<AuthService>();

  // Find the user
  final userResult = await db.query(
    'SELECT id FROM users WHERE phone = @phone LIMIT 1',
    substitutionValues: {'phone': phone},
  );

  if (userResult.isEmpty) {
    return ApiResponse.error(
      message: 'Invalid reset request',
      statusCode: HttpStatus.unauthorized,
    );
  }

  final userId = userResult.first.toColumnMap()['id'] as String;

  // Get the latest reset code for this user
  final otpResult = await db.query(
    '''
    SELECT * FROM otp_logs
    WHERE user_id = @userId
    ORDER BY created_at DESC
    LIMIT 1
    ''',
    substitutionValues: {'userId': userId},
  );

  if (otpResult.isEmpty) {
    return ApiResponse.error(message: 'No reset code found. Please request a new one.');
  }

  final otpRow = otpResult.first.toColumnMap();
  final expiresAt = otpRow['expires_at'] as DateTime;
  final codeHash = otpRow['otp_hash'] as String;

  // Check expiration
  if (DateTime.now().toUtc().isAfter(expiresAt)) {
    return ApiResponse.error(message: 'Reset code has expired. Please request a new one.');
  }

  // Verify the code
  if (!authService.verifyPassword(code, codeHash)) {
    return ApiResponse.error(
      message: 'Invalid reset code',
      statusCode: HttpStatus.unauthorized,
    );
  }

  // Code is valid — update the password
  final newHash = authService.hashPassword(newPassword);

  await db.query(
    'UPDATE users SET password_hash = @hash WHERE id = @userId',
    substitutionValues: {
      'hash': newHash,
      'userId': userId,
    },
  );

  // Clear all OTPs for this user to prevent replay
  await db.query(
    'DELETE FROM otp_logs WHERE user_id = @userId',
    substitutionValues: {'userId': userId},
  );

  return ApiResponse.success(message: 'Password has been reset successfully. You can now login.');
}
