import 'dart:io';
import 'dart:math';
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

  if (phone == null || phone.isEmpty) {
    return ApiResponse.error(message: 'Phone number is required');
  }

  final db = context.read<PostgresService>();
  final authService = context.read<AuthService>();

  final result = await db.query(
    'SELECT id FROM users WHERE phone = @phone LIMIT 1',
    substitutionValues: {'phone': phone},
  );

  if (result.isEmpty) {
    return ApiResponse.error(message: 'No user found with this phone number.', statusCode: HttpStatus.notFound);
  }

  final userId = result.first.toColumnMap()['id'] as String;

  // Generate a random 6-digit OTP
  final r = Random();
  final otp = List.generate(6, (index) => r.nextInt(10)).join();
  
  // Hash the OTP using bcrypt before storing it
  final otpHash = authService.hashPassword(otp);
  
  // OTP expires in 5 minutes
  final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 5));

  // Insert into OTP logs table
  await db.query(
    '''
    INSERT INTO otp_logs (user_id, phone, otp_hash, expires_at)
    VALUES (@user_id, @phone, @otp_hash, @expires_at)
    ''',
    substitutionValues: {
      'user_id': userId,
      'phone': phone,
      'otp_hash': otpHash,
      'expires_at': expiresAt,
    }
  );

  return ApiResponse.success(
    message: 'OTP generated and sent successfully.',
  );
}
