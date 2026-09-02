import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final name = body['name'] as String?;
  final phone = body['phone'] as String?;
  final password = body['password'] as String?;
  final email = body['email'] as String?;

  if (name == null || phone == null || password == null) {
    return ApiResponse.error(message: 'name, phone, and password are required');
  }

  if (password.length < 6) {
    return ApiResponse.error(message: 'Password must be at least 6 characters');
  }

  final db = context.read<PostgresService>();
  final authService = context.read<AuthService>();

  // Check if phone already exists
  final existing = await db.query(
    'SELECT id FROM users WHERE phone = @phone LIMIT 1',
    substitutionValues: {'phone': phone},
  );

  if (existing.isNotEmpty) {
    return ApiResponse.error(
      message: 'A user with this phone number already exists',
      statusCode: HttpStatus.conflict,
    );
  }

  // Get the 'customer' role ID (default role for new registrations)
  final roleResult = await db.query(
    "SELECT id FROM roles WHERE name = 'customer' LIMIT 1",
  );

  if (roleResult.isEmpty) {
    return ApiResponse.error(
      message: 'System configuration error: customer role not found',
      statusCode: HttpStatus.internalServerError,
    );
  }

  final roleId = roleResult.first.toColumnMap()['id'] as String;
  final passwordHash = authService.hashPassword(password);

  // Insert the new user
  final insertResult = await db.query(
    '''
    INSERT INTO users (name, phone, email, password_hash, role_id, status)
    VALUES (@name, @phone, @email, @passwordHash, @roleId, 'active')
    RETURNING id
    ''',
    substitutionValues: {
      'name': name,
      'phone': phone,
      'email': email,
      'passwordHash': passwordHash,
      'roleId': roleId,
    },
  );

  final userId = insertResult.first.toColumnMap()['id'] as String;
  final token = authService.generateToken(userId, 'customer');

  return ApiResponse.success(
    message: 'Registration successful',
    statusCode: HttpStatus.created,
    data: {
      'token': token,
      'user': {
        'id': userId,
        'name': name,
        'phone': phone,
        'email': email,
        'role': 'customer',
      },
    },
  );
}
