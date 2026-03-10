-- Proof-of-rescue schema + RPC update for rescue completion flow.

ALTER TABLE incidents
    ADD COLUMN IF NOT EXISTS rescue_photo_url TEXT,
    ADD COLUMN IF NOT EXISTS drop_off_type TEXT;

ALTER TABLE incidents
    DROP CONSTRAINT IF EXISTS incidents_drop_off_type_check;

ALTER TABLE incidents
    ADD CONSTRAINT incidents_drop_off_type_check
    CHECK (
        drop_off_type IS NULL
        OR drop_off_type IN ('vet_hospital', 'ngo_shelter', 'treated_on_scene')
    );

CREATE OR REPLACE FUNCTION complete_incident(
    p_incident_id UUID,
    p_rescuer_id UUID,
    p_rescue_photo_url TEXT DEFAULT NULL,
    p_drop_off_type TEXT DEFAULT 'treated_on_scene'
)
RETURNS JSONB AS $$
BEGIN
    UPDATE incidents
    SET status = 'rehabilitated',
        rescue_photo_url = p_rescue_photo_url,
        drop_off_type = p_drop_off_type,
        updated_at = NOW()
    WHERE id = p_incident_id
      AND assigned_rescuer_id = p_rescuer_id
      AND status IN ('dispatched', 'active');

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'reason', 'not_authorized_or_wrong_state');
    END IF;

    UPDATE active_rescuers_location
    SET is_available = TRUE,
        last_updated = NOW()
    WHERE rescuer_id = p_rescuer_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
