import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/tech/jobs → List assigned jobs (pending, in progress, etc.)
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();
  
  final statusFilter = request.url.queryParameters['status'];

  String whereClause = 'WHERE j.technician_id = @techId';
  final values = <String, dynamic>{'techId': user.id};

  if (statusFilter != null && statusFilter.isNotEmpty) {
    whereClause += ' AND j.status = @status';
    values['status'] = statusFilter;
  }

  final result = await db.query(
    '''
    SELECT j.*, u.name as customer_name, u.phone as customer_phone
    FROM jobs j
    JOIN users u ON j.customer_id = u.id
    $whereClause
    ORDER BY scheduled_at ASC NULLS LAST
    ''',
    substitutionValues: values,
  );

  final jobs = result.map((r) => r.toColumnMap()).toList();

  return ApiResponse.success(data: {'jobs': jobs});
}
