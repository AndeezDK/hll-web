// ============================================================================
// HLL Web Tool v0.3.24 - Shared JavaScript Module
// ============================================================================

// ============================================================================
// CONFIGURATION
// ============================================================================

const HLL = {
    version: '0.3.24',
    
    // Default Supabase config (can be overridden via localStorage)
    config: {
        supabaseUrl: 'https://mtcfoncuegnokymtebpg.supabase.co',
        supabaseKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im10Y2ZvbmN1ZWdub2t5bXRlYnBnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5NjAzODAsImV4cCI6MjA4NTUzNjM4MH0.-i2hVz1jDGSrm0pOsUrKUfdsip1gg8wpcOx7k75j8pc',
        defaultTeam: 'Circle'
    },
    
    // State
    supabase: null,
    isOnline: false,
    currentTeam: null,
    players: [],
    
    // Maps list
    maps: [
        'Carentan', 'SME', 'SMDM', 'Purple Heart Lane', 'Hill 400', 
        'Hurtgen Forest', 'Foy', 'Kursk', 'Stalingrad', 'Remagen', 
        'Kharkov', 'Driel', 'El Alamein', 'Omaha Beach', 'Utah Beach', 'Mortain'
    ],
    
    // Roles list
    roles: [
        'Commander', 'Artillery (TC)', 'TC (SL)', 'Tank Gunner', 'Tank Driver',
        'Recon Spotter', 'Recon Sniper', 'Infantry', 'SL-1', 'SL-2', 'SL-3',
        'Rocket Snipe', 'Driver', 'AT', 'MG', 'Engineer', 'Supp'
    ],
    
    // Teams
    teams: ['Circle', 'DKB', 'Merc']
};

// ============================================================================
// INITIALIZATION
// ============================================================================

HLL.init = async function() {
    console.log(`HLL Web Tool v${this.version} initializing...`);
    
    // Load config from localStorage
    this.loadConfig();
    
    // Initialize Supabase
    await this.initSupabase();
    
    // Update nav status
    this.updateNavStatus();
    
    return this.isOnline;
};

HLL.loadConfig = function() {
    const savedUrl = localStorage.getItem('hll_supabase_url');
    const savedKey = localStorage.getItem('hll_supabase_key');
    const savedTeam = localStorage.getItem('hll_default_team');
    
    if (savedUrl) this.config.supabaseUrl = savedUrl;
    if (savedKey) this.config.supabaseKey = savedKey;
    if (savedTeam) this.config.defaultTeam = savedTeam;
    
    this.currentTeam = this.config.defaultTeam;
};

HLL.saveConfig = function(url, key, team) {
    localStorage.setItem('hll_supabase_url', url);
    localStorage.setItem('hll_supabase_key', key);
    localStorage.setItem('hll_default_team', team);
    
    this.config.supabaseUrl = url;
    this.config.supabaseKey = key;
    this.config.defaultTeam = team;
    this.currentTeam = team;
};

// ============================================================================
// SUPABASE CONNECTION
// ============================================================================

HLL.initSupabase = async function() {
    try {
        this.supabase = window.supabase.createClient(
            this.config.supabaseUrl, 
            this.config.supabaseKey
        );
        
        // Test connection
        const { data, error } = await this.supabase
            .from('teams')
            .select('id, name')
            .limit(1);
        
        if (error) throw error;
        
        this.isOnline = true;
        console.log('Supabase connected');
        
        return true;
    } catch (err) {
        console.error('Supabase connection failed:', err);
        this.isOnline = false;
        return false;
    }
};

HLL.updateNavStatus = function() {
    const statusDot = document.querySelector('.status-dot');
    const statusText = document.querySelector('.nav-status span:last-child');
    
    if (!statusDot) return;
    
    statusDot.classList.remove('connected', 'connecting', 'error');
    
    if (this.isOnline) {
        statusDot.classList.add('connected');
        if (statusText) statusText.textContent = 'Connected';
    } else {
        statusDot.classList.add('error');
        if (statusText) statusText.textContent = 'Offline';
    }
};

// ============================================================================
// REALTIME SUBSCRIPTIONS
// ============================================================================

HLL.subscribeToLineups = function(teamId, callback) {
    if (!this.supabase || !this.isOnline) return null;
    
    const channel = this.supabase
        .channel('lineups-changes')
        .on('postgres_changes', 
            { 
                event: '*', 
                schema: 'public', 
                table: 'lineups',
                filter: teamId ? `team_id=eq.${teamId}` : undefined
            }, 
            (payload) => {
                console.log('Lineup change:', payload);
                if (callback) callback(payload);
            }
        )
        .subscribe();
    
    return channel;
};

HLL.unsubscribe = function(channel) {
    if (channel) {
        this.supabase.removeChannel(channel);
    }
};

// ============================================================================
// PLAYER OPERATIONS
// ============================================================================

HLL.loadPlayers = async function(teamFilter = null) {
    if (!this.supabase || !this.isOnline) {
        return [];
    }
    
    try {
        let query = this.supabase
            .from('players')
            .select('*')
            .order('name');
        
        if (teamFilter) {
            query = query.eq('team', teamFilter);
        }
        
        const { data, error } = await query;
        
        if (error) throw error;
        
        this.players = data || [];
        console.log(`Loaded ${this.players.length} players`);
        
        return this.players;
    } catch (err) {
        console.error('Error loading players:', err);
        return [];
    }
};

HLL.getPlayer = async function(steamId) {
    if (!this.supabase || !this.isOnline) return null;
    
    const { data, error } = await this.supabase
        .from('players')
        .select('*')
        .eq('steam_id', steamId)
        .single();
    
    if (error) {
        console.error('Error getting player:', error);
        return null;
    }
    
    return data;
};

HLL.updatePlayer = async function(steamId, updates) {
    if (!this.supabase || !this.isOnline) return false;
    
    const { error } = await this.supabase
        .from('players')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('steam_id', steamId);
    
    if (error) {
        console.error('Error updating player:', error);
        return false;
    }
    
    return true;
};

HLL.createPlayer = async function(player) {
    if (!this.supabase || !this.isOnline) return false;
    
    const { error } = await this.supabase
        .from('players')
        .insert(player);
    
    if (error) {
        console.error('Error creating player:', error);
        return false;
    }
    
    return true;
};

// ============================================================================
// MATCH OPERATIONS
// ============================================================================

HLL.loadMatches = async function(limit = 50) {
    if (!this.supabase || !this.isOnline) return [];
    
    const { data, error } = await this.supabase
        .from('matches')
        .select('*')
        .order('match_date', { ascending: false })
        .limit(limit);
    
    if (error) {
        console.error('Error loading matches:', error);
        return [];
    }
    
    return data || [];
};

HLL.getMatch = async function(matchId) {
    if (!this.supabase || !this.isOnline) return null;
    
    const { data, error } = await this.supabase
        .from('matches')
        .select(`
            *,
            match_details (*),
            match_lineups (*)
        `)
        .eq('match_id', matchId)
        .single();
    
    if (error) {
        console.error('Error getting match:', error);
        return null;
    }
    
    return data;
};

// ============================================================================
// STATS OPERATIONS
// ============================================================================

HLL.getMapStats = async function() {
    if (!this.supabase || !this.isOnline) return [];
    
    const { data, error } = await this.supabase
        .from('team_stats_by_map')
        .select('*');
    
    if (error) {
        console.error('Error loading map stats:', error);
        return [];
    }
    
    return data || [];
};

HLL.getEnemyStats = async function() {
    if (!this.supabase || !this.isOnline) return [];
    
    const { data, error } = await this.supabase
        .from('team_stats_by_enemy')
        .select('*');
    
    if (error) {
        console.error('Error loading enemy stats:', error);
        return [];
    }
    
    return data || [];
};

HLL.getPlayerStats = async function() {
    if (!this.supabase || !this.isOnline) return [];
    
    const { data, error } = await this.supabase
        .from('player_stats')
        .select('*')
        .order('total_matches', { ascending: false });
    
    if (error) {
        console.error('Error loading player stats:', error);
        return [];
    }
    
    return data || [];
};

// ============================================================================
// LINEUP OPERATIONS
// ============================================================================

HLL.loadLineup = async function(teamId, lineupNumber) {
    if (!this.supabase || !this.isOnline) return [];
    
    const { data, error } = await this.supabase
        .from('lineups')
        .select('*')
        .eq('team_id', teamId)
        .eq('lineup_number', lineupNumber);
    
    if (error) {
        console.error('Error loading lineup:', error);
        return [];
    }
    
    return data || [];
};

HLL.saveLineupSlot = async function(teamId, lineupNumber, cellPosition, slotData) {
    if (!this.supabase || !this.isOnline) return false;
    
    const record = {
        team_id: teamId,
        lineup_number: lineupNumber,
        cell_position: cellPosition,
        ...slotData,
        updated_at: new Date().toISOString()
    };
    
    const { error } = await this.supabase
        .from('lineups')
        .upsert(record, { 
            onConflict: 'team_id,lineup_number,cell_position' 
        });
    
    if (error) {
        console.error('Error saving lineup slot:', error);
        return false;
    }
    
    return true;
};

HLL.clearLineup = async function(teamId, lineupNumber) {
    if (!this.supabase || !this.isOnline) return false;
    
    const { error } = await this.supabase
        .from('lineups')
        .delete()
        .eq('team_id', teamId)
        .eq('lineup_number', lineupNumber);
    
    if (error) {
        console.error('Error clearing lineup:', error);
        return false;
    }
    
    return true;
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

HLL.formatPlayerName = function(name, team) {
    if (team === 'Circle') return '◯ | ' + name;
    if (team === 'DKB') return '[DKB] ' + name;
    return name;
};

HLL.stripPlayerTag = function(displayName) {
    if (displayName.startsWith('◯ | ')) return displayName.substring(4);
    if (displayName.startsWith('[DKB] ')) return displayName.substring(6);
    return displayName;
};

HLL.getTeamBadgeClass = function(team) {
    if (team === 'Circle') return 'badge-team-circle';
    if (team === 'DKB') return 'badge-team-dkb';
    return 'badge-team-merc';
};

HLL.getResultBadgeClass = function(result) {
    if (result === 'W') return 'badge-win';
    if (result === 'L') return 'badge-loss';
    return 'badge-draw';
};

HLL.formatDate = function(dateStr) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-GB', { 
        day: '2-digit', 
        month: 'short', 
        year: '2-digit' 
    });
};

HLL.formatNumber = function(num, decimals = 0) {
    if (num === null || num === undefined) return '-';
    return Number(num).toFixed(decimals);
};

HLL.getTrendArrow = function(current, average, threshold = 0.1) {
    if (!current || !average) return '';
    const ratio = current / average;
    if (ratio > 1 + threshold) return '↑';
    if (ratio < 1 - threshold) return '↓';
    return '→';
};

HLL.getTrendClass = function(current, average, threshold = 0.1) {
    if (!current || !average) return '';
    const ratio = current / average;
    if (ratio > 1 + threshold) return 'trend-up';
    if (ratio < 1 - threshold) return 'trend-down';
    return 'trend-stable';
};

// ============================================================================
// UI HELPERS
// ============================================================================

HLL.showLoading = function(text = 'Loading...') {
    let overlay = document.getElementById('loadingOverlay');
    if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'loadingOverlay';
        overlay.className = 'loading-overlay';
        overlay.innerHTML = `
            <div class="loading-spinner"></div>
            <div class="loading-text">${text}</div>
        `;
        document.body.appendChild(overlay);
    } else {
        overlay.querySelector('.loading-text').textContent = text;
        overlay.classList.remove('hidden');
    }
};

HLL.hideLoading = function() {
    const overlay = document.getElementById('loadingOverlay');
    if (overlay) overlay.classList.add('hidden');
};

HLL.showAlert = function(message, type = 'info', duration = 3000) {
    const alert = document.createElement('div');
    alert.className = `alert alert-${type}`;
    alert.textContent = message;
    alert.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        z-index: 4000;
        min-width: 250px;
        animation: slideIn 0.3s ease;
    `;
    
    document.body.appendChild(alert);
    
    setTimeout(() => {
        alert.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => alert.remove(), 300);
    }, duration);
};

HLL.confirm = function(message) {
    return window.confirm(message);
};

// ============================================================================
// TABLE SORTING
// ============================================================================

HLL.initSortableTable = function(tableId, data, renderRow) {
    const table = document.getElementById(tableId);
    if (!table) return;
    
    const headers = table.querySelectorAll('th.sortable');
    let currentSort = { column: null, direction: 'asc' };
    
    headers.forEach(header => {
        header.addEventListener('click', () => {
            const column = header.dataset.column;
            
            // Toggle direction if same column
            if (currentSort.column === column) {
                currentSort.direction = currentSort.direction === 'asc' ? 'desc' : 'asc';
            } else {
                currentSort.column = column;
                currentSort.direction = 'asc';
            }
            
            // Update header classes
            headers.forEach(h => h.classList.remove('sorted-asc', 'sorted-desc'));
            header.classList.add(`sorted-${currentSort.direction}`);
            
            // Sort data
            const sorted = [...data].sort((a, b) => {
                let aVal = a[column];
                let bVal = b[column];
                
                // Handle nulls
                if (aVal === null || aVal === undefined) return 1;
                if (bVal === null || bVal === undefined) return -1;
                
                // Handle numbers
                if (typeof aVal === 'number' && typeof bVal === 'number') {
                    return currentSort.direction === 'asc' ? aVal - bVal : bVal - aVal;
                }
                
                // Handle strings
                aVal = String(aVal).toLowerCase();
                bVal = String(bVal).toLowerCase();
                
                if (currentSort.direction === 'asc') {
                    return aVal.localeCompare(bVal);
                } else {
                    return bVal.localeCompare(aVal);
                }
            });
            
            // Re-render
            const tbody = table.querySelector('tbody');
            tbody.innerHTML = sorted.map(renderRow).join('');
        });
    });
};

// ============================================================================
// EXPORT
// ============================================================================

// Make HLL globally available
window.HLL = HLL;
