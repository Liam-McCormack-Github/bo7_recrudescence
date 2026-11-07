// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// ============================================================================
// recrud_zm_ee_eggs.gsc  (isolated so a failure here cannot break armor/PaP)
// Easter Egg completion -> 2 Golden Mr. Peeks eggs per player (instead of the stock reward).
//
// Stock facts (decompiled script_45e1c753917c8703 = Peeks egg event):
//  - egg item bundle = getscriptbundle( peeksbundle.var_e04bbe555cbd90d4 )   <- tier 3 (golden)
//  - spawned with common_item::function_61c2c0251e742ffd( bundle, 1, spawnoptions )
//  - on pickup: common_item::function_577fe3f000fcb275( 0.1, 27, peeksbundle.var_11414037c992badb.var_36ab00b9ea8953d4, spawnoptions )
// Quest end hook: level callback #"zm_mq_quest_complete" (fired by each map when the main quest ends).
// ============================================================================
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\mp\loot\common_item;

autoexec recrud_ee_eggs_init()
{
    level thread recrud_ee_eggs_main();
}

function private recrud_ee_eggs_main()
{
    level endon(#"game_ended");
    level callback::add(#"zm_mq_quest_complete", &recrud_on_mq_complete);
    level callback::add(#"player_used_item", &recrud_on_egg_used);
    {}
    level thread recrud_ee_reward_listener();
    level callback::add(#"hash_653c8d8c75c5f228", &recrud_on_step);
    {}
}

function private recrud_ee_debug_dvar()
{}

function private recrud_ee_autotest()
{}

function private recrud_on_step(params)
{
    {}
}

function private recrud_on_mq_complete(params)
{
    {}
    level thread recrud_spawn_golden_eggs();
}

function private recrud_peeks_bundle()
{
    bundle = level.var_966e7e1f42f9a195;
    if (!isdefined(bundle))
    {
        bundle = getscriptbundle(%"hash_1fa040df87f446e8");
    }
    if (!isdefined(bundle))
    {
        bundle = getscriptbundle(%"hash_2d453bdcd3bb8569");
    }
    return bundle;
}

function private recrud_spawn_golden_eggs()
{
    if (istrue(level.recrud_ee_eggs_spawned))
    {
        return;
    }
    level.recrud_ee_eggs_spawned = 1;
    {}

    wait 2.0;

    peeks = recrud_peeks_bundle();
    {}
    wait 0.5;
    if (isdefined(peeks))
    {
        {}
        wait 0.5;
    }
    if (!isdefined(peeks) || !isdefined(peeks.var_e04bbe555cbd90d4))
    {
        wait 0.5;
        {}
        return;
    }
    egg_bundle = getscriptbundle(peeks.var_e04bbe555cbd90d4);
    if (!isdefined(egg_bundle))
    {
        {}
        return;
    }

    players = level.players;
    if (!isdefined(players) || players.size < 1)
    {
        return;
    }

    if (isdefined(level.recrud_ee_reward_pos))
    {
        center = level.recrud_ee_reward_pos;
        count = 1;
    }
    else
    {
    center = (0, 0, 0);
    count = 0;
    foreach (p in players)
    {
        if (isdefined(p) && isalive(p))
        {
            center = center + p.origin;
            count++;
        }
    }
    if (count < 1)
    {
        return;
    }
    center = center / count;
    }

    total_eggs = 2 * players.size;
    {}

    angle_step = 360.0 / total_eggs;
    radius = 90.0 + (total_eggs > 4 ? 30.0 : 0.0);

    for (i = 0; i < total_eggs; i++)
    {
        yaw = 45 + i * angle_step;
        spawn_pos = center + (cos(yaw) * radius, sin(yaw) * radius, 15);
        ground = getgroundposition(spawn_pos + (0, 0, 50), 64);
        if (isdefined(ground))
        {
            spawn_pos = ground + (0, 0, 10);
        }

        spawn_options = common_item::function_65c7b093a7001815(spawn_pos);
        spawn_options.var_23d3495c57d61bdf = 1;
        spawn_options.var_b8402e625c429a31 = 1;
        spawn_options.var_90cdc5dbcd319e5d = 1;
        spawn_options.var_9161cf0784b6951d = 1;

        egg = common_item::function_61c2c0251e742ffd(egg_bundle, 1, spawn_options);
        if (isdefined(egg))
        {
            egg.recrud_egg = 1;
        }
        wait 0.05;
    }
}

// Own pickup handler (the stock one is only registered on maps that have egg spawn points)
function private recrud_on_egg_used(params)
{
    if (!isdefined(params) || !isdefined(params.item) || !istrue(params.item.recrud_egg))
    {
        return;
    }
    params.item.recrud_egg = 0;

    peeks = recrud_peeks_bundle();
    if (!isdefined(peeks) || !isdefined(peeks.var_11414037c992badb))
    {
        return;
    }
    reward = peeks.var_11414037c992badb;
    spawnoptions = common_item::function_65c7b093a7001815(params.item.origin);
    if (isdefined(reward.var_36ab00b9ea8953d4))
    {
        common_item::function_577fe3f000fcb275(0.1, 27, reward.var_36ab00b9ea8953d4, spawnoptions);
    }
}

function recrud_dbg(msg)
{}


function private recrud_ee_reward_listener()
{
    level endon(#"game_ended");
    while (1)
    {
        level waittill(#"recrud_ee_reward", pos);
        {}
        level.recrud_ee_reward_pos = pos;
        level.recrud_ee_eggs_spawned = 0;
        level thread recrud_spawn_golden_eggs();
    }
}
