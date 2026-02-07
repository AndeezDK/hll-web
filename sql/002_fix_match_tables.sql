-- ============================================================================
-- HLL Web Tool v0.3.20 — Migration: Fix match tables
-- Run this in Supabase SQL Editor
-- 
-- SAFE: These 4 tables are EMPTY (no data loss). Players/lineups/teams untouched.
-- ============================================================================

-- Drop in correct order (match_details/match_lineups/no_shows depend on matches)
DROP TABLE IF EXISTS match_details CASCADE;
DROP TABLE IF EXISTS match_lineups CASCADE;
DROP TABLE IF EXISTS no_shows CASCADE;
DROP TABLE IF EXISTS matches CASCADE;

-- Drop views that reference these tables
DROP VIEW IF EXISTS team_stats_by_map;
DROP VIEW IF EXISTS team_stats_by_enemy;

-- ============================================================================
-- MATCHES (Match_Log equivalent)
-- Fix: mvp_steam_id has NO FK constraint (MVP may not be in roster yet)
-- ============================================================================
CREATE TABLE matches (
    match_id TEXT PRIMARY KEY,
    match_date DATE NOT NULL,
    
    my_team TEXT NOT NULL,
    enemy_team TEXT NOT NULL,
    
    my_faction TEXT NOT NULL CHECK (my_faction IN ('Allies', 'Axis')),
    enemy_faction TEXT NOT NULL CHECK (enemy_faction IN ('Allies', 'Axis')),
    
    map TEXT NOT NULL,
    result TEXT CHECK (result IN ('W', 'L', 'D')),
    
    my_score INTEGER,
    enemy_score INTEGER,
    duration TEXT,
    
    mvp_steam_id TEXT,  -- No FK: MVP may not exist in roster yet during import
    mvp_name TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_matches_date ON matches(match_date DESC);
CREATE INDEX idx_matches_map ON matches(map);

-- ============================================================================
-- MATCH_DETAILS (per-player per-match stats)
-- Fix: kd, kpm, dpm widened to NUMERIC(8,2); longest_life_min to NUMERIC(8,1)
-- ============================================================================
CREATE TABLE match_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id TEXT NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
    steam_id TEXT NOT NULL,
    player_name TEXT NOT NULL,
    
    faction TEXT CHECK (faction IN ('Allies', 'Axis')),
    team TEXT CHECK (team IN ('Friendly', 'Enemy')),
    role TEXT,
    
    kills INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    kd NUMERIC(8,2),
    max_kill_streak INTEGER DEFAULT 0,
    kpm NUMERIC(8,2),
    dpm NUMERIC(8,2),
    max_death_streak INTEGER DEFAULT 0,
    max_tk_streak INTEGER DEFAULT 0,
    death_by_tk INTEGER DEFAULT 0,
    
    longest_life_min NUMERIC(8,1),
    shortest_life_sec INTEGER,
    
    combat_eff INTEGER DEFAULT 0,
    support_pts INTEGER DEFAULT 0,
    defensive_pts INTEGER DEFAULT 0,
    offensive_pts INTEGER DEFAULT 0,
    
    level INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(match_id, steam_id)
);

CREATE INDEX idx_match_details_match ON match_details(match_id);
CREATE INDEX idx_match_details_player ON match_details(steam_id);

-- ============================================================================
-- MATCH_LINEUPS (role assignments per match)
-- ============================================================================
CREATE TABLE match_lineups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id TEXT NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    player_name TEXT NOT NULL,
    steam_id TEXT REFERENCES players(steam_id),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_match_lineups_match ON match_lineups(match_id);

-- ============================================================================
-- NO_SHOWS
-- ============================================================================
CREATE TABLE no_shows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id TEXT NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
    steam_id TEXT NOT NULL REFERENCES players(steam_id),
    player_name TEXT NOT NULL,
    match_date DATE NOT NULL,
    excused BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(match_id, steam_id)
);

CREATE INDEX idx_no_shows_player ON no_shows(steam_id);

-- ============================================================================
-- RE-CREATE VIEWS
-- ============================================================================
CREATE OR REPLACE VIEW team_stats_by_map AS
SELECT 
    map,
    my_faction as faction,
    COUNT(*) as matches,
    COUNT(*) FILTER (WHERE result = 'W') as wins,
    COUNT(*) FILTER (WHERE result = 'L') as losses,
    COUNT(*) FILTER (WHERE result = 'D') as draws,
    ROUND(COUNT(*) FILTER (WHERE result = 'W')::NUMERIC / NULLIF(COUNT(*), 0) * 100, 0) as win_rate,
    SUM(my_score) as points_for,
    SUM(enemy_score) as points_against
FROM matches
GROUP BY map, my_faction
ORDER BY map, faction;

CREATE OR REPLACE VIEW team_stats_by_enemy AS
SELECT 
    enemy_team,
    COUNT(*) as matches,
    COUNT(*) FILTER (WHERE result = 'W') as wins,
    COUNT(*) FILTER (WHERE result = 'L') as losses,
    COUNT(*) FILTER (WHERE result = 'D') as draws,
    ROUND(COUNT(*) FILTER (WHERE result = 'W')::NUMERIC / NULLIF(COUNT(*), 0) * 100, 0) as win_rate,
    SUM(my_score) as points_for,
    SUM(enemy_score) as points_against
FROM matches
GROUP BY enemy_team
ORDER BY matches DESC;

-- ============================================================================
-- RE-ENABLE RLS + POLICIES
-- ============================================================================
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_lineups ENABLE ROW LEVEL SECURITY;
ALTER TABLE no_shows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all" ON matches FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON match_details FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON match_lineups FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON no_shows FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- RE-CREATE FUNCTION (in case it references old column types)
-- ============================================================================
CREATE OR REPLACE FUNCTION update_player_stats_from_match(p_match_id TEXT)
RETURNS void AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT 
            md.steam_id,
            md.kills,
            md.deaths,
            md.combat_eff,
            md.support_pts,
            m.match_date,
            m.mvp_steam_id
        FROM match_details md
        JOIN matches m ON m.match_id = md.match_id
        WHERE md.match_id = p_match_id
        AND md.team = 'Friendly'
    LOOP
        UPDATE players SET
            total_matches = total_matches + 1,
            total_kills = total_kills + r.kills,
            total_deaths = total_deaths + r.deaths,
            most_kills = GREATEST(most_kills, r.kills),
            avg_kills = ROUND((total_kills + r.kills)::NUMERIC / (total_matches + 1), 1),
            total_support = total_support + r.support_pts,
            avg_support = ROUND((total_support + r.support_pts)::NUMERIC / (total_matches + 1), 0),
            avg_ce = ROUND((avg_ce * total_matches + r.combat_eff)::NUMERIC / (total_matches + 1), 0),
            last_seen = r.match_date,
            first_seen = COALESCE(first_seen, r.match_date),
            mvp_count = CASE WHEN r.mvp_steam_id = steam_id THEN mvp_count + 1 ELSE mvp_count END,
            last_mvp = CASE WHEN r.mvp_steam_id = steam_id THEN r.match_date ELSE last_mvp END,
            updated_at = NOW()
        WHERE steam_id = r.steam_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
