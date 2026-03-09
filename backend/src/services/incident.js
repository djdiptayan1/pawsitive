import { supabase } from '../db/supabase.js';
import { startProgressiveDispatch, atomicAcceptIncident } from './dispatch.js';
import { broadcastToRescuers, broadcastToIncidentRoom } from '../ws/trackingServer.js';
import { resolveLocationNames, parseGeoLocation } from './location.js';

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
            id, title, status, created_at, severity, photo_url,
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

export async function completeIncident(incidentId, rescuerId) {
    const { data, error } = await supabase.rpc('complete_incident', {
        p_incident_id: incidentId,
        p_rescuer_id: rescuerId,
    });
    if (error) throw new Error(error.message);
    return data;
}

export async function completeIncidentAssignment(incidentId, rescuerId) {
    const result = await completeIncident(incidentId, rescuerId);

    broadcastToIncidentRoom(incidentId, {
        type: 'rescued',
        incidentId: incidentId,
        notification: {
            title: 'Incident Resolved 🐾',
            body: 'The rescuer has marked this incident as rescued. Thank you!'
        }
    });

    return result;
}