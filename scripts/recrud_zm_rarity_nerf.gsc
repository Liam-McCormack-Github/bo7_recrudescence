// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// Extra common-gun scalar only. Native higher-rarity multipliers run afterward.
// No starting-item markers, spawn callbacks, inventory scans or capture windows.
#using scripts\common\utility;

autoexec recrud_rarity_nerf_init()
{
    level.recrud_starting_whitelist = rsn_refs();
    utility::registersharedfunc(#"zombie_damage", #"hash_d276db87d69299de", &rsn_scalar);
    level thread rsn_setup();
}

function private rsn_setup()
{
    level endon(#"game_ended");
    setdvar(@"recrud_rarity_nerf_status", "common_gun_whitelist");
    {}
    while (1)
    {
        utility::registersharedfunc(#"zombie_damage", #"hash_d276db87d69299de", &rsn_scalar);
        wait 1;
    }
}

function private rsn_refs()
{
    // Literal engine basenames of regular guns from the verified 72-weapon catalogue; no launcher,
    // melee, wonder, grenade, perk-explosion or arbitrary zero-rarity reference.
    return [
        "sat_ar_albatross_mp",
        "sat_ar_condor_mp",
        "sat_ar_eagle_mp",
        "sat_ar_egret_mp",
        "sat_ar_emu_mp",
        "sat_ar_falcon_mp",
        "sat_ar_finch_mp",
        "sat_ar_hawk_mp",
        "sat_ar_heron_mp",
        "sat_ar_kite_mp",
        "sat_ar_kiwi_mp",
        "sat_ar_macaw_mp",
        "sat_ar_vulture_mp",
        "sat_ar_wren_mp",
        "sat_sm_bear_mp",
        "sat_sm_bengal_mp",
        "sat_sm_civet_mp",
        "sat_sm_cobra_mp",
        "sat_sm_gecko_mp",
        "sat_sm_hyena_mp",
        "sat_sm_komodo_mp",
        "sat_sm_mammoth_mp",
        "sat_sm_marmot_mp",
        "sat_sm_orca_mp",
        "sat_sm_otter_mp",
        "sat_sm_puma_mp",
        "sat_sm_serval_mp",
        "sat_sm_stoat_mp",
        "sat_sm_zebra_mp",
        "sat_lm_hades_mp",
        "sat_lm_hildr_mp",
        "sat_lm_typhon_mp",
        "sat_lm_zeus_mp",
        "sat_sh_akita_mp",
        "sat_sh_corso_mp",
        "sat_sh_husky_mp",
        "sat_sh_shepherd_mp",
        "sat_sh_terrier_mp",
        "sat_dm_kara_mp",
        "sat_dm_oman_mp",
        "sat_dm_samar_mp",
        "sat_dm_scotia_mp",
        "sat_dm_solomon_mp",
        "sat_dm_tasman_mp",
        "sat_sn_aden_mp",
        "sat_sn_baltic_mp",
        "sat_sn_caspian_mp",
        "sat_sn_coral_mp",
        "sat_sn_drake_mp",
        "sat_pi_alcor_mp",
        "sat_pi_atlas_mp",
        "sat_pi_orion_mp",
        "sat_pi_timir_mp"
    ];
}

function private rsn_gun(w)
{
    if (!isdefined(w) || !isweapon(w) || isnullweapon(w)) return 0;
    if (istrue(w.isalternate) || istrue(w.ismelee) || istrue(w.ismeleeweapon) || istrue(w.iswonderweapon)) return 0;
    if (!isarray(level.recrud_starting_whitelist)) return 0;
    return arraycontains(level.recrud_starting_whitelist, w.basename);
}

function private rsn_scalar(objweapon, attacker)
{
    if (!isdefined(attacker) || !isplayer(attacker) || !rsn_gun(objweapon)) return 1;
    if (!utility::issharedfuncdefined(#"zombie", #"getplayerweaponrarity")) return 1;
    rarity = attacker utility::callsharedfunc(#"zombie", #"getplayerweaponrarity", objweapon);
    // Do not infer rarity zero from an unavailable result.
    if (!isdefined(rarity) || rarity != 0) return 1;
    scale = getdvarfloat(@"zm_rarity_base_scale", 0.4);
    if (scale <= 0 || scale >= 1) return 1;
    if ((attacker.recrud_rarity_hit_logs ?? 0) < 8)
    {
        attacker.recrud_rarity_hit_logs = (attacker.recrud_rarity_hit_logs ?? 0) + 1;
        {}
    }
    return scale;
}

function private rlog(msg)
{}
