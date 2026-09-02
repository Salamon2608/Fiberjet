import 'dart:io';
import 'dart:convert';

void main() async {
  final client = HttpClient();
  
  // Login customer@fiberjet.com
  final loginReq = await client.postUrl(Uri.parse('http://127.0.0.1:8080/api/v1/auth/login'));
  loginReq.headers.contentType = ContentType.json;
  loginReq.write(jsonEncode({'email': 'customer@fiberjet.com', 'password': 'password123'}));
  
  final loginRes = await loginReq.close();
  final loginBody = await loginRes.transform(utf8.decoder).join();
  
  if (loginRes.statusCode != 200) {
    print('Login failed: $loginBody');
    exit(1);
  }
  
  final loginData = jsonDecode(loginBody);
  print('Login response: $loginData');
  
  final token = loginData['data']['token'];
  
  // Get dashboard
  final getReq = await client.getUrl(Uri.parse('http://127.0.0.1:8080/api/v1/customer/dashboard'));
  getReq.headers.add('Authorization', 'Bearer $token');
  
  final getRes = await getReq.close();
  final getBody = await getRes.transform(utf8.decoder).join();
  
  print('\nDashboard Status Code: ${getRes.statusCode}');
  print('Dashboard Response Body:');
  final encoder = const JsonEncoder.withIndent('  ');
  print(encoder.convert(jsonDecode(getBody)));
  
  // Get my subscriptions
  final subReq = await client.getUrl(Uri.parse('http://127.0.0.1:8080/api/v1/customer/my_subscriptions'));
  subReq.headers.add('Authorization', 'Bearer $token');
  
  final subRes = await subReq.close();
  final subBody = await subRes.transform(utf8.decoder).join();
  
  print('\nSubscriptions Status Code: ${subRes.statusCode}');
  print('Subscriptions Response Body:');
  print(encoder.convert(jsonDecode(subBody)));
  
  exit(0);
}
