# HLL Web Tool — Changelog

All notable changes to this project will be documented in this file.

---

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
