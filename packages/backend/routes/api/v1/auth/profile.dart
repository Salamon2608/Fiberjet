import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/auth_helper.dart';

/// GET  /api/v1/auth/profile  → Returns the authenticated user's full profile
/// PUT  /api/v1/auth/profile  → Updates the user's editable fields
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  // Inline auth — this route is in the public /auth directory but requires a token
  final (user, authError) = await AuthHelper.authenticate(context);
  if (user == null) return authError!;

  final db = context.read<PostgresService>();

  // ── GET: Return current profile ────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      '''
      SELECT u.*, r.name as role_name,
             up.id as plan_subscription_id, up.status as plan_status,
             p.name as plan_name, p.speed_mbps, p.price as plan_price
      FROM users u
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN user_plans up ON up.user_id = u.id AND up.status = 'active'
      LEFT JOIN plans p ON up.plan_id = p.id
      WHERE u.id = @userId
      LIMIT 1
      ''',
      substitutionValues: {'userId': user.id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'User not found',
        statusCode: HttpStatus.notFound,
      );
    }

    final row = result.first.toColumnMap();

    return ApiResponse.success(
      data: {
        'id': row['id']?.toString(),
        'name': row['name']?.toString(),
        'email': row['email']?.toString(),
        'phone': row['phone']?.toString(),
        'address': row['address']?.toString(),
        'role': row['role_name']?.toString(),
        'status': row['status']?.toString(),
        'is_vip': row['is_vip'],
        'created_at': row['created_at']?.toString(),
        'active_plan': row['plan_name'] != null
            ? {
                'subscription_id': row['plan_subscription_id']?.toString(),
                'name': row['plan_name']?.toString(),
                'speed_mbps': row['speed_mbps'],
                'price': row['plan_price'],
                'status': row['plan_status']?.toString(),
              }
            : null,
      },
    );
  }

  // ── PUT: Update profile fields ─────────────────────────────
  if (request.method == HttpMethod.put) {
    try {
      final body = await request.json() as Map<String, dynamic>;

      final name = body['name'] as String?;
      final email = body['email'] as String?;
      final phone = body['phone'] as String?;
      final address = body['address'] as String?;

      if (name == null && email == null && phone == null && address == null) {
        return ApiResponse.error(
          message: 'Provide at least one field to update (name, email, phone, address)',
        );
      }

      // If phone is changing, check for duplicates
      if (phone != null) {
        final phoneCheck = await db.query(
          'SELECT id FROM users WHERE phone = @phone AND id != @userId LIMIT 1',
          substitutionValues: {'phone': phone, 'userId': user.id},
        );
        if (phoneCheck.isNotEmpty) {
          return ApiResponse.error(
            message: 'This phone number is already registered to another account',
            statusCode: HttpStatus.conflict,
          );
        }
      }

      final updates = <String>[];
      final values = <String, dynamic>{'userId': user.id};

      if (name != null) {
        updates.add('name = @name');
        values['name'] = name;
      }
      if (email != null) {
        updates.add('email = @email');
        values['email'] = email;
      }
      if (phone != null) {
        updates.add('phone = @phone');
        values['phone'] = phone;
      }
      if (address != null) {
        updates.add('address = @address');
        values['address'] = address;
      }

      await db.query(
        'UPDATE users SET ${updates.join(', ')}, updated_at = NOW() WHERE id = @userId',
        substitutionValues: values,
      );

      return ApiResponse.success(message: 'Profile updated successfully');
    } catch (e, stackTrace) {
      print('ERROR updating profile: $e');
      print(stackTrace);
      return ApiResponse.error(
        message: 'Database error: $e',
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
