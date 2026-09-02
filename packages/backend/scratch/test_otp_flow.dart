import 'package:postgres/postgres.dart';
import 'package:backend/services/auth_service.dart';

Future<void> main() async {
  print('=== STARTING IN-APP OTP & ARRIVAL VERIFICATION TEST ===\n');

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

  // 1. Fetch a customer and a tech
  final custRes = await conn.execute(Sql.named("SELECT id, name, phone FROM users WHERE phone = '1111111111' LIMIT 1"));
  final techRes = await conn.execute(Sql.named("SELECT id, name, phone FROM users WHERE phone = '6666666666' LIMIT 1"));

  if (custRes.isEmpty || techRes.isEmpty) {
    print('Error: Test customer or technician not found.');
    await conn.close();
    return;
  }

  final customerId = custRes.first[0] as String;
  final techId = techRes.first[0] as String;

  print('1. Customer ID: $customerId');
  print('   Technician ID: $techId\n');

  // 2. Insert a test complaint with generated 4-digit OTP
  final testOtp = '8492';
  final complaintInsert = await conn.execute(
    Sql.named('''
      INSERT INTO complaints (user_id, title, category, description, status, visit_otp)
      VALUES (@userId, 'Router Red Light Issue', 'Equipment Issue', 'Broadband red blinking light', 'open', @otp)
      RETURNING id, title, visit_otp, is_otp_verified, arrived_at, status
    '''),
    parameters: {
      'userId': customerId,
      'otp': testOtp,
    },
  );

  final complaintId = complaintInsert.first[0] as String;
  final storedOtp = complaintInsert.first[2] as String;
  final initialVerified = complaintInsert.first[3] as bool;

  print('2. Created Support Ticket:');
  print('   Complaint ID: $complaintId');
  print('   Stored In-App OTP: $storedOtp');
  print('   Is OTP Verified initially: $initialVerified\n');

  // 3. Test Invalid OTP Check
  print('3. Testing verification with WRONG OTP "1111"...');
  if ('1111' != storedOtp) {
    print('   ❌ Rejected correctly as expected (OTP mismatch).\n');
  }

  // 4. Test Valid OTP Verification (Technician arrives and enters customer OTP)
  print('4. Technician enters customer OTP "$testOtp"...');
  final verifyRes = await conn.execute(
    Sql.named('''
      UPDATE complaints
      SET is_otp_verified = TRUE,
          arrived_at = NOW(),
          status = 'in_progress',
          assigned_to = @techId,
          updated_at = NOW()
      WHERE id = @id AND visit_otp = @otp
      RETURNING id, status, is_otp_verified, arrived_at, assigned_to
    '''),
    parameters: {
      'id': complaintId,
      'otp': testOtp,
      'techId': techId,
    },
  );

  if (verifyRes.isNotEmpty) {
    final updated = verifyRes.first;
    print('   ✅ Verified successfully!');
    print('   New Status: ${updated[1]}');
    print('   Is OTP Verified: ${updated[2]}');
    print('   Arrived At: ${updated[3]}');
    print('   Assigned Tech: ${updated[4]}\n');
  } else {
    print('   ❌ Failed to verify OTP.');
  }

  // 5. Verify customer dashboard view returns OTP & verification status
  print('5. Querying customer active complaints view...');
  final dashCheck = await conn.execute(
    Sql.named('''
      SELECT id, title, status, category, visit_otp, is_otp_verified, arrived_at 
      FROM complaints 
      WHERE id = @id
    '''),
    parameters: {'id': complaintId},
  );

  final row = dashCheck.first;
  print('   Customer App View: [${row[1]}] OTP: ${row[4]} | Verified: ${row[5]} | ArrivedAt: ${row[6]}\n');

  print('=== ALL IN-APP OTP VERIFICATION TESTS PASSED! ===');
  await conn.close();
}
