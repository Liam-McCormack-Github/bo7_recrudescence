// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// ============================================================================
// recrud_zm_standard_upgrades.gsc
// Standard Mode Upgrades:
// 1. No Spawn Armor (must buy Tier 1 Armor Vest at wallbuy)
// 2. Armor Wallbuys include Tier 1 (5k), Tier 2 (10k), Tier 3 (15k), Tier 4 Golden Armor (30k)
// 3. Pack-a-Punch Level 4 (50k essence) available
// 4. Tier 5 Weapon Rarity (Ultra) unlocked in Arsenal
// ============================================================================
#using scripts\common\callbacks;
#using scripts\common\system;
#using scripts\common\utility;
#using scripts\mp\armor;
#using scripts\mp\currency;
#using scripts\mp\interaction;
#using scripts\mp\pack_a_punch;
#using scripts\mp\purchasemenu;
#using scripts\mp\common\utility\game_utility;
#using scripts\mp\common\utility\lui_game_event_aggregator;
#using scripts\mp\wallbuy;
#using scripts\mp\zm\systems\zm_armor;

autoexec recrud_standard_upgrades_init()
{
    level thread recrud_standard_upgrades_main();
}

function recrud_standard_upgrades_main()
{
    level endon(#"game_ended");

    level callback::add(#"player_spawned", &recrud_on_player_spawned);
    level callback::add("on_variant_wallbuy_spawn", &recrud_on_armor_wall_spawned);

    lui_game_event_aggregator::registeronluieventcallback(&pap_four_fallback, "pap_weaponupgrade_purchase");

    {}
    level thread maintain_pap_and_armor_loop();
    level thread bind_armor_walls();

    {}
    {}
}

// -------------------- PACK-A-PUNCH LEVEL 4 --------------------
function private pap_price(item)
{
    if (!isdefined(item))
    {
        return 0;
    }
    if (isdefined(item.itemref) && (!isdefined(level.recrud_last_pap_ref) || item.itemref != level.recrud_last_pap_ref))
    {
        level.recrud_last_pap_ref = item.itemref;
        {}
    }
    if (!isdefined(item.itemref))
    {
        return item.cost ?? 0;
    }

    switch (item.itemref)
    {
        case "level1": return 5000;
        case "level2": return 15000;
        case "level3": return 30000;
        case "level4": return 50000;
    }
    return item.cost ?? 0;
}

function private pap_four_fallback(channel, menuitemindex)
{
    if (channel != "pap_weaponupgrade_purchase" || !isdefined(menuitemindex))
    {
        return;
    }
    {}
    s_menu = pack_a_punch::get_pap_purchase_menu(self.origin);
    if (!isdefined(s_menu))
    {
        {}
        return;
    }
    item = purchasemenu::create_item_struct(s_menu.ref, menuitemindex);
    if (!isdefined(item) || !isdefined(item.itemref) || item.itemref != "level4")
    {
        {}
        return;
    }
    if (item.tier == 4)
    {
        {}
        return;
    }
    gun = self getcurrentweapon();
    if (!isweapon(gun) || self pack_a_punch::get_pap_level(gun) != 3)
    {
        {}
        return;
    }
    if (!self currency::attempt_purchase(#"essence", 50000, 1, undefined, #"packapunch"))
    {
        {}
        purchasemenu::function_93f934ea2f1c06f8(3);
        return;
    }
    {}
    self pack_a_punch::pap_weapon(gun, 3, 50000, undefined, #"essence");
    purchasemenu::function_93f934ea2f1c06f8(1);
}

// -------------------- NO STARTING ARMOR --------------------
function private empty_starting_armor(player)
{
    return [0, 0];
}

function private maintain_pap_and_armor_loop()
{
    level endon(#"game_ended");
    {}
    while (1)
    {
        level.get_pap_cost_override = &pap_price;
        level.max_pack_a_punch_level = 4;
        level.startingarmoroverridefunc = &empty_starting_armor;

        // Stock armor wall: min(4, level+1) (golden tier) instead of min(3, ...) when this is >= 1
        level.var_7b4a8d359bf67f40 = 1;

        // Unlock Tier 5 Rarity (Ultra) in Arsenal
        level.var_48e2b36291b57f44 = 5;

        if (isdefined(level.zm_mode_modifiers))
        {
            level.zm_mode_modifiers.zmmodenoarmor = 0;
        }
        if (!istrue(level.recrud_loop_logged) && isdefined(level.zm_mode_modifiers))
        {
            level.recrud_loop_logged = 1;
            {}
        }
        wait 0.25;
    }
}

function private recrud_on_player_spawned(params)
{
    if (!isplayer(self))
    {
        return;
    }
    self.recrud_armor_bought_this_life = 0;
    {}
    self thread clear_spawn_armor();
}

function private clear_spawn_armor()
{
    self endon(#"disconnect");

    wait 0.20;
    if (!istrue(self.recrud_armor_bought_this_life))
    {
        self force_armor_zero();
    }
    wait 0.50;
    if (!istrue(self.recrud_armor_bought_this_life))
    {
        self force_armor_zero();
    }
    wait 1.0;
    if (!istrue(self.recrud_armor_bought_this_life))
    {
        self force_armor_zero();
    }
}

function private force_armor_zero()
{
    {}
    self.platecarrierlevel = 0;
    self.maxarmorhealth = 0;
    self.hasgoldenarmorplate = 0;
    self setclientomnvar("ui_armor_current_level", 0);
    self armor::setarmorhealth(0, 1, 1);
    self armor::external_setarmorplates(0);
}

// -------------------- ARMOR WALL-BUY (TIER 1 - 4 GOLDEN) --------------------
function private is_armor_wall(wall)
{
    if (!isdefined(wall))
    {
        return false;
    }
    if (isdefined(wall.variant_type) && (wall.variant_type == "armor" || wall.variant_type == #"armor"))
    {
        return true;
    }
    return isdefined(wall.scriptablenamehash) && wall.scriptablenamehash == #"wallbuy_zm_t10_armor_legendary";
}

function private recrud_on_armor_wall_spawned(params)
{
    {}
    if (is_armor_wall(self))
    {
        self bind_one_armor_wall();
    }
}

function private bind_armor_walls()
{
    level endon(#"game_ended");
    while (1)
    {
        wallbuy::register_wallbuy_variant_spawn("armor", &purchase_armor, &armor_hint);
        if (isdefined(level.interacts))
        {
            foreach (wall in level.interacts)
            {
                if (is_armor_wall(wall))
                {
                    if (!istrue(wall.recrud_logged))
                    {
                        wall.recrud_logged = 1;
                        {}
                    }
                    wall bind_one_armor_wall();
                    wall sync_wall_chalk(wall);
                }
            }
        }
        wait 0.25;
    }
}

// Wall chalk: stock single-wall mode shows one colour for everyone. Once a player owns tier 3, switch the
// wall to the gold chalk (the colour of the tier 4 purchase); revert to the stock state when nobody does.
function private sync_wall_chalk(wall)
{
    part = "\x8e\xb5\x08wX\x1b\xb1\xc4W\xcb";
    gold_state = "\xb9\xe9\x07`\xb3z\t`g";
    stock_state = "\xa4\x19\n\x0f\xe8\xd4v\xa5\x0b\x82!\xeb";
    want_gold = 0;
    foreach (p in level.players)
    {
        if (isdefined(p) && ((p.platecarrierlevel ?? 0) >= 3 || istrue(p.hasgoldenarmorplate)))
        {
            want_gold = 1;
        }
    }
    if (!isdefined(wall.recrud_chalk_gold))
    {
        wall.recrud_chalk_gold = 0;
        {}
    }
    if (want_gold == wall.recrud_chalk_gold)
    {
        return;
    }
    if (!wall getscriptablehaspart(part))
    {
        return;
    }
    wall.recrud_chalk_gold = want_gold;
    wall setscriptablepartstate(part, want_gold ? gold_state : stock_state);
    {}
}

function private bind_one_armor_wall()
{
    self interaction::set_interact_use_callback(&purchase_armor);
    self interaction::set_interact_hint_callback(&armor_hint);
}

function private next_armor_tier(player)
{
    return minint(4, (player.platecarrierlevel ?? 0) + 1);
}

function private armor_cost(tier)
{
    switch (tier)
    {
        case 1: return 5000;
        case 2: return 10000;
        case 3: return 15000;
        case 4: return 30000;
    }
    return 30000;
}

function private purchase_armor(player)
{
    {}
    if (!isplayer(player))
    {
        return;
    }
    if (istrue(player.hasgoldenarmorplate))
    {
        {}
        return;
    }
    tier = next_armor_tier(player);
    cost = armor_cost(tier);
    {}

    if (!player currency::attempt_purchase(#"essence", cost, 1, undefined, #"wallbuy"))
    {
        {}
        player playsoundtoplayer(#"ui_zm_core_purchase_deny", player);
        return;
    }

    player.recrud_armor_bought_this_life = 1;

    {}
    if (tier == 4)
    {
        {}
        if (utility::issharedfuncdefined(#"zombie", #"set_golden_armor"))
        {
            player utility::callsharedfunc(#"zombie", #"set_golden_armor");
        }
        else if (utility::issharedfuncdefined(#"zombie", #"hash_27c1e4caeb1b7199"))
        {
            player utility::callsharedfunc(#"zombie", #"hash_27c1e4caeb1b7199");
        }
        player.hasgoldenarmorplate = 1;
        player.platecarrierlevel = 3;
        player setclientomnvar("ui_armor_current_level", 3);
    }
    else
    {
        player zm_armor::give_armor(tier);
    }
    {}

    params = spawnstruct();
    params.cost = cost;
    params.armor_level = tier;
    params.currency = #"essence";
    player callback::callback("wallbuy_armor_purchased", params);
    player playsoundtoplayer(#"ui_zm_core_purchase_success", player);
}

function private armor_hint(wall, player)
{
    if (!isplayer(player))
    {
        return { #string:&"", #type:"HINT_NOBUTTON" };
    }
    tier = next_armor_tier(player);
    cost = armor_cost(tier);
    afford = player currency::get_currency_amount(#"essence") >= cost;
    hkey = "" + tier + "/" + istrue(player.hasgoldenarmorplate) + "/" + afford;
    if (!isdefined(player.recrud_hint_key) || player.recrud_hint_key != hkey)
    {
        player.recrud_hint_key = hkey;
        {}
    }
    title = &"shared_hintstrings/armor_vest_lv1_pickup";
    description = &"cp_zmb/armor1_desc";

    switch (tier)
    {
        case 2:
            title = &"shared_hintstrings/wallbuy_armor_hint_level_ii";
            description = &"cp_zmb/armor2_desc";
            break;
        case 3:
            title = &"shared_hintstrings/wallbuy_armor_hint_level_iii";
            description = &"cp_zmb/armor3_desc";
            break;
        case 4:
            title = &"shared_hintstrings/wallbuy_armor_hint_gold";
            if (isdefined(level.var_c3cbabc25cac9c8e))
            {
                description = level.var_c3cbabc25cac9c8e.var_ecaed48dad41d0ff;
            }
            break;
    }

    hint = { #icon:"ui_icon_zm_ping_armor", #icon_text_value:cost, #icon_text:&"shared_hintstrings/cost_essence", #description:description, #title:title, #buttoncallout:&"shared_hintstrings/hint_buy", #params:[ cost, &"" ], #type:"HINT_BUTTON" };
    hint.string = title;

    if (istrue(player.hasgoldenarmorplate))
    {
        hint.title = &"cp_zmb/armor_repair";
        hint.interactable = 0;
    }
    else if (player currency::get_currency_amount(#"essence") < cost)
    {
        hint.aux_text = &"shared_hintstrings/not_enough_essence";
        hint.interactable = 0;
    }
    return hint;
}

// Log to the Lua console bridge (queued; flushed one line per 0.3s by recrud_zm_log.gsc)
function private rlog(msg)
{}
