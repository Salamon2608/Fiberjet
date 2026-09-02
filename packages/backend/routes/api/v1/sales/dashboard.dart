import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/sales/dashboard → Aggregated dashboard KPIs for the sales person
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
        message: 'Method not allowed',
        statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // 1. Today's leads count
  final todayLeadsResult = await db.query(
    '''
    SELECT COUNT(*) as count FROM leads
    WHERE sales_person_id = @salesId
      AND DATE(created_at) = CURRENT_DATE
    ''',
    substitutionValues: {'salesId': user.id},
  );
  final todayLeads = todayLeadsResult.first.toColumnMap()['count'] ?? 0;

  // 2. Month-to-date commission total
  final mtdResult = await db.query(
    '''
    SELECT COALESCE(SUM(amount), 0) as mtd_total
    FROM commissions
    WHERE sales_person_id = @salesId
      AND created_at >= DATE_TRUNC('month', CURRENT_DATE)
    ''',
    substitutionValues: {'salesId': user.id},
  );
  final mtdCommission = mtdResult.first.toColumnMap()['mtd_total'] ?? 0;

  // 3. Total withdrawable (pending commissions)
  final withdrawableResult = await db.query(
    '''
    SELECT COALESCE(SUM(amount), 0) as withdrawable
    FROM commissions
    WHERE sales_person_id = @salesId
      AND status IN ('approved', 'pending')
    ''',
    substitutionValues: {'salesId': user.id},
  );
  final withdrawable = withdrawableResult.first.toColumnMap()['withdrawable'] ?? 0;

  // 4. Leaderboard rank (by total commission this month across all sales reps)
  final leaderboardResult = await db.query(
    '''
    WITH rankings AS (
      SELECT sales_person_id,
             SUM(amount) as total,
             RANK() OVER (ORDER BY SUM(amount) DESC) as rank
      FROM commissions
      WHERE created_at >= DATE_TRUNC('month', CURRENT_DATE)
      GROUP BY sales_person_id
    )
    SELECT rank FROM rankings WHERE sales_person_id = @salesId
    ''',
    substitutionValues: {'salesId': user.id},
  );
  final leaderboardRank = leaderboardResult.isNotEmpty
      ? leaderboardResult.first.toColumnMap()['rank'] ?? 0
      : 0;

  // 5. Pipeline summary — count leads per stage
  final pipelineResult = await db.query(
    '''
    SELECT stage, COUNT(*) as count
    FROM leads
    WHERE sales_person_id = @salesId
    GROUP BY stage
    ''',
    substitutionValues: {'salesId': user.id},
  );
  final pipeline = <String, dynamic>{};
  var totalLeads = 0;
  for (final row in pipelineResult) {
    final map = row.toColumnMap();
    final stage = map['stage']?.toString() ?? 'unknown';
    final count = map['count'] ?? 0;
    pipeline[stage] = count;
    totalLeads += (count as int);
  }

  // 6. Latest lead per stage (for dashboard preview cards)
  final previewResult = await db.query(
    '''
    SELECT DISTINCT ON (stage)
      id, customer_name, phone, address, stage, score, created_at
    FROM leads
    WHERE sales_person_id = @salesId
    ORDER BY stage, created_at DESC
    ''',
    substitutionValues: {'salesId': user.id},
  );
  final previewLeads = previewResult.map((r) => r.toColumnMap()).toList();

  // 7. Recent activity (last 10 lead-related actions)
  final activityResult = await db.query(
    '''
    SELECT action, target_table, created_at
    FROM audit_logs
    WHERE user_id = @salesId
    ORDER BY created_at DESC
    LIMIT 10
    ''',
    substitutionValues: {'salesId': user.id},
  );
  final recentActivity = activityResult.map((r) => r.toColumnMap()).toList();

  // 8. Sales person name
  final nameResult = await db.query(
    'SELECT name FROM users WHERE id = @id LIMIT 1',
    substitutionValues: {'id': user.id},
  );
  final salesName = nameResult.isNotEmpty
      ? nameResult.first.toColumnMap()['name'] ?? 'Sales Rep'
      : 'Sales Rep';

  return ApiResponse.success(
    data: {
      'name': salesName,
      'today_leads': todayLeads,
      'mtd_commission': mtdCommission,
      'withdrawable': withdrawable,
      'leaderboard_rank': leaderboardRank,
      'total_leads': totalLeads,
      'pipeline': pipeline,
      'preview_leads': previewLeads,
      'recent_activity': recentActivity,
    },
  );
}
