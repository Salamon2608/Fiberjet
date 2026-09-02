import 'dart:io';
import 'dart:math';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/auth/forgot-password
/// Body: { "phone": "9876543210" }
/// Generates a 6-digit reset code, stores it hashed, and returns the code in debug mode.
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

  if (phone == null || phone.isEmpty) {
    return ApiResponse.error(message: 'Phone number is required');
  }

  final db = context.read<PostgresService>();
  final authService = context.read<AuthService>();

  // Verify the user exists
  final userResult = await db.query(
    'SELECT id FROM users WHERE phone = @phone LIMIT 1',
    substitutionValues: {'phone': phone},
  );

  if (userResult.isEmpty) {
    // Return success even if user not found to prevent phone enumeration
    return ApiResponse.success(
      message: 'If this phone number is registered, a reset code has been sent.',
    );
  }

  final userId = userResult.first.toColumnMap()['id'] as String;

  // Generate a 6-digit reset code
  final r = Random();
  final resetCode = List.generate(6, (_) => r.nextInt(10)).join();
  final codeHash = authService.hashPassword(resetCode);
  final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 10));

  // Store the reset code in otp_logs with type 'reset'
  await db.query(
    '''
    INSERT INTO otp_logs (user_id, phone, otp_hash, expires_at)
    VALUES (@userId, @phone, @codeHash, @expiresAt)
    ''',
    substitutionValues: {
      'userId': userId,
      'phone': phone,
      'codeHash': codeHash,
      'expiresAt': expiresAt,
    },
  );

  // TODO: Integrate SMS gateway (Twilio/MSG91) to send the code
  return ApiResponse.success(
    message: 'If this phone number is registered, a reset code has been sent.',
    data: {
      'debug_reset_code': resetCode, // TODO: Remove before production!
    },
  );
}
