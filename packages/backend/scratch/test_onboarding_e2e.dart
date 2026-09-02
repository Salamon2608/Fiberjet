import 'dart:convert';
import 'dart:io';

import 'package:backend/config/env_config.dart';
import 'package:postgres/postgres.dart';

Future<Map<String, dynamic>> post(
  String url,
  Map<String, dynamic> body, {
  String? token,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;
    if (token != null) {
      request.headers.add('Authorization', 'Bearer $token');
    }
    request.write(jsonEncode(body));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return {
      'statusCode': response.statusCode,
      'body': responseBody,
    };
  } finally {
    client.close();
  }
}

Future<Map<String, dynamic>> patch(
  String url,
  Map<String, dynamic> body, {
  String? token,
}) async {
  final client = HttpClient();
  try {
    final request = await client.patchUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;
    if (token != null) {
      request.headers.add('Authorization', 'Bearer $token');
    }
    request.write(jsonEncode(body));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return {
      'statusCode': response.statusCode,
      'body': responseBody,
    };
  } finally {
    client.close();
  }
}

void main() async {
  const baseUrl = 'http://localhost:8080/api/v1';

  print('=== STARTING ONBOARDING E2E INTEGRATION TEST ===');

  // 1. Login as Sales Person
  print('\n[1] Logging in as sales person (7777777777 / password123)...');
  final loginResponse = await post(
    '$baseUrl/auth/login',
    {
      'phone': '7777777777',
      'password': 'password123',
    },
  );

  if (loginResponse['statusCode'] != 200) {
    print('Error logging in sales user: ${loginResponse['body']}');
    return;
  }

  final loginData = jsonDecode(loginResponse['body'] as String);
  final token = loginData['data']['token'] as String;
  print('Successfully logged in! Token acquired.');

  // 2. Create a new lead
  final uniqueSuffix = DateTime.now().millisecondsSinceEpoch
      .toString()
      .substring(8, 13);
  final testPhone = '98765$uniqueSuffix';
  final testName = 'John Doe E2E Test';
  final testAddress = '123, E2E Test Street, Coimbatore';

  print('\n[2] Creating a new lead with phone $testPhone...');
  final createResponse = await post(
    '$baseUrl/sales/leads',
    {
      'customer_name': testName,
      'phone': testPhone,
      'address': testAddress,
    },
    token: token,
  );

  if (createResponse['statusCode'] != 201) {
    print('Failed to create lead: ${createResponse['body']}');
    return;
  }

  final leadData = jsonDecode(createResponse['body'] as String)['data'];
  final leadId = leadData['id'] as String;
  print('Lead created successfully with ID: $leadId');

  // 3. Update the lead's stage to 'approved'
  print('\n[3] Approving lead to trigger automated onboarding...');
  final patchResponse = await patch(
    '$baseUrl/sales/leads/$leadId',
    {
      'stage': 'approved',
    },
    token: token,
  );

  if (patchResponse['statusCode'] != 200) {
    print('Failed to approve lead: ${patchResponse['body']}');
    return;
  }
  print('Lead approved successfully!');

  // 4. Verify Database State
  print('\n[4] Connecting to Postgres DB to verify onboarding insertions...');
  final conn = await Connection.open(
    Endpoint(
      host: EnvConfig.dbHost,
      port: EnvConfig.dbPort,
      database: EnvConfig.dbName,
      username: EnvConfig.dbUser,
      password: EnvConfig.dbPass,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  try {
    // Check user account
    final userCheck = await conn.execute(
      r'SELECT id, name, phone, email, kyc_status FROM users WHERE phone = $1 LIMIT 1',
      parameters: [testPhone],
    );
    if (userCheck.isEmpty) {
      print('❌ FAILED: User account was not created!');
      return;
    }
    final user = userCheck.first.toColumnMap();
    final customerId = user['id'] as String;
    print('✅ SUCCESS: User account created successfully!');
    print('   Details: $user');

    // Check active subscription
    final planCheck = await conn.execute(
      r'''
      SELECT up.id, p.name as plan_name, up.status, up.start_date, up.expiry_date
      FROM user_plans up
      JOIN plans p ON up.plan_id = p.id
      WHERE up.user_id = $1 AND up.status = 'active'
      LIMIT 1
      ''',
      parameters: [customerId],
    );
    if (planCheck.isEmpty) {
      print('❌ FAILED: Plan subscription was not created!');
    } else {
      print('✅ SUCCESS: Plan subscription created successfully!');
      print('   Details: ${planCheck.first.toColumnMap()}');
    }

    // Check installation job
    final jobCheck = await conn.execute(
      r'SELECT id, type, status, address, technician_id FROM jobs WHERE customer_id = $1 LIMIT 1',
      parameters: [customerId],
    );
    if (jobCheck.isEmpty) {
      print('❌ FAILED: Installation job was not created!');
    } else {
      print('✅ SUCCESS: Installation job created successfully!');
      print('   Details: ${jobCheck.first.toColumnMap()}');
    }

    // Check sales commission
    final commCheck = await conn.execute(
      r'SELECT id, amount, type, status FROM commissions WHERE lead_id = $1 LIMIT 1',
      parameters: [leadId],
    );
    if (commCheck.isEmpty) {
      print('❌ FAILED: Sales commission was not created!');
    } else {
      print('✅ SUCCESS: Sales commission created successfully!');
      print('   Details: ${commCheck.first.toColumnMap()}');
    }

    // 5. Test Customer Login
    print(
      '\n[5] Verifying customer can log in using new account and default password...',
    );
    final custLoginResponse = await post(
      '$baseUrl/auth/login',
      {
        'phone': testPhone,
        'password': 'password123',
      },
    );

    if (custLoginResponse['statusCode'] == 200) {
      print('✅ SUCCESS: Customer logged in successfully!');
    } else {
      print(
        '❌ FAILED: Customer login failed! Response: ${custLoginResponse['body']}',
      );
    }

    // 6. Test Job Completion by Technician
    print('\n[6] Logging in as technician (6666666666 / password123)...');
    final techLoginResponse = await post(
      '$baseUrl/auth/login',
      {
        'phone': '6666666666',
        'password': 'password123',
      },
    );

    if (techLoginResponse['statusCode'] != 200) {
      print(
        '❌ FAILED: Technician login failed! Response: ${techLoginResponse['body']}',
      );
      return;
    }

    final techLoginData = jsonDecode(techLoginResponse['body'] as String);
    final techToken = techLoginData['data']['token'] as String;
    final jobId = jobCheck.first.toColumnMap()['id'] as String;

    print('Successfully logged in! Token acquired. Job ID is $jobId.');

    print('Updating job status to completed...');
    final completeJobResponse = await post(
      '$baseUrl/tech/jobs/$jobId/status',
      {
        'status': 'completed',
      },
      token: techToken,
    );

    if (completeJobResponse['statusCode'] != 200) {
      print(
        '❌ FAILED: Failed to complete job! Response: ${completeJobResponse['body']}',
      );
      return;
    }
    print('Job updated to completed successfully!');

    // Verify the lead stage is now 'installed'
    final leadCheck = await conn.execute(
      r'SELECT stage FROM leads WHERE id = $1 LIMIT 1',
      parameters: [leadId],
    );

    if (leadCheck.isNotEmpty &&
        leadCheck.first.toColumnMap()['stage'] == 'installed') {
      print('✅ SUCCESS: Lead stage automatically transitioned to "installed"!');
    } else {
      print(
        '❌ FAILED: Lead stage is not "installed"! Details: ${leadCheck.first.toColumnMap()}',
      );
    }
  } catch (e) {
    print('Error during verification: $e');
  } finally {
    await conn.close();
    print('\n=== E2E INTEGRATION TEST COMPLETED ===');
  }
}
