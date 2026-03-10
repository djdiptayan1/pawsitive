-- ============================================================
-- Pawsitive Credits — Rescuer Incentive Economy
-- ============================================================

-- Rescuer reward ledger
CREATE TABLE IF NOT EXISTS rescuer_credits (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rescuer_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    incident_id     UUID REFERENCES incidents(id) ON DELETE SET NULL,
    credits_earned  INTEGER NOT NULL DEFAULT 0,
    reason          TEXT NOT NULL,  -- 'fast_response', 'severe_case', 'distance_bonus', 'rescue_completion'
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rescuer_credits_rescuer ON rescuer_credits(rescuer_id);
CREATE INDEX IF NOT EXISTS idx_rescuer_credits_incident ON rescuer_credits(incident_id);

-- Auto-calculate credits when incident is completed
CREATE OR REPLACE FUNCTION award_rescue_credits(
    p_incident_id UUID,
    p_rescuer_id  UUID,
    p_severity    TEXT,
    p_response_minutes INTEGER,
    p_distance_km FLOAT
) RETURNS INTEGER AS $$
DECLARE
    v_credits INTEGER := 10; -- base credits for every rescue
BEGIN
    -- Severity bonus
    IF p_severity = 'Severe'   THEN v_credits := v_credits + 30; END IF;
    IF p_severity = 'Moderate' THEN v_credits := v_credits + 15; END IF;

    -- Speed bonus (under 5 min = gold tier)
    IF p_response_minutes < 5  THEN v_credits := v_credits + 50;
    ELSIF p_response_minutes < 10 THEN v_credits := v_credits + 25;
    END IF;

    -- Distance bonus (1 credit per 100m)
    v_credits := v_credits + FLOOR(p_distance_km * 10)::INTEGER;

    INSERT INTO rescuer_credits (rescuer_id, incident_id, credits_earned, reason)
    VALUES (p_rescuer_id, p_incident_id, v_credits, 'rescue_completion');

    RETURN v_credits;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
