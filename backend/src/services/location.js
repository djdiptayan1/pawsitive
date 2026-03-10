import { supabase } from '../db/supabase.js';
import { broadcastToIncidentRoom } from '../ws/trackingServer.js';

// Parse PostGIS EWKB hex string to { lat, lng }
// Format: 01 (LE) + 01000020 (Point+SRID) + E6100000 (SRID 4326) + 8 bytes X + 8 bytes Y
export function parseGeoLocation(hexStr) {
    if (!hexStr || hexStr.length < 50) return null;
    try {
        const buf = Buffer.from(hexStr, 'hex');
        const lng = buf.readDoubleLE(9);
        const lat = buf.readDoubleLE(17);
        if (isNaN(lat) || isNaN(lng)) return null;
        return { lat, lng };
    } catch {
        return null;
    }
}

// Reverse geocode lat/lng to a human-readable location name via Nominatim
export async function reverseGeocode(lat, lng) {
    try {
        const res = await fetch(
            `https://nominatim.openstreetmap.org/reverse?format=json&lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lng)}&zoom=16`,
            { headers: { 'User-Agent': 'Pawsitive-App/1.0' } }
        );
        if (!res.ok) return null;
        const data = await res.json();
        const addr = data.address;
        if (!addr) return data.display_name || null;
        const parts = [
            addr.road || addr.pedestrian || addr.neighbourhood,
            addr.suburb || addr.village || addr.town,
            addr.city || addr.state_district || addr.county,
        ].filter(Boolean);
        return parts.length > 0 ? parts.join(', ') : data.display_name || null;
    } catch {
        return null;
    }
}

// For an array of incidents, resolve location_name from geo_location where missing
export async function resolveLocationNames(incidents) {
    const results = await Promise.all(
        incidents.map(async (incident) => {
            if (incident.location_name) {
                delete incident.geo_location;
                return incident;
            }
            const coords = parseGeoLocation(incident.geo_location);
            delete incident.geo_location; // don't send raw hex to client
            if (!coords) return incident;

            const locationName = await reverseGeocode(coords.lat, coords.lng);
            if (locationName) {
                incident.location_name = locationName;
                // Cache in DB (fire and forget)
                supabase.from('incidents')
                    .update({ location_name: locationName })
                    .eq('id', incident.id)
                    .then(() => { });
            }
            return incident;
        })
    );
    return results;
}

// Upsert rescuer GPS position via Supabase RPC (stored function handles ON CONFLICT)
export async function upsertRescuerLocation(rescuerId, lat, lng, isAvailable = true) {
    const { error } = await supabase.rpc('upsert_rescuer_location', {
        p_rescuer_id: rescuerId,
        p_lat: lat,
        p_lng: lng,
        p_available: isAvailable,
    });
    if (error) throw new Error(`Location upsert failed: ${error.message}`);
}

// Find nearby available rescuers with their lat/lng positions (single optimized query)
export async function findNearbyRescuersWithLocation(lat, lng, radiusMeters = 100000) {
    console.log(`   🔎 Calling get_nearby_rescuers_with_location RPC (lat=${lat}, lng=${lng}, radius=${radiusMeters}m)`);

    // Try optimized RPC that returns lat/lng as plain floats (no hex parsing)
    const { data: nearby, error: rpcError } = await supabase.rpc('get_nearby_rescuers_with_location', {
        p_lat: lat,
        p_lng: lng,
        p_radius: radiusMeters,
    });

    if (rpcError) {
        console.log(`   ⚠️ Optimized RPC failed: ${rpcError.message}, using fallback...`);
        // Fallback to original RPC + separate location fetch
        const { data: fallback, error: fallbackError } = await supabase.rpc('get_nearby_rescuers', {
            lat, lng, radius: radiusMeters,
        });
        if (fallbackError) throw new Error(`Nearby rescuers query failed: ${fallbackError.message}`);
        if (!fallback || fallback.length === 0) {
            console.log(`   ℹ️ Fallback: No rescuers found within ${radiusMeters}m`);
            return [];
        }

        console.log(`   📋 Fallback RPC returned ${fallback.length} rescuers, fetching locations...`);
        const rescuerIds = fallback.map(r => r.rescuer_id);
        const { data: locations, error: locError } = await supabase
            .from('active_rescuers_location')
            .select('rescuer_id, current_location')
            .in('rescuer_id', rescuerIds);
        if (locError) throw new Error(`Location fetch failed: ${locError.message}`);

        const coordMap = {};
        for (const loc of (locations || [])) {
            const coords = parseGeoLocation(loc.current_location);
            if (coords) coordMap[loc.rescuer_id] = coords;
        }

        return fallback.map(r => ({
            rescuer_id: r.rescuer_id,
            full_name: r.full_name,
            distance_meters: r.distance_meters,
            lat: coordMap[r.rescuer_id]?.lat || null,
            lng: coordMap[r.rescuer_id]?.lng || null,
        })).filter(r => r.lat !== null);
    }

    console.log(`   ✅ Optimized RPC returned ${nearby?.length || 0} rescuers`);

    // New RPC returns rescuer_lat / rescuer_lng directly as floats — no hex parsing needed
    const results = (nearby || []).map(r => {
        console.log(`      ✓ ${r.full_name}: (${r.rescuer_lat}, ${r.rescuer_lng}) - ${Math.round(r.distance_meters)}m`);
        return {
            rescuer_id: r.rescuer_id,
            full_name: r.full_name,
            distance_meters: r.distance_meters,
            lat: r.rescuer_lat,
            lng: r.rescuer_lng,
        };
    }).filter(r => r.lat != null && r.lng != null);

    console.log(`   ✅ Returning ${results.length} rescuers`);
    return results;
}

// Log a GPS ping to history table (for replay)
export async function logLocationHistory(incidentId, rescuerId, lat, lng) {
    await supabase.from('rescue_location_history').insert({
        incident_id: incidentId,
        rescuer_id: rescuerId,
        location: `SRID=4326;POINT(${lng} ${lat})`,
    });
}

// Fetch full location history for a completed rescue (for replay)
export async function getLocationHistory(incidentId) {
    const { data, error } = await supabase
        .from('rescue_location_history')
        .select('id, rescuer_id, location, recorded_at')
        .eq('incident_id', incidentId)
        .order('recorded_at', { ascending: true });

    if (error) throw new Error(`Failed to fetch location history: ${error.message}`);

    return (data || []).map(point => {
        const coords = parseGeoLocation(point.location);
        return {
            id: point.id,
            rescuerId: point.rescuer_id,
            lat: coords?.lat || null,
            lng: coords?.lng || null,
            createdAt: point.recorded_at,
        };
    }).filter(p => p.lat !== null);
}

// Handle incoming location update from a rescuer
export async function updateRescuerLocation(rescuerId, lat, lng, incidentId, eta) {
    // Upsert to active_rescuers_location (PostGIS)
    await upsertRescuerLocation(rescuerId, lat, lng);

    // If on an active rescue, relay live position to citizen
    if (incidentId) {
        await logLocationHistory(incidentId, rescuerId, lat, lng);

        broadcastToIncidentRoom(incidentId, {
            type: 'location_update',
            lat, lng,
            etaSeconds: eta || null,
        });
    }
}