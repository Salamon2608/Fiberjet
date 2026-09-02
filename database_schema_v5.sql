-- FiberJet Database Schema Migration V5
-- Adds My Jio-style plan management fields

-- 1. Add category for plan grouping (Popular, OTT Bundles, Data Add-on, Annual, etc.)
ALTER TABLE plans ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'Popular';

-- 2. Add promotional badge (Bestseller, Trending, Recommended, New, Value, etc.)
ALTER TABLE plans ADD COLUMN IF NOT EXISTS badge VARCHAR(50);

-- 3. Add daily data quota (e.g., 2GB/day) alongside existing total data_limit_gb
ALTER TABLE plans ADD COLUMN IF NOT EXISTS data_per_day_gb NUMERIC;

-- 4. Add post-FUP speed (speed after data quota exhaustion)
ALTER TABLE plans ADD COLUMN IF NOT EXISTS fup_speed_mbps INT;

-- 5. Add display priority for sorting within a category (lower = shown first)
ALTER TABLE plans ADD COLUMN IF NOT EXISTS priority INT DEFAULT 100;

-- 6. Indexing for category-based queries
CREATE INDEX IF NOT EXISTS idx_plans_category ON plans(category);
CREATE INDEX IF NOT EXISTS idx_plans_priority ON plans(category, priority);
CREATE INDEX IF NOT EXISTS idx_plans_active_category ON plans(is_active, category, priority);
