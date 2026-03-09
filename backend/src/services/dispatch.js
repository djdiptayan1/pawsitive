import { supabase } from '../db/supabase.js';
import { broadcastToRescuers } from '../ws/trackingServer.js';

// Ring config mirrors the DB table (cached here to avoid repeated queries)
const RING_CONFIG = {
    Severe: [{ ring: 1, radius: 2000, wait: 60 }, { ring: 2, radius: 5000, wait: 60 }, { ring: 3, radius: 10000, wait: 60 }],
    Moderate: [{ ring: 1, radius: 3000, wait: 90 }, { ring: 2, radius: 6000, wait: 90 }, { ring: 3, radius: 10000, wait: 90 }],
    Minor: [{ ring: 1, radius: 5000, wait: 120 }, { ring: 2, radius: 8000, wait: 120 }, { ring: 3, radius: 10000, wait: 120 }],
};

// Initial dispatch — called when citizen submits SOS
// Broadcasts Ring 1 and starts the expansion timer chain
export async function startProgressiveDispatch(incident) {
    const { id, severity, geo_location_lat, geo_location_lng } = incident;
    const rings = RING_CONFIG[severity] || RING_CONFIG['Moderate'];
    const ring1 = rings[0];

    // Broadcast ring 1
    const rescuers = await findRescuersInRadius(
        geo_location_lat, geo_location_lng, ring1.radius
    );

    if (rescuers.length > 0) {
        const ids = rescuers.map(r => r.rescuer_id);
        broadcastToRescuers(ids, {
            type: 'new_incident',
            incidentId: id,
            severity,
            lat: geo_location_lat,
            lng: geo_location_lng,
        });

        // Track who was already notified
        await supabase
            .from('incidents')
            .update({ notified_rescuers: ids, last_broadcast_at: new Date().toISOString() })
            .eq('id', id);
    }

    // Schedule ring 2, ring 3 expansions
    scheduleRingExpansion(id, severity, geo_location_lat, geo_location_lng, 1, rings);
}

// Recursive timer — fires after each ring's wait window
function scheduleRingExpansion(incidentId, severity, lat, lng, currentRing, rings) {
    const nextRingConfig = rings[currentRing]; // currentRing is 0-indexed here: rings[1] = ring 2
    if (!nextRingConfig) return;               // no more rings

    setTimeout(async () => {
        // Ask DB if we should expand (incident might already be accepted)
        const { data } = await supabase.rpc('get_next_dispatch_ring', {
            p_incident_id: incidentId
        });

        if (!data?.should_expand) {
            console.log(`⏹️  Dispatch stopped for ${incidentId}: ${data?.reason}`);
            return;
        }

        const prevConfig = rings[currentRing - 1];
        const newRescuers = await findRescuersInNewRing(
            lat, lng,
            prevConfig.radius,   // inner boundary — don't re-notify
            nextRingConfig.radius // outer boundary — newly in range
        );

        if (newRescuers.length > 0) {
            const ids = newRescuers.map(r => r.rescuer_id);
            broadcastToRescuers(ids, {
                type: 'new_incident',
                incidentId,
                severity,
                lat, lng,
                ring: nextRingConfig.ring, // so iOS can show "expanding search" UI
            });
            console.log(`📡 Ring ${nextRingConfig.ring} broadcast: ${ids.length} new rescuers`);
        }

        // Schedule next ring
        scheduleRingExpansion(incidentId, severity, lat, lng, currentRing + 1, rings);

    }, nextRingConfig.wait * 1000);
}

// Query Ring 1: all rescuers within radius
export async function findRescuersInRadius(lat, lng, radiusMeters) {
    const { data, error } = await supabase.rpc('get_nearby_rescuers', {
        lat, lng, radius: radiusMeters,
    });
    if (error) throw new Error(`Dispatch query failed: ${error.message}`);
    return data || [];
}

// Query ring expansion: only NEW rescuers between prev and new radius
async function findRescuersInNewRing(lat, lng, prevRadius, newRadius) {
    const { data, error } = await supabase.rpc('get_ring_expansion_rescuers', {
        lat, lng,
        prev_radius: prevRadius,
        new_radius: newRadius,
    });
    if (error) throw new Error(`Ring expansion query failed: ${error.message}`);
    return data || [];
}

// Race-condition-safe accept via Supabase stored function
export async function atomicAcceptIncident(incidentId, rescuerId) {
    const { data, error } = await supabase.rpc('accept_incident', {
        p_incident_id: incidentId,
        p_rescuer_id: rescuerId,
    });
    if (error) throw new Error(`Accept failed: ${error.message}`);
    return data; // { success: bool, reason?: string, reporter_id?: uuid }
}