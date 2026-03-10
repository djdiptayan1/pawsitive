import { supabase } from '../db/supabase.js';

/**
 * Award Pawsitive Credits to a rescuer upon rescue completion.
 * Calls the `award_rescue_credits` Postgres function.
 */
export async function awardCredits(incidentId, rescuerId, severity, responseMinutes, distanceKm) {
    console.log('🏅 [Credits] Awarding credits to rescuer:', rescuerId);
    console.log('   Incident:', incidentId, '| Severity:', severity);
    console.log('   Response time:', responseMinutes, 'min | Distance:', distanceKm, 'km');

    const { data, error } = await supabase.rpc('award_rescue_credits', {
        p_incident_id: incidentId,
        p_rescuer_id: rescuerId,
        p_severity: severity,
        p_response_minutes: responseMinutes || 10,
        p_distance_km: distanceKm || 0,
    });

    if (error) {
        console.error('❌ [Credits] Failed to award credits:', error.message);
        // Don't throw — credits are a bonus, shouldn't block rescue completion
        return 0;
    }

    console.log(`✅ [Credits] Awarded ${data} credits`);
    return data || 0;
}

/**
 * Get total Pawsitive Credits for a rescuer.
 */
export async function getTotalCredits(rescuerId) {
    const { data, error } = await supabase
        .from('rescuer_credits')
        .select('credits_earned')
        .eq('rescuer_id', rescuerId);

    if (error) {
        console.error('❌ [Credits] Failed to fetch credits:', error.message);
        return 0;
    }

    const total = (data || []).reduce((sum, row) => sum + (row.credits_earned || 0), 0);
    return total;
}

/**
 * Get credit history for a rescuer (most recent first).
 */
export async function getCreditHistory(rescuerId, limit = 20) {
    const { data, error } = await supabase
        .from('rescuer_credits')
        .select('id, incident_id, credits_earned, reason, created_at')
        .eq('rescuer_id', rescuerId)
        .order('created_at', { ascending: false })
        .limit(limit);

    if (error) {
        console.error('❌ [Credits] Failed to fetch credit history:', error.message);
        return [];
    }

    return data || [];
}

/**
 * Derive the rescuer's tier from total credits.
 *   🥉  0-99     — Volunteer
 *   🥈  100-499  — Responder
 *   🥇  500-999  — Elite Rescuer
 *   🏆  1000+    — Pawsitive Hero
 */
export function deriveTier(totalCredits) {
    if (totalCredits >= 1000) return { name: 'Pawsitive Hero', badge: '🏆' };
    if (totalCredits >= 500) return { name: 'Elite Rescuer', badge: '🥇' };
    if (totalCredits >= 100) return { name: 'Responder', badge: '🥈' };
    return { name: 'Volunteer', badge: '🥉' };
}
