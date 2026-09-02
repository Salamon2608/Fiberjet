import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/leads → List all leads globally for CRM oversight
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final db = context.read<PostgresService>();
  final params = request.url.queryParameters;

  final stage = params['stage'];
  final salesPersonId = params['sales_person_id'];
  final search = params['search'];

  final conditions = <String>['1=1'];
  final values = <String, dynamic>{};

  if (stage != null && stage.isNotEmpty) {
    conditions.add('l.stage = @stage');
    values['stage'] = stage;
  }

  if (salesPersonId != null && salesPersonId.isNotEmpty) {
    conditions.add('l.sales_person_id = @salesPersonId');
    values['salesPersonId'] = salesPersonId;
  }

  if (search != null && search.isNotEmpty) {
    conditions.add(
      '(l.customer_name ILIKE @search OR l.phone ILIKE @search)',
    );
    values['search'] = '%$search%';
  }

  final whereClause = conditions.join(' AND ');

  final result = await db.query(
    '''
    SELECT l.id, l.customer_name, l.phone, l.address, l.stage, l.score, l.follow_up_at, l.created_at,
           u.name as sales_person_name
    FROM leads l
    LEFT JOIN users u ON l.sales_person_id = u.id
    WHERE $whereClause
    ORDER BY l.created_at DESC
    ''',
    substitutionValues: values.isEmpty ? null : values,
  );

  final leads = result.map((r) {
    final row = r.toColumnMap();
    return <String, dynamic>{
      for (final entry in row.entries)
        entry.key: entry.value is DateTime
            ? (entry.value as DateTime).toIso8601String()
            : entry.value is bool ||
                  entry.value is int ||
                  entry.value is double ||
                  entry.value == null
            ? entry.value
            : entry.value.toString(),
    };
  }).toList();

  // Also calculate summary grouped by stage
  final summaryResult = await db.query('''
    SELECT stage, COUNT(id) as total
    FROM leads l
    WHERE $whereClause
    GROUP BY stage
  ''', substitutionValues: values.isEmpty ? null : values);

  final summary = <String, int>{
    'new': 0,
    'contacted': 0,
    'interested': 0,
    'negotiation': 0,
    'converted': 0,
    'lost': 0,
  };

  for (final row in summaryResult) {
    final map = row.toColumnMap();
    final stageName = map['stage'] as String?;
    final count = map['total'];
    if (stageName != null && summary.containsKey(stageName)) {
      summary[stageName] = count is int ? count : int.tryParse(count.toString()) ?? 0;
    } else if (stageName != null) {
      summary[stageName] = count is int ? count : int.tryParse(count.toString()) ?? 0;
    }
  }

  return ApiResponse.success(data: {
    'leads': leads,
    'summary': summary,
  });
}
