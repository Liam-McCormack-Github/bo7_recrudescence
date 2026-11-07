// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// Zombie movement policy: speed cap 160, no super sprinters.
// Single melee-reach owner: zombie_reach percent (default 70; <=0/100 = stock).
// Native normal/moving reach and AI attack trigger use the same multiplier.
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\mp\zm\systems\zm_round_logic;

autoexec recrud_zt_autoexec()
{
    level thread recrud_zt_init();
}

function recrud_zt_init()
{
    level endon(#"game_ended");
    wait 1;
    level.recrud_zt_logged = 0;
    level callback::add(#"on_ai_spawned", &recrud_zt_on_spawn);
    foreach (zombie in getaiarray()) if (isdefined(zombie)) zombie thread recrud_zt_reach();
    for (i = 0; i < 600; i++)
    {
        if (isdefined(level.var_a009ab14ee0d3223) && isdefined(level.var_a009ab14ee0d3223.supersprintinground))
        {
            break;
        }
        wait 0.5;
    }
    if (!isdefined(level.var_a009ab14ee0d3223) || !isdefined(level.var_a009ab14ee0d3223.supersprintinground))
    {
        {}
        return;
    }
    s = level.var_a009ab14ee0d3223;
    stock_mult = s.movespeedmultiplier;
    stock_super = s.supersprintinground;
    stock_off = s.movespeedoffset;
    {}
    last = -1;
    cap = 160;
    act = 0;
    r = 0;
    m = 0;
    while (1)
    {
        wait 1;
        cap = 160;
        if (cap > 0)
        {
            s.supersprintinground = 99999;
            s.movespeedoffset = 1;
            r = zm_round_logic::function_c00961f92fc28240();
            m = stock_mult;
            if (r * stock_mult > cap)
            {
                m = cap / r;
            }
            s.movespeedmultiplier = m;
        }
        else
        {
            s.supersprintinground = stock_super;
            s.movespeedoffset = stock_off;
            s.movespeedmultiplier = stock_mult;
        }
        act = 0;
        if (cap > 0)
        {
            act = 1;
        }
        if (act != last)
        {
            {}
            last = act;
        }
    }
}

function recrud_zt_on_spawn()
{
    self thread recrud_zt_reach();
}

function recrud_zt_reach()
{
    self notify(#"recrud_reach_restart");
    self endon(#"recrud_reach_restart");
    self endon(#"death");
    level endon(#"game_ended");
    // Wait for native melee initialization, rather than modifying half-set AI.
    wait 0.05;
    for (i = 0; i < 100; i++)
    {
        if (isdefined(self.var_401534fee836a334) && isdefined(self._blackboard) && isdefined(self._blackboard.var_5692974bb0dd3579)) break;
        wait 0.05;
    }
    self recrud_zt_apply_reach(getdvarint(@"zombie_reach", 70));
}

function private recrud_zt_apply_reach(pct)
{
    if (!isdefined(self.var_401534fee836a334) || !isdefined(self._blackboard)) return 0;
    if (pct <= 0 || pct > 100) pct = 100;
    settings = self.var_d6894f01a36b4ff3 ?? self.zombieaisettings;
    // Prefer immutable native input parameters. Repeated spawn callbacks or
    // reused AI entities must never multiply an already reduced value again.
    if (isdefined(settings) && istrue(settings.enablemelee) && isdefined(settings.meleerange))
    {
        self.recrud_zt_base_reach = settings.meleerange;
        self.recrud_zt_base_moving = settings.var_bf81fa5e188a756;
    }
    else if (isdefined(settings) && istrue(settings.var_83af5d957815f4eb) && isdefined(settings.biterange))
    {
        self.recrud_zt_base_reach = settings.biterange;
        self.recrud_zt_base_moving = undefined;
    }
    else if (!isdefined(self.recrud_zt_base_reach))
    {
        self.recrud_zt_base_reach = self.var_401534fee836a334;
        self.recrud_zt_base_moving = self.var_a94ea9449f3053dd;
    }
    if (self.recrud_zt_base_reach <= 0) return 0;
    self.var_401534fee836a334 = self.recrud_zt_base_reach * pct / 100;
    if (isdefined(self.recrud_zt_base_moving) && self.recrud_zt_base_moving >= 0)
        self.var_a94ea9449f3053dd = self.recrud_zt_base_moving * pct / 100;
    // Native initialization sets this trigger to normal reach. Keep a zero
    // trigger disabled if the current AI state has suppressed melee attacks.
    if (isdefined(self._blackboard.var_5692974bb0dd3579) && self._blackboard.var_5692974bb0dd3579 > 0)
        self._blackboard.var_5692974bb0dd3579 = self.var_401534fee836a334;
    if (level.recrud_zt_logged < 3)
    {
        level.recrud_zt_logged++;
        {}
        {}
    }
    return 1;
}

// Log to the Lua console bridge (queued; flushed by recrud_zm_log.gsc)
function private rlog(msg)
{}
