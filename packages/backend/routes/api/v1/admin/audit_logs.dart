import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/audit_logs → Paginated audit logs with filters
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();
  final params = request.url.queryParameters;

  final userId = params['user_id'];
  final action = params['action'];
  final dateFrom = params['date_from'];
  final dateTo = params['date_to'];
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
  final offset = (page - 1) * limit;

  final conditions = <String>['1=1'];
  final values = <String, dynamic>{'limit': limit, 'offset': offset};

  if (userId != null && userId.isNotEmpty) {
    conditions.add('al.user_id = @userId');
    values['userId'] = userId;
  }

  if (action != null && action.isNotEmpty) {
    conditions.add('al.action ILIKE @action');
    values['action'] = '%$action%';
  }

  if (dateFrom != null) {
    conditions.add('al.created_at >= @dateFrom');
    values['dateFrom'] = dateFrom;
  }

  if (dateTo != null) {
    conditions.add('al.created_at <= @dateTo');
    values['dateTo'] = dateTo;
  }

  final whereClause = conditions.join(' AND ');

  final result = await db.query(
    '''
    SELECT al.*, u.name as user_name
    FROM audit_logs al
    LEFT JOIN users u ON al.user_id = u.id
    WHERE $whereClause
    ORDER BY al.created_at DESC
    LIMIT @limit OFFSET @offset
    ''',
    substitutionValues: values,
  );

  final logs = result.map((r) => r.toColumnMap()).toList();

  return ApiResponse.success(
    data: {
      'logs': logs,
      'page': page,
      'limit': limit,
    },
  );
}
