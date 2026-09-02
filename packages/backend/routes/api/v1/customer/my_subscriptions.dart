import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  try {
    // 1. Fetch Active User Plan
    final activeResult = await db.query(
      '''
      SELECT up.id, up.plan_id, up.status, up.data_used_gb,
             up.start_date, up.expiry_date,
             p.name as plan_name, p.speed_mbps, p.price, 
             p.data_limit_gb, p.cloud_storage_gb, p.ott_benefits
      FROM user_plans up
      JOIN plans p ON up.plan_id = p.id
      WHERE up.user_id = @userId AND up.status = 'active'
      ORDER BY up.start_date DESC
      LIMIT 1
      ''',
      substitutionValues: {'userId': user.id},
    );

    // 2. Fetch Queued / Upcoming Plans
    final queuedResult = await db.query(
      '''
      SELECT up.id, up.plan_id, up.status,
             up.start_date, up.expiry_date,
             p.name as plan_name, p.speed_mbps, p.price, 
             p.data_limit_gb, p.cloud_storage_gb, p.ott_benefits
      FROM user_plans up
      JOIN plans p ON up.plan_id = p.id
      WHERE up.user_id = @userId AND up.status IN ('queued', 'pending')
      ORDER BY up.created_at ASC
      ''',
      substitutionValues: {'userId': user.id},
    );

    // 3. Fetch History (Expired Plans)
    final historyResult = await db.query(
      '''
      SELECT up.id, up.plan_id, up.status, up.data_used_gb,
             up.start_date, up.expiry_date,
             p.name as plan_name, p.speed_mbps, p.price, 
             p.data_limit_gb, p.cloud_storage_gb, p.ott_benefits
      FROM user_plans up
      JOIN plans p ON up.plan_id = p.id
      WHERE up.user_id = @userId AND up.status = 'expired'
      ORDER BY up.expiry_date DESC
      ''',
      substitutionValues: {'userId': user.id},
    );

    Map<String, dynamic> parseRow(Map<String, dynamic> row) {
      return row.map((key, value) {
        if (value is DateTime) return MapEntry(key, value.toIso8601String());
        return MapEntry(key, value);
      });
    }

    final activePlanRow = activeResult.isNotEmpty ? activeResult.first.toColumnMap() : null;
    Map<String, dynamic>? activePlan;
    if (activePlanRow != null) {
      activePlan = parseRow(activePlanRow);

      // Compute backend subscription statistics using the trusted server clock
      final expiryDate = activePlanRow['expiry_date'] as DateTime?;
      final startDate = activePlanRow['start_date'] as DateTime?;
      
      final dataLimitGbStr = activePlanRow['data_limit_gb'];
      final dataLimitGb = dataLimitGbStr != null ? double.tryParse(dataLimitGbStr.toString()) : null;
      final dataUsedGbStr = activePlanRow['data_used_gb'];
      final dataUsedGb = dataUsedGbStr != null ? (double.tryParse(dataUsedGbStr.toString()) ?? 0.0) : 0.0;

      if (expiryDate != null) {
        final now = DateTime.now();
        final diffHours = expiryDate.difference(now).inHours;
        final daysLeft = diffHours > 0 ? (diffHours / 24).ceil() : 0;
        activePlan['days_left'] = daysLeft;
        
        if (startDate != null) {
          final totalDays = expiryDate.difference(startDate).inDays;
          final passedDays = totalDays - daysLeft;
          final timeProgress = totalDays > 0 ? (passedDays / totalDays).clamp(0.0, 1.0) : 0.0;
          activePlan['time_progress'] = timeProgress;
        }
      }

      if (dataLimitGb != null && dataLimitGb > 0) {
        final double limit = dataLimitGb;
        final dataLeftGb = (limit - dataUsedGb).clamp(0.0, limit);
        final dataProgress = dataLeftGb / limit;
        activePlan['data_progress'] = dataProgress;
        activePlan['data_left_gb'] = dataLeftGb;
        activePlan['data_percent'] = dataProgress * 100;
      }
    }
    final upcomingPlans = queuedResult.map((r) => parseRow(r.toColumnMap())).toList();
    final history = historyResult.map((r) => parseRow(r.toColumnMap())).toList();

    return ApiResponse.success(
      data: {
        'active_plan': activePlan,
        'upcoming_plans': upcomingPlans,
        'history': history,
      },
    );
  } catch (e) {
    return ApiResponse.error(message: 'Failed to fetch subscriptions: $e');
  }
}
