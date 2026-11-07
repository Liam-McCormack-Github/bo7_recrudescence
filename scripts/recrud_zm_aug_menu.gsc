// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// ============================================================================
// recrud_zm_aug_menu.gsc  (v3)
// Server side of the Augments page in our own Arsenal menu (Assets\Lua\recrud_arsenal_menu_post.lua).
//
// Lua -> GSC:
//   Lua sets dvar  recrud_aug_req = "<augment bundle name>|M"   (M major, m minor)
//   then Engine.NotifyServer("recrud_aug_buy", 1)  ==>  #"luinotifyserver" (channel, value)
// GSC -> Lua (polled every 500ms by the page):
//   recrud_aug_own  = comma list of augment names the player has bought
//   recrud_aug_eq   = comma list of augment names currently equipped
//   recrud_aug_pts  = current essence (points)
//   recrud_aug_msg  = "<seq>|<text>" result of the last request
// Prices: major 250, minor 100 (salvage). Owned but unequipped = free re-equip.
// One major + one minor can be equipped per equipment (stock equip replaces the old one).
// ============================================================================
#using script_28b0cdf016eaa576;
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\mp\currency;
#using scripts\mp\supers;

autoexec recrud_aug_menu_init()
{
    level thread recrud_aug_menu_main();
}

function private recrud_aug_menu_main()
{
    level endon(#"game_ended");
    setdvar(@"recrud_aug_req", "");
    setdvar(@"recrud_aug_own", "");
    setdvar(@"recrud_aug_eq", "");
    setdvar(@"recrud_aug_pts", "0");
    setdvar(@"recrud_aug_msg", "");
    {}
    {}
    {}
    {}
    {}
    {}
    level.recrud_aug_seq = 0;
    wait 5;
    {}
    while (1)
    {
        foreach (p in level.players)
        {
            if (isdefined(p) && !istrue(p.recrud_aug_listening))
            {
                p.recrud_aug_listening = 1;
                p.recrud_aug_own = [];
                p.recrud_aug_eqslot = [];
                p.recrud_aug_eqname = [];
                p thread recrud_aug_listen();
                {}
            }
        }
        {}
        {}
        {}
        {}
        {}
        wait 0.5;
    }
}

// "set player_debug 1" in the console: logs this player's perk system state, equipped augments and per-type perk checks.
function private recrud_aug_debug_dump()
{}

// "set perk_debug 1": gives every zombies perk one at a time (logging each), then equips and unequips every augment one at a time (logging each).
function private recrud_aug_perk_debug()
{}

// "set ammo_debug 1" / "set field_debug 1": for every augment of the ammo mod (AM) or field upgrade (FU) types, equips it, checks the live "is equipped" state,
// unequips it through the menu path and checks again. BAD = still equipped after unequip.
function private recrud_aug_group_probe(tag)
{}

// "set charge_debug 1": logs the held field upgrade (super) points every second for 30 s so you can kill zombies and watch whether it charges.
// Also gives 1 point at the start to show the units.
function private recrud_aug_charge_probe()
{}

function private recrud_aug_listen()
{
    self endon(#"disconnect");
    while (1)
    {
        self waittill(#"luinotifyserver", channel, value);
        // Attachment frames are owned by the shop listener. The chunk decoder
        // already ignores these; skip its duplicate per-frame diagnostics too.
        if (isdefined(channel) && isdefined(value) && value >= 17301504 && value < 17760256 && (channel == #"bongo_item_unlock_status_is_locked" || ("" + channel) == "bongo_item_unlock_status_is_locked")) continue;
        if (!isdefined(level.recrud_aug_nseen))
        {
            level.recrud_aug_nseen = 0;
        }
        level.recrud_aug_nseen = level.recrud_aug_nseen + 1;
        if (level.recrud_aug_nseen <= 400 && isdefined(channel) && ("" + channel != "perk_choice_purchase") && ("" + channel != "scoreboard_close"))
        {
            {}
        }
        if (isdefined(channel) && isdefined(value) && value >= 16777216 && value < 33554432 && (channel == #"bongo_item_unlock_status_is_locked" || ("" + channel) == "bongo_item_unlock_status_is_locked"))
        {
            recrud_aug_chunk(self, value);
        }
    }
}

function private recrud_aug_msg(player, text)
{
    level.recrud_aug_seq = level.recrud_aug_seq + 1;
    {}
    if (isdefined(player))
    {
        {}
    }
}

function private recrud_aug_list_has(list, name)
{
    for (i = 0; i < list.size; i++)
    {
        if (list[i] == name)
        {
            return 1;
        }
    }
    return 0;
}

function private recrud_aug_chunk(player, value)
{
    v = value - 16777216;
    q = int(v / 65536);
    seq = q % 16;
    chunk = v - q * 65536;
    // Sequences 8..14 belong to Attachments; never append them to an augment hash.
    if (q >= 8 && q <= 14) return;
    if (seq == 15)
    {
        {}
        {}
        player thread recrud_aug_publish();
        return;
    }
    digits = "0123456789abcdef";
    h = "";
    n3 = int(chunk / 4096) % 16;
    n2 = int(chunk / 256) % 16;
    n1 = int(chunk / 16) % 16;
    n0 = chunk % 16;
    h = getsubstr(digits, n3, n3 + 1) + getsubstr(digits, n2, n2 + 1) + getsubstr(digits, n1, n1 + 1) + getsubstr(digits, n0, n0 + 1);
    if (seq == 0)
    {
        player.recrud_aug_hex = "";
    }
    if (!isdefined(player.recrud_aug_hex))
    {
        player.recrud_aug_hex = "";
    }
    player.recrud_aug_hex = player.recrud_aug_hex + h;
    if (seq == 3)
    {
        {}
        if (int(q / 32) % 2 == 1)
        {
            recrud_aug_handle_unequip(player, player.recrud_aug_hex);
        }
        else
        {
            recrud_aug_handle_buy(player, player.recrud_aug_hex);
        }
        player.recrud_aug_hex = "";
    }
}

function private recrud_aug_handle_unequip(player, name)
{
    found = recrud_aug_find(name);
    if (!isdefined(found.key))
    {
        {}
        return;
    }
    ub = level.zombie_augments[found.key];
    cur = player.zombie_augments[ub.augmenttype];
    // Same order as the stock stripper: snapshot the type's lists, clear the augment, then fire "unequipped" with the snapshot.
    snap = spawnstruct();
    snap.var_4c411197d5638fd4 = cur.var_4c411197d5638fd4;
    snap.var_4d84340989ac7ec0 = cur.var_4d84340989ac7ec0;
    snap.var_cafcc8be001cb0de = cur.var_cafcc8be001cb0de;
    snap.var_41a892151199064a = cur.var_41a892151199064a;
    snap.var_5b4699915fe0cf21 = cur.var_5b4699915fe0cf21;
    none = "\x9d\xba\x05k`\xda\xc8";
    if (istrue(ub.ismajor) && cur.var_4c411197d5638fd4 == found.key)
    {
        cur.var_4c411197d5638fd4 = none;
    }
    if (!istrue(ub.ismajor) && cur.var_4d84340989ac7ec0 == found.key)
    {
        cur.var_4d84340989ac7ec0 = none;
    }
    player recrud_aug_remove(found.key);
    cb = spawnstruct();
    cb.var_6a9a366904c2d389 = snap;
    cb.ismajor = ub.ismajor;
    cb.augmenttype = ub.augmenttype;
    cb.augmentname = found.key;
    player callback::callback("\xb6\x91\x18\x12\x90_\xc2k\xf9s\xad\xb2\x18\x81wOSP\x8a\x1b\xb1\xd1~\xbfQ\xd0", cb);
    eqok = player utility::callsharedfunc(#"zombie", #"hash_5b5c73998683a47", found.key);
    {}
    player thread recrud_aug_refresh_perk(ub.augmenttype);
    recrud_aug_msg(player, "Unequipped");
    {}
    player thread recrud_aug_publish();
}

// augment type -> the game's real perk key (taken from level.perkbundles via perk_debug)
function private recrud_aug_perkof(augtype)
{
    if (augtype == #"juggernog")
    {
        return "specialty_juggernog";
    }
    if (augtype == #"quick_revive")
    {
        return "specialty_quickrevive";
    }
    if (augtype == #"speedcola")
    {
        return "specialty_speedcola";
    }
    if (augtype == #"staminup")
    {
        return "specialty_staminup";
    }
    if (augtype == #"deadshot")
    {
        return "specialty_deadshot";
    }
    if (augtype == #"deathperception")
    {
        return "specialty_death_perception";
    }
    if (augtype == #"elemental_pop")
    {
        return "specialty_elemental_pop";
    }
    if (augtype == #"phdflopper")
    {
        return "specialty_phd_flopper";
    }
    if (augtype == #"vulture_aid")
    {
        return "specialty_vulture_aid";
    }
    if (augtype == #"m_mod")
    {
        return "specialty_m_mod";
    }
    if (augtype == #"d_mod")
    {
        return "specialty_d_mod";
    }
    if (augtype == #"w_mod")
    {
        return "specialty_w_mod";
    }
    if (augtype == #"z_mod")
    {
        return "specialty_z_mod";
    }
    if (augtype == #"y_mod")
    {
        return "specialty_y_mod";
    }
    return undefined;
}

function private recrud_aug_refresh_perk(augtype)
{
    self endon(#"death_or_disconnect");
    str_perk = recrud_aug_perkof(augtype);
    if (!isdefined(str_perk))
    {
        {}
        return;
    }
    if (!istrue(self utility::callsharedfunc(#"hash_e7a7d049d5f06935", #"hash_81cf46be569bf3bb", str_perk)))
    {
        nk = 0;
        mt = 0;
        if (isdefined(self.var_298fe7dcdb17fe4f))
        {
            foreach (kk, vv in self.var_298fe7dcdb17fe4f)
            {
                nk = nk + 1;
                if (kk == str_perk)
                {
                    mt = 1;
                }
            }
        }
        {}
        {}
        return;
    }
    idx = undefined;
    for (i = 0; i < self.perks_active.size; i++)
    {
        if (self.perks_active[i] == str_perk)
        {
            idx = i;
            break;
        }
    }
    if (!isdefined(idx))
    {
        {}
        return;
    }
    // same sequence as Rogue Run's augment equip (zm_rb_echo): take the perk, wait a frame, give it back in the same slot
    eternal = isdefined(self.var_435e0d69c85c6949) && arraycontains(self.var_435e0d69c85c6949, str_perk);
    bought = isdefined(self.var_9617244d7b4c2ae0) && self.var_9617244d7b4c2ae0[str_perk];
    self utility::callsharedfunc(#"hash_e7a7d049d5f06935", #"hash_899320e73bb1d103", str_perk, 1);
    eternal_now = isdefined(self.var_435e0d69c85c6949) && arraycontains(self.var_435e0d69c85c6949, str_perk);
    lost_eternal = eternal && !eternal_now;
    waitframe();
    self utility::callsharedfunc(#"hash_dc87e707c884850d", #"hash_d60bebeaed508539", str_perk, bought, 0, idx, lost_eternal);
    if (idx == 0 && self.perks_active[0] != str_perk)
    {
        reordered = [];
        reordered[0] = str_perk;
        foreach (p in self.perks_active)
        {
            if (p != str_perk)
            {
                reordered[reordered.size] = p;
            }
        }
        self.perks_active = reordered;
    }
    {}
}

function private recrud_aug_find(hex)
{
    r = spawnstruct();
    r.key = undefined;
    r.bundle = undefined;
    nkeys = 0;
    foreach (k, bb in level.zombie_augments)
    {
        ks = "" + k;
        if (nkeys < 0)
        {
            nkeys = nkeys + 1;
            {}
        }
        if (isdefined(bb) && isdefined(bb.augmenttype) && issubstr(ks, hex))
        {
            r.key = k;
            r.bundle = bb;
            return r;
        }
    }
    level.recrud_aug_dumped = 1;
    return r;
}

function private recrud_aug_handle_buy(player, name)
{
    found = recrud_aug_find(name);
    if (!isdefined(found.key))
    {
        recrud_aug_msg(player, "^1Unknown augment");
        {}
        return;
    }
    ismajor = istrue(found.bundle.ismajor);
    slotkey = "" + found.bundle.augmenttype;
    if (ismajor)
    {
        slotkey = slotkey + "M";
        cost = 250;
    }
    else
    {
        slotkey = slotkey + "m";
        cost = 100;
    }
    owned = recrud_aug_list_has(player.recrud_aug_own, name);
    if (!owned)
    {
        if (!player currency::attempt_purchase(#"salvage", cost, 1, undefined, #"wallbuy"))
        {
            recrud_aug_msg(player, "^1Not enough salvage (" + cost + ")");
            return;
        }
        player.recrud_aug_own[player.recrud_aug_own.size] = name;
        {}
    }
    player namespace_fce8f9f316b78881::function_c9cb0ae85eefe639(found.key, #"arsenal");
    player recrud_aug_enforce_me(found.key, found.bundle);
    player thread recrud_aug_refresh_perk(found.bundle.augmenttype);
    eqok = player utility::callsharedfunc(#"zombie", #"hash_5b5c73998683a47", found.key);
    {}
    slotidx = -1;
    for (i = 0; i < player.recrud_aug_eqslot.size; i++)
    {
        if (player.recrud_aug_eqslot[i] == slotkey)
        {
            slotidx = i;
        }
    }
    if (slotidx < 0)
    {
        slotidx = player.recrud_aug_eqslot.size;
    }
    player.recrud_aug_eqslot[slotidx] = slotkey;
    player.recrud_aug_eqname[slotidx] = name;
    if (!istrue(eqok))
    {
        recrud_aug_msg(player, "^1Equip failed");
    }
    else if (owned)
    {
        recrud_aug_msg(player, "Equipped");
    }
    else
    {
        recrud_aug_msg(player, "Purchased and equipped");
    }
    {}
    player thread recrud_aug_publish();
}

// Mutually exclusive MAJOR augment groups (script audit). Keep in sync with ME_GROUPS in the Lua page.
function private recrud_aug_partners(key)
{
    out = [];
    return out;
}

function private recrud_aug_remove(key)
{
    b = level.zombie_augments[key];
    if (!isdefined(b) || !isdefined(self.zombie_augments) || !isdefined(self.zombie_augments[b.augmenttype]))
    {
        return;
    }
    sl = self.zombie_augments[b.augmenttype];
    old = [];
    n = [];
    if (istrue(b.ismajor))
    {
        old = sl.var_cafcc8be001cb0de;
    }
    else
    {
        old = sl.var_41a892151199064a;
    }
    if (isdefined(old))
    {
        foreach (x in old)
        {
            if (x != key)
            {
                n[n.size] = x;
            }
        }
    }
    if (istrue(b.ismajor))
    {
        sl.var_cafcc8be001cb0de = n;
    }
    else
    {
        sl.var_41a892151199064a = n;
    }
    {}
}

// Mutual exclusion: majors only, listed groups only. Minors never conflict.
function private recrud_aug_enforce_me(key, bundle)
{
    return;
    if (!istrue(bundle.ismajor))
    {
        return;
    }
    foreach (x in recrud_aug_partners(key))
    {
        self recrud_aug_remove(x);
    }
}

function private recrud_aug_dump()
{}

function private recrud_aug_hexval(s)
{
    digits = "0123456789abcdef";
    v = 0;
    for (i = 0; i < s.size; i++)
    {
        c = getsubstr(s, i, i + 1);
        d = 0;
        for (j = 0; j < 16; j++)
        {
            if (getsubstr(digits, j, j + 1) == c)
            {
                d = j;
                break;
            }
        }
        v = v * 16 + d;
    }
    return v;
}

function private recrud_aug_tail(s)
{
    return recrud_aug_hexval(getsubstr(s, s.size - 5, s.size));
}

// Server truth -> page, over the stock purchase-menu notify omnvar (read by Lua).
// 23-bit messages: type*1048576 + low20.  1=begin 2=equipped(low20 of key) 3=end 4=owned
function private recrud_aug_publish()
{
    self endon(#"disconnect");
    self notify(#"recrud_aug_pub");
    self endon(#"recrud_aug_pub");
    msgs = [];
    msgs[msgs.size] = 1048576;
    neq = 0;
    if (isdefined(self.recrud_aug_own))
    {
        for (i = 0; i < self.recrud_aug_own.size; i++)
        {
            fnd = recrud_aug_find(self.recrud_aug_own[i]);
            if (isdefined(fnd.key) && istrue(self utility::callsharedfunc(#"zombie", #"hash_5b5c73998683a47", fnd.key)))
            {
                msgs[msgs.size] = 2097152 + recrud_aug_tail("" + fnd.key);
                neq = neq + 1;
            }
        }
    }
    if (isdefined(self.recrud_aug_own))
    {
        for (i = 0; i < self.recrud_aug_own.size; i++)
        {
            msgs[msgs.size] = 4194304 + recrud_aug_tail(self.recrud_aug_own[i]);
        }
    }
    msgs[msgs.size] = 3145728;
    {}
    self setclientomnvar("ui_purchasemenu_purchase_response", 0);
    for (i = 0; i < msgs.size; i++)
    {
        self setclientomnvar("ui_purchasemenu_purchase_response_notify", msgs[i]);
        wait 0.2;
    }
}

function private recrud_aug_join(list)
{
    s = "";
    for (i = 0; i < list.size && i < 24; i++)
    {
        if (i > 0)
        {
            s = s + ",";
        }
        s = s + list[i];
    }
    return s;
}

// Log to the Lua console bridge (queued; flushed one line per 0.3s by recrud_zm_log.gsc)
function private rlog(msg)
{}

function private recrud_aug_probe()
{}
