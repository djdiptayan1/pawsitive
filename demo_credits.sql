-- ============================================
-- Demo SQL Commands for Pawsitive Credits
-- ============================================
-- 
-- User IDs:
--   Citizen:  316710e7-465d-4741-89ce-2ebe9b6aa226
--   Rescuer:  cf3bad10-2ec4-410b-b91e-684fa9281816
--
-- Run these commands in the Supabase SQL Editor
-- to populate demo data for the earnings feature.
-- ============================================

-- Set the demo rescuer ID (change this to use a different user)
DO $$
DECLARE
  demo_rescuer_id UUID := 'cf3bad10-2ec4-410b-b91e-684fa9281816';
BEGIN

-- ============================================
-- 1. RESCUER CREDITS (Pawsitive Credits / Earnings)
-- ============================================
-- These go into the rescuer_credits table.
-- Each row represents credits earned for a specific rescue or achievement.
-- The rescuer will see these in their "Earnings" section.

-- Rescue completion credits (simulating completed rescues)
INSERT INTO rescuer_credits (rescuer_id, credits_earned, reason, created_at)
VALUES
  (demo_rescuer_id, 25, 'rescue_completion', NOW() - INTERVAL '7 days'),
  (demo_rescuer_id, 35, 'rescue_completion', NOW() - INTERVAL '5 days'),
  (demo_rescuer_id, 50, 'rescue_completion', NOW() - INTERVAL '3 days'),
  (demo_rescuer_id, 40, 'rescue_completion', NOW() - INTERVAL '2 days'),
  (demo_rescuer_id, 30, 'rescue_completion', NOW() - INTERVAL '1 day');

-- Bonus credits (fast response, severe cases, distance)
INSERT INTO rescuer_credits (rescuer_id, credits_earned, reason, created_at)
VALUES
  (demo_rescuer_id, 15, 'fast_response', NOW() - INTERVAL '6 days'),
  (demo_rescuer_id, 20, 'severe_case', NOW() - INTERVAL '4 days'),
  (demo_rescuer_id, 10, 'distance_bonus', NOW() - INTERVAL '3 days'),
  (demo_rescuer_id, 15, 'fast_response', NOW() - INTERVAL '1 day'),
  (demo_rescuer_id, 10, 'citizen_rating', NOW() - INTERVAL '12 hours');

-- Total: 250 credits → Rescuer reaches "Responder" tier (100-499)
-- This gives a nice demo with the progress bar showing progress toward "Elite Rescuer" at 500

END $$;

-- ============================================
-- 2. VERIFY THE DATA
-- ============================================
-- Run this to check total credits for the rescuer:

-- SELECT SUM(credits_earned) as total_credits FROM rescuer_credits 
--   WHERE rescuer_id = 'cf3bad10-2ec4-410b-b91e-684fa9281816';

-- Run this to see the credit history:

-- SELECT id, credits_earned, reason, created_at FROM rescuer_credits
--   WHERE rescuer_id = 'cf3bad10-2ec4-410b-b91e-684fa9281816'
--   ORDER BY created_at DESC;

-- ============================================
-- 3. (OPTIONAL) ADD MORE CREDITS TO REACH HIGHER TIERS
-- ============================================
-- Uncomment these to reach "Elite Rescuer" tier (500+ credits):

-- INSERT INTO rescuer_credits (rescuer_id, credits_earned, reason, created_at)
-- VALUES
--   ('cf3bad10-2ec4-410b-b91e-684fa9281816', 100, 'rescue_completion', NOW() - INTERVAL '30 minutes'),
--   ('cf3bad10-2ec4-410b-b91e-684fa9281816', 75, 'rescue_completion', NOW() - INTERVAL '20 minutes'),
--   ('cf3bad10-2ec4-410b-b91e-684fa9281816', 75, 'severe_case', NOW() - INTERVAL '10 minutes');

-- ============================================
-- 4. CLEANUP (if needed)
-- ============================================
-- To remove all demo credits:

-- DELETE FROM rescuer_credits 
--   WHERE rescuer_id = 'cf3bad10-2ec4-410b-b91e-684fa9281816';
