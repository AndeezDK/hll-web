-- ============================================================================
-- Migration 008: Team-Clan composition
-- Maps which clans (1-4) make up each competitive team
-- clan_name matches values in players.team
-- ============================================================================

CREATE TABLE IF NOT EXISTS team_clans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    clan_name TEXT NOT NULL,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(team_id, clan_name)
);

CREATE INDEX idx_team_clans_team ON team_clans(team_id);

-- Seed defaults: each existing team has itself as its only clan
-- (Adjust these after migration if Circle is actually Circle + DKB)
INSERT INTO team_clans (team_id, clan_name, sort_order)
SELECT id, name, 0 FROM teams
ON CONFLICT (team_id, clan_name) DO NOTHING;

-- RLS
ALTER TABLE team_clans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "team_clans_select" ON team_clans FOR SELECT USING (true);
CREATE POLICY "team_clans_insert" ON team_clans FOR INSERT WITH CHECK (is_super_admin(auth.uid()));
CREATE POLICY "team_clans_update" ON team_clans FOR UPDATE USING (is_super_admin(auth.uid()));
CREATE POLICY "team_clans_delete" ON team_clans FOR DELETE USING (is_super_admin(auth.uid()));
