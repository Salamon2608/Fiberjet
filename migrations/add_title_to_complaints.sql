-- Migration: Add 'title' column to complaints table (if not already present)
-- Run this in your PostgreSQL database

DO $$
BEGIN
    -- Add title column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'complaints' AND column_name = 'title'
    ) THEN
        ALTER TABLE complaints ADD COLUMN title VARCHAR(255) DEFAULT 'Support Ticket';
        RAISE NOTICE 'Added: title column to complaints';
    ELSE
        RAISE NOTICE 'Skipped: title column already exists';
    END IF;
END $$;
