import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/auth_helper.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  // Inline auth — this route is in the public /auth directory but requires a token
  final (user, authError) = await AuthHelper.authenticate(context);
  if (user == null) return authError!;

  final db = context.read<PostgresService>();

  // Clear the user's FCM token so they stop receiving push notifications
  await db.query(
    'UPDATE users SET fcm_token = NULL WHERE id = @userId',
    substitutionValues: {'userId': user.id},
  );

  // Log the logout event for audit trail
  try {
    await db.query(
      '''
      INSERT INTO audit_logs (user_id, action, details)
      VALUES (@userId, 'logout', 'User logged out')
      ''',
      substitutionValues: {'userId': user.id},
    );
  } catch (_) {
    // Audit log failure should not block logout
  }

  return ApiResponse.success(message: 'Logged out successfully');
}
