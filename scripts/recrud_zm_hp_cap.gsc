// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// Change the maximum inside the starting-health SCALER, not spawned AI health.
// Native round additions, co-op scaling and global multiplier remain in effect.
#using scripts\common\utility;
#using script_2498b7c75f1dee2d;

autoexec zm_hp_cap_init()
{
    level thread zm_hp_cap_hook();
    level thread recrud_hp_audit();
}

// Native mode initialization can register its scaler after mod autoexec.
// Restore only the exact saved native function; never wrap an unknown wrapper.
function private recrud_hp_audit()
{
    level endon(#"game_ended");
    repairs = 0;
    for (tick = 0; ; tick++)
    {
        wait 1;
        available = utility::issharedfuncdefined(#"zombie", #"health_scaling_get_starting_health");
        active = available ? utility::getsharedfunc(#"zombie", #"health_scaling_get_starting_health") : undefined;
        if (istrue(level.recrud_hp_scaler_installed) && active != &zm_hp_cap_health && active == level.recrud_hp_original)
        {
            utility::registersharedfunc(#"zombie", #"health_scaling_get_starting_health", &zm_hp_cap_health);
            repairs++;
            {}
        }
        {}
    }
}

function zm_hp_cap_hook()
{
    level endon(#"game_ended");
    // This runtime may not expose the native entry through getsharedfunc yet.
    // Wait on the native scaler's initialization marker instead of its registry.
    while (!isdefined(level.var_bf1316595b384341)) wait 0.05;
    wait 0.5;
    if (istrue(level.recrud_hp_scaler_installed)) return;
    if (!isdefined(level.sharedfuncs)) level.sharedfuncs = [];
    if (!isdefined(level.sharedfuncs[#"zombie"])) level.sharedfuncs[#"zombie"] = [];
    prior = utility::getsharedfunc(#"zombie", #"health_scaling_get_starting_health");
    level.recrud_hp_original = isfunction(prior) ? prior : &recrud_hp_native;
    level.recrud_hp_cache = [];
    level.recrud_hp_seen = [];
    level.recrud_hp_missing = [];
    utility::registersharedfunc(#"zombie", #"health_scaling_get_starting_health", &zm_hp_cap_health);
    level.recrud_hp_scaler_installed = 1;
    setdvar(@"zm_hp_cap_status", "scaler_max_25000");
    {}
}

function private recrud_hp_native(scriptbundle_name, current_round = 1, single_player = 0)
{
    return self namespace_775af9b7afedb6d1::function_28795222258b3cca(scriptbundle_name, current_round, single_player);
}

// Native health bundle references verified in the BO7 package dictionary.
function private recrud_hp_normal(name)
{
    if (!isdefined(name)) return 0;
    name = "" + name;
    if (name == "health_zombie_base" || name == "health_zombie_base_r_mod"
        || name == "health_zombie_base_armored_light" || name == "health_zombie_base_armored_light_r_mod"
        || name == "health_zombie_base_armored_heavy" || name == "health_zombie_base_armored_heavy_r_mod"
        || name == "health_zombie_base_armored_agni" || name == "health_zombie_base_luna"
        || name == "health_zombie_base_luna_r_mod" || name == "health_zombie_base_toxic") return 1;
    return 0;
}

function private recrud_hp_ref(name)
{
    if (!isdefined(name)) return name;
    name = "" + name;
    if (getsubstr(name, 0, 19) == "healthscalinground:") return getsubstr(name, 19, name.size);
    return name;
}

function zm_hp_cap_health(scriptbundle_name, current_round = 1, single_player = 0)
{
    level.recrud_hp_calls = (level.recrud_hp_calls ?? 0) + 1;
    if (level.recrud_hp_calls <= 3) {}
    if (!isdefined(scriptbundle_name)) return self [[ level.recrud_hp_original ]](scriptbundle_name, current_round, single_player);
    name = recrud_hp_ref(scriptbundle_name);
    // Match native gametype health-bundle redirection before choosing a scaler.
    foreach (override in level.gametypebundle.var_b608dbcf2a9c24e6 ?? [])
        if (override.originalhealth === hashcat(%"healthscalinground:", name)) name = recrud_hp_ref(override.newhealth);
    cap = getdvarint(@"zm_hp_cap", 25000);
    if (!recrud_hp_normal(name) || cap <= 0)
    {
        if (isdefined(name) && !isdefined(level.recrud_hp_seen[name]))
        {
            level.recrud_hp_seen[name] = 1;
            {}
        }
        return self [[ level.recrud_hp_original ]](scriptbundle_name, current_round, single_player);
    }

    multiplier = getdvarfloat(@"hash_a296d84ecc8ab62a", level.gametypebundle.var_6cfc57a4b0d987d ?? 1);
    players = single_player ? 1 : level.var_b29bf68fec4ea398 ?? level.players.size;
    if (!isdefined(level.recrud_hp_cache_cap) || level.recrud_hp_cache_cap != cap || level.recrud_hp_cache_mult != multiplier)
    {
        level.recrud_hp_cache = [];
        level.recrud_hp_cache_cap = cap;
        level.recrud_hp_cache_mult = multiplier;
    }
    if (!isdefined(level.recrud_hp_cache[name])) level.recrud_hp_cache[name] = [];
    if (!isdefined(level.recrud_hp_cache[name][current_round][players]))
    {
        bundle = getscriptbundle("healthscalinground:" + name);
        if (!isdefined(bundle))
        {
            if (!isdefined(level.recrud_hp_missing[name]))
            {
                level.recrud_hp_missing[name] = 1;
                {}
            }
            return self [[ level.recrud_hp_original ]](scriptbundle_name, current_round, single_player);
        }
        base = bundle.overridebasehealth ?? self.basehealth ?? 100;
        maximum = bundle.maxhealth ?? base;
        coop = 1;
        if (isdefined(bundle.var_674ca87a808f9ea1) && players > 1) coop += (players - 1) * bundle.var_674ca87a808f9ea1;
        // Cap the scaling ceiling before native additions/co-op/multiplier.
        // Dividing by the active factors keeps the FINAL maximum at 25k too.
        maximum = min(maximum, (multiplier > 0 && coop > 0) ? cap / (multiplier * coop) : cap);
        health = base;
        tiers = bundle.var_cc106eb8f18f06bb;
        if (current_round > 1 && isdefined(tiers))
        {
            for (i = 0; i < tiers.size; i++)
            {
                if (current_round < tiers[i].startround) break;
                added = tiers[i].healthadded ?? 0;
                rounds = isdefined(tiers[i + 1]) && current_round >= tiers[i + 1].startround
                    ? tiers[i + 1].startround - tiers[i].startround : current_round - tiers[i].startround;
                health += added * rounds;
            }
        }
        if (health > maximum) health = maximum;
        health *= coop;
        if (level.recrud_hp_cache[name].size >= 10) level.recrud_hp_cache[name] = [];
        if (!isdefined(level.recrud_hp_cache[name][current_round])) level.recrud_hp_cache[name][current_round] = [];
        level.recrud_hp_cache[name][current_round][players] = int(health);
        if (!isdefined(level.recrud_hp_seen[name]))
        {
            level.recrud_hp_seen[name] = 1;
            {}
        }
    }
    return level.recrud_hp_cache[name][current_round][players] * multiplier;
}

function private rlog(msg)
{}
