import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final phone = body['phone'] as String?;
  final otp = body['otp'] as String?;

  if (phone == null || otp == null) {
    return ApiResponse.error(message: 'Phone and OTP are required');
  }

  final db = context.read<PostgresService>();
  final authService = context.read<AuthService>();

  final userResult = await db.query(
    'SELECT u.*, r.name as role_name FROM users u JOIN roles r ON u.role_id = r.id WHERE phone = @phone LIMIT 1',
    substitutionValues: {'phone': phone},
  );

  if (userResult.isEmpty) {
    return ApiResponse.error(message: 'User not found', statusCode: HttpStatus.notFound);
  }

  final userRow = userResult.first.toColumnMap();
  final userId = userRow['id'] as String;

  // Fetch the latest OTP generated for this user
  final otpResult = await db.query(
    '''
    SELECT * FROM otp_logs 
    WHERE user_id = @user_id 
    ORDER BY created_at DESC 
    LIMIT 1
    ''',
    substitutionValues: {'user_id': userId},
  );

  if (otpResult.isEmpty) {
    return ApiResponse.error(message: 'No recent OTP requests found for this user.');
  }

  final otpRow = otpResult.first.toColumnMap();
  final expiresAt = otpRow['expires_at'] as DateTime;
  final otpHash = otpRow['otp_hash'] as String;

  if (DateTime.now().toUtc().isAfter(expiresAt)) {
    return ApiResponse.error(message: 'OTP has expired. Please request a new one.');
  }

  if (!authService.verifyPassword(otp, otpHash)) {
    return ApiResponse.error(message: 'Invalid OTP.', statusCode: HttpStatus.unauthorized);
  }

  // Clear the OTP to prevent replay attacks
  await db.query(
    'DELETE FROM otp_logs WHERE id = @id',
    substitutionValues: {'id': otpRow['id'] as String},
  );

  final roleName = userRow['role_name'] as String;
  final token = authService.generateToken(userId, roleName);

  return ApiResponse.success(
    message: 'OTP verified successfully',
    data: {
      'token': token,
      'user': {
        'id': userId,
        'name': userRow['name'],
        'phone': userRow['phone'],
        'role': roleName,
      }
    },
  );
}
