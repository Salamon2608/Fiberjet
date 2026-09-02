import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/utils/api_response.dart';

// ... 

Future<Response> _handlePost(RequestContext context, PostgresService db) async {
  final request = context.request;
  final body = await request.json() as Map<String, dynamic>;

  final name = body['name'] as String?;
  final phone = body['phone'] as String?;
  final email = body['email'] as String?;
  final password = body['password'] as String?;
  final roleName = body['role'] as String? ?? 'customer';
  final isVip = body['is_vip'] == true;
  final planId = body['plan_id'] as String?;

  if (name == null || phone == null || password == null) {
    return ApiResponse.error(message: 'name, phone, and password are required');
  }

  // Check if phone already exists
  final existing = await db.query(
    'SELECT id FROM users WHERE phone = @phone LIMIT 1',
    substitutionValues: {'phone': phone},
  );

  if (existing.isNotEmpty) {
    return ApiResponse.error(message: 'A user with this phone number already exists', statusCode: HttpStatus.conflict);
  }

  final roleResult = await db.query(
    'SELECT id FROM roles WHERE name = @role LIMIT 1',
    substitutionValues: {'role': roleName},
  );

  if (roleResult.isEmpty) {
    return ApiResponse.error(message: 'Invalid role provided', statusCode: HttpStatus.badRequest);
  }

  final roleId = roleResult.first.toColumnMap()['id'] as String;
  final authService = context.read<AuthService>();
  final passwordHash = authService.hashPassword(password);

  final insertResult = await db.query(
    '''
    INSERT INTO users (name, phone, email, password_hash, role_id, status, is_vip, kyc_status)
    VALUES (@name, @phone, @email, @passwordHash, @roleId, 'active', @isVip, 'verified')
    RETURNING id
    ''',
    substitutionValues: {
      'name': name,
      'phone': phone,
      'email': email,
      'passwordHash': passwordHash,
      'roleId': roleId,
      'isVip': isVip,
    },
  );

  final userId = insertResult.first.toColumnMap()['id'] as String;

  if (planId != null && roleName == 'customer') {
    // Assign plan
    await db.query(
      '''
      INSERT INTO user_plans (user_id, plan_id, status, started_at)
      VALUES (@userId, @planId, 'active', NOW())
      ''',
      substitutionValues: {
        'userId': userId,
        'planId': planId,
      },
    );
  }

  return ApiResponse.success(
    message: 'User created successfully',
    statusCode: HttpStatus.created,
    data: {'id': userId},
  );
}

/// GET /api/v1/admin/users → List all customers with search, filter, pagination
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  final db = context.read<PostgresService>();

  if (request.method == HttpMethod.get) {
    return _handleGet(context, db);
  } else if (request.method == HttpMethod.post) {
    return _handlePost(context, db);
  } else {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }
}

Future<Response> _handleGet(RequestContext context, PostgresService db) async {
  final request = context.request;
  final params = request.url.queryParameters;

  final search = params['search'];
  final status = params['status'];
  final kycStatus = params['kyc_status'];
  final isVip = params['is_vip'];
  final role = params['role'];
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
  final offset = (page - 1) * limit;

  final conditions = <String>['1=1'];
  final values = <String, dynamic>{};

  final planType = params['plan_type'];

  if (search != null && search.isNotEmpty) {
    conditions.add(
      '(u.name ILIKE @search OR u.phone ILIKE @search OR u.email ILIKE @search)',
    );
    values['search'] = '%$search%';
  }

  if (status != null && status.isNotEmpty) {
    conditions.add('u.status = @status');
    values['status'] = status;
  }

  if (kycStatus != null && kycStatus.isNotEmpty) {
    conditions.add('u.kyc_status = @kycStatus');
    values['kycStatus'] = kycStatus;
  }

  if (isVip != null) {
    conditions.add('u.is_vip = @isVip');
    values['isVip'] = isVip == 'true';
  }

  if (role != null && role.isNotEmpty) {
    conditions.add('r.name = @role');
    values['role'] = role;
  }

  if (planType != null && planType.isNotEmpty) {
    conditions.add('p.name ILIKE @planType');
    values['planType'] = '%$planType%';
  }

  final whereClause = conditions.join(' AND ');

  final result = await db.query(
    '''
    SELECT u.id, u.name, u.email, u.phone, u.status, u.is_vip, u.created_at, u.kyc_doc_paths, u.kyc_status,
           r.name as role, p.name as active_plan
    FROM users u
    LEFT JOIN roles r ON u.role_id = r.id
    LEFT JOIN user_plans up ON up.user_id = u.id AND up.status = 'active'
    LEFT JOIN plans p ON up.plan_id = p.id
    WHERE $whereClause
    ORDER BY u.created_at DESC
    LIMIT $limit OFFSET $offset
    ''',
    substitutionValues: values.isEmpty ? null : values,
  );

  // Total count
  final countResult = await db.query(
    '''
    SELECT COUNT(u.id) as total
    FROM users u
    LEFT JOIN roles r ON u.role_id = r.id
    LEFT JOIN user_plans up ON up.user_id = u.id AND up.status = 'active'
    LEFT JOIN plans p ON up.plan_id = p.id
    WHERE $whereClause
    ''',
    substitutionValues: values.isEmpty ? null : values,
  );

  final users = result.map((r) {
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
  final total = countResult.first.toColumnMap()['total'] ?? 0;

  return ApiResponse.success(
    data: {
      'users': users,
      'total': total,
      'page': page,
      'limit': limit,
    },
  );
}
