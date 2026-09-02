import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/auth_helper.dart';

/// POST /api/v1/auth/fcm-token
/// Body: { "fcm_token": "firebase_cloud_messaging_device_token" }
/// Called by the Flutter app on startup to register/update the device's push token.
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
  final fcmToken = body['fcm_token'] as String?;

  if (fcmToken == null || fcmToken.isEmpty) {
    return ApiResponse.error(message: 'fcm_token is required');
  }

  final db = context.read<PostgresService>();

  await db.query(
    'UPDATE users SET fcm_token = @token, updated_at = NOW() WHERE id = @userId',
    substitutionValues: {
      'token': fcmToken,
      'userId': user.id,
    },
  );

  return ApiResponse.success(message: 'FCM token updated');
}
