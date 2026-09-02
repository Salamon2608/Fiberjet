import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/auth/google
/// Body: { "id_token": "google_oauth_id_token", "name": "User Name", "email": "user@gmail.com" }
///
/// Flow:
/// 1. In production, verify the Google ID token with Google's API.
/// 2. Find or create the user by email.
/// 3. Return a JWT token.
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final idToken = body['id_token'] as String?;
  final name = body['name'] as String?;
  final email = body['email'] as String?;

  if (idToken == null || email == null) {
    return ApiResponse.error(message: 'id_token and email are required');
  }

  // TODO: Verify Google ID token with Google's tokeninfo endpoint
  // https://oauth2.googleapis.com/tokeninfo?id_token=$idToken
  // For now, we trust the client-provided token (development mode)

  final db = context.read<PostgresService>();
  final authService = context.read<AuthService>();

  // Check if user already exists by email
  final existingResult = await db.query(
    'SELECT u.*, r.name as role_name FROM users u JOIN roles r ON u.role_id = r.id WHERE u.email = @email LIMIT 1',
    substitutionValues: {'email': email},
  );

  if (existingResult.isNotEmpty) {
    // Existing user — just login
    final row = existingResult.first.toColumnMap();
    final userId = row['id'] as String;
    final roleName = row['role_name'] as String;
    final token = authService.generateToken(userId, roleName);

    return ApiResponse.success(
      message: 'Google login successful',
      data: {
        'token': token,
        'is_new_user': false,
        'user': {
          'id': userId,
          'name': row['name'],
          'email': row['email'],
          'phone': row['phone'],
          'role': roleName,
        },
      },
    );
  }

  // New user — create account with Google info
  final roleResult = await db.query(
    "SELECT id FROM roles WHERE name = 'customer' LIMIT 1",
  );

  if (roleResult.isEmpty) {
    return ApiResponse.error(
      message: 'System configuration error',
      statusCode: HttpStatus.internalServerError,
    );
  }

  final roleId = roleResult.first.toColumnMap()['id'] as String;

  // Create user without phone/password (they'll complete profile later)
  final insertResult = await db.query(
    '''
    INSERT INTO users (name, email, password_hash, role_id, status)
    VALUES (@name, @email, 'google_oauth', @roleId, 'active')
    RETURNING id
    ''',
    substitutionValues: {
      'name': name ?? email.split('@').first,
      'email': email,
      'roleId': roleId,
    },
  );

  final userId = insertResult.first.toColumnMap()['id'] as String;
  final token = authService.generateToken(userId, 'customer');

  return ApiResponse.success(
    message: 'Google registration successful',
    statusCode: HttpStatus.created,
    data: {
      'token': token,
      'is_new_user': true,
      'user': {
        'id': userId,
        'name': name ?? email.split('@').first,
        'email': email,
        'phone': null,
        'role': 'customer',
      },
    },
  );
}
