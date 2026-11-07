// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// Fixed FuzMenu catalogue: 63 regular guns/melee + 9 wonder builds, per player.
// Select identity first, rarity second. Never enumerate the stock box pool as our deck.
// Native stock animation/pickup is retained; its final spawn is replaced by exact
// weapon object + item bundle handles, avoiding source-name/dvar hash reconstruction.
#using script_4ccf8f7e270f2426;
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\common\weapon;
#using scripts\mp\loot\common_item_weapon;

autoexec recrud_box_cycle_autoexec()
{
    level thread recrud_box_init();
}

function private recrud_box_catalog()
{
    // [menu identity, build reference, wonder, Sundergat conversion]
    return [
        ["sat_ar_albatross_mp", "sat_ar_albatross", 0, 0],
        ["sat_ar_condor_mp", "sat_ar_condor", 0, 0],
        ["sat_ar_eagle_mp", "sat_ar_eagle", 0, 0],
        ["sat_ar_egret_mp", "sat_ar_egret", 0, 0],
        ["sat_ar_emu_mp", "sat_ar_emu", 0, 0],
        ["sat_ar_falcon_mp", "sat_ar_falcon", 0, 0],
        ["sat_ar_finch_mp", "sat_ar_finch", 0, 0],
        ["sat_ar_hawk_mp", "sat_ar_hawk", 0, 0],
        ["sat_ar_heron_mp", "sat_ar_heron", 0, 0],
        ["sat_ar_kite_mp", "sat_ar_kite", 0, 0],
        ["sat_ar_kiwi_mp", "sat_ar_kiwi", 0, 0],
        ["sat_ar_macaw_mp", "sat_ar_macaw", 0, 0],
        ["sat_ar_vulture_mp", "sat_ar_vulture", 0, 0],
        ["sat_ar_wren_mp", "sat_ar_wren", 0, 0],
        ["sat_sm_bear_mp", "sat_sm_bear", 0, 0],
        ["sat_sm_bengal_mp", "sat_sm_bengal", 0, 0],
        ["sat_sm_civet_mp", "sat_sm_civet", 0, 0],
        ["sat_sm_cobra_mp", "sat_sm_cobra", 0, 0],
        ["sat_sm_gecko_mp", "sat_sm_gecko", 0, 0],
        ["sat_sm_hyena_mp", "sat_sm_hyena", 0, 0],
        ["sat_sm_komodo_mp", "sat_sm_komodo", 0, 0],
        ["sat_sm_mammoth_mp", "sat_sm_mammoth", 0, 0],
        ["sat_sm_marmot_mp", "sat_sm_marmot", 0, 0],
        ["sat_sm_orca_mp", "sat_sm_orca", 0, 0],
        ["sat_sm_otter_mp", "sat_sm_otter", 0, 0],
        ["sat_sm_puma_mp", "sat_sm_puma", 0, 0],
        ["sat_sm_serval_mp", "sat_sm_serval", 0, 0],
        ["sat_sm_stoat_mp", "sat_sm_stoat", 0, 0],
        ["sat_sm_zebra_mp", "sat_sm_zebra", 0, 0],
        ["sat_lm_hades_mp", "sat_lm_hades", 0, 0],
        ["sat_lm_hildr_mp", "sat_lm_hildr", 0, 0],
        ["sat_lm_typhon_mp", "sat_lm_typhon", 0, 0],
        ["sat_lm_zeus_mp", "sat_lm_zeus", 0, 0],
        ["sat_sh_akita_mp", "sat_sh_akita", 0, 0],
        ["sat_sh_corso_mp", "sat_sh_corso", 0, 0],
        ["sat_sh_husky_mp", "sat_sh_husky", 0, 0],
        ["sat_sh_shepherd_mp", "sat_sh_shepherd", 0, 0],
        ["sat_sh_terrier_mp", "sat_sh_terrier", 0, 0],
        ["sat_dm_kara_mp", "sat_dm_kara", 0, 0],
        ["sat_dm_oman_mp", "sat_dm_oman", 0, 0],
        ["sat_dm_samar_mp", "sat_dm_samar", 0, 0],
        ["sat_dm_scotia_mp", "sat_dm_scotia", 0, 0],
        ["sat_dm_solomon_mp", "sat_dm_solomon", 0, 0],
        ["sat_dm_tasman_mp", "sat_dm_tasman", 0, 0],
        ["sat_sn_aden_mp", "sat_sn_aden", 0, 0],
        ["sat_sn_baltic_mp", "sat_sn_baltic", 0, 0],
        ["sat_sn_caspian_mp", "sat_sn_caspian", 0, 0],
        ["sat_sn_coral_mp", "sat_sn_coral", 0, 0],
        ["sat_sn_drake_mp", "sat_sn_drake", 0, 0],
        ["sat_pi_alcor_mp", "sat_pi_alcor", 0, 0],
        ["sat_pi_atlas_mp", "sat_pi_atlas", 0, 0],
        ["sat_pi_orion_mp", "sat_pi_orion", 0, 0],
        ["sat_pi_timir_mp", "sat_pi_timir", 0, 0],
        ["sat_la_fang_mp", "sat_la_fang", 0, 0],
        ["sat_la_polis_mp", "sat_la_polis", 0, 0],
        ["sat_me_ballisticknife_mp", "sat_me_ballisticknife", 0, 0],
        ["sat_me_castor_mp", "sat_me_castor", 0, 0],
        ["sat_me_knife_mp", "sat_me_knife", 0, 0],
        ["sat_me_maru_mp", "sat_me_maru", 0, 0],
        ["sat_me_nashira_mp", "sat_me_nashira", 0, 0],
        ["sat_me_saiph_mp", "sat_me_saiph", 0, 0],
        ["sat_me_shockbaton_mp", "sat_me_shockbaton", 0, 0],
        ["sat_me_wasat_mp", "sat_me_wasat", 0, 0],
        ["sat_ww_firefly_zm", "sat_ww_firefly_zm", 1, 0],
        ["sat_ww_hornet_zm", "sat_ww_hornet_zm", 1, 0],
        ["sat_ww_locust_zm", "sat_ww_locust_zm", 1, 0],
        ["sat_ww_mantis_zm", "sat_ww_mantis_zm", 1, 0],
        ["sundergat", "sat_ww_mantis_zm", 1, 1],
        ["sat_ww_ruby_zm", "sat_ww_ruby_zm", 1, 0],
        ["sat_ww_scarab_zm", "sat_ww_scarab_zm", 1, 0],
        ["sat_ww_raygun_mp", "sat_ww_raygun", 1, 0],
        ["sat_ww_raygunmark2_mp", "sat_ww_raygunmark2", 1, 0]
    ];
}

function private recrud_box_init()
{
    level endon(#"game_ended");
    while (!isdefined(level.var_54989577c4e434aa) || !isdefined(level.commonitem))
    {
        wait 0.5;
    }
    wait 2;
    level.recrud_bx = spawnstruct();
    level.recrud_bx.catalog = recrud_box_catalog();
    level.recrud_bx.cache = [];
    level.recrud_bx.pending = [];
    level.recrud_bx.defaultlist = level.zm_bo6_box_bo7 ?? level.var_54989577c4e434aa;
    level.recrud_bx.ready = 0;
    level.recrud_bx.lastmissing = "";
    // The item pre-spawn callback explicitly reads back params.itembundle and
    // spawnoptions after callbacks. Only intercept the exact active box platform.
    callback::add(#"hash_c6570893b1c63e14", &recrud_box_spawn);
    while (!level.recrud_bx.ready)
    {
        recrud_box_validate();
        if (!level.recrud_bx.ready)
        {
            wait 5;
        }
    }
    level.recrud_bx.previoushooks = level.var_cb8cece2b97f9dc;
    level.recrud_box_owner = 1;
    level.var_cb8cece2b97f9dc = [&recrud_box_roll_weapon];
    setdvar(@"recrud_box_cycle_status", "box72 ready");
    {}
    while (1)
    {
        wait 1;
        if (level.var_cb8cece2b97f9dc.size != 1 || level.var_cb8cece2b97f9dc[0] != &recrud_box_roll_weapon)
        {
            level.var_cb8cece2b97f9dc = [&recrud_box_roll_weapon];
            {}
        }
    }
}

function private recrud_box_validate()
{
    // State fields avoid the BO7 local-variable issue documented by FuzMenu.
    level.recrud_bx.missing = "";
    level.recrud_bx.valid = 0;
    for (level.recrud_bx.i = 0; level.recrud_bx.i < 72; level.recrud_bx.i++)
    {
        if (!isdefined(level.recrud_bx.cache[level.recrud_bx.i]))
        {
            recrud_box_build_slot(level.recrud_bx.i);
        }
        if (isdefined(level.recrud_bx.cache[level.recrud_bx.i]))
        {
            level.recrud_bx.valid++;
        }
        else
        {
            level.recrud_bx.missing += level.recrud_bx.catalog[level.recrud_bx.i][0] + ",";
        }
    }
    level.recrud_bx.ready = (level.recrud_bx.valid == 72);
    if (!level.recrud_bx.ready)
    {
        setdvar(@"recrud_box_cycle_status", "box72 waiting " + level.recrud_bx.valid + "/72");
        if (level.recrud_bx.missing != level.recrud_bx.lastmissing)
        {
            {}
            level.recrud_bx.lastmissing = level.recrud_bx.missing;
        }
    }
}

function private recrud_box_build_slot(i)
{
    level.recrud_bx.build = undefined;
    if (!isdefined(level.weaponmapdata[level.recrud_bx.catalog[i][1]]) && !weaponexists(level.recrud_bx.catalog[i][1]))
    {
        return;
    }
    if (level.recrud_bx.catalog[i][2])
    {
        level.recrud_bx.build = weapon::buildweapon(level.recrud_bx.catalog[i][1], getweapondefaultattachments(level.recrud_bx.catalog[i][1]));
    }
    else
    {
        level.recrud_bx.build = weapon::buildweapon(level.recrud_bx.catalog[i][1]);
    }
    if (!isdefined(level.recrud_bx.build) || isnullweapon(level.recrud_bx.build))
    {
        return;
    }
    if (level.recrud_bx.catalog[i][3])
    {
        // Exactly FuzMenu's Sundergat conversion; this is a distinct deck slot.
        level.recrud_bx.build = level.recrud_bx.build function_21aa7260fe00ec7("sat_bar_ww_mantis");
        level.recrud_bx.build = level.recrud_bx.build function_f5dd5b7d34734bfb("sat_rec_ww_mantis");
        level.recrud_bx.build = level.recrud_bx.build function_21aa7260fe00ec7("sat_rec_ww_mantis2");
    }
    if (!isdefined(level.recrud_bx.build) || isnullweapon(level.recrud_bx.build))
    {
        return;
    }
    level.recrud_bx.entry = item_weapon::function_3da93a43aae4473d(level.recrud_bx.build.basename, undefined, level.recrud_bx.build.variantid);
    level.recrud_bx.bundle = isdefined(level.recrud_bx.entry) ? getscriptbundle(level.recrud_bx.entry) : undefined;
    if (!isdefined(level.recrud_bx.bundle) || !isdefined(level.recrud_bx.bundle.baseweapon) || !isdefined(level.recrud_bx.bundle.scriptable))
    {
        return;
    }
    level.recrud_bx.cache[i] = spawnstruct();
    level.recrud_bx.cache[i].weapon = level.recrud_bx.build;
    level.recrud_bx.cache[i].entry = level.recrud_bx.entry;
    level.recrud_bx.cache[i].rarity = level.recrud_bx.bundle.rarity ?? 0;
}

function recrud_box_roll_weapon(player, stockrarity, flags)
{
    setdvar(@"hash_5bf38da5a2eda0c8", "");
    if (!isdefined(player) || !isplayer(player))
    {
        return level.recrud_bx.defaultlist;
    }
    self.recrud_bx_pick = spawnstruct();
    self.recrud_bx_pick.player = player;
    self.recrud_bx_pick.index = player recrud_box_draw();
    self.recrud_bx_pick.weapon = level.recrud_bx.cache[self.recrud_bx_pick.index].weapon;
    self.recrud_bx_pick.round = utility::callsharedfunc(#"game", #"roundnumberdifficulty", self.origin) ?? 1;
    self.recrud_bx_pick.rarity = recrud_box_rarity(self.recrud_bx_pick.round, self.recrud_bx_pick.index);
    self.recrud_bx_pick.entry = item_weapon::function_3da93a43aae4473d(self.recrud_bx_pick.weapon.basename, self.recrud_bx_pick.rarity, self.recrud_bx_pick.weapon.variantid);
    if (!isdefined(self.recrud_bx_pick.entry) || !isdefined(getscriptbundle(self.recrud_bx_pick.entry)))
    {
        // Some melee/wonder builds do not have every rarity bundle. Identity stays.
        self.recrud_bx_pick.entry = level.recrud_bx.cache[self.recrud_bx_pick.index].entry;
    }
    self.recrud_bx_pick.bundle = getscriptbundle(self.recrud_bx_pick.entry);
    // Bundle fallback supplies the pickup asset, never the ordinary weapon tier.
    self.recrud_bx_pick.deadline = gettime() + 60000;
    self.recrud_bx_pick.applied = 0;
    if (!arraycontains(level.recrud_bx.pending, self))
    {
        level.recrud_bx.pending[level.recrud_bx.pending.size] = self;
    }
    // No name-to-hash roundtrip and no persistent force-weapon dvar.
    // Stock rolls only drive the animation shell; the scoped spawn hook below
    // provides the authoritative weapon/bundle and never consumes stock identity.
    {}
    return level.recrud_bx.defaultlist;
}

function private recrud_box_draw()
{
    if (!isarray(self.recrud_bx_deck) || self.recrud_bx_deck.size == 0)
    {
        self.recrud_bx_deck = [];
        for (self.recrud_bx_n = 0; self.recrud_bx_n < 72; self.recrud_bx_n++)
        {
            self.recrud_bx_deck[self.recrud_bx_deck.size] = self.recrud_bx_n;
        }
        self.recrud_bx_deck = arrayrandomize(self.recrud_bx_deck);
        if (isdefined(self.recrud_bx_last) && self.recrud_bx_deck[71] == self.recrud_bx_last)
        {
            self.recrud_bx_deck[71] = self.recrud_bx_deck[0];
            self.recrud_bx_deck[0] = self.recrud_bx_last;
        }
        {}
    }
    self.recrud_bx_choice = self.recrud_bx_deck[self.recrud_bx_deck.size - 1];
    self.recrud_bx_nextdeck = [];
    for (self.recrud_bx_n = 0; self.recrud_bx_n < self.recrud_bx_deck.size - 1; self.recrud_bx_n++)
    {
        self.recrud_bx_nextdeck[self.recrud_bx_nextdeck.size] = self.recrud_bx_deck[self.recrud_bx_n];
    }
    self.recrud_bx_deck = self.recrud_bx_nextdeck;
    self.recrud_bx_last = self.recrud_bx_choice;
    return self.recrud_bx_choice;
}

function private recrud_box_rarity(round, index)
{
    if (level.recrud_bx.catalog[index][2])
    {
        return level.recrud_bx.cache[index].rarity;
    }
    level.recrud_bx.roll = randomfloat(100);
    if (round >= 50)
    {
        if (level.recrud_bx.roll < 75) return 5;
        if (level.recrud_bx.roll < 85) return 4;
        if (level.recrud_bx.roll < 93) return 3;
        if (level.recrud_bx.roll < 97) return 2;
        return 1;
    }
    if (round >= 36 && level.recrud_bx.roll < 5) return 5;
    // Below round 50, retain the native round-table weights for ordinary tiers.
    // Ultra is an independent first roll, as in our existing box logic.
    level.recrud_bx.roll = randomfloat(100);
    if (isdefined(level.var_8da4a65dbf286b46.var_e706c54ff9d8cadc))
    {
        foreach (chances in level.var_8da4a65dbf286b46.var_e706c54ff9d8cadc)
        {
            if (round < chances.minround || round > chances.maxround) continue;
            level.recrud_bx.threshold = chances.legendarychance ?? 0;
            if (level.recrud_bx.roll < level.recrud_bx.threshold) return 4;
            level.recrud_bx.threshold += chances.epicchance ?? 0;
            if (level.recrud_bx.roll < level.recrud_bx.threshold) return 3;
            level.recrud_bx.threshold += chances.rarechance ?? 0;
            if (level.recrud_bx.roll < level.recrud_bx.threshold) return 2;
            break;
        }
    }
    // The stock normal-weapon branch defaults to its uncommon entry.
    return 1;
}

function private recrud_box_spawn(params)
{
    if (!isdefined(level.recrud_bx) || !level.recrud_bx.ready || !isdefined(params.spawnoptions.baseorigin)) return;
    // Stock box uniquely supplies this flag and spawns at its active platform.
    if (!isdefined(params.spawnoptions.var_f35b5b18b029c493) || params.spawnoptions.var_f35b5b18b029c493 != 0) return;
    foreach (box in level.recrud_bx.pending)
    {
        if (!isdefined(box) || !isdefined(box.recrud_bx_pick) || box.recrud_bx_pick.applied || gettime() > box.recrud_bx_pick.deadline) continue;
        if (!isdefined(box.var_aaebed696583903c) || distancesquared(params.spawnoptions.baseorigin, box.var_aaebed696583903c.origin) > 1) continue;
        params.itembundle = box.recrud_bx_pick.entry;
        params.spawnoptions.weapon = box.recrud_bx_pick.weapon;
        params.spawnoptions.rarity = box.recrud_bx_pick.rarity;
        // The stock spinner's temporary weapon data must not leak into our item.
        // Native item_weapon builds the instance rarity and packed pickup count
        // from this struct. Supplying only spawnoptions.rarity is insufficient:
        // a unique weapon's fallback bundle may have its own Ultra default.
        params.spawnoptions.var_6828becb300b1c44 = spawnstruct();
        params.spawnoptions.var_6828becb300b1c44.rarity = box.recrud_bx_pick.rarity;
        params.spawnoptions.var_6828becb300b1c44.baseweapon = box.recrud_bx_pick.weapon.basename;
        params.spawnoptions.var_6828becb300b1c44.variantid = box.recrud_bx_pick.weapon.variantid;
        params.spawnoptions.var_6828becb300b1c44.attachments = box.recrud_bx_pick.weapon.attachments;
        params.spawnoptions.var_6828becb300b1c44.itembundlename = box.recrud_bx_pick.entry;
        params.spawnoptions.var_6828becb300b1c44.paplevel = 0;
        params.spawnoptions.var_6828becb300b1c44.camoref = box.recrud_bx_pick.bundle.camoref;
        params.spawnoptions.var_6828becb300b1c44.attachmentslots = box.recrud_bx_pick.bundle.var_ef872c5384bdd7ce;
        params.spawnoptions.weaponinfostruct = undefined;
        box.var_182083fc5337ebe9 = box.recrud_bx_pick.entry;
        box.recrud_bx_pick.applied = 1;
        box thread recrud_box_verify_spawn();
        return;
    }
}

function private recrud_box_verify_spawn()
{
    waitframe();
    if (!isdefined(self.var_aaebed696583903c.item))
    {
        {}
        return;
    }
    self.var_aaebed696583903c.var_9ff2f93ccbf71b93 = getscriptbundle(self.recrud_bx_pick.entry);
    self.var_aaebed696583903c.var_2e08e94c9cb1747c = self.recrud_bx_pick.weapon.basename;
    if (self.var_aaebed696583903c.item.weaponobj != self.recrud_bx_pick.weapon)
    {
        {}
        return;
    }
    {}
}

function private rlog(msg)
{}
