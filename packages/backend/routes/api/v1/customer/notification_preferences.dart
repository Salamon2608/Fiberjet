import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/customer/notification_preferences → Returns user's preferences
/// PUT  /api/v1/customer/notification_preferences → Updates user's preferences
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: Fetch preferences ─────────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      'SELECT * FROM notification_preferences WHERE user_id = @userId LIMIT 1',
      substitutionValues: {'userId': user.id},
    );

    if (result.isEmpty) {
      // Return defaults if no row exists yet
      return ApiResponse.success(data: {
        'network_alerts': true,
        'security_warnings': true,
        'bill_reminders': true,
        'promotional_offers': false,
      });
    }

    final row = result.first.toColumnMap();
    return ApiResponse.success(data: {
      'network_alerts': row['network_alerts'] ?? true,
      'security_warnings': row['security_warnings'] ?? true,
      'bill_reminders': row['bill_reminders'] ?? true,
      'promotional_offers': row['promotional_offers'] ?? false,
    });
  }

  // ── PUT: Update preferences ────────────────────────────────
  if (request.method == HttpMethod.put) {
    final body = await request.json() as Map<String, dynamic>;

    // Upsert the preferences row
    await db.query(
      '''
      INSERT INTO notification_preferences (user_id, network_alerts, security_warnings, bill_reminders, promotional_offers, updated_at)
      VALUES (@userId, @networkAlerts, @securityWarnings, @billReminders, @promotionalOffers, NOW())
      ON CONFLICT (user_id) DO UPDATE SET
        network_alerts = @networkAlerts,
        security_warnings = @securityWarnings,
        bill_reminders = @billReminders,
        promotional_offers = @promotionalOffers,
        updated_at = NOW()
      ''',
      substitutionValues: {
        'userId': user.id,
        'networkAlerts': body['network_alerts'] ?? true,
        'securityWarnings': body['security_warnings'] ?? true,
        'billReminders': body['bill_reminders'] ?? true,
        'promotionalOffers': body['promotional_offers'] ?? false,
      },
    );

    return ApiResponse.success(message: 'Notification preferences updated');
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
