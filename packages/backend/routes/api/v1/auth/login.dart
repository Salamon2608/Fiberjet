import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final loginIdentifier = (body['phone'] as String?) ?? (body['email'] as String?);
  final password = body['password'] as String?;

  if (loginIdentifier == null || password == null) {
    return ApiResponse.error(message: 'Login identifier (email or phone) and password are required');
  }

  final db = context.read<PostgresService>();
  final authService = context.read<AuthService>();

  final result = await db.query(
    '''
    SELECT u.*, r.name as role_name 
    FROM users u 
    JOIN roles r ON u.role_id = r.id 
    WHERE phone = @id OR email = @id 
    LIMIT 1
    ''',
    substitutionValues: {'id': loginIdentifier},
  );

  if (result.isEmpty) {
    return ApiResponse.error(message: 'Invalid credentials', statusCode: HttpStatus.unauthorized);
  }

  final userRow = result.first.toColumnMap();
  final passwordHash = userRow['password_hash'] as String?;

  if (passwordHash == null || !authService.verifyPassword(password, passwordHash)) {
    return ApiResponse.error(message: 'Invalid phone or password', statusCode: HttpStatus.unauthorized);
  }

  // User is valid, generate JWT token
  final userId = userRow['id'] as String;
  final roleName = userRow['role_name'] as String;
  final token = authService.generateToken(userId, roleName);

  return ApiResponse.success(
    message: 'Login successful',
    data: {
      'token': token,
      'user': {
        'id': userId,
        'name': userRow['name'],
        'phone': userRow['phone'],
        'role': roleName,
      }
    },
  );
}
