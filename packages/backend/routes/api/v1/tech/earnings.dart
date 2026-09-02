import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/tech/earnings → History of payouts and earnings stats
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // 1. Get Payout History
  final payoutsResult = await db.query(
    '''
    SELECT * FROM payouts 
    WHERE user_id = @userId AND role = 'technician'
    ORDER BY created_at DESC
    ''',
    substitutionValues: {'userId': user.id},
  );

  final payouts = payoutsResult.map((r) => r.toColumnMap()).toList();

  // 2. Get Job Completion Stats (Last 30 days)
  final statsResult = await db.query(
    '''
    SELECT 
      COUNT(*) as total_jobs,
      SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_jobs
    FROM jobs
    WHERE technician_id = @userId AND created_at > NOW() - INTERVAL '30 days'
    ''',
    substitutionValues: {'userId': user.id},
  );

  final stats = statsResult.first.toColumnMap();

  return ApiResponse.success(
    data: {
      'payouts': payouts,
      'stats': {
        'total_jobs_30d': stats['total_jobs'] ?? 0,
        'completed_jobs_30d': stats['completed_jobs'] ?? 0,
      }
    },
  );
}
