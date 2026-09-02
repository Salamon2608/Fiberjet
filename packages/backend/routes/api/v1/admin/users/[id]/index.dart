import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/users/[id] → Get user details
/// PUT /api/v1/admin/users/[id] → Update user details (name, password)
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final db = context.read<PostgresService>();
  final authService = context.read<AuthService>();

  // 1. Check if user exists
  final checkRes = await db.query(
    'SELECT * FROM users WHERE id = @id LIMIT 1',
    substitutionValues: {'id': id},
  );

  if (checkRes.isEmpty) {
    return ApiResponse.error(message: 'User not found', statusCode: HttpStatus.notFound);
  }

  // ── GET: View User ───────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final user = checkRes.first.toColumnMap();
    // Remove sensitive data
    user.remove('password_hash');
    
    // Resolve role name
    if (user['role_id'] != null) {
      final roleRes = await db.query(
        'SELECT name FROM roles WHERE id = @roleId LIMIT 1',
        substitutionValues: {'roleId': user['role_id']},
      );
      if (roleRes.isNotEmpty) {
        final roleName = roleRes.first.toColumnMap()['name'] as String;
        user['role'] = roleName;

        // Fetch active plan details
        final planRes = await db.query(
          '''
          SELECT p.name as plan_name, p.price, p.speed_mbps, up.start_date, up.expiry_date
          FROM user_plans up
          JOIN plans p ON up.plan_id = p.id
          WHERE up.user_id = @id AND up.status = 'active'
          LIMIT 1
          ''',
          substitutionValues: {'id': id},
        );
        if (planRes.isNotEmpty) {
          final plan = planRes.first.toColumnMap();
          user['active_plan'] = plan['plan_name'];
          user['plan_start_date'] = plan['start_date']?.toString();
          user['plan_expiry_date'] = plan['expiry_date']?.toString();
          user['plan_price'] = plan['price'];
          user['plan_speed'] = plan['speed_mbps'];
        }

        if (roleName == 'customer') {
          // Fetch complaints/tickets raised by the customer
          final complaintsRes = await db.query(
            '''
            SELECT c.id, c.title, c.category, c.status, c.description, c.resolution, c.created_at, c.updated_at,
                   t.name as assigned_to_name
            FROM complaints c
            LEFT JOIN users t ON c.assigned_to = t.id
            WHERE c.user_id = @id
            ORDER BY c.created_at DESC
            ''',
            substitutionValues: {'id': id},
          );
          user['complaints'] = complaintsRes.map((r) {
            final map = r.toColumnMap();
            return {
              'id': map['id'],
              'title': map['title'],
              'category': map['category'],
              'status': map['status'],
              'description': map['description'],
              'resolution': map['resolution'],
              'created_at': map['created_at']?.toString(),
              'updated_at': map['updated_at']?.toString(),
              'assigned_to_name': map['assigned_to_name'],
            };
          }).toList();
        }

        if (roleName == 'technician') {
          // Fetch completed jobs count
          final countRes = await db.query(
            "SELECT COUNT(*) as total FROM jobs WHERE technician_id = @id AND status = 'completed'",
            substitutionValues: {'id': id},
          );
          user['completed_jobs'] = countRes.first.toColumnMap()['total'] ?? 0;
          
          // Fetch jobs list
          final jobsRes = await db.query(
            '''
            SELECT j.id, j.type, j.status, j.completed_at, j.scheduled_at, j.address,
                   u.name as customer_name
            FROM jobs j
            LEFT JOIN users u ON j.customer_id = u.id
            WHERE j.technician_id = @id
            ORDER BY j.created_at DESC
            ''',
            substitutionValues: {'id': id},
          );
          user['jobs'] = jobsRes.map((r) {
            final map = r.toColumnMap();
            return {
              'id': map['id'],
              'type': map['type'],
              'status': map['status'],
              'completed_at': map['completed_at']?.toString(),
              'scheduled_at': map['scheduled_at']?.toString(),
              'address': map['address'],
              'customer_name': map['customer_name'],
            };
          }).toList();

          // Fetch resolved complaints count
          final countComplaintsRes = await db.query(
            "SELECT COUNT(*) as total FROM complaints WHERE assigned_to = @id AND status = 'resolved'",
            substitutionValues: {'id': id},
          );
          user['resolved_complaints_count'] = countComplaintsRes.first.toColumnMap()['total'] ?? 0;

          // Fetch complaints list
          final complaintsRes = await db.query(
            '''
            SELECT c.id, c.title, c.category, c.status, c.resolution, c.updated_at,
                   u.name as customer_name
            FROM complaints c
            LEFT JOIN users u ON c.user_id = u.id
            WHERE c.assigned_to = @id
            ORDER BY c.updated_at DESC
            ''',
            substitutionValues: {'id': id},
          );
          user['complaints'] = complaintsRes.map((r) {
            final map = r.toColumnMap();
            return {
              'id': map['id'],
              'title': map['title'],
              'category': map['category'],
              'status': map['status'],
              'resolution': map['resolution'],
              'updated_at': map['updated_at']?.toString(),
              'customer_name': map['customer_name'],
            };
          }).toList();
        } else if (roleName == 'sales') {
          // Fetch leads stats
          final statsRes = await db.query(
            '''
            SELECT COUNT(*) as total_leads,
                   SUM(CASE WHEN stage = 'installed' THEN 1 ELSE 0 END) as converted_leads
            FROM leads
            WHERE sales_person_id = @id
            ''',
            substitutionValues: {'id': id},
          );
          final stats = statsRes.first.toColumnMap();
          user['total_leads'] = stats['total_leads'] ?? 0;
          user['converted_leads'] = stats['converted_leads'] ?? 0;

          // Fetch commission stats
          final commRes = await db.query(
            '''
            SELECT COALESCE(SUM(amount), 0) as total_commission
            FROM commissions
            WHERE sales_person_id = @id
            ''',
            substitutionValues: {'id': id},
          );
          user['total_commission'] = commRes.first.toColumnMap()['total_commission'] ?? 0;

          // Fetch leads list
          final leadsRes = await db.query(
            '''
            SELECT id, customer_name, phone, address, stage, created_at
            FROM leads
            WHERE sales_person_id = @id
            ORDER BY created_at DESC
            ''',
            substitutionValues: {'id': id},
          );
          user['leads'] = leadsRes.map((r) {
            final map = r.toColumnMap();
            return {
              'id': map['id'],
              'customer_name': map['customer_name'],
              'phone': map['phone'],
              'address': map['address'],
              'stage': map['stage'],
              'created_at': map['created_at']?.toString(),
            };
          }).toList();
        }
      }
    }
    
    return ApiResponse.success(data: user);
  }

  // ── PUT: Update User ─────────────────────────────────────
  if (request.method == HttpMethod.put) {
    try {
      final body = await request.json() as Map<String, dynamic>;
      final name = body['name'] as String?;
      final password = body['password'] as String?;
      final email = body['email'] as String?;
      final phone = body['phone'] as String?;
      final roleName = body['role'] as String?;

      if (name == null && password == null && email == null && phone == null && roleName == null) {
        return ApiResponse.error(message: 'No fields provided for update');
      }

      final setClauses = <String>[];
      final substitutions = <String, dynamic>{'id': id};

      if (name != null) {
        setClauses.add('name = @name');
        substitutions['name'] = name;
      }

      if (email != null) {
        setClauses.add('email = @email');
        substitutions['email'] = email;
      }

      if (phone != null) {
        // Check if phone already exists for another user
        final existing = await db.query(
          'SELECT id FROM users WHERE phone = @phone AND id != @id LIMIT 1',
          substitutionValues: {'phone': phone, 'id': id},
        );
        if (existing.isNotEmpty) {
          return ApiResponse.error(
            message: 'A user with this phone number already exists',
            statusCode: HttpStatus.conflict,
          );
        }
        setClauses.add('phone = @phone');
        substitutions['phone'] = phone;
      }

      if (roleName != null) {
        final roleResult = await db.query(
          'SELECT id FROM roles WHERE name = @role LIMIT 1',
          substitutionValues: {'role': roleName},
        );
        if (roleResult.isEmpty) {
          return ApiResponse.error(
            message: 'Invalid role provided',
            statusCode: HttpStatus.badRequest,
          );
        }
        final roleId = roleResult.first.toColumnMap()['id'] as String;
        setClauses.add('role_id = @roleId');
        substitutions['roleId'] = roleId;
      }

      if (password != null && password.isNotEmpty) {
        final hash = authService.hashPassword(password);
        setClauses.add('password_hash = @hash');
        substitutions['hash'] = hash;
      }

      if (setClauses.isEmpty) {
        return ApiResponse.error(message: 'Nothing to update');
      }

      final updateRes = await db.query(
        '''
        UPDATE users 
        SET ${setClauses.join(', ')}, updated_at = NOW() 
        WHERE id = @id 
        RETURNING *
        ''',
        substitutionValues: substitutions,
      );

      final updatedUser = updateRes.first.toColumnMap();
      updatedUser.remove('password_hash');

      return ApiResponse.success(
        message: 'User updated successfully',
        data: updatedUser,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Failed to update user: $e');
    }
  }

  // ── DELETE: Delete User ───────────────────────────────────
  if (request.method == HttpMethod.delete) {
    try {
      // Clean up child dependency records
      try {
        await db.query('DELETE FROM user_plans WHERE user_id = @id', substitutionValues: {'id': id});
        await db.query('DELETE FROM notification_preferences WHERE user_id = @id', substitutionValues: {'id': id});
        await db.query('DELETE FROM cloud_files WHERE user_id = @id', substitutionValues: {'id': id});
        await db.query('DELETE FROM network_devices WHERE user_id = @id', substitutionValues: {'id': id});
        await db.query('DELETE FROM modem_info WHERE user_id = @id', substitutionValues: {'id': id});
        await db.query('DELETE FROM speed_tests WHERE user_id = @id', substitutionValues: {'id': id});
        await db.query('DELETE FROM ott_claims WHERE user_id = @id', substitutionValues: {'id': id});
        await db.query('DELETE FROM notifications WHERE user_id = @id', substitutionValues: {'id': id});
      } catch (_) {}

      final deleteRes = await db.query(
        'DELETE FROM users WHERE id = @id RETURNING id, name',
        substitutionValues: {'id': id},
      );

      if (deleteRes.isEmpty) {
        return ApiResponse.error(
          message: 'User not found',
          statusCode: HttpStatus.notFound,
        );
      }

      final deletedUser = deleteRes.first.toColumnMap();

      // Record audit log
      try {
        await db.query(
          '''
          INSERT INTO audit_logs (user_id, action, target_table, target_id, new_values)
          VALUES (@adminId, 'delete_user', 'users', @id,
            jsonb_build_object('deleted_user_name', @name))
          ''',
          substitutionValues: {
            'adminId': (context.read<dynamic>() as dynamic).id ?? id,
            'id': id,
            'name': deletedUser['name'] ?? '',
          },
        );
      } catch (_) {}

      return ApiResponse.success(
        message: 'User deleted successfully',
      );
    } catch (e) {
      return ApiResponse.error(message: 'Failed to delete user: $e');
    }
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
