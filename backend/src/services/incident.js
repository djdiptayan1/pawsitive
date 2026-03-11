import { supabase } from '../db/supabase.js';
import { startProgressiveDispatch, atomicAcceptIncident } from './dispatch.js';
import { broadcastToIncidentRoom } from '../ws/trackingServer.js';
import { resolveLocationNames, parseGeoLocation } from './location.js';
import { awardCredits } from './credits.js';

const ACTIVE_INCIDENT_STATUSES = ['pending', 'dispatched', 'active'];

const STAGE_LABELS = {
    en_route: 'En Route',
    on_scene: 'On Scene',
    first_aid: 'First Aid',
    in_transport: 'In Transport',
    at_vet: 'At Vet',
    recovered: 'Recovered',
};

const STAGE_EMOJI = {
    en_route: '🚗',
    on_scene: '📍',
    first_aid: '🩹',
    in_transport: '🚑',
    at_vet: '🏥',
    recovered: '🐾',
};

export async function createIncident({ reporterId, title, locationName, photoUrl, lat, lng, severity }) {
    const { data, error } = await supabase
        .from('incidents')
        .insert({
            reporter_id: reporterId,
            title,
            location_name: locationName,
            photo_url: photoUrl,
            geo_location: `SRID=4326;POINT(${lng} ${lat})`,
            severity,
            status: 'pending',
        })
        .select()
        .single();

    if (error) throw new Error(`Failed to create incident: ${error.message}`);
    return data;
}

export async function reportIncident({ reporterId, title, locationName, photoUrl, lat, lng, severity }) {
    const incident = await createIncident({ reporterId, title, locationName, photoUrl, lat, lng, severity });

    // Start progressive radius dispatch (non-blocking)
    startProgressiveDispatch({
        id: incident.id,
        severity: incident.severity,
        geo_location_lat: lat,
        geo_location_lng: lng,
    }).catch(console.error);

    return incident;
}

export async function getIncidentById(id) {
    const { data, error } = await supabase
        .from('incidents')
        .select('*, reporter:reporter_id(full_name, email), rescuer:assigned_rescuer_id(full_name, email)')
        .eq('id', id)
        .single();

    if (error) throw new Error(`Incident not found: ${error.message}`);
    return data;
}

export async function getIncidentsByReporter(reporterId) {
    const { data, error } = await supabase
        .from('incidents')
        .select('id, title, status, created_at, severity, photo_url, location_name, geo_location')
        .eq('reporter_id', reporterId)
        .order('created_at', { ascending: false });

    if (error) throw new Error(error.message);
    return resolveLocationNames(data || []);
}

export async function getIncidentsByRescuer(rescuerId) {
    const { data, error } = await supabase
        .from('incidents')
        .select('id, title, status, created_at, severity, photo_url, location_name, geo_location')
        .eq('assigned_rescuer_id', rescuerId)
        .order('created_at', { ascending: false });

    if (error) throw new Error(error.message);
    return resolveLocationNames(data || []);
}

export async function getPendingIncidents() {
    const { data, error } = await supabase
        .from('incidents')
        .select('id, title, status, created_at, severity, photo_url, location_name, geo_location')
        .eq('status', 'pending')
        .order('created_at', { ascending: false });

    if (error) throw new Error(error.message);

    // Extract lat/lng from geo_location for map pins
    const incidents = (data || []).map(incident => {
        const coords = parseGeoLocation(incident.geo_location);
        if (coords) {
            incident.lat = coords.lat;
            incident.lng = coords.lng;
        }
        return incident;
    });

    return resolveLocationNames(incidents);
}

export async function getNearbyActiveIncidents(lat, lng, radiusMeters = 1500) {
    const { data, error } = await supabase.rpc('get_nearby_active_incidents', {
        p_lat: lat,
        p_lng: lng,
        p_radius_m: radiusMeters,
    });

    if (error) throw new Error(`Failed to fetch nearby incidents: ${error.message}`);

    return (data || []).map((incident) => ({
        id: incident.incident_id,
        title: incident.title,
        severity: incident.severity,
        status: incident.status,
        witness_count: incident.witness_count || 0,
        lat: incident.lat,
        lng: incident.lng,
        distance_meters: incident.distance_meters,
    }));
}

export async function submitWitnessReport(incidentId, reporterId, witnessSeverity) {
    const { data: targetIncident, error: incidentError } = await supabase
        .from('incidents')
        .select('id, title, severity, status, photo_url, geo_location, location_name, witness_count, urgency_score')
        .eq('id', incidentId)
        .in('status', ACTIVE_INCIDENT_STATUSES)
        .maybeSingle();

    if (incidentError) throw new Error(`Could not load incident: ${incidentError.message}`);
    if (!targetIncident) throw new Error('Incident not found or no longer active');

    const { data: existingWitness } = await supabase
        .from('incidents')
        .select('id')
        .eq('reporter_id', reporterId)
        .eq('duplicate_case_of', incidentId)
        .limit(1)
        .maybeSingle();

    if (existingWitness) {
        return { alreadyWitnessed: true, witnessCount: targetIncident.witness_count || 0 };
    }

    const severityWeight = witnessSeverity === 'Severe' ? 3 : witnessSeverity === 'Moderate' ? 2 : 1;

    const { error: duplicateInsertError } = await supabase
        .from('incidents')
        .insert({
            reporter_id: reporterId,
            title: `Witness report: ${targetIncident.title || 'Animal in distress'}`,
            photo_url: targetIncident.photo_url,
            geo_location: targetIncident.geo_location,
            severity: witnessSeverity || targetIncident.severity,
            status: targetIncident.status,
            duplicate_case_of: incidentId,
            location_name: targetIncident.location_name || null,
        });

    if (duplicateInsertError) {
        throw new Error(`Failed to submit witness report: ${duplicateInsertError.message}`);
    }

    const nextWitnessCount = (targetIncident.witness_count || 0) + 1;
    const nextUrgencyScore = (targetIncident.urgency_score || 0) + severityWeight;

    let nextSeverity = targetIncident.severity;
    if (nextSeverity === 'Minor' && nextUrgencyScore >= 6) nextSeverity = 'Moderate';
    if (nextSeverity === 'Moderate' && nextUrgencyScore >= 10) nextSeverity = 'Severe';

    const { error: updateError } = await supabase
        .from('incidents')
        .update({
            witness_count: nextWitnessCount,
            urgency_score: nextUrgencyScore,
            severity: nextSeverity,
            updated_at: new Date().toISOString(),
        })
        .eq('id', incidentId);

    if (updateError) throw new Error(`Failed to update witness counters: ${updateError.message}`);

    broadcastToIncidentRoom(incidentId, {
        type: 'witness_update',
        incidentId,
        witnessCount: nextWitnessCount,
        severity: nextSeverity,
        notification: {
            title: 'More witnesses joined this case',
            body: `${nextWitnessCount} people confirmed this SOS nearby.`,
        },
    });

    return {
        alreadyWitnessed: false,
        witnessCount: nextWitnessCount,
        severity: nextSeverity,
        urgencyScore: nextUrgencyScore,
    };
}

export async function getHeatmapPoints(limit = 500) {
    const { data, error } = await supabase
        .from('incidents')
        .select('geo_location, severity')
        .in('status', ['rehabilitated', 'pending', 'dispatched', 'active'])
        .order('created_at', { ascending: false })
        .limit(limit);

    if (error) throw new Error(`Failed to build heatmap: ${error.message}`);

    const points = (data || []).map((incident) => {
        const coords = parseGeoLocation(incident.geo_location);
        if (!coords) return null;
        return {
            lat: coords.lat,
            lng: coords.lng,
            weight: incident.severity === 'Severe' ? 3 : incident.severity === 'Moderate' ? 2 : 1,
        };
    }).filter(Boolean);

    return points;
}

export async function listConditionLog(incidentId) {
    const { data, error } = await supabase
        .from('rescue_condition_log')
        .select('id, incident_id, rescuer_id, stage, note, photo_url, created_at')
        .eq('incident_id', incidentId)
        .order('created_at', { ascending: true });

    if (error) throw new Error(`Failed to load condition log: ${error.message}`);
    return data || [];
}

export async function postConditionLog({ incidentId, rescuerId, stage, note, photoUrl }) {
    const { data: incident, error: incidentError } = await supabase
        .from('incidents')
        .select('id, assigned_rescuer_id')
        .eq('id', incidentId)
        .maybeSingle();

    if (incidentError) throw new Error(`Failed to load incident: ${incidentError.message}`);
    if (!incident) throw new Error('Incident not found');
    if (incident.assigned_rescuer_id !== rescuerId) throw new Error('Only assigned rescuer can post updates');

    const { data: inserted, error: insertError } = await supabase
        .from('rescue_condition_log')
        .insert({
            incident_id: incidentId,
            rescuer_id: rescuerId,
            stage,
            note: note || null,
            photo_url: photoUrl || null,
        })
        .select('id, incident_id, rescuer_id, stage, note, photo_url, created_at')
        .single();

    if (insertError) throw new Error(`Failed to post condition update: ${insertError.message}`);

    const label = STAGE_LABELS[stage] || stage;
    const icon = STAGE_EMOJI[stage] || '🐾';

    broadcastToIncidentRoom(incidentId, {
        type: 'condition_update',
        incidentId,
        stage,
        note: inserted.note,
        createdAt: inserted.created_at,
        notification: {
            title: `Update: ${label}`,
            body: `${icon} Rescuer posted a progress update${inserted.note ? `: ${inserted.note}` : ''}`,
        },
    });

    return inserted;
}

// Get the rescuer's currently active rescue (dispatched/active)
export async function getActiveRescueForRescuer(rescuerId) {
    const { data, error } = await supabase
        .from('incidents')
        .select(`
            id, title, status, created_at, severity, photo_url,
            location_name, geo_location,
            reporter:reporter_id(full_name, email)
        `)
        .eq('assigned_rescuer_id', rescuerId)
        .in('status', ['dispatched', 'active'])
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

    if (error) throw new Error(error.message);
    if (!data) return null;

    const coords = parseGeoLocation(data.geo_location);
    delete data.geo_location;
    if (coords) {
        data.lat = coords.lat;
        data.lng = coords.lng;
    }
    return data;
}

// Get the citizen's currently active incident (pending/dispatched/active)
export async function getActiveIncidentForCitizen(reporterId) {
    const { data, error } = await supabase
        .from('incidents')
        .select(`
            id, title, status, created_at, severity, photo_url, witness_count,
            location_name, geo_location,
            assigned_rescuer_id,
            rescuer:assigned_rescuer_id(full_name, email, avatar_url, associated_ngo_id, ngo:associated_ngo_id(name, operating_city))
        `)
        .eq('reporter_id', reporterId)
        .in('status', ['pending', 'dispatched', 'active'])
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

    if (error) throw new Error(error.message);
    if (!data) return null;

    // Extract lat/lng from geo_location for the client
    const coords = parseGeoLocation(data.geo_location);
    delete data.geo_location;
    if (coords) {
        data.lat = coords.lat;
        data.lng = coords.lng;
    }
    return data;
}

export async function acceptIncidentAssignment(incidentId, user) {
    const result = await atomicAcceptIncident(incidentId, user.id);

    if (!result.success) {
        throw new Error('Incident already claimed by another rescuer');
    }

    // Notify citizen via WebSocket
    broadcastToIncidentRoom(incidentId, {
        type: 'accepted',
        rescuerId: user.id,
        rescuerName: user.email,
        notification: {
            title: 'Help is on the way!',
            body: `A rescuer has accepted your SOS and is en route.`
        }
    });

    return result;
}

export async function completeIncident(incidentId, rescuerId, rescuePhotoUrl, dropOffType) {
    const { data, error } = await supabase.rpc('complete_incident', {
        p_incident_id: incidentId,
        p_rescuer_id: rescuerId,
        p_rescue_photo_url: rescuePhotoUrl,
        p_drop_off_type: dropOffType || 'treated_on_scene',
    });
    if (error) throw new Error(error.message);
    return data;
}

export async function completeIncidentAssignment(incidentId, rescuerId, rescuePhotoUrl, dropOffType) {
    // Fetch incident details for credit calculation before completing
    let severity = 'Minor';
    let responseMinutes = 10;
    try {
        const { data: incident } = await supabase
            .from('incidents')
            .select('severity, created_at, updated_at')
            .eq('id', incidentId)
            .single();
        if (incident) {
            severity = incident.severity || 'Minor';
            const created = new Date(incident.created_at);
            const now = new Date();
            const MS_PER_MINUTE = 60000;
            responseMinutes = Math.max(1, Math.round((now - created) / MS_PER_MINUTE));
        }
    } catch (err) {
        console.error('⚠️ [Credits] Could not fetch incident for credit calc:', err.message);
    }

    const result = await completeIncident(incidentId, rescuerId, rescuePhotoUrl, dropOffType);

    // Award Pawsitive Credits (non-blocking, best-effort)
    awardCredits(incidentId, rescuerId, severity, responseMinutes, 0).catch(err => {
        console.error('⚠️ [Credits] Failed to award credits:', err.message);
    });

    broadcastToIncidentRoom(incidentId, {
        type: 'rescued',
        incidentId: incidentId,
        rescuePhotoUrl,
        dropOffType: dropOffType || 'treated_on_scene',
        notification: {
            title: 'Animal is safe! 🐾',
            body: 'The rescuer just sent a photo. Thank you for reporting this case.'
        }
    });

    return result;
}