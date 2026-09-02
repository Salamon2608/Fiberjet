import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/tech/notifications → List technician notifications
/// PATCH /api/v1/tech/notifications → Mark notifications as read
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  if (request.method == HttpMethod.get) {
    final result = await db.query(
      '''
      SELECT id, title, body, type, is_read, data, sent_at
      FROM notifications
      WHERE user_id = @userId
      ORDER BY sent_at DESC
      LIMIT 50
      ''',
      substitutionValues: {'userId': user.id},
    );

    final notifications = result.map((r) => r.toColumnMap()).toList();
    final unreadCount = notifications.where((n) => n['is_read'] == false).length;

    return ApiResponse.success(data: {
      'notifications': notifications,
      'unread_count': unreadCount,
    });
  }

  // PATCH: Mark all as read
  if (request.method == HttpMethod.patch) {
    await db.query(
      'UPDATE notifications SET is_read = true WHERE user_id = @userId AND is_read = false',
      substitutionValues: {'userId': user.id},
    );
    return ApiResponse.success(message: 'All notifications marked as read');
  }

  return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
}
