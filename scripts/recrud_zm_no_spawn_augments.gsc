// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// ============================================================================
// recrud_zm_no_spawn_augments.gsc
// Disables all lobby loadout augments on spawn in (Rogue Run / Cursed behavior)
// Players start with 0 augments at round 1
// ============================================================================
#using scripts\common\callbacks;
#using scripts\common\utility;

autoexec recrud_no_augments_init()
{
    // DISABLED for augment testing: spawn augments are no longer stripped.
    return;
    level thread recrud_setup_rogue_augment_system();
    callback::add(#"player_spawned", &recrud_on_player_spawned);
    level callback::add(#"player_spawned", &recrud_on_player_spawned);
}

function recrud_setup_rogue_augment_system()
{
    level endon(#"game_ended");

    // Call official Treyarch relic disable sharedfunc if registered
    while (!utility::issharedfuncdefined(#"hash_b40a9d0e3ded2b0f", #"hash_7b764bfa39f0c244"))
    {
        if (isdefined(level.var_d387a7914df3c24a))
        {
            level.var_d387a7914df3c24a.var_883a0291ac45b227 = 1;
        }
        wait 0.2;
    }

    if (isdefined(level.var_d387a7914df3c24a))
    {
        level.var_d387a7914df3c24a.var_883a0291ac45b227 = 1;
    }

    utility::callsharedfunc(#"hash_b40a9d0e3ded2b0f", #"hash_7b764bfa39f0c244");
    {}

    // Official Rogue Run stripper loop across all players for the spawn window (30 seconds)
    level thread recrud_rogue_run_global_watchdog();
}

function recrud_rogue_run_global_watchdog()
{
    level endon(#"game_ended");

    for (i = 0; i < 20; i++)
    {
        if (isdefined(level.players))
        {
            foreach (player in level.players)
            {
                if (isdefined(player) && isplayer(player))
                {
                    if (utility::issharedfuncdefined(#"zombie", #"hash_ce4704a324ef399f"))
                    {
                        player utility::callsharedfunc(#"zombie", #"hash_ce4704a324ef399f");
                    }
                }
            }
        }
        wait 1.5;
    }
}

function recrud_on_player_spawned(params)
{
    player = isplayer(self) ? self : (isdefined(params) && isplayer(params) ? params : (isdefined(params) ? params.player : undefined));
    if (!isdefined(player) || !isplayer(player))
    {
        return;
    }

    player thread recrud_strip_loadout_augments();
}

function recrud_strip_loadout_augments()
{
    self endon(#"disconnect");
    self notify(#"recrud_strip_loadout_augments");
    self endon(#"recrud_strip_loadout_augments");

    // Poll over the loadout application window (0.5s to 6s) to ensure late engine sync does not reapply augments
    delays = [0.5, 1.0, 1.5, 2.5, 4.0, 6.0];
    for (i = 0; i < delays.size; i++)
    {
        wait delays[i];
        if (utility::issharedfuncdefined(#"zombie", #"hash_ce4704a324ef399f"))
        {
            self utility::callsharedfunc(#"zombie", #"hash_ce4704a324ef399f");
        }
    }

    {}
    {}
}

// Log to the Lua console bridge (queued; flushed one line per 0.3s by recrud_zm_ee_eggs.gsc)
function private rlog(msg)
{}
