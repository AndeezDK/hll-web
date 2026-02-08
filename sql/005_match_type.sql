-- ============================================================================
-- Migration 005: Match type tagging + My team divisions
-- ============================================================================

-- Add match_type to matches (which league/division the match was played in, or 'Friendly')
ALTER TABLE matches ADD COLUMN IF NOT EXISTS match_type TEXT DEFAULT 'Friendly';

-- My team divisions — uses same divisions table as enemy teams
-- Links your team(s) to divisions they play in
CREATE TABLE IF NOT EXISTS my_team_divisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_name TEXT NOT NULL,
    division_id UUID NOT NULL REFERENCES divisions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(team_name, division_id)
);

CREATE INDEX IF NOT EXISTS idx_mtd_team ON my_team_divisions(team_name);
