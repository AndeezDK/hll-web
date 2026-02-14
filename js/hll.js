// ============================================================================
// HLL Web Tool - Shared JavaScript Module
// ============================================================================

// ============================================================================
// CONFIGURATION
// ============================================================================

const HLL = {
    version: '0.7.1',
    
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
    currentUser: null,
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
    
    // Auto-populate version badges only if not already set by the page
    document.querySelectorAll('.version-badge').forEach(el => {
        if (!el.textContent.trim()) el.textContent = 'v' + this.version;
    });
    
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
    const clean = HLL.stripPlayerTag(name);
    if (team === 'Circle') return '◯ | ' + clean;
    if (team === 'DKB') return '[DKB] ' + clean;
    return clean;
};

HLL.stripPlayerTag = function(displayName) {
    if (!displayName) return displayName;
    // Loop to strip nested/multiple tags: ◯ | , ◯ I , 〇 I , 〇 | , Ⓡ | , Ⓡ I , [DKB] , [CRC]
    let name = displayName;
    let prev;
    do {
        prev = name;
        name = name.replace(/^[\u25CB\u3007]\s*[|I]\s*/i, '')  // ◯ | or ◯ I or 〇 | or 〇 I
                   .replace(/^\u24C7\s*[|I]\s*/i, '')           // Ⓡ | or Ⓡ I
                   .replace(/^\[[A-Za-z0-9]+\]\s*/i, '')        // [DKB], [CRC], etc.
                   .trim();
    } while (name !== prev);
    return name;
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
// AUTHENTICATION
// ============================================================================

HLL._authWallMode = 'login';

HLL.injectAuthWall = function() {
    // Inject CSS
    const style = document.createElement('style');
    style.textContent = `
        .auth-wall {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: #0d1117;
            z-index: 4000;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        .auth-wall.hidden { display: none; }
        .auth-wall-box {
            background: #1c2128;
            border: 1px solid #30363d;
            border-radius: 12px;
            padding: 32px;
            width: 360px;
            max-width: 90vw;
            text-align: center;
        }
        .auth-wall-logo {
            font-size: 28px;
            font-weight: 700;
            color: #f5a623;
            margin-bottom: 4px;
        }
        .auth-wall-subtitle {
            color: #8b949e;
            font-size: 12px;
            margin-bottom: 24px;
        }
        .auth-wall-box label {
            display: block;
            color: #8b949e;
            font-size: 11px;
            margin-bottom: 4px;
            font-weight: 600;
            text-align: left;
        }
        .auth-wall-box input {
            width: 100%;
            padding: 10px 12px;
            background: #0d1117;
            border: 1px solid #30363d;
            border-radius: 6px;
            color: #e7e9ea;
            font-size: 14px;
            margin-bottom: 14px;
            box-sizing: border-box;
            font-family: inherit;
        }
        .auth-wall-box input:focus {
            outline: none;
            border-color: #f5a623;
        }
        .auth-wall-error {
            color: #f85149;
            font-size: 11px;
            margin-bottom: 10px;
            display: none;
        }
        .auth-wall-error.visible { display: block; }
        .auth-wall-btn {
            width: 100%;
            padding: 10px;
            background: #f5a623;
            color: #0f1419;
            border: none;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 700;
            cursor: pointer;
            transition: 0.15s ease;
            margin-top: 4px;
            font-family: inherit;
        }
        .auth-wall-btn:hover { background: #f7b84e; }
        .auth-wall-btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .auth-wall-toggle {
            color: #f5a623;
            font-size: 11px;
            margin-top: 16px;
            cursor: pointer;
        }
        .auth-wall-toggle:hover { text-decoration: underline; }
        .auth-wall-loading {
            color: #8b949e;
            font-size: 12px;
            margin-top: 12px;
        }
        .nav-user {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 11px;
            color: #8b949e;
            margin-right: 8px;
        }
        .nav-user-email {
            max-width: 140px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            color: #c9d1d9;
            font-weight: 500;
        }
        .nav-logout-btn {
            background: none;
            border: 1px solid #30363d;
            color: #8b949e;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 11px;
            cursor: pointer;
            transition: 0.15s ease;
            font-family: inherit;
        }
        .nav-logout-btn:hover { background: #2d333b; color: #f85149; border-color: #f85149; }
    `;
    document.head.appendChild(style);

    // Inject auth wall HTML
    const wall = document.createElement('div');
    wall.className = 'auth-wall';
    wall.id = 'authWall';
    wall.innerHTML = `
        <div class="auth-wall-box">
            <div class="auth-wall-logo">HLL Tool</div>
            <div class="auth-wall-subtitle">Sign in to access this page</div>
            <label for="wallEmail">Email</label>
            <input type="email" id="wallEmail" placeholder="you@example.com" autocomplete="email">
            <label for="wallPassword">Password</label>
            <input type="password" id="wallPassword" placeholder="Password" autocomplete="current-password">
            <div class="auth-wall-error" id="wallError"></div>
            <button class="auth-wall-btn" id="wallSubmitBtn">Log In</button>
            <div class="auth-wall-toggle" id="wallToggleLink">Don't have an account? Sign up</div>
            <div class="auth-wall-loading" id="wallLoading" style="display:none;">Checking session...</div>
        </div>
    `;
    document.body.prepend(wall);

    // Bind events
    document.getElementById('wallSubmitBtn').addEventListener('click', () => HLL.authWallSubmit());
    document.getElementById('wallToggleLink').addEventListener('click', () => HLL.toggleAuthWallMode());
    ['wallEmail', 'wallPassword'].forEach(id => {
        document.getElementById(id).addEventListener('keydown', (e) => {
            if (e.key === 'Enter') { e.preventDefault(); HLL.authWallSubmit(); }
        });
    });

    // Inject nav user area (before nav-status if it exists)
    const navStatus = document.querySelector('.nav-status');
    if (navStatus) {
        const navUser = document.createElement('div');
        navUser.className = 'nav-user';
        navUser.id = 'navUser';
        navUser.style.display = 'none';
        navUser.innerHTML = `
            <span class="nav-user-email" id="navUserEmail"></span>
            <button class="nav-logout-btn" id="navLogoutBtn">Log out</button>
        `;
        navStatus.parentNode.insertBefore(navUser, navStatus);
        document.getElementById('navLogoutBtn').addEventListener('click', () => HLL.authSignOut());
    }
};

HLL.toggleAuthWallMode = function() {
    this._authWallMode = this._authWallMode === 'login' ? 'signup' : 'login';
    const isLogin = this._authWallMode === 'login';
    document.getElementById('wallSubmitBtn').textContent = isLogin ? 'Log In' : 'Sign Up';
    document.getElementById('wallToggleLink').textContent = isLogin 
        ? "Don't have an account? Sign up" 
        : 'Already have an account? Log in';
    document.getElementById('wallPassword').autocomplete = isLogin ? 'current-password' : 'new-password';
    document.getElementById('wallError').classList.remove('visible');
};

HLL.authWallSubmit = async function() {
    const email = document.getElementById('wallEmail').value.trim();
    const password = document.getElementById('wallPassword').value;
    const errorEl = document.getElementById('wallError');
    const submitBtn = document.getElementById('wallSubmitBtn');
    
    if (!email || !password) {
        errorEl.textContent = 'Please enter email and password.';
        errorEl.classList.add('visible');
        return;
    }
    
    if (this._authWallMode === 'signup' && password.length < 6) {
        errorEl.textContent = 'Password must be at least 6 characters.';
        errorEl.classList.add('visible');
        return;
    }
    
    if (!this.supabase) {
        errorEl.textContent = 'Failed to connect to database.';
        errorEl.classList.add('visible');
        return;
    }
    
    submitBtn.disabled = true;
    submitBtn.textContent = this._authWallMode === 'login' ? 'Signing in...' : 'Creating account...';
    errorEl.classList.remove('visible');
    
    try {
        let result;
        if (this._authWallMode === 'login') {
            result = await this.supabase.auth.signInWithPassword({ email, password });
        } else {
            result = await this.supabase.auth.signUp({ email, password });
        }
        
        if (result.error) throw result.error;
        
        if (this._authWallMode === 'signup' && result.data?.user?.identities?.length === 0) {
            errorEl.textContent = 'An account with this email already exists.';
            errorEl.classList.add('visible');
            return;
        }
        
        if (this._authWallMode === 'signup' && !result.data?.session) {
            errorEl.textContent = 'Check your email to confirm your account, then log in.';
            errorEl.classList.add('visible');
            errorEl.style.color = '#3fb950';
            setTimeout(() => { errorEl.style.color = ''; }, 5000);
            return;
        }
        
        // Success
        this.currentUser = result.data.session.user;
        await this._onAuthSuccess();
        
    } catch (err) {
        console.error('Auth error:', err);
        errorEl.textContent = err.message || 'Authentication failed.';
        errorEl.classList.add('visible');
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = this._authWallMode === 'login' ? 'Log In' : 'Sign Up';
    }
};

HLL._onAuthSuccess = async function() {
    // Hide wall
    document.getElementById('authWall').classList.add('hidden');
    
    // Update nav
    const navUser = document.getElementById('navUser');
    if (navUser) {
        navUser.style.display = 'flex';
        document.getElementById('navUserEmail').textContent = this.currentUser.email;
    }
    
    // Complete normal HLL.init() steps if not already done
    if (!this.isOnline) {
        await this.initSupabase();
    }
    this.updateNavStatus();
    document.querySelectorAll('.version-badge').forEach(el => {
        if (!el.textContent.trim()) el.textContent = 'v' + this.version;
    });
    
    // Fetch user roles
    await this.loadUserRoles();
    
    // Fire callback if page registered one
    if (typeof this._authCallback === 'function') {
        await this._authCallback();
    }
};

HLL.authSignOut = async function() {
    if (!this.supabase) return;
    try {
        await this.supabase.auth.signOut();
        this.currentUser = null;
        
        // Update nav
        const navUser = document.getElementById('navUser');
        if (navUser) navUser.style.display = 'none';
        
        // Show wall again
        document.getElementById('authWall').classList.remove('hidden');
        document.getElementById('wallEmail').value = '';
        document.getElementById('wallPassword').value = '';
    } catch (err) {
        console.error('Sign out error:', err);
    }
};

/**
 * Main entry point for pages using auth.
 * Call HLL.initWithAuth(callback) instead of HLL.init().
 * The callback runs only after successful authentication.
 */
HLL.initWithAuth = async function(callback) {
    this._authCallback = callback;
    
    // Inject auth wall UI
    this.injectAuthWall();
    
    // Show "checking session" state
    document.getElementById('wallLoading').style.display = 'block';
    document.getElementById('wallSubmitBtn').style.display = 'none';
    document.getElementById('wallToggleLink').style.display = 'none';
    
    // Load config and create Supabase client
    this.loadConfig();
    try {
        this.supabase = window.supabase.createClient(
            this.config.supabaseUrl, 
            this.config.supabaseKey
        );
        
        // Check for existing session
        const { data: { session } } = await this.supabase.auth.getSession();
        
        if (session?.user) {
            // Already logged in — skip wall
            this.currentUser = session.user;
            this.isOnline = true;
            await this._onAuthSuccess();
            return;
        }
    } catch (err) {
        console.error('Session check failed:', err);
    }
    
    // No session — show login form
    document.getElementById('wallLoading').style.display = 'none';
    document.getElementById('wallSubmitBtn').style.display = '';
    document.getElementById('wallToggleLink').style.display = '';
    document.getElementById('wallEmail').focus();
};

// ============================================================================
// ROLE MANAGEMENT
// ============================================================================

HLL.loadUserRoles = async function() {
    this.userRoles = [];
    this.userTeams = [];
    this.currentRole = null;
    this.isSuperAdmin = false;
    
    if (!this.supabase || !this.currentUser) return;
    
    try {
        const { data, error } = await this.supabase
            .from('user_roles')
            .select('role, team_id, teams(name)')
            .eq('user_id', this.currentUser.id);
        
        if (error) throw error;
        
        this.userRoles = data || [];
        this.isSuperAdmin = data?.some(r => r.role === 'super_admin') || false;
        this.userTeams = data?.map(r => ({ 
            team_id: r.team_id, 
            team_name: r.teams?.name, 
            role: r.role 
        })) || [];
        
        // Set currentRole to highest role across all teams
        const hierarchy = ['super_admin', 'team_admin', 'officer', 'viewer'];
        for (const level of hierarchy) {
            if (data?.some(r => r.role === level)) {
                this.currentRole = level;
                break;
            }
        }
        
        console.log(`User role: ${this.currentRole}, teams: ${this.userTeams.map(t => t.team_name).join(', ')}`);
        
        // Update nav to show role
        const navEmail = document.getElementById('navUserEmail');
        if (navEmail && this.currentRole) {
            const roleLabel = this.currentRole.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
            navEmail.textContent = roleLabel;
        }
        
    } catch (err) {
        console.error('Error loading user roles:', err);
    }
};

HLL.hasRole = function(minRole, teamId) {
    const hierarchy = ['viewer', 'officer', 'team_admin', 'super_admin'];
    if (this.isSuperAdmin) return true;
    
    const minLevel = hierarchy.indexOf(minRole);
    if (minLevel === -1) return false;
    
    const matching = teamId 
        ? this.userRoles.filter(r => r.team_id === teamId)
        : this.userRoles;
    
    return matching.some(r => hierarchy.indexOf(r.role) >= minLevel);
};

HLL.canEdit = function(teamId) {
    return this.hasRole('officer', teamId);
};

HLL.canDelete = function(teamId) {
    return this.hasRole('team_admin', teamId);
};

HLL.canManageRoles = function() {
    return this.isSuperAdmin;
};

// ============================================================================
// EXPORT
// ============================================================================

// Make HLL globally available
window.HLL = HLL;
