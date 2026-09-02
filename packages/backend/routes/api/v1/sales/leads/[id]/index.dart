import 'dart:io';
import 'dart:math';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET    /api/v1/sales/leads/:id → Get lead details
/// PATCH  /api/v1/sales/leads/:id → Update lead (stage, KYC doc, address, customer details)
/// DELETE /api/v1/sales/leads/:id → Delete lead
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: Lead Details ─────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      '''
      SELECT l.*, 
             j.technician_id,
             t.name as technician_name
      FROM leads l
      LEFT JOIN users c ON l.phone = c.phone AND c.role_id = (SELECT id FROM roles WHERE name = 'customer')
      LEFT JOIN jobs j ON j.customer_id = c.id AND j.type = 'installation'
      LEFT JOIN users t ON j.technician_id = t.id
      WHERE l.id = @id AND l.sales_person_id = @salesId
      LIMIT 1
      ''',
      substitutionValues: {'id': id, 'salesId': user.id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(message: 'Lead not found', statusCode: HttpStatus.notFound);
    }

    return ApiResponse.success(data: result.first.toColumnMap());
  }

  // ── PATCH: Update Lead ────────────────────────────────────
  if (request.method == HttpMethod.patch) {
    final body = await request.json() as Map<String, dynamic>;
    
    // Build dynamic query
    final updates = <String>[];
    final values = <String, dynamic>{'id': id, 'salesId': user.id};

    if (body.containsKey('stage')) {
      updates.add('stage = @stage');
      values['stage'] = body['stage'];
    }
    if (body.containsKey('kyc_doc_path')) {
      updates.add('kyc_doc_path = @kyc');
      values['kyc'] = body['kyc_doc_path'];
    }
    if (body.containsKey('address')) {
      updates.add('address = @address');
      values['address'] = body['address'];
    }
    if (body.containsKey('customer_name')) {
      updates.add('customer_name = @customerName');
      values['customerName'] = body['customer_name'];
    }
    if (body.containsKey('phone')) {
      updates.add('phone = @phone');
      values['phone'] = body['phone'];
    }
    if (body.containsKey('email')) {
      updates.add('email = @email');
      values['email'] = body['email'];
    }
    if (body.containsKey('score')) {
      updates.add('score = @score');
      values['score'] = body['score'];
    }

    if (updates.isEmpty) {
      return ApiResponse.error(message: 'No fields provided for update');
    }

    final result = await db.query(
      '''
      UPDATE leads 
      SET ${updates.join(', ')}
      WHERE id = @id AND sales_person_id = @salesId
      RETURNING *
      ''',
      substitutionValues: values,
    );

    if (result.isEmpty) {
      return ApiResponse.error(message: 'Lead not found or update failed', statusCode: HttpStatus.notFound);
    }

    final lead = result.first.toColumnMap();
    final newStage = lead['stage'] as String?;
    if (newStage == 'approved') {
      try {
        final authService = context.read<AuthService>();
        // 1. Get 'customer' role ID
        final customerRoleResult = await db.query(
          "SELECT id FROM roles WHERE name = 'customer' LIMIT 1",
        );
        if (customerRoleResult.isNotEmpty) {
          final customerRoleId = customerRoleResult.first.toColumnMap()['id'] as String;
          final phone = lead['phone'] as String;
          final name = lead['customer_name'] as String;
          final address = lead['address'] as String?;

          // Check if user already exists
          final userCheckResult = await db.query(
            'SELECT id FROM users WHERE phone = @phone LIMIT 1',
            substitutionValues: {'phone': phone},
          );

          String customerId;
            if (userCheckResult.isEmpty) {
              final passwordHash = authService.hashPassword('password123');
              // Use the email provided in the lead, fallback to cust_{phone}@fiberjet.com
              final userEmail = lead['email'] != null && lead['email'].toString().isNotEmpty
                  ? lead['email']
                  : 'cust_${phone}@fiberjet.com';
                  
              final insertUserResult = await db.query(
                '''
                INSERT INTO users (name, phone, email, password_hash, role_id, status, kyc_status)
                VALUES (@name, @phone, @email, @passwordHash, @roleId, 'active', 'verified')
                RETURNING id
                ''',
                substitutionValues: {
                  'name': name,
                  'phone': phone,
                  'email': userEmail,
                  'passwordHash': passwordHash,
                  'roleId': customerRoleId,
                },
              );
              customerId = insertUserResult.first.toColumnMap()['id'] as String;
          } else {
            customerId = userCheckResult.first.toColumnMap()['id'] as String;
          }

          // 2. Fetch 'FiberJet Starter' plan
          final planResult = await db.query(
            "SELECT id, validity_days FROM plans WHERE name = 'FiberJet Starter' LIMIT 1",
          );
          if (planResult.isNotEmpty) {
            final planId = planResult.first.toColumnMap()['id'] as String;
            final validityDays = planResult.first.toColumnMap()['validity_days'] as int? ?? 30;

            // Check if user_plans already active
            final activePlanCheck = await db.query(
              "SELECT id FROM user_plans WHERE user_id = @userId AND status = 'active' LIMIT 1",
              substitutionValues: {'userId': customerId},
            );
            if (activePlanCheck.isEmpty) {
              await db.query(
                '''
                INSERT INTO user_plans (user_id, plan_id, status, start_date, expiry_date)
                VALUES (@userId, @planId, 'active', NOW(), NOW() + INTERVAL '$validityDays days')
                ''',
                substitutionValues: {
                  'userId': customerId,
                  'planId': planId,
                },
              );
            }
          }

          // 3. Assign technician installation job
          String? technicianId = body['technician_id']?.toString();
          if (technicianId == null || technicianId.isEmpty) {
            final techResult = await db.query(
              '''
              SELECT u.id FROM users u
              JOIN roles r ON u.role_id = r.id
              WHERE r.name = 'technician' AND u.status = 'active'
              LIMIT 1
              ''',
            );
            technicianId = techResult.isNotEmpty
                ? techResult.first.toColumnMap()['id'] as String
                : '66666666-6666-6666-6666-666666666666'; // fallback tech ID
          }

          final jobCheck = await db.query(
            "SELECT id FROM jobs WHERE customer_id = @customerId AND type = 'installation' LIMIT 1",
            substitutionValues: {'customerId': customerId},
          );
          if (jobCheck.isEmpty) {
            final randomOtp = (1000 + Random().nextInt(9000)).toString();
            await db.query(
              '''
              INSERT INTO jobs (technician_id, customer_id, type, status, address, scheduled_at, checklist, service_charge, payout_amount, visit_otp)
              VALUES (@techId, @customerId, 'installation', 'pending', @address, NOW() + INTERVAL '1 day', @checklist::jsonb, 0, 0, @visitOtp)
              ''',
              substitutionValues: {
                'techId': technicianId,
                'customerId': customerId,
                'address': address ?? '',
                'checklist': '{"router_positioned": false, "fiber_sliced": false, "ont_configured": false, "speed_tested": false}',
                'visitOtp': randomOtp,
              },
            );
          } else if (body['technician_id'] != null) {
            // Update existing job with new technician
            await db.query(
              'UPDATE jobs SET technician_id = @techId WHERE id = @jobId',
              substitutionValues: {
                'techId': technicianId,
                'jobId': jobCheck.first.toColumnMap()['id'],
              },
            );
          }

          // 4. Create commission entry for the sales person
          final commCheck = await db.query(
            'SELECT id FROM commissions WHERE lead_id = @leadId LIMIT 1',
            substitutionValues: {'leadId': id},
          );
          if (commCheck.isEmpty) {
            await db.query(
              '''
              INSERT INTO commissions (sales_person_id, lead_id, amount, type, status)
              VALUES (@salesId, @leadId, @amount, 'one_time', 'approved')
              ''',
              substitutionValues: {
                'salesId': lead['sales_person_id'],
                'leadId': id,
                'amount': 500.00,
              },
            );
          }
        }
      } catch (e) {
        print('Automated onboarding failed: $e');
      }
    }

    return ApiResponse.success(
      message: 'Lead updated successfully',
      data: lead,
    );
  }

  // ── DELETE: Remove Lead ───────────────────────────────────
  if (request.method == HttpMethod.delete) {
    // Delete related comments first
    await db.query(
      'DELETE FROM lead_comments WHERE lead_id = @id',
      substitutionValues: {'id': id},
    );

    final result = await db.query(
      'DELETE FROM leads WHERE id = @id AND sales_person_id = @salesId RETURNING id',
      substitutionValues: {'id': id, 'salesId': user.id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'Lead not found or you do not have permission to delete it',
        statusCode: HttpStatus.notFound,
      );
    }

    return ApiResponse.success(message: 'Lead deleted successfully');
  }

  return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
}
