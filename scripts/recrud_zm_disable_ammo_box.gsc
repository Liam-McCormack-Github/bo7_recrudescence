// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// ============================================================================
// recrud_zm_disable_ammo_box.gsc
// Disables ammo caches / ammo boxes using the official Relic system
// Spawns Mr. Peeks disabled mascot, disables VFX/prompts, and blocks ammo refills
// ============================================================================
#using scripts\common\callbacks;
#using scripts\common\utility;

autoexec recrud_ammo_cache_relic_init()
{
    // Override ammo refill sharedfunc to completely block ammo refill
    utility::registersharedfunc(#"ammo_cache", #"hash_bce776fc2c862b31", &recrud_null_ammo_refill);

    level thread recrud_ammo_cache_relic_watchdog();
}

function recrud_null_ammo_refill(weapon)
{
    return;
}

function recrud_ammo_cache_relic_watchdog()
{
    level endon(#"game_ended");

    // Wait until relic manager sharedfunc is registered
    while (!utility::issharedfuncdefined(#"hash_b40a9d0e3ded2b0f", #"hash_3b26c24c45b712a3"))
    {
        wait 0.2;
    }

    // Call Treyarch official relic disable function (places Mr. Peeks doll, triggers fx, disables interaction)
    utility::callsharedfunc(#"hash_b40a9d0e3ded2b0f", #"hash_3b26c24c45b712a3");

    {}
    {}

    // Secondary safety: ensure interaction remains locked for all caches
    while (1)
    {
        if (isdefined(level.var_6c83d1b7ba6fafa5) && isdefined(level.var_6c83d1b7ba6fafa5.var_ea07e36d8fd28578))
        {
            foreach (cache in level.var_6c83d1b7ba6fafa5.var_ea07e36d8fd28578)
            {
                if (isdefined(cache.var_38ab0335efaa5fa5))
                {
                    cache.var_38ab0335efaa5fa5.var_94d1ab5da995e573 = 1;
                }
            }
        }
        wait 1.0;
    }
}

// Log to the Lua console bridge (queued; flushed one line per 0.3s by recrud_zm_ee_eggs.gsc)
function private rlog(msg)
{}
