-- FiberJet Database Schema Migration V4
-- Adds columns for revenue tracking and user approval

-- 1. Add revenue to ads
ALTER TABLE ads ADD COLUMN IF NOT EXISTS revenue_generated NUMERIC(10,2) DEFAULT 0;

-- 2. Add service charge to jobs
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS service_charge NUMERIC(10,2) DEFAULT 0;

-- 3. Add kyc_rejection_reason to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS kyc_rejection_reason TEXT;
