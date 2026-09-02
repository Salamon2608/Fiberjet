import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  // The UserModel is automatically injected by jwtAuthGuard via the roleGuard chain.
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // Fetch Active User Plan joined with Plan details
  final plansResult = await db.query(
    '''
    SELECT up.id, up.plan_id, up.status, up.data_used_gb,
           up.start_date, up.expiry_date,
           p.name as plan_name, p.speed_mbps, p.price, 
           p.data_limit_gb, p.cloud_storage_gb, p.ott_benefits
    FROM user_plans up
    JOIN plans p ON up.plan_id = p.id
    WHERE up.user_id = @userId AND up.status = 'active'
    LIMIT 1
    ''',
    substitutionValues: {'userId': user.id},
  );

  // Fetch Active Complaints
  final complaintsResult = await db.query(
    '''
    SELECT id, title, status, category, description, visit_otp, is_otp_verified, arrived_at, created_at 
    FROM complaints 
    WHERE user_id = @userId AND status IN ('open', 'in_progress')
    ORDER BY created_at DESC
    ''',
    substitutionValues: {'userId': user.id},
  );

  // Fetch Active Ads
  final adsResult = await db.query(
    '''
    SELECT * FROM ads
    WHERE is_active = true
      AND (start_date IS NULL OR start_date <= CURRENT_DATE)
      AND (end_date IS NULL OR end_date >= CURRENT_DATE)
    ORDER BY created_at DESC
    ''',
  );

  // Parse results safely — convert all values to JSON-safe types
  Map<String, dynamic>? activePlan;
  if (plansResult.isNotEmpty) {
    final row = plansResult.first.toColumnMap();
    activePlan = row.map((key, value) {
      if (value is DateTime) return MapEntry(key, value.toIso8601String());
      return MapEntry(key, value);
    });

    // Compute backend subscription statistics using the trusted server clock
    final expiryDate = row['expiry_date'] as DateTime?;
    final startDate = row['start_date'] as DateTime?;
    
    final dataLimitGbStr = row['data_limit_gb'];
    final dataLimitGb = dataLimitGbStr != null ? double.tryParse(dataLimitGbStr.toString()) : null;
    final dataUsedGbStr = row['data_used_gb'];
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

  final activeComplaints = complaintsResult.map((r) {
    final row = r.toColumnMap();
    return row.map((key, value) {
      if (value is DateTime) return MapEntry(key, value.toIso8601String());
      return MapEntry(key, value);
    });
  }).toList();

  final activeAds = adsResult.map((r) {
    final row = r.toColumnMap();
    return row.map((key, value) {
      if (value is DateTime) return MapEntry(key, value.toIso8601String());
      return MapEntry(key, value);
    });
  }).toList();

  return ApiResponse.success(
    data: {
      'user': user.toJson(),
      'active_plan': activePlan,
      'active_complaints': activeComplaints,
      'active_ads': activeAds,
    },
  );
}

