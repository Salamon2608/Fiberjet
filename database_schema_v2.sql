-- FiberJet Database Schema Migration V2
-- Adds missing tables and columns required for SRS parity

-- 1. Create Speed Tests table
CREATE TABLE IF NOT EXISTS speed_tests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    download_mbps NUMERIC NOT NULL,
    upload_mbps NUMERIC NOT NULL,
    ping_ms NUMERIC,
    jitter_ms NUMERIC,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Add missing columns to Users
ALTER TABLE users ADD COLUMN IF NOT EXISTS nc_username TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS kyc_status VARCHAR(50) DEFAULT 'pending';
ALTER TABLE users ADD COLUMN IF NOT EXISTS kyc_doc_paths JSONB;

-- 3. Add missing columns to Plans
ALTER TABLE plans ADD COLUMN IF NOT EXISTS validity_days INT DEFAULT 30;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS is_active BOOL DEFAULT true;

-- 4. Add missing columns to User Plans
ALTER TABLE user_plans ADD COLUMN IF NOT EXISTS nc_quota_set BOOL DEFAULT false;

-- 5. Add missing columns to Complaints
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS title VARCHAR(255);

-- 6. Add missing columns to Job Photos
ALTER TABLE job_photos ADD COLUMN IF NOT EXISTS nc_file_id TEXT;

-- 7. Add missing columns to Cloud Files
ALTER TABLE cloud_files ADD COLUMN IF NOT EXISTS nc_file_path TEXT;
ALTER TABLE cloud_files ADD COLUMN IF NOT EXISTS nc_share_token TEXT;

-- 8. Add missing columns to Audit Logs
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS user_agent TEXT;

-- 9. Add User ID to OTP Logs for better tracking
ALTER TABLE otp_logs ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;

-- 10. Create Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'system',
    is_read BOOL DEFAULT false,
    data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Add description column to Plans
ALTER TABLE plans ADD COLUMN IF NOT EXISTS description TEXT;

-- 12. Create Plan Change Requests table
CREATE TABLE IF NOT EXISTS plan_change_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    current_plan_id UUID REFERENCES plans(id) ON DELETE SET NULL,
    target_plan_id UUID REFERENCES plans(id) ON DELETE CASCADE,
    reason TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. Indexing for performance
CREATE INDEX IF NOT EXISTS idx_speed_tests_user_id ON speed_tests(user_id);
CREATE INDEX IF NOT EXISTS idx_otp_logs_user_id ON otp_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints(status);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_plan_change_requests_user ON plan_change_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_cloud_files_user ON cloud_files(user_id, is_deleted);

