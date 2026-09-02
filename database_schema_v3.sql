-- FiberJet Database Schema Migration V3
-- Adds notification preferences table and complaint attachments

-- 1. Notification Preferences table
CREATE TABLE IF NOT EXISTS notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    network_alerts BOOL DEFAULT true,
    security_warnings BOOL DEFAULT true,
    bill_reminders BOOL DEFAULT true,
    promotional_offers BOOL DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Complaint attachments column
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS attachment_url TEXT;

-- 3. Index for notification preferences
CREATE INDEX IF NOT EXISTS idx_notification_prefs_user ON notification_preferences(user_id);
