import { createClient } from '@supabase/supabase-js';
import { ENV } from '../config/env.js';

// Service-role client: bypasses RLS — backend use ONLY
export const supabase = createClient(
    ENV.SUPABASE_URL,
    ENV.SUPABASE_SERVICE_KEY
);

// Anon client: used to verify user JWTs
export const supabaseAnon = createClient(
    ENV.SUPABASE_URL,
    ENV.SUPABASE_ANON_KEY
);