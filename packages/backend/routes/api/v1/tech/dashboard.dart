import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/tech/dashboard → Full aggregated dashboard data
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
        message: 'Method not allowed',
        statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // 1. All relevant Jobs (active/pending/completed recently)
  final todayJobsResult = await db.query(
    '''
    SELECT j.*, u.name as customer_name, u.phone as customer_phone
    FROM jobs j
    JOIN users u ON j.customer_id = u.id
    WHERE j.technician_id = @techId
      AND (j.status != 'completed' OR DATE(j.scheduled_at) = CURRENT_DATE)
    ORDER BY j.scheduled_at ASC NULLS LAST
    ''',
    substitutionValues: {'techId': user.id},
  );
  final todayJobs = todayJobsResult.map((r) => r.toColumnMap()).toList();

  // 2. Job counts
  final countsResult = await db.query(
    '''
    SELECT
      COUNT(*) as total,
      SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
      SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending,
      SUM(CASE WHEN status IN ('en_route', 'arrived', 'in_progress') THEN 1 ELSE 0 END) as active
    FROM jobs
    WHERE technician_id = @techId
      AND (status != 'completed' OR DATE(scheduled_at) = CURRENT_DATE)
    ''',
    substitutionValues: {'techId': user.id},
  );
  final counts = countsResult.first.toColumnMap();

  // 3. Weekly Earnings
  final weekEarningsResult = await db.query(
    '''
    SELECT COALESCE(SUM(amount), 0) as weekly_total
    FROM payouts
    WHERE user_id = @techId AND role = 'technician'
      AND created_at > NOW() - INTERVAL '7 days' AND status = 'approved'
    ''',
    substitutionValues: {'techId': user.id},
  );
  final weeklyEarnings = weekEarningsResult.first.toColumnMap()['weekly_total'] ?? 0;

  // 4. Daily earnings
  final dailyResult = await db.query(
    '''
    SELECT COALESCE(SUM(amount), 0) as daily_total
    FROM payouts
    WHERE user_id = @techId AND role = 'technician'
      AND DATE(created_at) = CURRENT_DATE AND status = 'approved'
    ''',
    substitutionValues: {'techId': user.id},
  );
  final dailyEarnings = dailyResult.first.toColumnMap()['daily_total'] ?? 0;

  // 5. Active/Current job
  Map<String, dynamic>? activeJob;
  for (final job in todayJobs) {
    final status = job['status']?.toString() ?? '';
    if (status != 'completed' && status != 'rejected' && status != 'cancelled') {
      activeJob = job;
      break;
    }
  }

  // 6. Assigned customers count (unique customers from all jobs)
  final customerCountResult = await db.query(
    '''
    SELECT COUNT(DISTINCT customer_id) as total_customers
    FROM jobs WHERE technician_id = @techId
    ''',
    substitutionValues: {'techId': user.id},
  );
  final totalCustomers = customerCountResult.first.toColumnMap()['total_customers'] ?? 0;

  // 7. Device health (modem status for assigned customers)
  final deviceHealthResult = await db.query(
    '''
    SELECT
      COUNT(*) as total_devices,
      SUM(CASE WHEN m.signal_strength > -50 THEN 1 ELSE 0 END) as healthy,
      SUM(CASE WHEN m.signal_strength BETWEEN -70 AND -50 THEN 1 ELSE 0 END) as warning,
      SUM(CASE WHEN m.signal_strength < -70 THEN 1 ELSE 0 END) as critical,
      SUM(CASE WHEN m.signal_strength > -100 THEN 1 ELSE 0 END) as online,
      SUM(CASE WHEN m.signal_strength <= -100 OR m.signal_strength IS NULL THEN 1 ELSE 0 END) as offline
    FROM modem_info m
    WHERE m.user_id IN (
      SELECT DISTINCT customer_id FROM jobs WHERE technician_id = @techId
    )
    ''',
    substitutionValues: {'techId': user.id},
  );
  final deviceHealth = deviceHealthResult.first.toColumnMap();

  // 8. Urgent tickets (open complaints assigned to this tech)
  final urgentTicketsResult = await db.query(
    '''
    SELECT c.id, c.title, c.category, c.status, c.description, c.created_at,
           u.name as customer_name, u.phone as customer_phone
    FROM complaints c
    JOIN users u ON c.user_id = u.id
    WHERE (c.assigned_to = @techId OR (
      c.assigned_to IS NULL AND c.category IN ('Technical Support', 'Connection Speed', 'Equipment Issue')
    ))
    AND c.status IN ('open', 'in_progress')
    ORDER BY c.created_at ASC
    LIMIT 5
    ''',
    substitutionValues: {'techId': user.id},
  );
  final urgentTickets = urgentTicketsResult.map((r) => r.toColumnMap()).toList();

  // 9. Recent activity (last 5 actions from audit_logs)
  final activityResult = await db.query(
    '''
    SELECT action, target_table, created_at
    FROM audit_logs
    WHERE user_id = @techId
    ORDER BY created_at DESC
    LIMIT 5
    ''',
    substitutionValues: {'techId': user.id},
  );
  final recentActivity = activityResult.map((r) => r.toColumnMap()).toList();

  // 10. Technician Online Status
  final isOnlineResult = await db.query(
    'SELECT is_online FROM users WHERE id = @techId',
    substitutionValues: {'techId': user.id},
  );
  final isOnline = isOnlineResult.isNotEmpty 
      ? (isOnlineResult.first.toColumnMap()['is_online'] ?? false) 
      : false;

  return ApiResponse.success(
    data: {
      'is_online': isOnline,
      'today_jobs': todayJobs,
      'counts': {
        'total': counts['total'] ?? 0,
        'completed': counts['completed'] ?? 0,
        'pending': counts['pending'] ?? 0,
        'active': counts['active'] ?? 0,
      },
      'earnings': {
        'daily': dailyEarnings,
        'weekly': weeklyEarnings,
      },
      'active_job': activeJob,
      'total_customers': totalCustomers,
      'device_health': {
        'total': deviceHealth['total_devices'] ?? 0,
        'healthy': deviceHealth['healthy'] ?? 0,
        'warning': deviceHealth['warning'] ?? 0,
        'critical': deviceHealth['critical'] ?? 0,
        'online': deviceHealth['online'] ?? 0,
        'offline': deviceHealth['offline'] ?? 0,
      },
      'urgent_tickets': urgentTickets,
      'recent_activity': recentActivity,
    },
  );
}
