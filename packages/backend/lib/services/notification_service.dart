import 'package:backend/services/postgres_service.dart';

class NotificationService {
  final PostgresService _db;

  NotificationService(this._db);

  /// Sends a notification to a user.
  /// Currently logs to console and saves to DB. 
  /// FCM integration will be added in Phase H.
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'system',
    Map<String, dynamic>? data,
  }) async {
    print('🔔 [NOTIFICATION] To: $userId | Title: $title | Body: $body');

    try {
      await _db.query(
        '''
        INSERT INTO notifications (user_id, title, body, type, data)
        VALUES (@userId, @title, @body, @type, @data)
        ''',
        substitutionValues: {
          'userId': userId,
          'title': title,
          'body': body,
          'type': type,
          'data': data ?? {},
        },
      );
    } catch (e) {
      print('❌ Failed to save notification to DB: $e');
    }
  }
}
