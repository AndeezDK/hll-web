# HLL Web Tool — Changelog

All notable changes to this project will be documented in this file.

---

## [v0.6.4] - 2026-02-08
### Fixed
- **stats.html**: Division Rankings now filtered by match_type — only shows W/L/score from matches tagged with that division, not overall record

## [v0.6.3] - 2026-02-08
### Fixed
- **PPS normalization**: PPS now divided by match duration in seconds (parsed from H:MM:SS). Scores now ~1-5 range instead of 7,000-15,000.
- **Threat/100**: Updated to `avg_pps / 5.0 * 100` (PPS 5.0 = 100 extreme, 2.5 = 50 high, 1.0 = 20 low)
- **Duplicate match**: Cleaned up MTH-000002 duplicate. Import duplicate detection TODO.
- **admin.html**: calculatePPS now accepts duration parameter and normalizes by seconds

## [v0.6.2] - 2026-02-08
### Added
- **sql/007_role_pps.sql**: Role-based PPS system
  - `match_lineups` now stores `cell_position`, `section`, `sl_role`, `note` per player per match
  - `player_role_pps` view: joins PPS with lineup data to assign role groups (Infantry, Squad Leader, Defence, Defence SL, Spotter, Sniper, Tank Crew, Commander, Artillery)
  - `role_leaderboard` view: avg/best PPS per player per role group
- **admin.html**: Import now saves cell_position, section, sl_role, and note to match_lineups. Fixed getRoleFromCellPosition to properly distinguish Defence section from Infantry.
- **stats.html**: Role Leaderboard section — select a role to see players ranked by avg PPS with all stats

## [v0.6.1] - 2026-02-08
### Added
- **sql/006_pps.sql**: Player Performance Score (PPS) system inspired by hellor.pro H-Score
  - `player_match_pps` view: calculates PPS per player per match using combat_eff, offensive_pts, defensive_pts, support_pts with K/D and KPM multipliers and support diminishing returns
  - Updated `enemy_player_stats` view: threat score now based on avg PPS (normalized to 0-100), shows avg_pps, max_pps, last_pps
- **enemies.html**: Player Intel table now shows Avg PPS and Best PPS columns. Threat summary shows team avg PPS.
- **admin.html**: MVP selection now uses PPS instead of raw Combat Efficiency. Preview shows PPS score.

## [v0.6.0] - 2026-02-08
### Added
- **stats.html**: New "Team Compare" tab with 4 sections:
  - **My Team Summary**: aggregate stats (matches, W/L, win rate, team K/D, avg kills/deaths per match, divisions)
  - **Division Rankings**: select a division to see all teams ranked by win rate, with your team highlighted
  - **Head-to-Head**: select an enemy team for side-by-side comparison (wins, kills, deaths, K/D, avg kills)
  - **Player Comparison**: top 10 players from each side ranked by avg kills per match

## [v0.5.6] - 2026-02-08
### Changed
- **lineup.html**: Auto-fill nodes now uses note-dropdown assignments — players marked "Eng" go to Eng node slots, "Supp" go to Supp node slots. Only SL, Rocket, AT, MG, Driver are skipped. Players with no note are assigned based on roster role data.

## [v0.5.5] - 2026-02-08
### Changed
- **lineup.html**: Auto-fill nodes only pulls from infantry squads (not reserves). Players with any task (SL, Rocket, AT, MG, Supp, Eng, Driver) are skipped. Players stay in their squad — nodes are additional duty. Also skips players already assigned to other node slots.

## [v0.5.4] - 2026-02-08
### Fixed
- **lineup.html**: Auto-fill nodes no longer removes players from their infantry slot — node duty is an additional task, players stay in their squad

## [v0.5.3] - 2026-02-08
### Changed
- **lineup.html**: Rewrote `autoPopulateNodes()` with proper game logic:
  - Sources from Reserves + Infantry (NW, Meat Grind, Flex, SE, Infiltration) only
  - Never pulls from Defence, Tanks, Recon, Command, or Artillery
  - Skips infantry players with special tasks (SL role, Rocket, AT, MG, or any note assignment)
  - Matches Engineers → Eng slots, Supports → Supp slots based on roster role data
  - Moves players out of their source slot (infantry/reserves) when assigned to nodes
  - Shows summary: how many filled, how many from reserves vs infantry

## [v0.5.2] - 2026-02-08
### Fixed
- **lineup.html**: Smart `autoPopulateNodes()` — prioritizes reserve players first, matches Engineers to Eng slots and Supports to Supp slots based on player role data, falls back to unassigned players. Button now visible.

## [v0.5.1] - 2026-02-08
### Added
- **matches.html**: Delete button (🗑️) on each match row — removes match, player stats, lineup data, and no-show records with confirmation prompt

## [v0.5.0] - 2026-02-08
### Changed
- **admin.html**: Match Type is now selected via popup dialog before import preview — shows all available divisions plus "Friendly" as clickable buttons

## [v0.4.9] - 2026-02-08
### Added
- **admin.html**: Match Type dropdown in import preview — tag matches as "Friendly" or any division (ECL Div. 1-6, HBL, HCA, Seasonals, etc.)
- **admin.html**: "My Team Divisions" section — tag your own team with the divisions you play in
- **matches.html**: Match Type column in match history table with color-coded badges
- **sql/005_match_type.sql**: Added `match_type` column to matches table and `my_team_divisions` table

## [v0.4.8] - 2026-02-08
### Added
- **enemies.html**: Multi-division system — teams can be tagged with multiple leagues/divisions (ECL Div. 1-6, HBL, HCA, Seasonals)
- **enemies.html**: Division picker modal with checkboxes, add new divisions, remove divisions
- **enemies.html**: Division tags shown on team cards and team detail header
- **sql/004_divisions.sql**: New `divisions` table and `enemy_team_divisions` many-to-many table with default divisions seeded

## [v0.4.7] - 2026-02-08
### Added
- **enemies.html**: Division/tier field on enemy teams — shown on team cards and detail header, click to edit
- **sql/003_enemy_intel.sql**: Added `division` column to `enemy_teams` table and `enemy_team_stats` view

## [v0.4.6] - 2026-02-08
### Added
- **enemies.html**: Player Intel table now shows Last Game (Kills, Deaths, K/D) and Average (Kills, Deaths, K/D) columns instead of just totals
- **sql/003_enemy_intel.sql**: Updated `enemy_player_stats` view with `last_kills`, `last_deaths`, `last_kd`, `avg_deaths`, `avg_kd` fields using lateral join for last game data

## [v0.4.5] - 2026-02-08
### Fixed
- **sql/003_enemy_intel.sql**: Fixed threat score bug — players with 0 kills no longer show as 100 EXTREME (now correctly score 0). Also fixed 0-deaths edge case (treats as 1 death instead of NULL)

## [v0.4.4] - 2026-02-07
### Added
- **admin.html**: Editable "My Team" field in import preview — pre-filled from config but editable per match, supports importing for multiple teams (Circle, DKB, etc.)

## [v0.4.3] - 2026-02-07
### Changed
- **admin.html**: Enemy team field in import preview is now an editable text input — auto-detected tag is pre-filled but user can correct it before confirming import

## [v0.4.2] - 2026-02-07
### Fixed
- **admin.html**: Bulk CSV player import now also uses `stripClanTag()` for consistent name cleaning across all import paths

## [v0.4.1] - 2026-02-07
### Fixed
- **admin.html**: New `stripClanTag()` function removes clan tag prefixes (◯ |, 〇 I, [TAG], TAG |) when auto-adding new friendly players to roster — keeps names clean and consistent with original roster entries

## [v0.4.0] - 2026-02-07
### Added
- **enemies.html**: New "Enemy Intel" page with team cards grid, mercenary alerts, and team detail view
- **enemies.html**: Team detail has 3 tabs — Overview (match stats, combat totals, threat summary), Player Intel (sortable table with threat scores), Match History
- **enemies.html**: Threat/100 scoring system — Extreme (75+), High (50-74), Medium (25-49), Low (<25)
- **enemies.html**: Mercenary detection — flags players seen on 2+ different enemy teams
- **admin.html**: `updateEnemyIntel()` — auto-registers enemy teams and players during import, tracks team affiliations for mercenary detection
- **sql/003_enemy_intel.sql**: New tables (enemy_teams, enemy_players, enemy_player_teams) and views (enemy_team_stats, enemy_player_stats, enemy_team_combat, mercenary_players)
- **roster.html**: Added "No-Shows" column to roster table (sortable) and No-Shows stat to player detail modal
- **all pages**: Added "Enemy Intel" nav link

## [v0.3.31] - 2026-02-07
### Removed
- **admin.html**: Removed streamer field (streamers will be imported normally, tagged manually if needed)

## [v0.3.30] - 2026-02-07
### Added
- **admin.html**: Optional "Streamers / Casters" text field on import form — comma-separated names are excluded from import entirely (no stats stored)

## [v0.3.29] - 2026-02-07
### Fixed
- **admin.html**: Name parser now strips non-breaking spaces (U+00A0) and trailing whitespace from rank/kills/deaths lines — browser paste includes invisible trailing spaces that broke `/^\d+$/` regex
- **admin.html**: Extended kills verification range from 1 to 3 lines after name to handle empty lines between name and kills count

## [v0.3.28] - 2026-02-07
### Fixed
- **admin.html**: Name extraction parser rewritten with strict rank matching — rank must be exactly `expectedRank` to prevent death/kill counts (e.g. 22, 30) from being confused with rank numbers
- **admin.html**: Added kills-line verification: after rank→name, next numeric line must exist to confirm valid player entry
- **admin.html**: Now extracts 49/49 names from Carentan test data (was 14/49 in v0.3.27)

## [v0.3.27] - 2026-02-07
### Added
- **admin.html**: "Team" tab detection — blocks import if user pastes combined view instead of Allies/Axis tab
- **admin.html**: Paste/CSV cross-check — verifies at least 5 paste names appear in CSV, warns if different games
- **admin.html**: Improved confirmation popup with date, score, duration, and fixed map detection (now searches before "Game statistics" to avoid sidebar maps)

## [v0.3.26] - 2026-02-07
### Changed
- **admin.html**: Reverted `matchPlayersToRoster()` to dual check matching VBA v5.5.23: SteamID in roster → friendly, then name in Team_Paste → friendly

## [v0.3.25] - 2026-02-07
### Added
- **admin.html**: Debug logging for unmatched paste names vs CSV names in `matchPlayersToRoster()`

## [v0.3.24] - 2026-02-07
### Fixed
- **admin.html**: `normalizeName()` now uses unicode-aware regex (`\p{L}\p{N}` with `u` flag) to preserve non-ASCII letters (ÖÖF, 𝓻𝓮𝓪𝓵, etc.)

## [v0.3.23] - 2026-02-07
### Changed
- **admin.html**: `matchPlayersToRoster()` changed to use Team_Paste names as sole source of truth for friendly/enemy detection (later reverted in v0.3.26)

## [v0.3.22] - 2026-02-07
### Fixed
- **admin.html**: `parseTeamData()` name extraction rewritten for browser paste format — multi-line parser with sequential rank tracking (replaced tab-delimited single-line logic)

## [v0.3.21] - 2026-02-07
### Added
- **admin.html**: Team_Paste validation popup with faction, player count, map detection before import
- **admin.html**: Keyword validation for helo-system.de markers ("Game statistics", "Search for a player")

## [v0.3.20] - 2026-02-07
### Fixed
- **admin.html**: Match import database schema fixes (NUMERIC overflow, MVP FK constraint removal)

## [v0.3.19] - 2026-02-06
### Changed
- **roster.html**: Replaced "Primary Role" column with two new columns:
  - **Played** — color-coded chips showing top 3 roles from match history (e.g. `42% SL | 31% INF | 15% CMD`), green ≥40%, blue ≥20%, grey below
  - **Prefers** — ranked preference tags from officer-set roles (1st choice highlighted orange)
- **roster.html**: Edit modal role dropdowns relabeled to "Prefers — 1st/2nd/3rd Choice"
- **roster.html**: Search now includes all three preferred roles
- **roster.html**: CSV export headers updated to "Prefers 1st/2nd/3rd"
### Added
- **roster.html**: Loads match_lineups data on init to calculate per-player role percentages

---

## [v0.3.18] - 2026-02-06
### Added
- **matches.html**: Summary stats bar (Matches, Wins, Losses, Win Rate, Avg Score) — updates with filters
- **matches.html**: Enemy team dropdown filter
- **matches.html**: Sortable columns (Date, Map, Enemy, Score, Result) with ascending/descending toggle
- **matches.html**: Clickable table rows open match detail modal
- **matches.html**: "Showing X of Y" match count next to filters
- **matches.html**: Delete Match button in modal footer (cascades to match_details, match_lineups, no_shows)
- **matches.html**: Support points column in modal friendly & enemy tables
- **matches.html**: Team kill/death totals in modal section headers
- **matches.html**: Role display from match_lineups table (more accurate than match_details.role)
- **matches.html**: Mobile responsive modal (single-column grid, capped width/height)
- **matches.html**: Offline state handling (shows "Database offline" instead of infinite loading)

---

## [v0.3.17] - 2026-02-06
### Added
- **roster.html**: Manual SteamID entry in player edit modal — TEMP players show an editable SteamID field (marked ⚠️ Temporary)
- Entering a real SteamID replaces the TEMP entry: creates new player with real ID, deletes temp, updates lineup references
- Validates that the new SteamID doesn't already exist in the roster

---

## [v0.3.16] - 2026-02-06
### Added
- **admin.html**: Players can now be added without a SteamID — generates a `TEMP-xxxxxxxx` placeholder
- **admin.html**: SteamID pairing during Preview Import — detects TEMP roster players matching friendly CSV players by name, shows checkboxes to approve pairing
- **admin.html**: On Confirm Import, approved pairings replace TEMP IDs with real SteamIDs in the database
- **roster.html**: ⚠️ "No SteamID" badge shown next to players with TEMP IDs

---

## [v0.3.15] - 2026-02-06
### Changed
- **lineup.html**: Node slots (Nodes North, Middle, South) no longer block players already assigned elsewhere in the lineup
- Infantry players can now be picked for node duty without being greyed out
- All other sections (Commander, Artillery, SL, Infantry, Tanks, etc.) keep the conflict check as before
- Applies to both desktop dropdown and mobile bottom sheet pickers

---

## [v0.3.14] - 2026-02-06
### Fixed
- **admin.html**: Moved `autoAddNewPlayers()` to run BEFORE match insert (was Step 6, now Step 0)
- Fixes FK constraint failure: `matches.mvp_steam_id` references `players(steam_id)` — MVP must exist in roster before match insert
- Fixes FK constraint failure: `match_lineups.steam_id` references `players(steam_id)` — lineup players must exist before lineup insert
- Fixes `update_player_stats_from_match` RPC missing new players — new players are now in roster before stats update runs

---

## [v0.3.13] - 2026-02-06
### Added
- **admin.html**: Name change tracking in `autoAddNewPlayers()` — mirrors VBA `UpdateRosterStats` L1048-1063
- When a friendly player's SteamID matches an existing roster entry but name differs, old name is appended to `previous_names` array and roster name is updated to the new name
- Duplicate old names are not re-added (normalized comparison)
- Name changes logged to console during import

---

## [v0.3.12] - 2026-02-06
### Changed
- **stats.html**: Replaced "Top Players by Role" card with per-player Role% table matching Excel Roster columns (CMD%, ART%, SL%, INF%, SNIPER%, SPOTTER%, TC%, TANK_CREW%, DEFENSE%)
- Role% calculated from `match_lineups`: count of role appearances / total unique matches per player
- Color-coded: ≥50% green, ≥25% blue, >0% default, 0% dimmed
- Sorted by total matches descending
- Removed unused role-group CSS

---

## [v0.3.11] - 2026-02-06
### Added
- **stats.html**: Role Distribution section — horizontal bar chart showing how often each role is used across all matches
- **stats.html**: Top Players by Role section — for each role, shows top 3 most frequent players
- Both sections query `match_lineups` table; gracefully show "No data" when empty

---

## [v0.3.10] - 2026-02-06
### Changed
- **admin.html**: CSV textarea replaced with file upload input (`<input type="file" accept=".csv,.txt">`)
- Match import flow is now: paste team data + upload CSV file (simpler than two textareas)

---

## [v0.3.9] - 2026-02-06
### Fixed
- **admin.html**: Friendly names extraction failed (0 names) — tab split `\t+` merged empty columns, moved name to wrong index. Fixed to single `\t` split
- **admin.html**: CSV stats (CE, Support, etc.) all zero — simple comma split broke on JSON fields (Nemesis, Victim, Weapons). Added proper `parseCSVLine()` handling quoted fields
- **admin.html**: Faction detected as Allies instead of Axis — matched plain "Allies" label before the actual faction tab "Axis (49)". Now requires parenthesis like VBA `ParseFaction`
- **admin.html**: Score parsing failed on non-breaking spaces (`\u00a0`) from helo-system format. Added normalization before regex

### Tested
- Verified against real match data: 49 friendly / 51 enemy, SMDM, 2:3, Axis, MVP: ◯ | wix (CE: 1562)

---

## [v0.3.8] - 2026-02-06
### Added
- **admin.html**: Full match import implementation (Phase 2) — ports VBA import logic to JavaScript
- `parseTeamData()` — full helo-system team page parser (map aliases, date formats, score, faction, duration, friendly names)
- `parseCSVData()` — 20-column CSV parser matching VBA `ParseRawPaste` layout
- `matchPlayersToRoster()` — friendly detection via Supabase roster SteamID + Team_Paste names
- `matchPlayersToLineup()` — role assignment from Supabase lineups table
- `detectNoShows()` — lineup vs game data comparison
- `calculateMVP()` — highest CE among friendly, excludes Artillery
- `detectEnemyTeam()` — most common [TAG] in enemy player names
- `confirmMatchImport()` — writes to matches, match_details, match_lineups, no_shows tables
- `generateMatchId()` — sequential MTH-000001 format
- `autoAddNewPlayers()` — upserts new friendly players to roster
- `normalizeName()` — strip non-alphanumeric, lowercase
- `getRoleFromCellPosition()` — maps data-cell IDs to role names
- Full preview UI with friendly/enemy split, roles, stats, no-shows, MVP highlight, validation warnings

---

## [v0.3.7] - 2026-02-06
### Changed
- **lineup.html**: Hidden Auto-fill Nodes button (`display:none`). Function `autoPopulateNodes()` left intact for future smart logic fix

---

## [v0.3.6] - 2026-02-06
### Added
- **lineup.html**: Conflict check on submit — `submitLineup()` runs `getConflicts()` first, blocks if conflicts found

### Changed
- Extracted `getConflicts()` from `checkConflicts()` for reuse

---

## [v0.3.5] - 2026-02-06
### Added
- **lineup.html**: Live auto-save — `debouncedAutoSave()` fires 1s after any `markModified()` call
- Every player assign/remove/dropdown change auto-saves to Supabase

---

## [v0.3.4] - 2026-02-06
### Fixed
- **lineup.html**: Real conflict detection — `checkConflicts()` now queries Supabase via `checkConflictsFromDatabase()` + in-memory `lineupData`
- Removed hardcoded mock conflict data
- Fixed `keepFirst()`, `removeFromCurrent()`, `moveToReserve()` to use clean names

---

## [v0.3.3] - 2026-02-06
### Fixed
- **lineup.html**: `clearLineupUI()` now clears `dataset.player` and resets infantry sections to default 6 slots

---

## [v0.3.2] - 2026-02-06
### Changed
- **lineup.html**: Auto-save to Supabase on tab switch
- Removed confirm dialog from `switchLineup()` (now `async`)

---

## [v0.3.1] - 2026-02-06
### Added
- **lineup.html**: `data-cell` IDs on all 27 static + dynamic infantry slots
- `populateUIFromLineupData()` implemented (was stub)

### Fixed
- `collectLineupSlots()` now uses clean names (`dataset.player`) instead of tagged display names
