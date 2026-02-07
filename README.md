# HLL Web Tool v0.3.0

## Overview
Web-based clan management system for Hell Let Loose competitive gaming.
Built with plain HTML/CSS/JS + Supabase backend.

## Features
- **Lineups** - Real-time collaborative lineup planning with Supabase sync
- **Roster** - Full player database with stats, roles, filtering
- **Stats** - Map win rates by faction, enemy records, leaderboards
- **Matches** - Match history with detailed player stats
- **Admin** - Player import, data management 1

## File Structure
```
hll-web-v0.3.0/
├── index.html          # Landing page / dashboard
├── css/
│   └── styles.css      # Shared styles
├── js/
│   └── hll.js          # Shared JavaScript module
├── pages/
│   ├── lineup.html     # Lineup management tool
│   ├── roster.html     # Player database
│   ├── stats.html      # Team statistics
│   ├── matches.html    # Match history
│   └── admin.html      # Admin tools
└── sql/
    └── 001_schema.sql  # Supabase database schema
```

## Setup

### 1. Database Setup
1. Go to your Supabase project
2. Open SQL Editor
3. Run the contents of `sql/001_schema.sql`

### 2. Deploy to GitHub Pages
1. Create a GitHub repo
2. Push all files
3. Enable GitHub Pages in Settings > Pages
4. Access at `yourusername.github.io/repo-name`

### 3. Configuration
On first load, enter your Supabase credentials:
- Project URL: `https://xxx.supabase.co`
- Anon Key: `eyJ...`
- Default Team: Circle/DKB

Credentials are saved to localStorage.

## Real-time Sync
The lineup page uses Supabase real-time subscriptions.
Multiple users can edit lineups simultaneously and see changes instantly.

## Version History
- v0.3.0 - Full web app with multiple pages, real-time sync
- v0.2.2 - Standalone lineup tool with +/- buttons
