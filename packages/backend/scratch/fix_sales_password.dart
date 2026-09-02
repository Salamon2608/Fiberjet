import 'package:postgres/postgres.dart';
import 'package:bcrypt/bcrypt.dart';

Future<void> main() async {
  final conn = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'fiberjet',
      username: 'postgres',
      password: 'salo',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  final res = await conn.execute(
    Sql.named("SELECT id, name, email, phone, password_hash FROM users WHERE email = 'sales@fiberjet.com' OR role_id = (SELECT id FROM roles WHERE name = 'sales' LIMIT 1)"),
  );

  print('Found users with sales role / email:');
  for (final row in res) {
    final email = row[2];
    final phone = row[3];
    final hash = row[4] as String;
    final valid = BCrypt.checkpw('password123', hash);
    print('User: email=$email, phone=$phone, is password123 valid? $valid');
  }

  // Update password to password123 for sales@fiberjet.com and 7777777777
  final newHash = BCrypt.hashpw('password123', BCrypt.gensalt());
  await conn.execute(
    Sql.named("UPDATE users SET password_hash = @hash, phone = '7777777777' WHERE email = 'sales@fiberjet.com' OR role_id = (SELECT id FROM roles WHERE name = 'sales' LIMIT 1)"),
    parameters: {'hash': newHash},
  );

  print('\nUpdated sales password to password123 and phone to 7777777777 successfully!');

  await conn.close();
}
