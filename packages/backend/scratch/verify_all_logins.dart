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
    Sql.named('''
      SELECT u.id, u.name, u.email, u.phone, r.name as role_name, u.password_hash 
      FROM users u 
      JOIN roles r ON u.role_id = r.id
      ORDER BY r.name
    '''),
  );

  print('=== ALL USERS AUTH STATUS ===');
  for (final row in res) {
    final name = row[1];
    final email = row[2];
    final phone = row[3];
    final role = row[4];
    final hash = row[5] as String;
    final valid = BCrypt.checkpw('password123', hash);
    print('[$role] Name: $name | Email: $email | Phone: $phone | Password "password123" valid: $valid');
  }

  await conn.close();
}
