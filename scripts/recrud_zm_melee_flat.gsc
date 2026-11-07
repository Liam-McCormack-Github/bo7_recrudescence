// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// Native-first damage scaling: normal/armored swipes have 50 BASE damage.
// Armor/perks follow the swipe filter; other attack types retain native values.
#using scripts\common\utility;
#using script_17aac58f7828f476;

autoexec zm_damage_cap_init()
{
    level thread zm_damage_cap_hook();
    level thread recrud_swipe_audit();
}

function private recrud_swipe_audit()
{
    level endon(#"game_ended");
    for (tick = 0; ; tick++)
    {
        wait 1;
        scaler = utility::issharedfuncdefined(#"zombie", #"hash_e27e55920dabe660") ? utility::getsharedfunc(#"zombie", #"hash_e27e55920dabe660") : undefined;
        filter = utility::issharedfuncdefined(#"zombie", #"hash_ec597a712c9bb135") ? utility::getsharedfunc(#"zombie", #"hash_ec597a712c9bb135") : undefined;
        if (istrue(level.recrud_swipe_installed))
        {
            if (scaler != &recrud_swipe_scaler && scaler == level.recrud_swipe_original_scaler)
            {
                utility::registersharedfunc(#"zombie", #"hash_e27e55920dabe660", &recrud_swipe_scaler);
                {}
            }
            if (filter != &recrud_swipe_filter && filter == level.recrud_swipe_original_filter)
            {
                utility::registersharedfunc(#"zombie", #"hash_ec597a712c9bb135", &recrud_swipe_filter);
                {}
            }
        }
        {}
    }
}

function zm_damage_cap_hook()
{
    level endon(#"game_ended");
    while (!isdefined(level.var_bf1316595b384341)) wait 0.05;
    wait 0.5;
    if (istrue(level.recrud_swipe_installed)) return;
    if (!isdefined(level.sharedfuncs)) level.sharedfuncs = [];
    if (!isdefined(level.sharedfuncs[#"zombie"])) level.sharedfuncs[#"zombie"] = [];
    prior = utility::getsharedfunc(#"zombie", #"hash_e27e55920dabe660");
    level.recrud_swipe_original_scaler = isfunction(prior) ? prior : &recrud_swipe_native;
    level.recrud_swipe_original_filter = undefined;
    if (utility::issharedfuncdefined(#"zombie", #"hash_ec597a712c9bb135"))
        level.recrud_swipe_original_filter = utility::getsharedfunc(#"zombie", #"hash_ec597a712c9bb135");
    level.recrud_swipe_seen = [];
    level.recrud_swipe_hit_logs = 0;
    utility::registersharedfunc(#"zombie", #"hash_e27e55920dabe660", &recrud_swipe_scaler);
    utility::registersharedfunc(#"zombie", #"hash_ec597a712c9bb135", &recrud_swipe_filter);
    level.recrud_swipe_installed = 1;
    setdvar(@"zm_damage_cap_status", "native_first_swipe50");
    {}
}

function private recrud_swipe_native(round)
{
    return self namespace_ce77b5e0fc016a5a::function_c0f17eb03e09d5ef(round);
}

function private recrud_swipe_ref(actor)
{
    if (!isdefined(actor) || !isai(actor) || isplayer(actor)) return undefined;
    settings = actor.var_d6894f01a36b4ff3 ?? actor.zombieaisettings;
    if (!isdefined(settings)) return undefined;
    name = settings.healthscriptbundle;
    if (!isdefined(name)) return undefined;
    name = "" + name;
    if (getsubstr(name, 0, 19) == "healthscalinground:") return getsubstr(name, 19, name.size);
    return name;
}

function private recrud_is_swiper(actor)
{
    name = recrud_swipe_ref(actor);
    if (name == "health_zombie_base" || name == "health_zombie_base_r_mod"
        || name == "health_zombie_base_armored_light" || name == "health_zombie_base_armored_light_r_mod"
        || name == "health_zombie_base_armored_heavy" || name == "health_zombie_base_armored_heavy_r_mod"
        || name == "health_zombie_base_armored_agni" || name == "health_zombie_base_luna"
        || name == "health_zombie_base_luna_r_mod" || name == "health_zombie_base_toxic") return 1;
    return 0;
}

function private recrud_swipe_scaler(round)
{
    level.recrud_swipe_calls = (level.recrud_swipe_calls ?? 0) + 1;
    // Run the prior scaler on the original AI/round before touching melee.
    // Ranged, leap, armor, custom multipliers and attacker limits stay native.
    result = self [[ level.recrud_swipe_original_scaler ]](round);
    target = getdvarint(@"zm_melee_damage", 50);
    if (target >= 0 && recrud_is_swiper(self) && isdefined(self.var_6c41e8e873b7594e))
    {
        self.var_6c41e8e873b7594e = target;
        if (isdefined(self.var_c542902f7936ac8e) && self.var_c542902f7936ac8e > 0)
            self.var_98dbd659d6ef0838 = target / self.var_c542902f7936ac8e;
    }
    ref = "" + recrud_swipe_ref(self);
    if (!isdefined(level.recrud_swipe_seen[ref]))
    {
        level.recrud_swipe_seen[ref] = 1;
        {}
    }
    return result;
}

function private recrud_swipe_filter(dmg)
{
    level.recrud_swipe_filter_calls = (level.recrud_swipe_filter_calls ?? 0) + 1;
    if (level.recrud_swipe_filter_calls <= 8 && isdefined(dmg))
        {}
    // Chain the previous modifier/cancellations, then enforce base swipe damage.
    // This native hook precedes armor, perks and defensive damage reductions.
    result = isdefined(dmg) ? dmg.idamage : undefined;
    if (isfunction(level.recrud_swipe_original_filter))
    {
        prior = self [[ level.recrud_swipe_original_filter ]](dmg);
        result = isdefined(prior) ? prior : (isdefined(dmg) ? dmg.idamage : result);
    }
    if (!isdefined(dmg) || !isdefined(result) || result <= 0 || !isplayer(self)) return result;
    melee = dmg.smeansofdeath == "MOD_MELEE" || dmg.smeansofdeath == #"mod_melee";
    if (!melee || !recrud_is_swiper(dmg.eattacker)) return result;
    target = getdvarint(@"zm_melee_damage", 50);
    if (target < 0) return result;
    if (level.recrud_swipe_hit_logs < 5)
    {
        level.recrud_swipe_hit_logs++;
        {}
    }
    return target;
}

// Melee reach is owned solely by recrud_zm_zombie_tweaks.gsc.
function private rlog(msg)
{}
