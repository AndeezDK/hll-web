-- ============================================================================
-- HLL Web Tool v0.3.0 - Database Schema
-- Run this in Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- TEAMS TABLE (already exists, but ensure structure)
-- ============================================================================
CREATE TABLE IF NOT EXISTS teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    tag TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default teams if not exist
INSERT INTO teams (name, tag) VALUES 
    ('Circle', '◯ |'),
    ('DKB', '[DKB]'),
    ('Merc', NULL)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- PLAYERS TABLE (expanded from current)
-- ============================================================================
DROP TABLE IF EXISTS players CASCADE;

CREATE TABLE players (
    steam_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    team TEXT DEFAULT 'Merc',
    
    -- Roles
    primary_role TEXT,
    secondary_role TEXT,
    tertiary_role TEXT,
    
    -- Activity tracking
    first_seen DATE,
    last_seen DATE,
    total_matches INTEGER DEFAULT 0,
    no_shows INTEGER DEFAULT 0,
    
    -- Combat stats
    total_kills INTEGER DEFAULT 0,
    total_deaths INTEGER DEFAULT 0,
    most_kills INTEGER DEFAULT 0,
    avg_kills NUMERIC(5,1) DEFAULT 0,
    avg_ce INTEGER DEFAULT 0,
    
    -- Support stats
    total_support INTEGER DEFAULT 0,
    avg_support INTEGER DEFAULT 0,
    
    -- MVP tracking
    mvp_count INTEGER DEFAULT 0,
    last_mvp DATE,
    
    -- Meta
    notes TEXT,
    previous_names TEXT[],
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX idx_players_team ON players(team);
CREATE INDEX idx_players_name ON players(name);

-- ============================================================================
-- MATCHES TABLE (Match_Log equivalent)
-- ============================================================================
CREATE TABLE matches (
    match_id TEXT PRIMARY KEY,  -- Format: MTH-XXXXXX
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
    
    mvp_steam_id TEXT REFERENCES players(steam_id),
    mvp_name TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_matches_date ON matches(match_date DESC);
CREATE INDEX idx_matches_map ON matches(map);

-- ============================================================================
-- MATCH_DETAILS TABLE (per-player per-match stats)
-- ============================================================================
CREATE TABLE match_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id TEXT NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
    steam_id TEXT NOT NULL,
    player_name TEXT NOT NULL,
    
    faction TEXT CHECK (faction IN ('Allies', 'Axis')),
    team TEXT CHECK (team IN ('Friendly', 'Enemy')),
    role TEXT,
    
    -- Combat stats
    kills INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    kd NUMERIC(4,2),
    max_kill_streak INTEGER DEFAULT 0,
    kpm NUMERIC(4,2),
    dpm NUMERIC(4,2),
    max_death_streak INTEGER DEFAULT 0,
    max_tk_streak INTEGER DEFAULT 0,
    death_by_tk INTEGER DEFAULT 0,
    
    -- Time stats
    longest_life_min NUMERIC(5,1),
    shortest_life_sec INTEGER,
    
    -- Points
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
-- MATCH_LINEUPS TABLE (role assignments per match)
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
-- NO_SHOWS TABLE
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
-- LINEUPS TABLE (live lineup planning - expanded from current)
-- ============================================================================
DROP TABLE IF EXISTS lineups CASCADE;

CREATE TABLE lineups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID REFERENCES teams(id),
    lineup_number INTEGER NOT NULL CHECK (lineup_number BETWEEN 1 AND 4),
    
    -- Match info
    enemy_team TEXT,
    map TEXT,
    faction TEXT CHECK (faction IN ('Allies', 'Axis')),
    match_date DATE,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'locked', 'submitted')),
    
    -- Slot data
    cell_position TEXT NOT NULL,  -- e.g., 'commander', 'tank1_tc', 'north_1'
    steam_id TEXT REFERENCES players(steam_id),
    player_name TEXT,
    role TEXT,
    sl_role TEXT,
    note TEXT,
    is_here BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(team_id, lineup_number, cell_position)
);

CREATE INDEX idx_lineups_team ON lineups(team_id, lineup_number);

-- ============================================================================
-- TEAM_STATS VIEW (calculated from matches)
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
-- PLAYER STATS VIEW (calculated role percentages)
-- ============================================================================
CREATE OR REPLACE VIEW player_stats AS
SELECT 
    p.steam_id,
    p.name,
    p.team,
    p.total_matches,
    p.no_shows,
    CASE WHEN (p.total_matches + p.no_shows) > 0 
        THEN ROUND(p.total_matches::NUMERIC / (p.total_matches + p.no_shows) * 100, 0)
        ELSE NULL 
    END as attendance_pct,
    p.total_kills,
    p.total_deaths,
    CASE WHEN p.total_deaths > 0 
        THEN ROUND(p.total_kills::NUMERIC / p.total_deaths, 2)
        ELSE NULL 
    END as kd_ratio,
    p.avg_kills,
    p.most_kills,
    p.avg_ce,
    p.avg_support,
    p.mvp_count,
    p.first_seen,
    p.last_seen
FROM players p;

-- ============================================================================
-- ENABLE REALTIME for lineups table
-- ============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE lineups;

-- ============================================================================
-- ROW LEVEL SECURITY (basic - allow all for now)
-- ============================================================================
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_lineups ENABLE ROW LEVEL SECURITY;
ALTER TABLE no_shows ENABLE ROW LEVEL SECURITY;
ALTER TABLE lineups ENABLE ROW LEVEL SECURITY;

-- Allow anonymous read/write for now (tighten later with auth)
CREATE POLICY "Allow all" ON players FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON matches FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON match_details FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON match_lineups FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON no_shows FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON lineups FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- FUNCTION: Generate Match ID
-- ============================================================================
CREATE OR REPLACE FUNCTION generate_match_id()
RETURNS TEXT AS $$
BEGIN
    RETURN 'MTH-' || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCTION: Update player stats after match import
-- ============================================================================
CREATE OR REPLACE FUNCTION update_player_stats_from_match(p_match_id TEXT)
RETURNS void AS $$
DECLARE
    r RECORD;
BEGIN
    -- Update stats for each friendly player in the match
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
