import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/tech/customers → List customers assigned to this technician
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();
  final search = request.url.queryParameters['search'];

  String searchClause = '';
  final params = <String, dynamic>{'techId': user.id};

  if (search != null && search.isNotEmpty) {
    searchClause = "AND (u.name ILIKE @search OR u.phone ILIKE @search)";
    params['search'] = '%$search%';
  }

  final result = await db.query(
    '''
    SELECT DISTINCT ON (u.id) u.id, u.name, u.phone, u.email, u.status as account_status,
      u.location::text as location, u.created_at,
      p.name as plan_name, p.speed_mbps, p.price as plan_price,
      up.expiry_date, up.data_used_gb, up.status as plan_status,
      m.signal_strength, m.ip_address as modem_ip, m.device_type as modem_type,
      m.last_synced as modem_last_seen,
      CASE WHEN m.signal_strength > -100 AND m.signal_strength IS NOT NULL THEN 'online' ELSE 'offline' END as connection_status
    FROM users u
    INNER JOIN jobs j ON j.customer_id = u.id AND j.technician_id = @techId
    INNER JOIN roles r ON u.role_id = r.id AND r.name = 'customer'
    LEFT JOIN user_plans up ON up.user_id = u.id AND up.status = 'active'
    LEFT JOIN plans p ON up.plan_id = p.id
    LEFT JOIN modem_info m ON m.user_id = u.id
    WHERE 1=1 $searchClause
    ORDER BY u.id, u.name ASC
    ''',
    substitutionValues: params,
  );

  final customers = result.map((r) => r.toColumnMap()).toList();

  return ApiResponse.success(data: {'customers': customers, 'total': customers.length});
}
