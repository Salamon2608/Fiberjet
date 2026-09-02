-- Add visit OTP and arrival verification to complaints and jobs

-- 1. Complaints table
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS visit_otp VARCHAR(10);
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS is_otp_verified BOOL DEFAULT FALSE;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS arrived_at TIMESTAMPTZ;

-- Backfill existing complaints with 4-digit OTPs
UPDATE complaints 
SET visit_otp = (1000 + floor(random() * 9000))::text 
WHERE visit_otp IS NULL;

-- 2. Jobs table
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS visit_otp VARCHAR(10);
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS is_otp_verified BOOL DEFAULT FALSE;

-- Backfill existing jobs with 4-digit OTPs
UPDATE jobs 
SET visit_otp = (1000 + floor(random() * 9000))::text 
WHERE visit_otp IS NULL;
