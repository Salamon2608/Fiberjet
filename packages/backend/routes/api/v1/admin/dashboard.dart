import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/dashboard → Global KPIs for admin overview
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();

  try {

  // 1. User stats
  final userStats = await db.query('''
    SELECT 
      COUNT(u.id) as total_users,
      SUM(CASE WHEN u.status = 'active' AND r.name = 'customer' THEN 1 ELSE 0 END) as active_users,
      SUM(CASE WHEN u.is_vip = true AND r.name = 'customer' THEN 1 ELSE 0 END) as vip_users,
      SUM(CASE WHEN u.status = 'blocked' AND r.name = 'customer' THEN 1 ELSE 0 END) as blocked_users,
      SUM(CASE WHEN u.created_at >= NOW() - INTERVAL '7 days' AND r.name = 'customer' THEN 1 ELSE 0 END) as new_this_week,
      SUM(CASE WHEN u.created_at >= NOW() - INTERVAL '30 days' AND r.name = 'customer' THEN 1 ELSE 0 END) as new_this_month
    FROM users u
    LEFT JOIN roles r ON u.role_id = r.id
  ''');

  // 2. Complaint stats
  final complaintStats = await db.query('''
    SELECT 
      COUNT(*) as total_complaints,
      SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END) as open_complaints,
      SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_complaints
    FROM complaints
  ''');

  // Helper to safely convert postgres numerics to int
  int toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '0') ?? 0;

  final complaintCategories = await db.query('SELECT category, COUNT(*) as count FROM complaints GROUP BY category');
  final Map<String, int> categoriesBreakdown = {};
  for (final row in complaintCategories) {
    final map = row.toColumnMap();
    final cat = map['category']?.toString() ?? 'unknown';
    categoriesBreakdown[cat] = toInt(map['count']);
  }

  // 3. Financial Stats
  final financialStats = await db.query('''
    SELECT 
      COALESCE((SELECT SUM(amount) FROM payouts WHERE status = 'paid'), 0) as total_expenses,
      COALESCE((SELECT SUM(price) FROM user_plans up JOIN plans p ON up.plan_id = p.id WHERE up.status = 'active'), 0) as subscription_earnings,
      COALESCE((SELECT SUM(amount) FROM payouts WHERE status = 'pending'), 0) as pending_payments
  ''');

  // 4. Technician efficiency
  final techStats = await db.query('''
    SELECT 
      COUNT(*) as total_jobs_30d,
      SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_jobs_30d,
      SUM(CASE WHEN status != 'completed' AND scheduled_at < NOW() THEN 1 ELSE 0 END) as missed_appointments_count,
      AVG(EXTRACT(EPOCH FROM (completed_at - scheduled_at))/3600) as avg_completion_time_hours
    FROM jobs
    WHERE created_at > NOW() - INTERVAL '30 days'
  ''');

  final ratingStats = await db.query('SELECT COALESCE(AVG(stars), 0) as avg_rating FROM ratings');

  // 5. Lead stats
  final leadStats = await db.query('''
    SELECT 
      COUNT(*) as total_leads,
      SUM(CASE WHEN stage = 'new' THEN 1 ELSE 0 END) as new_leads,
      SUM(CASE WHEN stage = 'installed' THEN 1 ELSE 0 END) as converted_leads
    FROM leads
  ''');

  // 6. Pending Approvals
  final pendingApprovalsResult = await db.query('''
    SELECT u.id, u.name, r.name as role_name, u.created_at
    FROM users u
    LEFT JOIN roles r ON u.role_id = r.id
    WHERE u.status = 'pending'
    ORDER BY u.created_at DESC
    LIMIT 5
  ''');

  final pendingApprovals = pendingApprovalsResult.map((row) {
    final map = row.toColumnMap();
    return {
      'id': map['id']?.toString(),
      'name': map['name']?.toString() ?? 'Unknown',
      'role': map['role_name']?.toString() ?? 'customer',
      'created_at': map['created_at']?.toString(),
    };
  }).toList();

  // 7. Active Users Growth (Last 6 Months)
  final userGrowthResult = await db.query('''
    SELECT TO_CHAR(u.created_at, 'Mon') as month, COUNT(u.id)::int as count 
    FROM users u
    JOIN roles r ON u.role_id = r.id
    WHERE u.created_at >= NOW() - INTERVAL '6 months' AND r.name = 'customer'
    GROUP BY TO_CHAR(u.created_at, 'Mon'), EXTRACT(MONTH FROM u.created_at)
    ORDER BY EXTRACT(MONTH FROM u.created_at)
  ''');

  final userGrowth = <Map<String, dynamic>>[];
  final now = DateTime.now();
  final monthsNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  
  for (int i = 5; i >= 0; i--) {
    final prevMonthDate = DateTime(now.year, now.month - i, 1);
    final monthLabel = monthsNames[prevMonthDate.month - 1];
    
    double countVal = 0.0;
    for (final row in userGrowthResult) {
      final map = row.toColumnMap();
      if (map['month']?.toString().toLowerCase().trim() == monthLabel.toLowerCase().trim()) {
        countVal = (map['count'] is int ? map['count'] as int : int.tryParse(map['count'].toString()) ?? 0).toDouble();
        break;
      }
    }
    
    userGrowth.add({
      'label': monthLabel,
      'value': countVal,
    });
  }

  // 8. Revenue History (Last 7 Days)
  final revenueHistoryResult = await db.query('''
    SELECT TO_CHAR(up.created_at, 'Dy') as day, SUM(p.price)::numeric as total 
    FROM user_plans up
    JOIN plans p ON up.plan_id = p.id
    WHERE up.created_at >= NOW() - INTERVAL '7 days' 
    GROUP BY TO_CHAR(up.created_at, 'Dy'), EXTRACT(DOW FROM up.created_at)
    ORDER BY EXTRACT(DOW FROM up.created_at)
  ''');

  final revenueHistory = <Map<String, dynamic>>[];
  final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  
  for (int i = 6; i >= 0; i--) {
    final prevDayDate = now.subtract(Duration(days: i));
    final dayLabel = dayNames[prevDayDate.weekday % 7];
    
    double dayTotal = 0.0;
    for (final row in revenueHistoryResult) {
      final map = row.toColumnMap();
      if (map['day']?.toString().toLowerCase().trim() == dayLabel.toLowerCase().trim()) {
        dayTotal = double.tryParse(map['total']?.toString() ?? '0') ?? 0.0;
        break;
      }
    }
    
    revenueHistory.add({
      'label': dayLabel,
      'value': dayTotal,
    });
  }

  // 9. Live Tracking (Technicians)
  final liveTrackingResult = await db.query('''
    SELECT u.id, u.name, u.location, r.name as role_name
    FROM users u
    JOIN roles r ON u.role_id = r.id
    WHERE r.name = 'technician' AND u.location IS NOT NULL
  ''');

  final liveTracking = liveTrackingResult.map((row) {
    final map = row.toColumnMap();
    final location = map['location'];
    return {
      'id': map['id']?.toString(),
      'name': map['name']?.toString() ?? 'Unknown',
      'location': location?.toString(),
    };
  }).toList();

  final users = userStats.first.toColumnMap();
  final complaints = complaintStats.first.toColumnMap();
  final fins = financialStats.first.toColumnMap();
  final tech = techStats.first.toColumnMap();
  final leads = leadStats.first.toColumnMap();
  final rating = ratingStats.first.toColumnMap();

  final totalJobs = toInt(tech['total_jobs_30d']);
  final completedJobs = toInt(tech['completed_jobs_30d']);
  
  final subscriptionEarnings = double.tryParse(fins['subscription_earnings']?.toString() ?? '0') ?? 0.0;
  final totalExpenses = double.tryParse(fins['total_expenses']?.toString() ?? '0') ?? 0.0;
  final pendingPayments = double.tryParse(fins['pending_payments']?.toString() ?? '0') ?? 0.0;
  final netProfit = subscriptionEarnings - totalExpenses;

  return ApiResponse.success(
    data: {
      'users': {
        'total': toInt(users['total_users']),
        'active': toInt(users['active_users']),
        'vip': toInt(users['vip_users']),
        'blocked': toInt(users['blocked_users']),
        'new_this_week': toInt(users['new_this_week']),
        'new_this_month': toInt(users['new_this_month']),
      },
      'complaints': {
        'total': toInt(complaints['total_complaints']),
        'open': toInt(complaints['open_complaints']),
        'in_progress': toInt(complaints['in_progress_complaints']),
        'categories_breakdown': categoriesBreakdown,
      },
      'revenue': {
        'mrr': subscriptionEarnings.toStringAsFixed(2),
        'subscription_earnings': subscriptionEarnings.toStringAsFixed(2),
        'total_expenses': totalExpenses.toStringAsFixed(2),
        'pending_payments': pendingPayments.toStringAsFixed(2),
        'net_profit': netProfit.toStringAsFixed(2),
      },
      'technicians': {
        'total_jobs_30d': totalJobs,
        'completed_jobs_30d': completedJobs,
        'missed_appointments_count': toInt(tech['missed_appointments_count']),
        'avg_completion_time_hours': double.tryParse(tech['avg_completion_time_hours']?.toString() ?? '0') ?? 0.0,
        'avg_rating': double.tryParse(rating['avg_rating']?.toString() ?? '0') ?? 0.0,
        'efficiency': totalJobs > 0
            ? (completedJobs / totalJobs * 100).toStringAsFixed(1)
            : '0.0',
      },
      'leads': {
        'total': toInt(leads['total_leads']),
        'new': toInt(leads['new_leads']),
        'converted': toInt(leads['converted_leads']),
      },
      'pending_approvals': pendingApprovals,
      'charts': {
        'user_growth': userGrowth,
        'revenue_history': revenueHistory,
      },
      'live_tracking': liveTracking,
    },
  );
  } catch (e) {
    return ApiResponse.error(message: 'Dashboard error: $e');
  }
}
