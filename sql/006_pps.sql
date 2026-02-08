-- ============================================================================
-- Migration 006: Player Performance Score (PPS)
-- Inspired by hellor.pro H-Score, adapted for helo-system.de data
-- PPS is normalized by match duration in seconds
-- ============================================================================

DROP VIEW IF EXISTS role_leaderboard;
DROP VIEW IF EXISTS player_role_pps;
DROP VIEW IF EXISTS enemy_player_stats;
DROP VIEW IF EXISTS player_match_pps;

CREATE OR REPLACE VIEW player_match_pps AS
SELECT
    md.match_id,
    md.steam_id,
    md.player_name,
    md.team,
    md.kills,
    md.deaths,
    md.kd,
    md.kpm,
    md.combat_eff,
    md.support_pts,
    md.defensive_pts,
    md.offensive_pts,
    LEAST(2.5, GREATEST(0.3, COALESCE(md.kd, 0) / 1.5)) as kd_factor,
    LEAST(2.5, GREATEST(0.3, COALESCE(md.kpm, 0) / 0.8)) as kpm_factor,
    1.0 / (1.0 + COALESCE(md.support_pts, 0)::NUMERIC / 5000) as support_factor,
    GREATEST(1, 
        COALESCE(
            SPLIT_PART(m.duration, ':', 1)::INT * 3600 +
            SPLIT_PART(m.duration, ':', 2)::INT * 60 +
            SPLIT_PART(m.duration, ':', 3)::INT,
        5400)
    ) as duration_secs,
    ROUND((
        (COALESCE(md.combat_eff, 0) * 4.0 * LEAST(2.5, GREATEST(0.3, COALESCE(md.kd, 0) / 1.5)) * LEAST(2.5, GREATEST(0.3, COALESCE(md.kpm, 0) / 0.8))) +
        (COALESCE(md.offensive_pts, 0) * 0.9 * LEAST(2.5, GREATEST(0.3, COALESCE(md.kd, 0) / 1.5)) * LEAST(2.5, GREATEST(0.3, COALESCE(md.kpm, 0) / 0.8))) +
        (COALESCE(md.defensive_pts, 0) * 1.1 * LEAST(2.5, GREATEST(0.3, COALESCE(md.kd, 0) / 1.5)) * LEAST(2.5, GREATEST(0.3, COALESCE(md.kpm, 0) / 0.8))) +
        (COALESCE(md.support_pts, 0) * 2.0 * (1.0 / (1.0 + COALESCE(md.support_pts, 0)::NUMERIC / 5000)))
    )::NUMERIC / GREATEST(1,
        COALESCE(
            SPLIT_PART(m.duration, ':', 1)::INT * 3600 +
            SPLIT_PART(m.duration, ':', 2)::INT * 60 +
            SPLIT_PART(m.duration, ':', 3)::INT,
        5400)
    ), 2) as pps
FROM match_details md
JOIN matches m ON m.match_id = md.match_id;

-- Threat/100 = avg_pps / 5.0 * 100 (PPS 5.0 = extreme, 2.5 = high, 1.0 = low)
CREATE OR REPLACE VIEW enemy_player_stats AS
SELECT 
    ep.steam_id, ep.name, ep.primary_team_tag, ep.notes,
    COUNT(md.id) as total_matches,
    SUM(md.kills) as total_kills, SUM(md.deaths) as total_deaths,
    ROUND(SUM(md.kills)::NUMERIC / NULLIF(SUM(md.deaths), 0), 2) as kd_ratio,
    ROUND(SUM(md.kills)::NUMERIC / NULLIF(COUNT(md.id), 0), 1) as avg_kills,
    ROUND(SUM(md.deaths)::NUMERIC / NULLIF(COUNT(md.id), 0), 1) as avg_deaths,
    ROUND((SUM(md.kills)::NUMERIC / NULLIF(COUNT(md.id), 0)) / NULLIF(SUM(md.deaths)::NUMERIC / NULLIF(COUNT(md.id), 0), 0), 2) as avg_kd,
    MAX(md.kills) as most_kills,
    ROUND(SUM(md.combat_eff)::NUMERIC / NULLIF(COUNT(md.id), 0), 0) as avg_ce,
    CASE WHEN COALESCE(SUM(md.kills), 0) = 0 THEN 0
    ELSE LEAST(100, ROUND(COALESCE(pps_agg.avg_pps, 0) / 5.0 * 100, 0)) END as threat_score,
    COALESCE(pps_agg.avg_pps, 0) as avg_pps,
    COALESCE(pps_agg.max_pps, 0) as max_pps,
    last_game.last_kills, last_game.last_deaths, last_game.last_kd, last_game.last_pps,
    MAX(m.match_date) as last_seen, MIN(m.match_date) as first_seen,
    (SELECT COUNT(*) FROM enemy_player_teams ept WHERE ept.steam_id = ep.steam_id) as teams_played_for
FROM enemy_players ep
LEFT JOIN match_details md ON md.steam_id = ep.steam_id AND md.team = 'Enemy'
LEFT JOIN matches m ON m.match_id = md.match_id
LEFT JOIN LATERAL (
    SELECT ROUND(AVG(pps)::NUMERIC, 2) as avg_pps, MAX(pps) as max_pps
    FROM player_match_pps pmp WHERE pmp.steam_id = ep.steam_id AND pmp.team = 'Enemy'
) pps_agg ON true
LEFT JOIN LATERAL (
    SELECT lg_md.kills as last_kills, lg_md.deaths as last_deaths,
        ROUND(lg_md.kills::NUMERIC / NULLIF(lg_md.deaths, 0), 2) as last_kd,
        COALESCE(lg_pps.pps, 0) as last_pps
    FROM match_details lg_md
    JOIN matches lg_m ON lg_m.match_id = lg_md.match_id
    LEFT JOIN player_match_pps lg_pps ON lg_pps.match_id = lg_md.match_id AND lg_pps.steam_id = lg_md.steam_id
    WHERE lg_md.steam_id = ep.steam_id AND lg_md.team = 'Enemy'
    ORDER BY lg_m.match_date DESC LIMIT 1
) last_game ON true
GROUP BY ep.steam_id, ep.name, ep.primary_team_tag, ep.notes, 
         last_game.last_kills, last_game.last_deaths, last_game.last_kd, last_game.last_pps,
         pps_agg.avg_pps, pps_agg.max_pps;
