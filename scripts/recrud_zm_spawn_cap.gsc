// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// Live cap 70 and faster solo cadence. Native actual-player round totals.
#using scripts\mp\zm\systems\zm_round_logic;
#using scripts\mp\zm\systems\zm_round_spawning;

autoexec recrud_ss_autoexec()
{
    level thread recrud_ss_init();
}

function recrud_ss_init()
{
    level endon(#"game_ended");
    wait 1;
    for (i = 0; i < 600; i++)
    {
        if (isdefined(level.var_a009ab14ee0d3223) && isdefined(level.var_a009ab14ee0d3223.var_63a0ca44b877a390)) break;
        wait 0.5;
    }
    if (!isdefined(level.var_a009ab14ee0d3223) || !isdefined(level.var_a009ab14ee0d3223.var_63a0ca44b877a390)) { {} return; }
    level.recrud_zc_target = 70;
    level.recrud_zc_last_log = -10000;
    if (!isdefined(level.var_7f29a2c7fe5ec0ef)) level.var_7f29a2c7fe5ec0ef = &recrud_solo_spawn_delay;
    {}
    setdvar(@"recrud_spawn_cap_status", "live70_native_totals_fastsolo");
    while (1)
    {
        // Preserve the existing 70-alive policy, independently of round totals.
        level.var_a009ab14ee0d3223.var_63a0ca44b877a390 = level.recrud_zc_target;
        level.var_d61fcb760217368 = undefined;
        if (gettime() - level.recrud_zc_last_log >= 10000)
        {
            level.recrud_zc_last_log = gettime();
            {}
            {}
        }
        wait 1;
    }
}

// Same native cadence curve; only solo uses the four-player base delay.
// Two or more players retain their normal native base delay and decay.
function private recrud_spawn_cadence(players, round)
{
    cadence_players = players == 1 ? 4 : players;
    switch (cadence_players)
    {
        case 2: delay = 1.125; break;
        case 3: delay = 0.6675; break;
        case 4: delay = 0.5025; break;
        default: delay = 0.4125; break;
    }
    round = min(round, 60);
    for (i = 1; i < round; i++)
    {
        delay *= 0.95;
        if (delay <= 0.1) return 0.1;
    }
    return delay;
}

function private recrud_solo_spawn_delay()
{
    settings = level.var_a009ab14ee0d3223;
    players = level.players.size;
    round = zm_round_logic::get_rb_round_number();
    active = zm_round_spawning::get_round_enemies();
    cadence_players = players == 1 ? 4 : players;
    if (active.size < cadence_players + 4 + int(round % 2)) return 0.1;
    if (isdefined(settings.specialroundspawns[round]))
    {
        special = settings.specialroundspawns[round];
        if (istrue(special.var_c77a2bb3ee36c2c9) && isdefined(settings.var_883bfe37c0fd93a3[special.specialroundname]))
            return [[ settings.var_883bfe37c0fd93a3[special.specialroundname] ]](round, special);
    }
    return recrud_spawn_cadence(players, round);
}

function private rlog(msg)
{}
