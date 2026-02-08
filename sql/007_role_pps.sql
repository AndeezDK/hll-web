-- ============================================================================
-- Migration 007: Expand match_lineups with section/role detail for PPS
-- ============================================================================

-- Add section-level detail to match_lineups
ALTER TABLE match_lineups ADD COLUMN IF NOT EXISTS cell_position TEXT;
ALTER TABLE match_lineups ADD COLUMN IF NOT EXISTS section TEXT;
ALTER TABLE match_lineups ADD COLUMN IF NOT EXISTS sl_role TEXT;
ALTER TABLE match_lineups ADD COLUMN IF NOT EXISTS note TEXT;

-- ============================================================================
-- VIEW: Role-based PPS
-- Joins match_details with match_lineups to get per-match PPS by role group
-- ============================================================================
DROP VIEW IF EXISTS player_role_pps;
CREATE OR REPLACE VIEW player_role_pps AS
SELECT
    pps.match_id,
    pps.steam_id,
    pps.player_name,
    pps.team,
    pps.pps,
    pps.kills,
    pps.deaths,
    pps.kd,
    pps.kpm,
    pps.combat_eff,
    pps.support_pts,
    pps.defensive_pts,
    pps.offensive_pts,
    ml.role,
    ml.section,
    ml.sl_role,
    ml.note,
    -- Role group for comparison
    CASE 
        WHEN ml.sl_role IS NOT NULL AND ml.sl_role != '' AND ml.section = 'Defence' THEN 'Defence SL'
        WHEN ml.sl_role IS NOT NULL AND ml.sl_role != '' THEN 'Squad Leader'
        WHEN ml.role = 'Commander' THEN 'Commander'
        WHEN ml.role = 'Artillery' THEN 'Artillery'
        WHEN ml.role = 'Spotter' THEN 'Spotter'
        WHEN ml.role = 'Sniper' THEN 'Sniper'
        WHEN ml.role IN ('TC', 'Gunner', 'Driver') THEN 'Tank Crew'
        WHEN ml.role = 'Defence' OR ml.section = 'Defence' THEN 'Defence'
        WHEN ml.role = 'Nodes' THEN 'Nodes'
        WHEN ml.role = 'Infantry' THEN 'Infantry'
        ELSE 'Infantry'
    END as role_group,
    m.match_date
FROM player_match_pps pps
JOIN match_lineups ml ON ml.match_id = pps.match_id AND ml.steam_id = pps.steam_id
JOIN matches m ON m.match_id = pps.match_id
WHERE pps.team = 'Friendly';

-- ============================================================================
-- VIEW: Role leaderboards (avg PPS per player per role group)
-- ============================================================================
DROP VIEW IF EXISTS role_leaderboard;
CREATE OR REPLACE VIEW role_leaderboard AS
SELECT
    rp.steam_id,
    rp.player_name,
    rp.role_group,
    COUNT(*) as matches_in_role,
    ROUND(AVG(rp.pps)::NUMERIC, 0) as avg_pps,
    MAX(rp.pps) as best_pps,
    ROUND(AVG(rp.kills)::NUMERIC, 1) as avg_kills,
    ROUND(AVG(rp.deaths)::NUMERIC, 1) as avg_deaths,
    ROUND(AVG(rp.kd)::NUMERIC, 2) as avg_kd,
    ROUND(AVG(rp.combat_eff)::NUMERIC, 0) as avg_ce,
    ROUND(AVG(rp.defensive_pts)::NUMERIC, 0) as avg_def,
    ROUND(AVG(rp.offensive_pts)::NUMERIC, 0) as avg_off,
    ROUND(AVG(rp.support_pts)::NUMERIC, 0) as avg_sup
FROM player_role_pps rp
GROUP BY rp.steam_id, rp.player_name, rp.role_group;
