// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// ============================================================================
// recrud_zm_classic_points.gsc
// Cursed Mode Point System with Simultaneous 3D Damage Numbers:
// - Non-fatal bullet hit: +10 points (Type 6) & weapon damage number (Type 1)
// - Leg/foot kill: +50 points (Type 6) & fatal damage number (Type 1)
// - Splash/equipment kill: +50 points (Type 6)
// - Body/torso kill: +60 points (Type 6) & fatal damage number (Type 1)
// - Arm/shoulder kill: +70 points (Type 6) & fatal damage number (Type 1)
// - Headshot / critical kill: +100 points (Type 6) & fatal damage number (Type 1)
// - Melee kill: +130 points (Type 6)
// Suppresses standard mode 90/115 kill points.
// ============================================================================
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\mp\mp_agent_damage;
#using scripts\mp\supers;
#using scripts\mp\common\utility\game_utility;

function private recrud_get_point_scalar( player )
{
    if ( isdefined( player ) && isdefined( player.zombie_point_scalar ) && isnumber( player.zombie_point_scalar ) )
    {
        return player.zombie_point_scalar;
    }
    return 1;
}

autoexec recrud_points_init()
{
    {}
    {}
    {}
    level thread recrud_points_main();
}

function recrud_points_main()
{
    level endon(#"game_ended");

    // mode check removed

    // Suppress standard mode 90/115 kill scoreevents (script_2301d27669c5a079.gsc:234)
    level.var_f54e14d0ca3af7ed = 1;

    // Hook level AI damage and kill callbacks immediately
    level callback::add(#"on_ai_damaged", &recrud_on_ai_damaged);
    level callback::add(#"on_ai_killed", &recrud_on_ai_killed);

    // Wait until players connect
    while (!isdefined(level.players) || level.players.size == 0)
    {
        wait 0.5;
    }
    wait 1.0;

    setdvar(@"recrud_points_status", "cursed_active");
    {}
    level thread recrud_points_watchdog();
}

function recrud_points_watchdog()
{
    level endon(#"game_ended");

    while (1)
    {
        // Maintain suppression of standard mode 90/115 kill points
        level.var_f54e14d0ca3af7ed = 1;
        wait 1.0;
    }
}

// ----------------------------------------------------------------------------
// On AI Damaged: Award 10 points per non-fatal bullet hit
// Display BOTH weapon damage number (Type 1) and Cursed floating essence (Type 6)
// ----------------------------------------------------------------------------
function recrud_on_ai_damaged( params )
{
    if (!isdefined(params))
    {
        return;
    }

    attacker = params.eattacker;
    if (!isdefined(attacker) || !isplayer(attacker))
    {
        return;
    }

    // Only award on non-fatal hits (fatal hits handled by recrud_on_ai_killed)
    if (isdefined(self.health) && self.health > 0)
    {
        idamage = isdefined(params.idamage) ? params.idamage : 0;

        scalar = recrud_get_point_scalar( attacker );
        pts = int( 10 * scalar );

        // Award points to essence currency (scaled by Double Points)
        if (utility::issharedfuncdefined(#"points", #"add_points"))
        {
            attacker utility::callsharedfunc(#"points", #"add_points", pts);
        }

        // Show Cursed Floating Points rising from bottom of screen (Type 6)
        // (Damage numbers coming off the zombie are rendered natively by the game client)
        level mp_agent_damage::function_2b26b84aa6ce249c( attacker, 6, pts, ( 0, 0, 0 ), 0, undefined, 0 );
    }
}

// ----------------------------------------------------------------------------
// On AI Killed: Award Cursed mode kill points
// Leg/foot = 50, Body = 60, Arm = 70, Head/Crit = 100, Melee = 130
// ----------------------------------------------------------------------------
function recrud_on_ai_killed( params )
{
    if (!isdefined(params))
    {
        return;
    }

    attacker = params.eattacker;
    if (!isdefined(attacker) || !isplayer(attacker))
    {
        return;
    }

    pts = 60; // Default body kill
    is_crit = 0;
    label = "^2+60 ELIMINATION";

    smeans = params.smeansofdeath;
    shitloc = isdefined(params.shitloc) ? tolower(string(params.shitloc)) : "";

    is_melee = isdefined(smeans) && (smeans == #"mod_melee" || smeans == "MOD_MELEE" || issubstr(string(smeans), "melee"));
    is_headshot = istrue(params.biscritical) || issubstr(shitloc, "head") || issubstr(shitloc, "helmet") || issubstr(shitloc, "neck");
    is_leg = issubstr(shitloc, "leg") || issubstr(shitloc, "foot") || issubstr(shitloc, "feet") || issubstr(shitloc, "toe");
    is_arm = issubstr(shitloc, "arm") || issubstr(shitloc, "hand");
    is_splash = isdefined(smeans) && (issubstr(string(smeans), "splash") || issubstr(string(smeans), "grenade") || issubstr(string(smeans), "explosive"));

    if (is_melee)
    {
        pts = 130;
        label = "^2+130 MELEE ELIMINATION";
    }
    else if (is_headshot)
    {
        pts = 100;
        is_crit = 1;
        label = "^2+100 CRITICAL ELIMINATION";
    }
    else if (is_leg || is_splash)
    {
        pts = 50;
        label = "^2+50 LEG ELIMINATION";
    }
    else if (is_arm)
    {
        pts = 70;
        label = "^2+70 ARM ELIMINATION";
    }

    scalar = recrud_get_point_scalar( attacker );
    pts = int( pts * scalar );

    // Award calculated kill points to essence currency (scaled by Double Points)
    if (utility::issharedfuncdefined(#"points", #"add_points"))
    {
        attacker utility::callsharedfunc(#"points", #"add_points", pts);
    }

    // Show Cursed Floating Kill Points (+50/+60/+70/+100/+130) rising from bottom of screen (Type 6)
    // (Damage numbers coming off the zombie are rendered natively by the game client)
    level mp_agent_damage::function_2b26b84aa6ce249c( attacker, 6, pts, ( 0, 0, 0 ), 0, undefined, 1 );

    attacker recrud_charge_field_upgrade();
}

// Setting level.var_f54e14d0ca3af7ed = 1 (above) makes the stock scoreevent function return immediately, and that function is what
// charged the field upgrade meter on kills (plus XP, medals, challenge progress). So we charge the meter ourselves:
// "set recrud_fu_kills N" = kills to fill the meter from empty (default 25, 0 = off).
function private recrud_charge_field_upgrade()
{
    kills = getdvarint(@"recrud_fu_kills", 25);
    if (kills <= 0)
    {
        return;
    }
    sp = self supers_mp::getcurrentsuper();
    if (!isdefined(sp) || istrue(sp.isinuse) || self supers_mp::issuperready())
    {
        return;
    }
    need = self supers_mp::getsuperpointsneeded();
    mod = 1;
    if (isdefined(level.superpointsmod) && level.superpointsmod > 0)
    {
        mod = level.superpointsmod;
    }
    per = ceil(need / kills / mod);
    if (per < 1)
    {
        per = 1;
    }
    self supers_mp::givesuperpoints(per, undefined, 1);
}

function private recrud_is_supported_mode()
{
    mode = game_utility::getgametype();
    return isdefined(mode) && (mode == "zm_rb_classic" || mode == "zm_rb_survival");
}

// Log to the Lua console bridge (queued; flushed one line per 0.3s by recrud_zm_ee_eggs.gsc)
function private rlog(msg)
{}
