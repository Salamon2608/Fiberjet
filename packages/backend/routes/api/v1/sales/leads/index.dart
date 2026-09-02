import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/sales/leads → List leads for the current sales person
/// POST /api/v1/sales/leads → Create a new lead
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: List Leads ───────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final stage = request.url.queryParameters['stage'];
    final search = request.url.queryParameters['search'];

    String whereClause = 'WHERE sales_person_id = @salesId';
    final values = <String, dynamic>{'salesId': user.id};

    if (stage != null && stage.isNotEmpty) {
      whereClause += ' AND stage = @stage';
      values['stage'] = stage;
    }

    if (search != null && search.isNotEmpty) {
      whereClause += ' AND (customer_name ILIKE @search OR phone ILIKE @search)';
      values['search'] = '%$search%';
    }

    final result = await db.query(
      'SELECT * FROM leads $whereClause ORDER BY created_at DESC',
      substitutionValues: values,
    );

    final leads = result.map((r) => r.toColumnMap()).toList();
    return ApiResponse.success(data: {'leads': leads});
  }

  // ── POST: Create Lead ──────────────────────────────────────
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final name = body['customer_name'] as String?;
    final phone = body['phone'] as String?;
    final address = body['address'] as String?;

    final email = body['email'] as String?;

    if (name == null || phone == null) {
      return ApiResponse.error(message: 'customer_name and phone are required');
    }

    final result = await db.query(
      '''
      INSERT INTO leads (sales_person_id, customer_name, phone, address, email, stage)
      VALUES (@salesId, @name, @phone, @address, @email, 'new')
      RETURNING *
      ''',
      substitutionValues: {
        'salesId': user.id,
        'name': name,
        'phone': phone,
        'address': address ?? '',
        'email': email,
      },
    );

    return ApiResponse.success(
      message: 'Lead created successfully',
      statusCode: HttpStatus.created,
      data: result.first.toColumnMap(),
    );
  }

  return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
}
