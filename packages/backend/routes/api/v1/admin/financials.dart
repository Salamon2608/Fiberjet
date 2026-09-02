import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/financials → Revenue, expenses, net profit, monthly trend
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();

  // 1. Total Revenue Breakdown
  final revenueResult = await db.query('''
    SELECT 
      COALESCE((SELECT SUM(p.price) FROM user_plans up JOIN plans p ON up.plan_id = p.id WHERE up.status = 'active'), 0) as subscription_revenue,
      COALESCE((SELECT SUM(service_charge) FROM jobs WHERE status = 'completed'), 0) as service_revenue,
      COALESCE((SELECT SUM(revenue_generated) FROM ads), 0) as ad_revenue
  ''');

  // 2. Total Expenses Breakdown
  final expenseResult = await db.query('''
    SELECT 
      COALESCE((SELECT SUM(amount) FROM payouts), 0) as payout_expenses,
      COALESCE((SELECT SUM(amount) FROM expenses WHERE category ILIKE '%marketing%'), 0) as marketing_expenses,
      COALESCE((SELECT SUM(amount) FROM expenses WHERE category ILIKE '%maintenance%'), 0) as maintenance_expenses,
      COALESCE((SELECT SUM(amount) FROM expenses WHERE category NOT ILIKE '%marketing%' AND category NOT ILIKE '%maintenance%'), 0) as other_expenses
  ''');

  // 3. Monthly Revenue Trend (last 6 months)
  final trendResult = await db.query('''
    SELECT 
      TO_CHAR(up.created_at, 'YYYY-MM') as month,
      COALESCE(SUM(p.price), 0) as revenue
    FROM user_plans up
    JOIN plans p ON up.plan_id = p.id
    WHERE up.created_at > NOW() - INTERVAL '6 months'
    GROUP BY TO_CHAR(up.created_at, 'YYYY-MM')
    ORDER BY month ASC
  ''');

  // 4. Monthly Expenses Trend
  final expenseTrendResult = await db.query('''
    SELECT 
      TO_CHAR(expense_date, 'YYYY-MM') as month,
      COALESCE(SUM(amount), 0) as expenses
    FROM expenses
    WHERE expense_date > NOW() - INTERVAL '6 months'
    GROUP BY TO_CHAR(expense_date, 'YYYY-MM')
    ORDER BY month ASC
  ''');

  num parseNum(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    return num.tryParse(val.toString()) ?? 0;
  }

  final revRow = revenueResult.first.toColumnMap();
  final subRev = parseNum(revRow['subscription_revenue']);
  final srvRev = parseNum(revRow['service_revenue']);
  final adRev = parseNum(revRow['ad_revenue']);
  final totalRevenue = subRev + srvRev + adRev;

  final expRow = expenseResult.first.toColumnMap();
  final payExp = parseNum(expRow['payout_expenses']);
  final mktExp = parseNum(expRow['marketing_expenses']);
  final mntExp = parseNum(expRow['maintenance_expenses']);
  final othExp = parseNum(expRow['other_expenses']);
  final totalExpenses = payExp + mktExp + mntExp + othExp;

  // Forecasting (simple projection based on last month if exists, else average)
  num projectedRevenue = 0;
  num projectedExpenses = 0;
  num growthEstimation = 0;

  if (trendResult.isNotEmpty) {
    projectedRevenue = parseNum(trendResult.last.toColumnMap()['revenue']) * 1.05; // 5% growth assumption
    growthEstimation = 5.0;
  }
  if (expenseTrendResult.isNotEmpty) {
    projectedExpenses = parseNum(expenseTrendResult.last.toColumnMap()['expenses']) * 1.02; // 2% expense growth
  }

  return ApiResponse.success(
    data: {
      'summary': {
        'total_revenue': totalRevenue,
        'total_expenses': totalExpenses,
        'net_profit': totalRevenue - totalExpenses,
      },
      'revenue_breakdown': {
        'subscriptions': subRev,
        'service_charges': srvRev,
        'ads': adRev,
      },
      'expense_breakdown': {
        'payouts': payExp,
        'marketing': mktExp,
        'maintenance': mntExp,
        'other': othExp,
      },
      'forecast': {
        'future_revenue': projectedRevenue,
        'expected_expenses': projectedExpenses,
        'growth_estimation': growthEstimation,
      },
      'revenue_trend': trendResult.map((r) {
        final row = r.toColumnMap();
        return <String, dynamic>{
          for (final entry in row.entries)
            entry.key: entry.key == 'revenue' ? parseNum(entry.value) : entry.value,
        };
      }).toList(),
      'expense_trend': expenseTrendResult.map((r) {
        final row = r.toColumnMap();
        return <String, dynamic>{
          for (final entry in row.entries)
            entry.key: entry.key == 'expenses' ? parseNum(entry.value) : entry.value,
        };
      }).toList(),
    },
  );
}
