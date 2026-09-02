INSERT INTO plans (name, description, speed_mbps, price, data_limit_gb, cloud_storage_gb, ott_benefits, validity_days, is_active, category, badge, data_per_day_gb, fup_speed_mbps, priority) VALUES
('FiberJet Starter', 'Perfect for casual browsing and social media', 50, 399, NULL, 5, '{"JioCinema": true}', 30, true, 'Popular', 'Value', 1.5, 5, 10),
('FiberJet Pro', 'High-speed plan for streaming and gaming', 100, 699, NULL, 25, '{"Netflix": true, "Amazon Prime": true, "JioCinema": true}', 30, true, 'OTT Bundles', 'Bestseller', 2.5, 10, 20),
('FiberJet Ultra', 'Unlimited premium experience with all OTT', 300, 1499, NULL, 100, '{"Netflix": true, "Amazon Prime": true, "Disney+ Hotstar": true, "JioCinema": true, "Spotify": true}', 90, true, 'OTT Bundles', 'Premium', NULL, NULL, 30),
('FiberJet Annual', 'Best value 365 days of uninterrupted internet', 100, 6999, NULL, 50, '{"Netflix": true, "Amazon Prime": true}', 365, true, 'Annual', 'Trending', 3.0, 15, 40),
('FiberJet Gaming', 'Ultra low latency plan for pro gamers', 500, 1999, NULL, 10, '{"YouTube Premium": true}', 30, true, 'Gaming', 'New', NULL, NULL, 50);
