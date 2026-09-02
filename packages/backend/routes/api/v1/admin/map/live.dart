import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/map/live
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final db = context.read<PostgresService>();

  // Fetch all technicians who have a location set
  final techsResult = await db.query('''
    SELECT u.id, u.name, u.phone, u.location[0] as lng, u.location[1] as lat
    FROM users u
    JOIN roles r ON u.role_id = r.id
    WHERE r.name = 'technician' AND u.location IS NOT NULL
  ''');

  final technicians = techsResult.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'],
      'name': m['name'],
      'phone': m['phone'],
      'lat': m['lat'],
      'lng': m['lng'],
    };
  }).toList();

  // Fetch all active jobs (assigned, in_transit, started)
  final jobsResult = await db.query('''
    SELECT j.id, j.type, j.status, j.address, j.technician_id,
           c.name as customer_name, c.phone as customer_phone,
           c.location[0] as customer_lng, c.location[1] as customer_lat
    FROM jobs j
    JOIN users c ON j.customer_id = c.id
    WHERE j.status IN ('assigned', 'in_transit', 'started')
  ''');

  final jobs = jobsResult.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'],
      'type': m['type'],
      'status': m['status'],
      'address': m['address'],
      'technician_id': m['technician_id'],
      'customer': {
        'name': m['customer_name'],
        'phone': m['customer_phone'],
        'lat': m['customer_lat'],
        'lng': m['customer_lng'],
      }
    };
  }).toList();

  return ApiResponse.success(data: {
    'technicians': technicians,
    'active_jobs': jobs,
  });
}
