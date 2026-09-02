import 'package:postgres/postgres.dart';

Future<void> main() async {
  final conn = await Connection.open(
    Endpoint(host: 'localhost', port: 5432, database: 'fiberjet', username: 'postgres', password: 'salo'),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  print('=== FULL DATABASE SCHEMA AUDIT ===\n');

  // Check all table columns
  final tables = ['users', 'roles', 'plans', 'user_plans', 'leads', 'lead_comments',
    'jobs', 'job_photos', 'complaints', 'ott_claims', 'cloud_files',
    'network_devices', 'commissions', 'payouts', 'notifications', 'job_chats',
    'ads', 'ratings', 'expenses', 'modem_info', 'audit_logs', 'otp_logs',
    'speed_tests', 'notification_preferences', 'plan_change_requests'];

  for (final table in tables) {
    try {
      final cols = await conn.execute(Sql.named(
        "SELECT column_name, data_type, is_nullable, column_default "
        "FROM information_schema.columns "
        "WHERE table_name = @tbl ORDER BY ordinal_position"
      ), parameters: {'tbl': table});
      
      if (cols.isEmpty) {
        print('⚠️  TABLE "$table" DOES NOT EXIST');
        continue;
      }
      
      print('📋 TABLE: $table (${cols.length} columns)');
      for (final c in cols) {
        print('   ${c[0]} (${c[1]}) ${c[2] == "YES" ? "nullable" : "NOT NULL"}');
      }
      print('');
    } catch (e) {
      print('❌ Error checking table $table: $e');
    }
  }

  // Check for missing columns that backend routes reference
  print('\n=== COLUMN EXISTENCE CHECKS ===\n');
  
  final checks = <String, List<String>>{
    'users': ['is_online', 'address', 'nc_username', 'kyc_status', 'kyc_doc_paths', 'kyc_rejection_reason'],
    'jobs': ['en_route_at', 'arrived_at', 'in_progress_at', 'visit_otp', 'is_otp_verified', 'service_charge', 'address'],
    'complaints': ['visit_otp', 'is_otp_verified', 'arrived_at', 'latitude', 'longitude', 'resolution_note', 'attachment_url'],
    'plans': ['category', 'badge', 'data_per_day_gb', 'fup_speed_mbps', 'priority', 'description', 'is_active', 'validity_days'],
    'ads': ['revenue_generated'],
  };

  for (final entry in checks.entries) {
    final table = entry.key;
    for (final col in entry.value) {
      final res = await conn.execute(Sql.named(
        "SELECT COUNT(*) FROM information_schema.columns "
        "WHERE table_name = @tbl AND column_name = @col"
      ), parameters: {'tbl': table, 'col': col});
      final exists = (res.first[0] as int) > 0;
      print('${exists ? "✅" : "❌"} $table.$col ${exists ? "exists" : "MISSING"}');
    }
  }

  // Check data counts
  print('\n=== DATA COUNTS ===\n');
  for (final table in ['users', 'roles', 'plans', 'jobs', 'complaints', 'leads', 'modem_info', 'ratings', 'audit_logs']) {
    try {
      final res = await conn.execute("SELECT COUNT(*) FROM $table");
      print('📊 $table: ${res.first[0]} rows');
    } catch (e) {
      print('❌ $table: $e');
    }
  }

  // Check user role distribution
  print('\n=== USER ROLE DISTRIBUTION ===\n');
  final roleRes = await conn.execute(
    "SELECT r.name, COUNT(u.id)::int FROM users u JOIN roles r ON u.role_id = r.id GROUP BY r.name ORDER BY COUNT(u.id) DESC"
  );
  for (final r in roleRes) {
    print('   ${r[0]}: ${r[1]} users');
  }

  // Check job status distribution
  print('\n=== JOB STATUS DISTRIBUTION ===\n');
  final jobRes = await conn.execute("SELECT status, COUNT(*)::int FROM jobs GROUP BY status ORDER BY COUNT(*) DESC");
  for (final r in jobRes) {
    print('   ${r[0]}: ${r[1]} jobs');
  }

  // Check complaint status distribution
  print('\n=== COMPLAINT STATUS DISTRIBUTION ===\n');
  final compRes = await conn.execute("SELECT status, COUNT(*)::int FROM complaints GROUP BY status ORDER BY COUNT(*) DESC");
  for (final r in compRes) {
    print('   ${r[0]}: ${r[1]} complaints');
  }

  await conn.close();
  print('\n=== AUDIT COMPLETE ===');
}
