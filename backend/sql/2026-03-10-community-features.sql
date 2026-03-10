-- Community-facing rescue upgrades:
-- 1) Witness confirmations (duplicate_case_of already exists)
-- 2) Rescue condition timeline for live medical-style updates

ALTER TABLE incidents
    ADD COLUMN IF NOT EXISTS witness_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS urgency_score INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS rescue_condition_log (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    rescuer_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stage       TEXT NOT NULL CHECK (stage IN ('en_route', 'on_scene', 'first_aid', 'in_transport', 'at_vet', 'recovered')),
    note        TEXT,
    photo_url   TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rescue_condition_log_incident_created_at
    ON rescue_condition_log (incident_id, created_at);

-- Returns active incidents near a citizen so they can tap "I'm a witness too".
CREATE OR REPLACE FUNCTION get_nearby_active_incidents(
    p_lat FLOAT,
    p_lng FLOAT,
    p_radius_m FLOAT DEFAULT 1500
)
RETURNS TABLE (
    incident_id UUID,
    title TEXT,
    severity TEXT,
    status TEXT,
    witness_count INTEGER,
    lat FLOAT,
    lng FLOAT,
    distance_meters FLOAT
) AS $$
    SELECT
        i.id AS incident_id,
        i.title,
        i.severity,
        i.status,
        i.witness_count,
        ST_Y(i.geo_location::geometry) AS lat,
        ST_X(i.geo_location::geometry) AS lng,
        ST_Distance(
            i.geo_location,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        ) AS distance_meters
    FROM incidents i
    WHERE
        i.duplicate_case_of IS NULL
        AND i.status IN ('pending', 'dispatched', 'active')
        AND ST_DWithin(
            i.geo_location,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
            p_radius_m
        )
    ORDER BY distance_meters ASC
    LIMIT 30;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
