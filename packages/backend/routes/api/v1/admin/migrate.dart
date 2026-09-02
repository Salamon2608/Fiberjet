import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/migrate → Run pending database migrations
Future<Response> onRequest(RequestContext context) async {
  final db = context.read<PostgresService>();
  final results = <String>[];

  try {
    // 1. complaints extras
    await db.query("ALTER TABLE complaints ADD COLUMN IF NOT EXISTS title VARCHAR(255) DEFAULT 'Support Ticket'");
    await db.query("ALTER TABLE complaints ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()");
    await db.query("ALTER TABLE complaints ADD COLUMN IF NOT EXISTS priority VARCHAR(20) DEFAULT 'medium'");
    await db.query("ALTER TABLE complaints ADD COLUMN IF NOT EXISTS assigned_to UUID");
    results.add('✅ complaints columns ensured');

    // 2. job_chats table
    await db.query('''
      CREATE TABLE IF NOT EXISTS job_chats (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
        sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
        message TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');
    results.add('✅ job_chats table ensured');

    // 3. ratings table
    await db.query('''
      CREATE TABLE IF NOT EXISTS ratings (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
        customer_id UUID REFERENCES users(id),
        technician_id UUID REFERENCES users(id),
        stars INTEGER NOT NULL CHECK (stars >= 1 AND stars <= 5),
        comment TEXT DEFAULT '',
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');
    results.add('✅ ratings table ensured');

    // 4. payouts extras
    await db.query("ALTER TABLE payouts ADD COLUMN IF NOT EXISTS bank_account VARCHAR(100)");
    await db.query("ALTER TABLE payouts ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100)");
    await db.query("ALTER TABLE payouts ADD COLUMN IF NOT EXISTS aadhaar VARCHAR(20)");
    results.add('✅ payouts columns ensured');

    // 5. network_devices extras
    await db.query("ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS device_type VARCHAR(50)");
    await db.query("ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS ip_address VARCHAR(50)");
    await db.query("ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'online'");
    results.add('✅ network_devices columns ensured');

    // 7. Technician Jobs and Status Tracking
    await db.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_online BOOL DEFAULT false");
    await db.query("ALTER TABLE jobs ADD COLUMN IF NOT EXISTS en_route_at TIMESTAMPTZ");
    await db.query("ALTER TABLE jobs ADD COLUMN IF NOT EXISTS arrived_at TIMESTAMPTZ");
    await db.query("ALTER TABLE jobs ADD COLUMN IF NOT EXISTS in_progress_at TIMESTAMPTZ");
    await db.query("ALTER TABLE jobs ADD COLUMN IF NOT EXISTS rejection_reason TEXT");
    await db.query("ALTER TABLE jobs ADD COLUMN IF NOT EXISTS payout_amount NUMERIC(10,2)");
    results.add('✅ technician job status columns ensured');

    // 8. Chat Enhancements
    await db.query("ALTER TABLE job_chats ADD COLUMN IF NOT EXISTS file_url TEXT");
    await db.query("ALTER TABLE job_chats ADD COLUMN IF NOT EXISTS is_read BOOL DEFAULT false");
    await db.query("ALTER TABLE job_chats ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ");
    results.add('✅ chat enhancements ensured');

    // 6. notification_preferences table
    await db.query('''
      CREATE TABLE IF NOT EXISTS notification_preferences (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        network_alerts BOOLEAN NOT NULL DEFAULT TRUE,
        security_warnings BOOLEAN NOT NULL DEFAULT TRUE,
        bill_reminders BOOLEAN NOT NULL DEFAULT TRUE,
        promotional_offers BOOLEAN NOT NULL DEFAULT FALSE,
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');
    results.add('✅ notification_preferences table ensured');

    // 9. ads table analytics columns
    await db.query('ALTER TABLE ads ADD COLUMN IF NOT EXISTS impressions INT DEFAULT 0');
    await db.query('ALTER TABLE ads ADD COLUMN IF NOT EXISTS clicks INT DEFAULT 0');
    results.add('✅ ads impressions and clicks columns ensured');

    // 10. users table address column
    await db.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS address TEXT');
    results.add('✅ users address column ensured');

    // 11. complaints table coordinates columns
    await db.query('ALTER TABLE complaints ADD COLUMN IF NOT EXISTS latitude NUMERIC');
    await db.query('ALTER TABLE complaints ADD COLUMN IF NOT EXISTS longitude NUMERIC');
    results.add('✅ complaints latitude and longitude columns ensured');

    return ApiResponse.success(
      message: 'All migrations completed successfully',
      data: {'results': results},
    );
  } catch (e) {
    return ApiResponse.error(message: 'Migration error: $e');
  }
}
