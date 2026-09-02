import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/admin/plans → List all plans with filters
/// POST /api/v1/admin/plans → Create a new plan
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final db = context.read<PostgresService>();

  // ── GET: List Plans ──────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final params = request.uri.queryParameters;
    final category = params['category'];
    final isActive = params['is_active'];
    final search = params['search'];

    var whereClause = 'WHERE 1=1';
    final subs = <String, dynamic>{};

    if (category != null && category.isNotEmpty) {
      whereClause += ' AND category = @category';
      subs['category'] = category;
    }
    if (isActive != null) {
      whereClause += ' AND is_active = @isActive';
      subs['isActive'] = isActive == 'true';
    }
    if (search != null && search.isNotEmpty) {
      whereClause += ' AND (name ILIKE @search OR description ILIKE @search)';
      subs['search'] = '%$search%';
    }

    final result = await db.query(
      '''
      SELECT * FROM plans
      $whereClause
      ORDER BY category ASC, priority ASC, price ASC
      ''',
      substitutionValues: subs.isNotEmpty ? subs : null,
    );

    final plans = result.map((r) {
      final row = r.toColumnMap();
      return <String, dynamic>{
        for (final entry in row.entries)
          entry.key: entry.value is DateTime
              ? (entry.value as DateTime).toIso8601String()
              : entry.value,
      };
    }).toList();

    // Also get categories from the plan_categories table
    final catResult = await db.query(
      "SELECT name FROM plan_categories WHERE is_active = true ORDER BY display_order ASC",
    );
    final categories = catResult.map((r) => r.toColumnMap()['name']?.toString() ?? '').where((c) => c.isNotEmpty).toList();

    return ApiResponse.success(data: {
      'plans': plans,
      'categories': categories,
      'total': plans.length,
    });
  }

  // ── POST: Create Plan ────────────────────────────────────
  if (request.method == HttpMethod.post) {
    try {
      final body = await request.json() as Map<String, dynamic>;

      final name = body['name'] as String?;
      final speedMbps = body['speed_mbps'];
      final price = body['price'];

      if (name == null || speedMbps == null || price == null) {
        return ApiResponse.error(message: 'name, speed_mbps, and price are required');
      }

      final ottBenefits = body['ott_benefits'];
      final ottJson = ottBenefits != null ? jsonEncode(ottBenefits) : null;

      final result = await db.query(
        '''
        INSERT INTO plans (
          name, description, speed_mbps, price, data_limit_gb,
          cloud_storage_gb, ott_benefits, validity_days, is_active,
          category, badge, data_per_day_gb, fup_speed_mbps, priority
        ) VALUES (
          @name, @description, @speedMbps, @price, @dataLimitGb,
          @cloudStorageGb, @ottBenefits::jsonb, @validityDays, @isActive,
          @category, @badge, @dataPerDayGb, @fupSpeedMbps, @priority
        )
        RETURNING *
        ''',
        substitutionValues: {
          'name': name,
          'description': body['description'] ?? '',
          'speedMbps': speedMbps is int ? speedMbps : int.tryParse(speedMbps.toString()) ?? 0,
          'price': price is num ? price : double.tryParse(price.toString()) ?? 0,
          'dataLimitGb': body['data_limit_gb'],
          'cloudStorageGb': body['cloud_storage_gb'] ?? 0,
          'ottBenefits': ottJson,
          'validityDays': body['validity_days'] ?? 30,
          'isActive': body['is_active'] ?? true,
          'category': body['category'] ?? 'Popular',
          'badge': body['badge'],
          'dataPerDayGb': body['data_per_day_gb'],
          'fupSpeedMbps': body['fup_speed_mbps'],
          'priority': body['priority'] ?? 100,
        },
      );

      final row = result.first.toColumnMap();
      final safe = <String, dynamic>{
        for (final e in row.entries)
          e.key: e.value is DateTime
              ? (e.value as DateTime).toIso8601String()
              : e.value,
      };

      return ApiResponse.success(
        message: 'Plan created successfully',
        statusCode: HttpStatus.created,
        data: safe,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Failed to create plan: $e');
    }
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
