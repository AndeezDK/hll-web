-- ============================================================================
-- HLL Web Tool v0.3.32 - Enemy Intel System
-- Run this in Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- ENEMY_TEAMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS enemy_teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag TEXT NOT NULL UNIQUE,
    name TEXT,
    first_seen DATE,
    last_seen DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_enemy_teams_tag ON enemy_teams(tag);

-- ============================================================================
-- ENEMY_PLAYERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS enemy_players (
    steam_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    primary_team_tag TEXT,
    first_seen DATE,
    last_seen DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_enemy_players_team ON enemy_players(primary_team_tag);

-- ============================================================================
-- ENEMY_PLAYER_TEAMS - tracks which teams a player has played for
-- (for mercenary detection)
-- ============================================================================
CREATE TABLE IF NOT EXISTS enemy_player_teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    steam_id TEXT NOT NULL REFERENCES enemy_players(steam_id) ON DELETE CASCADE,
    team_tag TEXT NOT NULL,
    match_count INTEGER DEFAULT 1,
    first_seen DATE,
    last_seen DATE,
    
    UNIQUE(steam_id, team_tag)
);

CREATE INDEX idx_enemy_player_teams_steam ON enemy_player_teams(steam_id);
CREATE INDEX idx_enemy_player_teams_tag ON enemy_player_teams(team_tag);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE enemy_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE enemy_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE enemy_player_teams ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all" ON enemy_teams FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON enemy_players FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON enemy_player_teams FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- VIEW: Enemy team stats (calculated from matches)
-- ============================================================================
CREATE OR REPLACE VIEW enemy_team_stats AS
SELECT 
    et.id,
    et.tag,
    et.name,
    et.notes,
    COUNT(m.match_id) as total_matches,
    COUNT(*) FILTER (WHERE m.result = 'W') as wins,
    COUNT(*) FILTER (WHERE m.result = 'L') as losses,
    COUNT(*) FILTER (WHERE m.result = 'D') as draws,
    ROUND(
        COUNT(*) FILTER (WHERE m.result = 'W')::NUMERIC / 
        NULLIF(COUNT(m.match_id), 0) * 100, 0
    ) as win_rate,
    SUM(m.my_score) as points_for,
    SUM(m.enemy_score) as points_against,
    MAX(m.match_date) as last_played,
    MIN(m.match_date) as first_played,
    et.first_seen,
    et.last_seen
FROM enemy_teams et
LEFT JOIN matches m ON m.enemy_team = et.tag
GROUP BY et.id, et.tag, et.name, et.notes, et.first_seen, et.last_seen
ORDER BY total_matches DESC;

-- ============================================================================
-- VIEW: Enemy player stats (calculated from match_details)
-- ============================================================================
CREATE OR REPLACE VIEW enemy_player_stats AS
SELECT 
    ep.steam_id,
    ep.name,
    ep.primary_team_tag,
    ep.notes,
    COUNT(md.id) as total_matches,
    SUM(md.kills) as total_kills,
    SUM(md.deaths) as total_deaths,
    ROUND(
        SUM(md.kills)::NUMERIC / NULLIF(SUM(md.deaths), 0), 2
    ) as kd_ratio,
    ROUND(SUM(md.kills)::NUMERIC / NULLIF(COUNT(md.id), 0), 1) as avg_kills,
    MAX(md.kills) as most_kills,
    ROUND(SUM(md.combat_eff)::NUMERIC / NULLIF(COUNT(md.id), 0), 0) as avg_ce,
    -- Threat/100: (avg_kills * kd_ratio), capped at 100. 0 kills = 0 threat. 0 deaths = use kills as KD.
    CASE WHEN COALESCE(SUM(md.kills), 0) = 0 THEN 0
    ELSE LEAST(100, ROUND(
        (SUM(md.kills)::NUMERIC / NULLIF(COUNT(md.id), 0)) *
        (SUM(md.kills)::NUMERIC / GREATEST(SUM(md.deaths), 1)),
    0)) END as threat_score,
    MAX(m.match_date) as last_seen,
    MIN(m.match_date) as first_seen,
    -- Count of distinct teams played for (for mercenary detection)
    (SELECT COUNT(*) FROM enemy_player_teams ept WHERE ept.steam_id = ep.steam_id) as teams_played_for
FROM enemy_players ep
LEFT JOIN match_details md ON md.steam_id = ep.steam_id AND md.team = 'Enemy'
LEFT JOIN matches m ON m.match_id = md.match_id
GROUP BY ep.steam_id, ep.name, ep.primary_team_tag, ep.notes;

-- ============================================================================
-- VIEW: Mercenary detection
-- Players who have played for 2+ different enemy teams
-- ============================================================================
CREATE OR REPLACE VIEW mercenary_players AS
SELECT 
    ep.steam_id,
    ep.name,
    ep.primary_team_tag,
    COUNT(DISTINCT ept.team_tag) as team_count,
    ARRAY_AGG(DISTINCT ept.team_tag) as teams,
    ARRAY_AGG(DISTINCT ept.team_tag || ' (' || ept.match_count || ')') as teams_with_counts,
    SUM(ept.match_count) as total_matches
FROM enemy_players ep
JOIN enemy_player_teams ept ON ept.steam_id = ep.steam_id
GROUP BY ep.steam_id, ep.name, ep.primary_team_tag
HAVING COUNT(DISTINCT ept.team_tag) >= 2
ORDER BY COUNT(DISTINCT ept.team_tag) DESC, SUM(ept.match_count) DESC;

-- ============================================================================
-- VIEW: Combat totals per enemy team (us vs them)
-- ============================================================================
CREATE OR REPLACE VIEW enemy_team_combat AS
SELECT 
    m.enemy_team as tag,
    -- Their stats against us
    SUM(CASE WHEN md.team = 'Enemy' THEN md.kills ELSE 0 END) as their_total_kills,
    SUM(CASE WHEN md.team = 'Enemy' THEN md.deaths ELSE 0 END) as their_total_deaths,
    -- Our stats against them
    SUM(CASE WHEN md.team = 'Friendly' THEN md.kills ELSE 0 END) as our_total_kills,
    SUM(CASE WHEN md.team = 'Friendly' THEN md.deaths ELSE 0 END) as our_total_deaths,
    -- K/D ratio: our kills / our deaths
    ROUND(
        SUM(CASE WHEN md.team = 'Friendly' THEN md.kills ELSE 0 END)::NUMERIC /
        NULLIF(SUM(CASE WHEN md.team = 'Friendly' THEN md.deaths ELSE 0 END), 0),
    2) as our_kd_vs_them
FROM matches m
JOIN match_details md ON md.match_id = m.match_id
GROUP BY m.enemy_team;
