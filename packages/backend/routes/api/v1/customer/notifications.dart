import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/customer/notifications       → List notifications (paginated)
/// POST /api/v1/customer/notifications       → Mark notification(s) as read
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: Fetch user's notifications ────────────────────────
  if (request.method == HttpMethod.get) {
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
    final offset = (page - 1) * limit;

    final result = await db.query(
      '''
      SELECT * FROM notifications
      WHERE user_id = @userId
      ORDER BY created_at DESC
      LIMIT @limit OFFSET @offset
      ''',
      substitutionValues: {
        'userId': user.id,
        'limit': limit,
        'offset': offset,
      },
    );

    // Get unread count
    final countResult = await db.query(
      '''
      SELECT COUNT(*) as unread_count FROM notifications
      WHERE user_id = @userId AND is_read = false
      ''',
      substitutionValues: {'userId': user.id},
    );

    final notifications = result.map((r) => r.toColumnMap()).toList();
    final unreadCount = countResult.first.toColumnMap()['unread_count'] ?? 0;

    return ApiResponse.success(
      data: {
        'notifications': notifications,
        'unread_count': unreadCount,
        'page': page,
        'limit': limit,
      },
    );
  }

  // ── POST: Mark notification(s) as read ─────────────────────
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final notificationId = body['notification_id'] as String?;
    final markAllRead = body['mark_all_read'] as bool? ?? false;

    if (markAllRead) {
      await db.query(
        'UPDATE notifications SET is_read = true WHERE user_id = @userId',
        substitutionValues: {'userId': user.id},
      );
      return ApiResponse.success(message: 'All notifications marked as read');
    }

    if (notificationId == null) {
      return ApiResponse.error(
        message: 'notification_id or mark_all_read is required',
      );
    }

    await db.query(
      'UPDATE notifications SET is_read = true WHERE id = @id AND user_id = @userId',
      substitutionValues: {
        'id': notificationId,
        'userId': user.id,
      },
    );

    return ApiResponse.success(message: 'Notification marked as read');
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
