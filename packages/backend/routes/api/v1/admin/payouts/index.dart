import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/admin/payouts → List pending payouts with user details
/// POST /api/v1/admin/payouts → (redirects to /approve for backward compat)
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();
  final params = request.url.queryParameters;
  final statusFilter = params['status'] ?? 'pending';
  final role = params['role'];

  final conditions = <String>['1=1'];
  final values = <String, dynamic>{};

  if (statusFilter.isNotEmpty) {
    conditions.add('p.status = @status');
    values['status'] = statusFilter;
  }

  if (role != null && role.isNotEmpty) {
    conditions.add('p.role = @role');
    values['role'] = role;
  }

  final whereClause = conditions.join(' AND ');

  final result = await db.query(
    '''
    SELECT p.id, p.user_id, p.role, p.amount, p.bank_account, p.upi_id, 
           p.status, p.created_at,
           u.name as user_name, u.phone as user_phone
    FROM payouts p
    JOIN users u ON p.user_id = u.id
    WHERE $whereClause
    ORDER BY p.created_at DESC
    ''',
    substitutionValues: values,
  );

  final payouts = result.map((r) => r.toColumnMap()).toList();

  // Summary stats
  final summaryResult = await db.query('''
    SELECT 
      COUNT(*) as total_pending,
      COALESCE(SUM(amount), 0) as total_amount
    FROM payouts
    WHERE status = 'pending'
  ''');

  final summary = summaryResult.first.toColumnMap();

  return ApiResponse.success(data: {
    'payouts': payouts,
    'summary': {
      'total_pending': summary['total_pending'] ?? 0,
      'total_amount': summary['total_amount'] ?? 0,
    },
  });
}
