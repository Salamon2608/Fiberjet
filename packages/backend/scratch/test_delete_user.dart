import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  print('=== TESTING DELETE USER ENDPOINT ===\n');

  final conn = await Connection.open(
    Endpoint(host: 'localhost', port: 5432, database: 'fiberjet', username: 'postgres', password: 'salo'),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  // 1. Find admin token
  final adminRes = await conn.execute("SELECT id, phone, password_hash FROM users WHERE role_id = (SELECT id FROM roles WHERE name = 'admin') LIMIT 1");
  final adminPhone = adminRes.first[1] as String;

  print('Logging in as Admin ($adminPhone)...');
  final client = HttpClient();
  final loginReq = await client.postUrl(Uri.parse('http://127.0.0.1:8080/api/v1/auth/login'));
  loginReq.headers.contentType = ContentType.json;
  loginReq.write(jsonEncode({'phone': adminPhone, 'password': 'password123'}));
  final loginResp = await loginReq.close();
  final loginBody = await loginResp.transform(utf8.decoder).join();

  print('Login status: ${loginResp.statusCode}');
  print('Login body: $loginBody');
  final loginData = jsonDecode(loginBody);
  final token = loginData['data']?['token'] as String?;

  if (token == null) {
    print('Failed to get admin token!');
    await conn.close();
    return;
  }

  // 2. Create a dummy test user to delete
  print('\nCreating dummy user to test deletion...');
  final roleRes = await conn.execute("SELECT id FROM roles WHERE name = 'customer' LIMIT 1");
  final roleId = roleRes.first[0] as String;

  final testUserRes = await conn.execute(Sql.named(
    "INSERT INTO users (name, phone, email, password_hash, role_id, status) "
    "VALUES ('Test Delete User', '9888888888', 'delete_test@fiberjet.com', 'dummy_hash', @roleId, 'active') "
    "RETURNING id"
  ), parameters: {'roleId': roleId});
  final testUserId = testUserRes.first[0] as String;
  print('Created test user ID: $testUserId');

  // 3. Call DELETE /api/v1/admin/users/$testUserId
  print('\nCalling DELETE /api/v1/admin/users/$testUserId...');
  final delReq = await client.openUrl('DELETE', Uri.parse('http://127.0.0.1:8080/api/v1/admin/users/$testUserId'));
  delReq.headers.contentType = ContentType.json;
  delReq.headers.set('Authorization', 'Bearer $token');
  final delResp = await delReq.close();
  final delBody = await delResp.transform(utf8.decoder).join();

  print('DELETE Response Status: ${delResp.statusCode}');
  print('DELETE Response Body: $delBody');

  // Clean up if not deleted
  await conn.execute("DELETE FROM users WHERE id = '$testUserId'");
  await conn.close();
}
