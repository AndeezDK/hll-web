-- ============================================================================
-- Migration 004: Divisions system
-- Multi-select leagues/divisions for enemy teams
-- ============================================================================

-- Remove old single division column if it exists
ALTER TABLE enemy_teams DROP COLUMN IF EXISTS division;

-- Available divisions/leagues
CREATE TABLE IF NOT EXISTS divisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Many-to-many: which teams are in which divisions
CREATE TABLE IF NOT EXISTS enemy_team_divisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_tag TEXT NOT NULL REFERENCES enemy_teams(tag) ON DELETE CASCADE,
    division_id UUID NOT NULL REFERENCES divisions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(team_tag, division_id)
);

CREATE INDEX idx_etd_team ON enemy_team_divisions(team_tag);
CREATE INDEX idx_etd_division ON enemy_team_divisions(division_id);

-- Seed default divisions
INSERT INTO divisions (name, sort_order) VALUES
    ('ECL Div. 1', 10),
    ('ECL Div. 2', 20),
    ('ECL Div. 3', 30),
    ('ECL Div. 4', 40),
    ('ECL Div. 5', 50),
    ('ECL Div. 6', 60),
    ('HBL', 70),
    ('HCA', 80),
    ('Seasonals', 90)
ON CONFLICT (name) DO NOTHING;
