// created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
// Arsenal Weapons: edit the currently held weapon using nine native attachment categories.
// Requests: single server-catalog index plus generation guard in sequence 10.
// Client never uploads a weapon build. Server owns rule resolution and construction.
// Replies: dedicated recrud_weap_reply dvar; stock notify omnvar is a time event, not payload storage.
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\common\weapon;
#using scripts\mp\currency;
#using scripts\mp\loot\common_item_weapon;
#using script_4f24ca7a470a5fa8;
#using script_1ade2fa7cae9593d;

autoexec recrud_weapon_shop_init()
{
    {}
    level.rw_transport_verbose = getdvarint(@"recrud_weap_verbose");
    rm_init_catalog();
    setdvar(@"recrud_camo_reply", "0");
    level.rw_refdigits = [];
    alphabet = "abcdefghijklmnopqrstuvwxyz0123456789_";
    for (i = 0; i < alphabet.size; i++) level.rw_refdigits[getsubstr(alphabet, i, i + 1)] = i + 1;
    setdvar(@"recrud_weap_reply", "0");
    setdvar(@"recrud_weap_catalog", "0");
    {}
    {}
    level thread rw_main();
}

function private rw_main()
{
    level endon(#"game_ended");
    wait 5;
    {}
    while (1)
    {
        foreach (p in level.players)
        {
            if (isdefined(p) && !isdefined(p.rw))
            {
                p.rw = spawnstruct();
                p.rw.serial = 0;
                p.rw.busy = 0;
                p.rw.active = 0;
                p.rw.epoch = 0;
                p.rw.stage = "listener-ready";
                p.rw.outside = 0;
                p thread rw_listen();
                {}
            }
        }
        wait 1;
    }
}

function private rw_category(slot)
{
    switch (slot)
    {
        case "scope": case "optic": return 1;
        case "muzzle": return 2;
        case "frontpiece": case "barrel": return 3;
        case "underbarrel": case "undermount": return 4;
        case "magazine": case "loader": return 5;
        case "reargrip": return 6;
        case "backpiece": case "stock": return 7;
        case "laser": case "other": case "extra": return 8;
        case "modifier": case "trigger": case "firemod": case "gunperk": return 9;
    }
    return 0;
}

// Physical engine slots are NOT Gunsmith categories: Fire Mods can use "other",
// while an underbarrel can use "trigger". Read the same bundle category as Lua.
function private rw_att_category(w, att)
{
    bundle = function_333a08591af6b59(w, att);
    if (!isdefined(bundle)) return 0;
    fields = getscriptbundlefieldvalues(bundle, [#"category"]);
    if (!isdefined(fields) || !isdefined(fields.category) || fields.category == "") return 0;
    category = getscriptbundlefieldvalues(fields.category, [#"ref", #"parent"]);
    if (!isdefined(category)) return 0;
    if (isdefined(category.parent) && category.parent != "")
    {
        parent = getscriptbundlefieldvalues(category.parent, [#"ref"]);
        if (isdefined(parent) && isdefined(parent.ref)) return rw_category(parent.ref);
    }
    if (isdefined(category.ref)) return rw_category(category.ref);
    return 0;
}

function private rw_default(w, att)
{
    if (arraycontains(getweapondefaultattachments(w.basename) ?? [], att)) return 1;
    bundle = function_333a08591af6b59(w, att);
    if (!isdefined(bundle)) return 0;
    fields = getscriptbundlefieldvalues(bundle, [#"isdefault"]);
    return isdefined(fields) && istrue(fields.isdefault);
}

function private rw_hidden(w, att)
{
    bundle = function_333a08591af6b59(w, att);
    if (!isdefined(bundle)) return 0;
    fields = getscriptbundlefieldvalues(bundle, [#"hideinui"]);
    return isdefined(fields) && istrue(fields.hideinui);
}

// Receiver/default parts live in native build fields that generic attachment
// mutation/membership does not always cover. Use the actual serialized part list.
function private rw_has_part(w, ref)
{
    return isdefined(w) && !isnullweapon(w) && arraycontains(getweaponattachments(w) ?? [], ref);
}

function private rw_trace(msg)
{}

function private rw_trace_build(label, w)
{}

function private rw_trace_diff(before, after)
{}


function private rw_current()
{
    {}
    self.rw.current = self getcurrentweapon();
    if (!isdefined(self.rw.current) || isnullweapon(self.rw.current)) { {} return undefined; }
    {}
    return self.rw.current getnoaltweapon();
}

function private rw_listen()
{
    self endon(#"disconnect");
    while (1)
    {
        self waittill(#"luinotifyserver", channel, value);
        if (channel == #"arsenal_close" || ("" + channel) == "arsenal_close") self rw_cancel();
        if (channel != #"bongo_item_unlock_status_is_locked" && ("" + channel) != "bongo_item_unlock_status_is_locked") continue;
        if (!isdefined(value) || value < 17301504 || value >= 17760256)
        {
            if (self.rw.outside < 8) {}
            self.rw.outside++;
            continue;
        }
        {}
        self.rw.seq = int((value - 16777216) / 65536);
        self.rw.arg = (value - 16777216) % 65536;
        {}
        if (self.rw.seq == 12) { self rw_cancel(); continue; }
        if (self.rw.seq == 13)
        {
            if (self.rw.arg == 1) { if (istrue(self.rw.camo_mode)) self rw_cancel(); continue; }
            if (self.rw.arg != 0 || self.rw.busy) continue;
            self thread rm_open(); continue;
        }
        if (self.rw.seq == 14)
        {
            if (!istrue(self.rw.camo_mode) || self.rw.busy) continue;
            self thread rm_purchase(self.rw.arg, self.rw.epoch); continue;
        }
        if (self.rw.seq == 10)
        {
            self.rw.arg = self rw_index_target(self.rw.arg);
            if (self.rw.arg < 0) { {} if (!self.rw.busy) self rw_publish(3, 3); continue; }
            self.rw.op = 3;
        }
        else if (self.rw.seq == 8) self.rw.op = 0;
        else if (self.rw.seq == 9) self.rw.op = 2;
        else continue; // No ID chunks or client build frames are accepted.
        {}
        if (self.rw.busy) { {} continue; }
        if (self.rw.op == 0) self.rw.epoch++;
        self thread rw_request(self.rw.op, self.rw.arg, self.rw.epoch);
    }
}

function private rw_cancel()
{
    if (istrue(self.rw.trace_active)) { {} self.rw.trace_active = 0; }
    {}
    self.rw.active = 0;
    self.rw.high = undefined;
    self.rw.plan_token = undefined;
    self.rw.plan_words = [];
    self.rw.plan_started = 0;
    self.rw.plan_done = 0;
    self.rw.busy = 0;
    self.rw.epoch++;
    self notify(#"rw_publish_cancel");
    {}
}

function private rw_request(op, arg, epoch)
{
    self.rw.busy = 1;
    self.rw.stage = "dispatch";
    {}
    if (!isalive(self)) { {} self.rw.busy = 0; return; }
    if (op == 0)
    {
        self.rw.camo_mode = 0;
        self notify(#"recrud_aug_pub");
        self.rw.active = 1;
        self.rw.origin = self.origin;
        self.rw.stage = "open-held-snapshot";
        self.rw.editweapon = self rw_current();
        self.rw.category = 0;
        self.rw.plan_catalog = undefined;
        {}
        if (!isdefined(self.rw.editweapon) || weapon::isfistweapon(self.rw.editweapon)) self rw_publish(3, 2);
        else self rw_publish(0, 0);
        self.rw.busy = 0;
        return;
    }
    self.rw.stage = "session-validation";
    {}
    if (!self.rw.active || distancesquared(self.origin, self.rw.origin) > 16384)
    {
        self rw_publish(3, 1);
        self.rw.busy = 0;
        return;
    }
    if (op == 2 && arg >= 1 && arg <= 9)
    {
        if (isdefined(self.rw.editweapon) && self.rw.editweapon == self rw_current())
        {
            self.rw.stage = "category-accepted";
            self.rw.category = arg;
            {}
            self rw_publish(2, 0);
        }
        else self rw_publish(3, 3);
    }
    else if (op == 3)
    {
        self rw_purchase(arg, epoch);
    }
    if (epoch == self.rw.epoch) self.rw.busy = 0;
    {}
}

function private rw_publish(mode, result)
{
    self endon(#"disconnect");
    self endon(#"rw_publish_cancel");
    if (istrue(self.rw.camo_mode)) { self rm_reply(mode, result); return; }
    if ((mode == 3 || mode == 4) && istrue(self.rw.trace_active))
    {
        if (mode == 3 && isdefined(self.rw.candidate))
        {
            {}
            if (isdefined(self.rw.old))
            {
                {}
                {}
            }
        }
        {}
        self.rw.trace_active = 0;
    }
    if (mode == 3) {}
    self.rw.serial = (self.rw.serial + 1) % 1024;
    // The stock purchase notify is a time event: observed Lua values were game time.
    // Registering the dedicated dvar at init also makes the listen-server value readable.
    self.rw.reply = 5242880 + self.rw.serial * 1024 + mode * 128 + result * 16 + (self.rw.category ?? 0);
    {}
    // Same local server-to-Lua dvar write path as the proven recrud_dbg bridge.
    self.rw.replybuild = "";
    if (isdefined(self.rw.editweapon))
    {
        self.rw.replybuild = self.rw.editweapon.basename;
        foreach (part in getweaponattachments(self.rw.editweapon)) self.rw.replybuild += "+" + part;
    }
    // Only swaps need settling. Stop waiting as soon as the held weapon is ready;
    // retain the previous 200 ms upper bound if the engine takes longer.
    if (mode == 4)
    {
        self.rw.settle_deadline = gettime() + 200;
        for (self.rw.settle_polls = 0; self.rw.settle_polls < 200 && gettime() < self.rw.settle_deadline; self.rw.settle_polls++)
        {
            self.rw.settle_weapon = self getcurrentweapon();
            if (isdefined(self.rw.settle_weapon) && !isnullweapon(self.rw.settle_weapon) && self.rw.settle_weapon == self.rw.editweapon) break;
            wait 0.01;
        }
        {}
        {}
    }
    if (isdefined(self.rw.editweapon)) self rw_menu_catalog();
    setdvar(@"recrud_weap_reply", "" + self.rw.reply + "|" + (mode == 4 ? (self.rw.removedmask ?? 0) : 0) + "|" + self.rw.replybuild);
    {}
    {}
    {}
}

function private rw_blocks(base, blocker, other)
{
    if (arraycontains(getattachmentsblocked(base, blocker) ?? [], other)) return 1;
    if (arraycontains(getattachmentslotsblocked(base, blocker) ?? [], getattachmentslot(base, other))) return 1;
    return arraycontains(getattachmentbasetypesblocked(base, blocker) ?? [], getattachmentbasetype(base, other));
}

// Two bounded hashes identify a reference from THIS weapon's native catalog.
// A collision or unknown reference rejects the entire plan before charging.
function private rw_refhash(ref, seed, multiplier)
{
    result = seed;
    for (i = 0; i < ref.size; i++)
    {
        digit = level.rw_refdigits[getsubstr(ref, i, i + 1)];
        if (!isdefined(digit)) return -1;
        result = (result * multiplier + digit) % 65521;
    }
    return int(result);
}

function private rw_build_catalog()
{
    refs = getweaponattachments(self.rw.old);
    foreach (part in getweapondefaultattachments(self.rw.old.basename) ?? []) if (!arraycontains(refs, part)) refs[refs.size] = part;
    if (isdefined(self.rw.att) && !arraycontains(refs, self.rw.att)) refs[refs.size] = self.rw.att;
    // Same physical slot set as native ATTACHMENT.AttachmentSlots.
    slots = ["override", "scope", "modifier", "other", "extra", "trigger", "reargrip", "muzzle", "underbarrel", "magazine", "backpiece", "frontpiece", "receiver", "conversionkit", "gametype"];
    foreach (slot in slots)
    {
        foreach (part in function_2e5ecdd8ac47f308(self.rw.old.basename, slot, 0) ?? [])
        {
            if (!arraycontains(refs, part)) refs[refs.size] = part;
        }
    }
    catalog = [];
    foreach (part in refs)
    {
        row = spawnstruct(); row.ref = part;
        row.h1 = rw_refhash(part, 1, 33); row.h2 = rw_refhash(part, 7, 131);
        if (row.h1 >= 0 && row.h2 >= 0) catalog[catalog.size] = row;
    }
    self.rw.plan_catalog = catalog;
    {}
}

function private rw_packhash16(value)
{
    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_";
    return getsubstr(alphabet, int(value / 4096), int(value / 4096) + 1) + getsubstr(alphabet, int(value / 64) % 64, int(value / 64) % 64 + 1) + getsubstr(alphabet, value % 64, value % 64 + 1);
}

// A request-scoped dictionary defines the exact bit index on both sides. Share
// hash pairs rather than long names; 144 refs fit safely in one bounded dvar.
function private rw_publish_catalog()
{
    self.rw.bitmap_catalog_valid = self.rw.plan_catalog.size > 0 && self.rw.plan_catalog.size <= 144;
    self.rw.catalog_seen = [];
    self.rw.catalog_wire = "";
    if (self.rw.bitmap_catalog_valid)
    {
        foreach (row in self.rw.plan_catalog)
        {
            key = "" + row.h1 + ":" + row.h2;
            if (isdefined(self.rw.catalog_seen[key])) { self.rw.bitmap_catalog_valid = 0; break; }
            self.rw.catalog_seen[key] = 1;
            self.rw.catalog_wire += rw_packhash16(row.h1) + rw_packhash16(row.h2);
        }
    }
    if (self.rw.bitmap_catalog_valid) setdvar(@"recrud_weap_catalog", "" + self.rw.plan_token + "|" + self.rw.plan_catalog.size + "|" + self.rw.catalog_wire);
    else setdvar(@"recrud_weap_catalog", "" + self.rw.plan_token + "|0|");
    {}
}

function private rw_constructor_probe()
{}

function private rw_purchase(id, epoch)
{
    self.rw.transaction = (self.rw.transaction ?? 0) + 1;
    self.rw.trace_active = 1;
    self.rw.candidate = undefined;
    self.rw.charged = 0;
    self.rw.refunded = 0;
    {}
    {}
    {}
    self.rw.stage = "purchase-target";
    {}
    self.rw.att = undefined;
    self.rw.old = self.rw.editweapon;
    if (!isdefined(self.rw.category) || self.rw.category < 1 || self.rw.category > 9 || !isdefined(self.rw.old))
    {
        self rw_publish(3, 3); return;
    }
    if (self.rw.old != self rw_current() || !(self hasweapon(self.rw.old)))
    {
        self rw_publish(3, 3); return;
    }
    self.rw.atts = getweaponattachments(self.rw.old);
    self.rw.removedmask = 0;
    self.rw.att = undefined;
    if (id > 0)
    {
        self.rw.ref = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(id);
        if (!isdefined(self.rw.ref) || self.rw.ref == "") { self rw_publish(3, 4); return; }
        self.rw.att = function_c9ae02897389d9b0(function_99ee3cf75e2291a6(%"hash_3c2c9813bb16552f", self.rw.ref), #"hash_3be72d7e1d0b16e5");
        if (!isdefined(self.rw.att) || rw_att_category(self.rw.old, self.rw.att) != self.rw.category) { self rw_publish(3, 4); return; }
        if (rw_default(self.rw.old, self.rw.att) || rw_hidden(self.rw.old, self.rw.att) || rw_has_part(self.rw.old, self.rw.att)) { self rw_publish(3, 5); return; }
    }
    else
    {
        self.rw.removable = 0;
        foreach (part in self.rw.atts) if (rw_att_category(self.rw.old, part) == self.rw.category && !rw_default(self.rw.old, part) && !rw_hidden(self.rw.old, part)) self.rw.removable = 1;
        if (!self.rw.removable) { self rw_publish(3, 5); return; }
    }
    self.rw.stage = "server-whole-build";
    self.rw.plan_success = self rw_server_plan(epoch);
    if (epoch != self.rw.epoch) return;
    if (!self.rw.plan_success) { self rw_publish(3, 6); return; }
    if (id > 0 && !rw_has_part(self.rw.candidate, self.rw.att)) { self rw_publish(3, 4); return; }
    foreach (part in self.rw.atts)
    {
        if (id == 0 && rw_att_category(self.rw.old, part) == self.rw.category && !rw_default(self.rw.old, part) && !rw_hidden(self.rw.old, part) && rw_has_part(self.rw.candidate, part)) { self rw_publish(3, 4); return; }
        if (!rw_has_part(self.rw.candidate, part) && !rw_default(self.rw.old, part))
        {
            self.rw.removecat = rw_att_category(self.rw.old, part);
            if (self.rw.removecat > 0) self.rw.removedmask |= 1 << (self.rw.removecat - 1);
        }
    }
    self.rw.cost = id > 0 ? 10 : 0;
    self rw_commit(id, epoch);
}

// Shared, already validated weapon swap, metadata restore, and rollback path.
function private rw_commit(id, epoch)
{
    {}
    {}
    {}
    self.rw.stage = "load-assets";
    {}
    self.rw.load_started_ms = gettime();
    self loadweaponsforplayer([self.rw.candidate], 1);
    self.rw.load_deadline = self.rw.load_started_ms + 3000;
    for (self.rw.loading = 0; self.rw.loading < 300 && gettime() < self.rw.load_deadline && !(self hasloadedviewweapons([self.rw.candidate])); self.rw.loading++) wait 0.01;
    {}
    if (epoch != self.rw.epoch) { {} return; }
    if (!(self hasloadedviewweapons([self.rw.candidate]))) { self rw_publish(3, 6); return; }
    self.rw.stage = "post-load-session-validation";
    if (!isalive(self) || !self.rw.active || distancesquared(self.origin, self.rw.origin) > 16384 || self.rw.old != self rw_current())
    {
        self rw_publish(3, 3); return;
    }
    {}
    self.rw.stage = "snapshot-weapon-metadata";
    self.rw.wasmelee = (self getweaponmeleeslot()) == self.rw.old;
    self.rw.data = self item_weapon::function_92b8514cdacab7f9(self.rw.old);
    {}
    // Taking/re-giving a gun can reorder primaryinventory. Save every weapon's
    // metadata, so editing slot 1 cannot reset another slot's rarity/ammo mod.
    self.rw.metaweapons = [];
    self.rw.metadata = [];
    for (self.rw.mi = 0; self.rw.mi < self.primaryinventory.size; self.rw.mi++)
    {
        self.rw.metaweapons[self.rw.mi] = self.primaryinventory[self.rw.mi];
        self.rw.metadata[self.rw.mi] = self.var_1a87a9e7cf39ff69[self.rw.mi];
        {}
    }
    self.rw.pap = self pack_a_punch::get_pap_level(self.rw.old);
    self.rw.clip = self getweaponammoclip(self.rw.old) ?? 0;
    self.rw.left = self.rw.old.isdualwield ? (self getweaponammoclip(self.rw.old, "left") ?? 0) : 0;
    self.rw.stock = self getweaponammostock(self.rw.old) ?? 0;
    self.rw.held = self getcurrentweapon();
    {}
    self.rw.stage = "payment";
    {}
    if (self.rw.cost > 0 && !(self currency::attempt_purchase(#"salvage", self.rw.cost, 1, undefined, #"wallbuy"))) { self rw_publish(3, 7); return; }
    self.rw.charged = self.rw.cost;
    // No waits between payment and commit/rollback. All validation precedes payment.
    {}
    self.rw.stage = "swap";
    self takeweapon(self.rw.old);
    {}
    self giveweapon(self.rw.candidate, undefined, 0, -1, 0);
    {}
    if (!(self hasweapon(self.rw.candidate)))
    {
        {}
        self giveweapon(self.rw.old, undefined, 0, -1, 0);
        self setweaponammoclip(self.rw.old, self.rw.clip);
        if (self.rw.old.isdualwield) self setweaponammoclip(self.rw.old, self.rw.left, "left");
        self setweaponammostock(self.rw.old, self.rw.stock);
        self rw_restore_data(self.rw.old, self.rw.old);
        if (self.rw.held == self.rw.old) self switchtoweapon(self.rw.old);
        if (self.rw.cost > 0) self currency::add_currency_amount(#"salvage", self.rw.cost, #"wallbuy");
        self.rw.refunded = self.rw.cost;
        {}
        self rw_publish(3, 6); return;
    }
    self.rw.stage = "restore-metadata";
    self rw_restore_data(self.rw.candidate, self.rw.old);
    if (!isarray(self.recrud_edited_weapon_builds)) self.recrud_edited_weapon_builds = [];
    self.recrud_edited_weapon_builds[self.recrud_edited_weapon_builds.size] = self.rw.candidate;
    self.rw.stage = "restore-ammo";
    self.rw.overflow = max(0, self.rw.clip - weaponclipsize(self.rw.candidate));
    if (self.rw.candidate.isdualwield) self.rw.overflow += max(0, self.rw.left - weaponclipsize(self.rw.candidate));
    else self.rw.overflow += self.rw.left;
    self setweaponammoclip(self.rw.candidate, min(self.rw.clip, weaponclipsize(self.rw.candidate)));
    if (self.rw.candidate.isdualwield) self setweaponammoclip(self.rw.candidate, min(self.rw.left, weaponclipsize(self.rw.candidate)), "left");
    self setweaponammostock(self.rw.candidate, self.rw.stock + self.rw.overflow);
    {}
    self.rw.stage = "restore-held-and-notify";
    self.rw.editweapon = self.rw.candidate;
    if (self.rw.held == self.rw.old) self switchtoweapon(self.rw.candidate);
    else if (self hasweapon(self.rw.held)) self switchtoweapon(self.rw.held);
    self item_weapon::function_cf9036e07d207279(self.rw.candidate);
    {}
    {}
    {}
    self rw_publish(4, 0);
}

function private rw_restore_data(w, previous)
{
    {}
    // Use the actual native melee slot; these replace two unresolved script imports.
    if (self.rw.wasmelee) self assignweaponmeleeslot(w);
    else self assignweaponprimaryslot(w);
    for (self.rw.i = 0; self.rw.i < self.primaryinventory.size; self.rw.i++)
    {
        self.rw.swapmeta = undefined;
        if (self.primaryinventory[self.rw.i] == w) self.rw.swapmeta = self.rw.data;
        else
        {
            for (self.rw.j = 0; self.rw.j < self.rw.metaweapons.size; self.rw.j++)
            {
                if (self.rw.metaweapons[self.rw.j] == self.primaryinventory[self.rw.i])
                {
                    self.rw.swapmeta = self.rw.metadata[self.rw.j]; break;
                }
            }
        }
        if (isdefined(self.rw.swapmeta)) self.var_1a87a9e7cf39ff69[self.rw.i] = self.rw.swapmeta;
        {}
    }
    if (isdefined(self.rw.data))
    {
        self.rw.data.attachments = w.attachments;
        self.rw.data.variantid = w.variantid;
        self.rw.data.camo = w.camo;
    }
    self pack_a_punch::function_3f3b9cdbb4843e45(w, self.rw.pap, 1, previous);
    {}
}

function private rlog(msg)
{}

// Server-side attachment assembly. UI sends a selection index, never build parts.
function private rw_rule_blocks(w, blocker, other)
{
    if (arraycontains(getattachmentsblocked(w, blocker) ?? [], other)) return 1;
    if (arraycontains(getattachmentslotsblocked(w, blocker) ?? [], getattachmentslot(w, other))) return 1;
    return arraycontains(getattachmentbasetypesblocked(w, blocker) ?? [], getattachmentbasetype(w, other));
}

function private rw_extras(w, parts)
{
    result = [];
    owners = [];
    foreach (part in parts) if (!arraycontains(owners, part)) owners[owners.size] = part;
    for (i = 0; i < owners.size && i < 96; i++)
    {
        bundle = function_333a08591af6b59(w, owners[i]);
        if (!isdefined(bundle)) continue;
        fields = getscriptbundlefieldvalues(bundle, [#"attachextralist"]);
        if (!isdefined(fields) || !isdefined(fields.attachextralist)) continue;
        foreach (entry in fields.attachextralist)
        {
            extra = isstring(entry) ? entry : entry.attachmentextra;
            if (!isdefined(extra) || extra == "" || extra == "none") continue;
            if (!arraycontains(result, extra)) { result[result.size] = extra; {} }
            if (!arraycontains(owners, extra)) owners[owners.size] = extra;
        }
    }
    return result;
}

// A later explicit/generated part displaces the same physical slot or parts it
// blocks. An earlier different-slot blocker still prevents an illegal selection.
function private rw_server_insert(att)
{
    // Preserve only the held gun's game-type layer, including PaP variants.
    if (getattachmentslot(self.rw.old.basename, att) == "gametype") return 1;
    self.rw.assembly_next = [];
    foreach (part in self.rw.assembly_parts)
    {
        if (part == att) return 1;
        if (getattachmentslot(self.rw.old.basename, part) != getattachmentslot(self.rw.old.basename, att)
            && !rw_rule_blocks(self.rw.old.basename, att, part)
            && rw_rule_blocks(self.rw.old.basename, part, att)) return 0;
    }
    foreach (part in self.rw.assembly_parts)
    {
        if (getattachmentslot(self.rw.old.basename, part) == getattachmentslot(self.rw.old.basename, att)
            || rw_rule_blocks(self.rw.old.basename, att, part)) continue;
        self.rw.assembly_next[self.rw.assembly_next.size] = part;
    }
    self.rw.assembly_next[self.rw.assembly_next.size] = att;
    self.rw.assembly_parts = self.rw.assembly_next;
    return 1;
}

function private rw_server_plan(epoch)
{
    self.rw.server_started_ms = gettime();
    self.rw.old_extras = rw_extras(self.rw.old, self.rw.atts);
    self.rw.explicit_parts = [];
    foreach (part in self.rw.atts)
    {
        if (getattachmentslot(self.rw.old.basename, part) == "gametype") continue;
        if (rw_default(self.rw.old, part) || rw_hidden(self.rw.old, part) || arraycontains(self.rw.old_extras, part)) continue;
        if (rw_att_category(self.rw.old, part) == self.rw.category) continue;
        if (isdefined(self.rw.att) && rw_rule_blocks(self.rw.old.basename, self.rw.att, part)) continue;
        self.rw.explicit_parts[self.rw.explicit_parts.size] = part;
    }
    if (isdefined(self.rw.att)) self.rw.explicit_parts[self.rw.explicit_parts.size] = self.rw.att;
    // Re-run from explicit choices until kit-only dependencies stop changing.
    for (self.rw.assembly_pass = 0; self.rw.assembly_pass < 49; self.rw.assembly_pass++)
    {
        self.rw.assembly_extras = rw_extras(self.rw.old, self.rw.explicit_parts);
        self.rw.probe_parts = [];
        foreach (part in self.rw.explicit_parts) self.rw.probe_parts[self.rw.probe_parts.size] = part;
        foreach (part in self.rw.assembly_extras) if (!arraycontains(self.rw.probe_parts, part)) self.rw.probe_parts[self.rw.probe_parts.size] = part;
        foreach (part in self.rw.atts) if (getattachmentslot(self.rw.old.basename, part) == "gametype" && !arraycontains(self.rw.probe_parts, part)) self.rw.probe_parts[self.rw.probe_parts.size] = part;
        // Field-backed arguments/results avoid the observed BO7 local-clobber bug.
        self.rw.probe = weapon::buildweapon(self.rw.old.basename, self.rw.probe_parts);
        if (!isdefined(self.rw.probe) || isnullweapon(self.rw.probe)) return 0;
        self.rw.assembly_defaults = getweapondefaultattachments(self.rw.probe) ?? [];
        {}
        self.rw.assembly_parts = [];
        foreach (part in self.rw.assembly_defaults) self rw_server_insert(part);
        foreach (part in self.rw.explicit_parts) self rw_server_insert(part);
        foreach (part in self.rw.assembly_extras) self rw_server_insert(part);
        foreach (part in self.rw.atts) if (getattachmentslot(self.rw.old.basename, part) == "gametype" && !arraycontains(self.rw.assembly_parts, part)) self.rw.assembly_parts[self.rw.assembly_parts.size] = part;
        self.rw.assembly_changed = 0;
        self.rw.explicit_next = [];
        foreach (part in self.rw.explicit_parts)
        {
            self.rw.part_available = arraycontains(self.rw.assembly_parts, part);
            foreach (required in getrequiredattachments(self.rw.probe, part) ?? [])
                if (!arraycontains(self.rw.assembly_parts, required)) self.rw.part_available = 0;
            if (!self.rw.part_available)
            {
                if (part == self.rw.att) { {} return 0; }
                {}
                self.rw.assembly_changed = 1;
            }
            else self.rw.explicit_next[self.rw.explicit_next.size] = part;
        }
        self.rw.explicit_parts = self.rw.explicit_next;
        if (!self.rw.assembly_changed) break;
    }
    if (self.rw.assembly_changed || self.rw.assembly_parts.size < 1 || self.rw.assembly_parts.size > 48) return 0;
    // Validate every generated/default dependency too; do not give a partial kit.
    foreach (part in self.rw.assembly_parts)
        foreach (required in getrequiredattachments(self.rw.probe, part) ?? [])
            if (!arraycontains(self.rw.assembly_parts, required)) { {} return 0; }
    self.rw.plan_parts = self.rw.assembly_parts;
    self.rw.plan_metadata = self item_weapon::function_92b8514cdacab7f9(self.rw.old);
    self.rw.plan_stickers = undefined;
    if (isdefined(self.rw.plan_metadata)) self.rw.plan_stickers = [self.rw.plan_metadata.stickerslot0, self.rw.plan_metadata.stickerslot1, self.rw.plan_metadata.stickerslot2, self.rw.plan_metadata.stickerslot3, self.rw.plan_metadata.var_73762c7cb8b2063];
    self.rw.candidate = weapon::buildweapon(self.rw.old.basename, self.rw.plan_parts, self.rw.old.camo, self.rw.old.reticle, self.rw.old.variantid, undefined, undefined, self.rw.plan_stickers);
    if (epoch != self.rw.epoch || !isdefined(self.rw.candidate) || isnullweapon(self.rw.candidate) || self.rw.candidate.basename != self.rw.old.basename) return 0;
    foreach (part in self.rw.plan_parts) if (!rw_has_part(self.rw.candidate, part)) { {} return 0; }
    foreach (part in getweaponattachments(self.rw.candidate)) if (!arraycontains(self.rw.plan_parts, part)) { {} return 0; }
    {}
    return 1;
}

// Refresh the server-owned lookup before publishing a new authoritative page.
function private rw_menu_catalog()
{
    self.rw.old = self.rw.editweapon;
    self rw_build_catalog();
    self.rw.menu_catalog = self.rw.plan_catalog;
    self.rw.menu_token = self.rw.serial % 128;
    self.rw.plan_token = self.rw.menu_token;
    self rw_publish_catalog();
    self.rw.menu_catalog_valid = self.rw.bitmap_catalog_valid;
    self.rw.index_weapon = self.rw.editweapon;
    self.rw.plan_token = undefined;
}

function private rw_index_target(value)
{
    if (!self.rw.active || self.rw.busy || !istrue(self.rw.menu_catalog_valid)) return -1;
    if (int(value / 256) != self.rw.menu_token || self.rw.index_weapon != self.rw.editweapon) return -1;
    self.rw.selection_index = value % 256;
    if (!self.rw.selection_index) return 0;
    if (self.rw.selection_index > self.rw.menu_catalog.size) return -1;
    self.rw.selection_ref = self.rw.menu_catalog[self.rw.selection_index - 1].ref;
    if (rw_att_category(self.rw.editweapon, self.rw.selection_ref) != self.rw.category) return -1;
    self.rw.selection_bundle = function_333a08591af6b59(self.rw.editweapon, self.rw.selection_ref);
    if (!isdefined(self.rw.selection_bundle)) return -1;
    self.rw.selection_fields = getscriptbundlefieldvalues(self.rw.selection_bundle, [#"lootid"]);
    if (!isdefined(self.rw.selection_fields) || !isdefined(self.rw.selection_fields.lootid) || self.rw.selection_fields.lootid < 1) return -1;
    return self.rw.selection_fields.lootid;
}

// Camos: a fixed server catalog, one index request, no client weapon/build upload.
// Sequences 13 (open/close) and 14 (selection) are excluded by Augments already.
function private rm_index(w)
{
    if (!isdefined(w) || isnullweapon(w) || !isdefined(w.camo)) return 0;
    for (ci = 1; ci <= 2412; ci++) if (w.camo == level.rm_refs[ci]) return ci;
    return 0;
}

function private rm_reply(mode, result)
{
    self.rw.serial = (self.rw.serial + 1) % 1024;
    self.rw.trace_active = 0;
    self.rw.camo_index = rm_index(self.rw.editweapon);
    self.rw.camo_reply = "" + self.rw.serial + "|" + mode + "|" + result + "|" + self.rw.camo_index + "|" + (self.rw.epoch % 16);
    setdvar(@"recrud_camo_reply", self.rw.camo_reply);
    {}
}

function private rm_open()
{
    if (!isalive(self)) return;
    self rw_cancel();
    self.rw.busy = 1;
    self.rw.camo_mode = 1;
    self.rw.active = 1;
    self.rw.origin = self.origin;
    self.rw.editweapon = self rw_current();
    self.rw.stage = "camo-open";
    if (!isdefined(self.rw.editweapon) || weapon::isfistweapon(self.rw.editweapon)) self rw_publish(3, 2);
    else self rw_publish(0, 0);
    self.rw.busy = 0;
}

function private rm_purchase(value, epoch)
{
    self.rw.busy = 1;
    self.rw.stage = "camo-validation";
    self.rw.transaction = (self.rw.transaction ?? 0) + 1;
    self.rw.trace_active = 1;
    self.rw.charged = 0;
    self.rw.candidate = undefined;
    self.rw.camo_selection = value % 4096;
    self.rw.old = self.rw.editweapon;
    {}
    if (!isalive(self) || !self.rw.active || epoch != self.rw.epoch || int(value / 4096) != epoch % 16 || distancesquared(self.origin, self.rw.origin) > 16384 || self.rw.old != self rw_current() || !(self hasweapon(self.rw.old)))
    {
        self rw_publish(3, 3); self.rw.busy = 0; return;
    }
    if (self.rw.camo_selection < 0 || self.rw.camo_selection > 2412)
    {
        self rw_publish(3, 4); self.rw.busy = 0; return;
    }
    self.rw.camo_target = self.rw.camo_selection ? level.rm_refs[self.rw.camo_selection] : undefined;
    // Two exported references do not resolve to bundles in the current game.
    if (self.rw.camo_target == "cer_camo_parachute_03_wz" || self.rw.camo_target == "sat_camo_temp_01")
    {
        self rw_publish(3, 4); self.rw.busy = 0; return;
    }
    if (rm_index(self.rw.old) == self.rw.camo_selection)
    {
        self rw_publish(4, 0); self.rw.busy = 0; return;
    }
    self.rw.camo_data = self item_weapon::function_92b8514cdacab7f9(self.rw.old);
    self.rw.camo_stickers = undefined;
    if (isdefined(self.rw.camo_data)) self.rw.camo_stickers = [self.rw.camo_data.stickerslot0, self.rw.camo_data.stickerslot1, self.rw.camo_data.stickerslot2, self.rw.camo_data.stickerslot3, self.rw.camo_data.var_73762c7cb8b2063];
    self.rw.candidate = weapon::buildweapon(self.rw.old.basename, getweaponattachments(self.rw.old), self.rw.camo_target, self.rw.old.reticle, self.rw.old.variantid, undefined, undefined, self.rw.camo_stickers);
    if (!isdefined(self.rw.candidate) || isnullweapon(self.rw.candidate) || self.rw.candidate.basename != self.rw.old.basename || rm_index(self.rw.candidate) != self.rw.camo_selection)
    {
        self rw_publish(3, 6); self.rw.busy = 0; return;
    }
    foreach (part in getweaponattachments(self.rw.old)) if (!rw_has_part(self.rw.candidate, part)) { self rw_publish(3, 6); self.rw.busy = 0; return; }
    foreach (part in getweaponattachments(self.rw.candidate)) if (!rw_has_part(self.rw.old, part)) { self rw_publish(3, 6); self.rw.busy = 0; return; }
    self.rw.cost = 0;
    self.rw.removedmask = 0;
    {}
    self rw_commit(self.rw.camo_selection, epoch);
    if (epoch == self.rw.epoch) self.rw.busy = 0;
}

function private rm_init_catalog()
{
    level.rm_refs = [];
    rm_catalog_0();
    rm_catalog_1();
    rm_catalog_2();
    rm_catalog_3();
    rm_catalog_4();
    rm_catalog_5();
    rm_catalog_6();
    rm_catalog_7();
    rm_catalog_8();
    rm_catalog_9();
    rm_catalog_10();
    rm_catalog_11();
    rm_catalog_12();
    rm_catalog_13();
    rm_catalog_14();
    rm_catalog_15();
    rm_catalog_16();
    rm_catalog_17();
    rm_catalog_18();
    rm_catalog_19();
    rm_catalog_20();
    rm_catalog_21();
    rm_catalog_22();
    rm_catalog_23();
    rm_catalog_24();
}
function private rm_catalog_0()
{
    level.rm_refs[1] = "camo_a_02";
    level.rm_refs[2] = "camo_a_03";
    level.rm_refs[3] = "camo_a_04";
    level.rm_refs[4] = "camo_a_05";
    level.rm_refs[5] = "camo_a_06";
    level.rm_refs[6] = "camo_a_07";
    level.rm_refs[7] = "camo_a_08";
    level.rm_refs[8] = "camo_a_09";
    level.rm_refs[9] = "camo_a_10";
    level.rm_refs[10] = "camo_a_11";
    level.rm_refs[11] = "camo_a_12";
    level.rm_refs[12] = "camo_a_13";
    level.rm_refs[13] = "camo_a_14";
    level.rm_refs[14] = "camo_a_15";
    level.rm_refs[15] = "camo_b_01";
    level.rm_refs[16] = "camo_b_02";
    level.rm_refs[17] = "camo_b_03";
    level.rm_refs[18] = "camo_b_04";
    level.rm_refs[19] = "camo_b_05";
    level.rm_refs[20] = "camo_b_06";
    level.rm_refs[21] = "camo_b_07";
    level.rm_refs[22] = "camo_b_08";
    level.rm_refs[23] = "camo_b_09";
    level.rm_refs[24] = "camo_b_10";
    level.rm_refs[25] = "camo_b_11";
    level.rm_refs[26] = "camo_b_12";
    level.rm_refs[27] = "camo_b_13";
    level.rm_refs[28] = "camo_b_14";
    level.rm_refs[29] = "camo_b_15";
    level.rm_refs[30] = "camo_c_01";
    level.rm_refs[31] = "camo_c_02";
    level.rm_refs[32] = "camo_c_03";
    level.rm_refs[33] = "camo_c_04";
    level.rm_refs[34] = "camo_c_05";
    level.rm_refs[35] = "camo_c_06";
    level.rm_refs[36] = "camo_c_07";
    level.rm_refs[37] = "camo_c_08";
    level.rm_refs[38] = "camo_c_09";
    level.rm_refs[39] = "camo_c_10";
    level.rm_refs[40] = "camo_c_11";
    level.rm_refs[41] = "camo_c_12";
    level.rm_refs[42] = "camo_c_13";
    level.rm_refs[43] = "camo_c_14";
    level.rm_refs[44] = "camo_c_15";
    level.rm_refs[45] = "camo_cdl_01";
    level.rm_refs[46] = "camo_cdl_02";
    level.rm_refs[47] = "camo_cdl_03";
    level.rm_refs[48] = "camo_cdl_04";
    level.rm_refs[49] = "camo_cdl_05";
    level.rm_refs[50] = "camo_cdl_06";
    level.rm_refs[51] = "camo_cdl_07";
    level.rm_refs[52] = "camo_cdl_08";
    level.rm_refs[53] = "camo_cdl_09";
    level.rm_refs[54] = "camo_cdl_10";
    level.rm_refs[55] = "camo_cdl_11";
    level.rm_refs[56] = "camo_cdl_12";
    level.rm_refs[57] = "camo_cdl_13";
    level.rm_refs[58] = "camo_comp_01";
    level.rm_refs[59] = "camo_comp_02";
    level.rm_refs[60] = "camo_comp_03";
    level.rm_refs[61] = "camo_comp_04";
    level.rm_refs[62] = "camo_d_01";
    level.rm_refs[63] = "camo_d_02";
    level.rm_refs[64] = "camo_d_03";
    level.rm_refs[65] = "camo_d_04";
    level.rm_refs[66] = "camo_d_05";
    level.rm_refs[67] = "camo_d_06";
    level.rm_refs[68] = "camo_d_07";
    level.rm_refs[69] = "camo_d_08";
    level.rm_refs[70] = "camo_d_09";
    level.rm_refs[71] = "camo_d_10";
    level.rm_refs[72] = "camo_d_11";
    level.rm_refs[73] = "camo_d_12";
    level.rm_refs[74] = "camo_d_13";
    level.rm_refs[75] = "camo_d_14";
    level.rm_refs[76] = "camo_d_15";
    level.rm_refs[77] = "camo_e_01";
    level.rm_refs[78] = "camo_e_02";
    level.rm_refs[79] = "camo_e_03";
    level.rm_refs[80] = "camo_e_04";
    level.rm_refs[81] = "camo_e_05";
    level.rm_refs[82] = "camo_e_06";
    level.rm_refs[83] = "camo_e_07";
    level.rm_refs[84] = "camo_e_08";
    level.rm_refs[85] = "camo_e_09";
    level.rm_refs[86] = "camo_e_10";
    level.rm_refs[87] = "camo_e_11";
    level.rm_refs[88] = "camo_e_12";
    level.rm_refs[89] = "camo_e_13";
    level.rm_refs[90] = "camo_e_14";
    level.rm_refs[91] = "camo_e_15";
    level.rm_refs[92] = "camo_f_01";
    level.rm_refs[93] = "camo_f_02";
    level.rm_refs[94] = "camo_f_03";
    level.rm_refs[95] = "camo_f_04";
    level.rm_refs[96] = "camo_f_05";
    level.rm_refs[97] = "camo_f_06";
    level.rm_refs[98] = "camo_f_07";
    level.rm_refs[99] = "camo_f_08";
    level.rm_refs[100] = "camo_f_09";
}
function private rm_catalog_1()
{
    level.rm_refs[101] = "camo_f_10";
    level.rm_refs[102] = "camo_f_11";
    level.rm_refs[103] = "camo_f_12";
    level.rm_refs[104] = "camo_f_13";
    level.rm_refs[105] = "camo_f_14";
    level.rm_refs[106] = "camo_f_15";
    level.rm_refs[107] = "camo_g_01";
    level.rm_refs[108] = "camo_g_02";
    level.rm_refs[109] = "camo_g_03";
    level.rm_refs[110] = "camo_g_04";
    level.rm_refs[111] = "camo_g_05";
    level.rm_refs[112] = "camo_g_06";
    level.rm_refs[113] = "camo_g_07";
    level.rm_refs[114] = "camo_g_08";
    level.rm_refs[115] = "camo_g_09";
    level.rm_refs[116] = "camo_g_10";
    level.rm_refs[117] = "camo_g_11";
    level.rm_refs[118] = "camo_g_12";
    level.rm_refs[119] = "camo_g_13";
    level.rm_refs[120] = "camo_g_14";
    level.rm_refs[121] = "camo_g_15";
    level.rm_refs[122] = "camo_h_01";
    level.rm_refs[123] = "camo_h_02";
    level.rm_refs[124] = "camo_h_03";
    level.rm_refs[125] = "camo_h_04";
    level.rm_refs[126] = "camo_h_05";
    level.rm_refs[127] = "camo_h_06";
    level.rm_refs[128] = "camo_h_07";
    level.rm_refs[129] = "camo_h_08";
    level.rm_refs[130] = "camo_h_09";
    level.rm_refs[131] = "camo_h_10";
    level.rm_refs[132] = "camo_h_11";
    level.rm_refs[133] = "camo_h_12";
    level.rm_refs[134] = "camo_h_13";
    level.rm_refs[135] = "camo_h_14";
    level.rm_refs[136] = "camo_h_15";
    level.rm_refs[137] = "camo_i_01";
    level.rm_refs[138] = "camo_i_02";
    level.rm_refs[139] = "camo_i_03";
    level.rm_refs[140] = "camo_i_04";
    level.rm_refs[141] = "camo_i_05";
    level.rm_refs[142] = "camo_i_06";
    level.rm_refs[143] = "camo_i_07";
    level.rm_refs[144] = "camo_i_08";
    level.rm_refs[145] = "camo_i_09";
    level.rm_refs[146] = "camo_i_10";
    level.rm_refs[147] = "camo_i_11";
    level.rm_refs[148] = "camo_i_12";
    level.rm_refs[149] = "camo_i_13";
    level.rm_refs[150] = "camo_i_14";
    level.rm_refs[151] = "camo_i_15";
    level.rm_refs[152] = "camo_j_01";
    level.rm_refs[153] = "camo_j_02";
    level.rm_refs[154] = "camo_j_03";
    level.rm_refs[155] = "camo_j_04";
    level.rm_refs[156] = "camo_j_05";
    level.rm_refs[157] = "camo_j_06";
    level.rm_refs[158] = "camo_j_07";
    level.rm_refs[159] = "camo_j_08";
    level.rm_refs[160] = "camo_j_09";
    level.rm_refs[161] = "camo_j_10";
    level.rm_refs[162] = "camo_j_11";
    level.rm_refs[163] = "camo_j_12";
    level.rm_refs[164] = "camo_j_13";
    level.rm_refs[165] = "camo_j_14";
    level.rm_refs[166] = "camo_j_15";
    level.rm_refs[167] = "camo_k_01";
    level.rm_refs[168] = "camo_k_02";
    level.rm_refs[169] = "camo_k_03";
    level.rm_refs[170] = "camo_k_04";
    level.rm_refs[171] = "camo_k_05";
    level.rm_refs[172] = "camo_k_06";
    level.rm_refs[173] = "camo_k_07";
    level.rm_refs[174] = "camo_k_08";
    level.rm_refs[175] = "camo_k_09";
    level.rm_refs[176] = "camo_k_10";
    level.rm_refs[177] = "camo_k_11";
    level.rm_refs[178] = "camo_k_12";
    level.rm_refs[179] = "camo_k_13";
    level.rm_refs[180] = "camo_k_14";
    level.rm_refs[181] = "camo_k_15";
    level.rm_refs[182] = "camo_l_01";
    level.rm_refs[183] = "camo_l_02";
    level.rm_refs[184] = "camo_l_03";
    level.rm_refs[185] = "camo_l_04";
    level.rm_refs[186] = "camo_l_05";
    level.rm_refs[187] = "camo_l_06";
    level.rm_refs[188] = "camo_l_07";
    level.rm_refs[189] = "camo_l_08";
    level.rm_refs[190] = "camo_l_09";
    level.rm_refs[191] = "camo_l_10";
    level.rm_refs[192] = "camo_l_11";
    level.rm_refs[193] = "camo_l_12";
    level.rm_refs[194] = "camo_l_13";
    level.rm_refs[195] = "camo_l_14";
    level.rm_refs[196] = "camo_l_15";
    level.rm_refs[197] = "camo_m_01";
    level.rm_refs[198] = "camo_m_02";
    level.rm_refs[199] = "camo_m_03";
    level.rm_refs[200] = "camo_m_04";
}
function private rm_catalog_2()
{
    level.rm_refs[201] = "camo_m_05";
    level.rm_refs[202] = "camo_m_06";
    level.rm_refs[203] = "camo_m_07";
    level.rm_refs[204] = "camo_m_08";
    level.rm_refs[205] = "camo_m_09";
    level.rm_refs[206] = "camo_m_10";
    level.rm_refs[207] = "camo_m_11";
    level.rm_refs[208] = "camo_m_12";
    level.rm_refs[209] = "camo_m_13";
    level.rm_refs[210] = "camo_m_14";
    level.rm_refs[211] = "camo_m_15";
    level.rm_refs[212] = "camo_n_01";
    level.rm_refs[213] = "camo_n_02";
    level.rm_refs[214] = "camo_n_03";
    level.rm_refs[215] = "camo_n_04";
    level.rm_refs[216] = "camo_n_05";
    level.rm_refs[217] = "camo_n_06";
    level.rm_refs[218] = "camo_n_07";
    level.rm_refs[219] = "camo_n_08";
    level.rm_refs[220] = "camo_n_09";
    level.rm_refs[221] = "camo_n_10";
    level.rm_refs[222] = "camo_n_11";
    level.rm_refs[223] = "camo_n_12";
    level.rm_refs[224] = "camo_n_13";
    level.rm_refs[225] = "camo_n_14";
    level.rm_refs[226] = "camo_n_15";
    level.rm_refs[227] = "camo_o_01";
    level.rm_refs[228] = "camo_o_02";
    level.rm_refs[229] = "camo_o_03";
    level.rm_refs[230] = "camo_o_04";
    level.rm_refs[231] = "camo_o_05";
    level.rm_refs[232] = "camo_o_06";
    level.rm_refs[233] = "camo_o_07";
    level.rm_refs[234] = "camo_o_08";
    level.rm_refs[235] = "camo_o_09";
    level.rm_refs[236] = "camo_o_10";
    level.rm_refs[237] = "camo_o_11";
    level.rm_refs[238] = "camo_o_12";
    level.rm_refs[239] = "camo_o_13";
    level.rm_refs[240] = "camo_o_14";
    level.rm_refs[241] = "camo_o_15";
    level.rm_refs[242] = "camo_p_01";
    level.rm_refs[243] = "camo_p_02";
    level.rm_refs[244] = "camo_p_03";
    level.rm_refs[245] = "camo_p_04";
    level.rm_refs[246] = "camo_p_05";
    level.rm_refs[247] = "camo_p_06";
    level.rm_refs[248] = "camo_p_07";
    level.rm_refs[249] = "camo_p_08";
    level.rm_refs[250] = "camo_p_09";
    level.rm_refs[251] = "camo_p_10";
    level.rm_refs[252] = "camo_p_11";
    level.rm_refs[253] = "camo_p_12";
    level.rm_refs[254] = "camo_p_13";
    level.rm_refs[255] = "camo_p_14";
    level.rm_refs[256] = "camo_p_15";
    level.rm_refs[257] = "camo_q_01";
    level.rm_refs[258] = "camo_q_02";
    level.rm_refs[259] = "camo_q_03";
    level.rm_refs[260] = "camo_q_04";
    level.rm_refs[261] = "camo_q_05";
    level.rm_refs[262] = "camo_q_06";
    level.rm_refs[263] = "camo_q_07";
    level.rm_refs[264] = "camo_q_08";
    level.rm_refs[265] = "camo_q_09";
    level.rm_refs[266] = "camo_q_10";
    level.rm_refs[267] = "camo_q_11";
    level.rm_refs[268] = "camo_q_12";
    level.rm_refs[269] = "camo_q_13";
    level.rm_refs[270] = "camo_q_14";
    level.rm_refs[271] = "camo_q_15";
    level.rm_refs[272] = "camo_r_01";
    level.rm_refs[273] = "camo_r_02";
    level.rm_refs[274] = "camo_r_03";
    level.rm_refs[275] = "camo_r_04";
    level.rm_refs[276] = "camo_r_05";
    level.rm_refs[277] = "camo_r_06";
    level.rm_refs[278] = "camo_r_07";
    level.rm_refs[279] = "camo_r_08";
    level.rm_refs[280] = "camo_r_09";
    level.rm_refs[281] = "camo_r_10";
    level.rm_refs[282] = "camo_r_11";
    level.rm_refs[283] = "camo_r_12";
    level.rm_refs[284] = "camo_r_13";
    level.rm_refs[285] = "camo_r_14";
    level.rm_refs[286] = "camo_s_01";
    level.rm_refs[287] = "camo_s_02";
    level.rm_refs[288] = "camo_s_03";
    level.rm_refs[289] = "camo_s_04";
    level.rm_refs[290] = "camo_s_05";
    level.rm_refs[291] = "camo_s_06";
    level.rm_refs[292] = "camo_s_07";
    level.rm_refs[293] = "camo_s_08";
    level.rm_refs[294] = "camo_s_09";
    level.rm_refs[295] = "camo_s_10";
    level.rm_refs[296] = "camo_s_11";
    level.rm_refs[297] = "camo_s_12";
    level.rm_refs[298] = "camo_s_13";
    level.rm_refs[299] = "camo_s_14";
    level.rm_refs[300] = "camo_s_15";
}
function private rm_catalog_3()
{
    level.rm_refs[301] = "camo_t_01";
    level.rm_refs[302] = "camo_t_02";
    level.rm_refs[303] = "camo_t_03";
    level.rm_refs[304] = "camo_t_04";
    level.rm_refs[305] = "camo_t_05";
    level.rm_refs[306] = "camo_t_06";
    level.rm_refs[307] = "camo_t_07";
    level.rm_refs[308] = "camo_t_08";
    level.rm_refs[309] = "camo_t_09";
    level.rm_refs[310] = "camo_t_10";
    level.rm_refs[311] = "camo_t_11";
    level.rm_refs[312] = "camo_t_12";
    level.rm_refs[313] = "camo_t_13";
    level.rm_refs[314] = "camo_t_14";
    level.rm_refs[315] = "camo_t_15";
    level.rm_refs[316] = "camo_u_01";
    level.rm_refs[317] = "camo_u_02";
    level.rm_refs[318] = "camo_u_03";
    level.rm_refs[319] = "camo_u_04";
    level.rm_refs[320] = "camo_u_05";
    level.rm_refs[321] = "camo_u_06";
    level.rm_refs[322] = "camo_u_07";
    level.rm_refs[323] = "camo_u_08";
    level.rm_refs[324] = "camo_u_09";
    level.rm_refs[325] = "camo_u_10";
    level.rm_refs[326] = "camo_u_11";
    level.rm_refs[327] = "camo_u_12";
    level.rm_refs[328] = "camo_u_13";
    level.rm_refs[329] = "camo_u_14";
    level.rm_refs[330] = "camo_u_15";
    level.rm_refs[331] = "camo_v_01";
    level.rm_refs[332] = "camo_v_02";
    level.rm_refs[333] = "camo_v_03";
    level.rm_refs[334] = "camo_v_04";
    level.rm_refs[335] = "camo_v_05";
    level.rm_refs[336] = "camo_v_06";
    level.rm_refs[337] = "camo_v_07";
    level.rm_refs[338] = "camo_v_08";
    level.rm_refs[339] = "camo_w_02";
    level.rm_refs[340] = "cer_camo_alfa_01";
    level.rm_refs[341] = "cer_camo_alfa_01_wz";
    level.rm_refs[342] = "cer_camo_alfa_01_zm";
    level.rm_refs[343] = "cer_camo_alfa_02";
    level.rm_refs[344] = "cer_camo_alfa_02_wz";
    level.rm_refs[345] = "cer_camo_alfa_02_zm";
    level.rm_refs[346] = "cer_camo_alfa_03";
    level.rm_refs[347] = "cer_camo_alfa_03_wz";
    level.rm_refs[348] = "cer_camo_alfa_03_zm";
    level.rm_refs[349] = "cer_camo_alfa_04";
    level.rm_refs[350] = "cer_camo_alfa_04_wz";
    level.rm_refs[351] = "cer_camo_alfa_04_zm";
    level.rm_refs[352] = "cer_camo_alfa_05";
    level.rm_refs[353] = "cer_camo_alfa_05_wz";
    level.rm_refs[354] = "cer_camo_alfa_05_zm";
    level.rm_refs[355] = "cer_camo_alfa_06";
    level.rm_refs[356] = "cer_camo_alfa_06_wz";
    level.rm_refs[357] = "cer_camo_alfa_06_zm";
    level.rm_refs[358] = "cer_camo_alfa_07";
    level.rm_refs[359] = "cer_camo_alfa_07_wz";
    level.rm_refs[360] = "cer_camo_alfa_07_zm";
    level.rm_refs[361] = "cer_camo_alfa_08";
    level.rm_refs[362] = "cer_camo_alfa_08_wz";
    level.rm_refs[363] = "cer_camo_alfa_08_zm";
    level.rm_refs[364] = "cer_camo_alfa_09";
    level.rm_refs[365] = "cer_camo_alfa_09_wz";
    level.rm_refs[366] = "cer_camo_alfa_09_zm";
    level.rm_refs[367] = "cer_camo_alfa_10";
    level.rm_refs[368] = "cer_camo_alfa_10_wz";
    level.rm_refs[369] = "cer_camo_alfa_10_zm";
    level.rm_refs[370] = "cer_camo_alfa_11";
    level.rm_refs[371] = "cer_camo_alfa_11_wz";
    level.rm_refs[372] = "cer_camo_alfa_11_zm";
    level.rm_refs[373] = "cer_camo_alfa_12";
    level.rm_refs[374] = "cer_camo_alfa_12_wz";
    level.rm_refs[375] = "cer_camo_alfa_12_zm";
    level.rm_refs[376] = "cer_camo_alfa_13";
    level.rm_refs[377] = "cer_camo_alfa_13_wz";
    level.rm_refs[378] = "cer_camo_alfa_13_zm";
    level.rm_refs[379] = "cer_camo_alfa_14";
    level.rm_refs[380] = "cer_camo_alfa_14_wz";
    level.rm_refs[381] = "cer_camo_alfa_14_zm";
    level.rm_refs[382] = "cer_camo_alfa_15";
    level.rm_refs[383] = "cer_camo_alfa_15_wz";
    level.rm_refs[384] = "cer_camo_alfa_15_zm";
    level.rm_refs[385] = "cer_camo_base_01_mp";
    level.rm_refs[386] = "cer_camo_base_01_wz";
    level.rm_refs[387] = "cer_camo_base_01_zm";
    level.rm_refs[388] = "cer_camo_base_02_mp";
    level.rm_refs[389] = "cer_camo_base_02_wz";
    level.rm_refs[390] = "cer_camo_base_02_zm";
    level.rm_refs[391] = "cer_camo_base_03_mp";
    level.rm_refs[392] = "cer_camo_base_03_wz";
    level.rm_refs[393] = "cer_camo_base_03_zm";
    level.rm_refs[394] = "cer_camo_base_04_mp";
    level.rm_refs[395] = "cer_camo_base_04_wz";
    level.rm_refs[396] = "cer_camo_base_04_zm";
    level.rm_refs[397] = "cer_camo_base_05_mp";
    level.rm_refs[398] = "cer_camo_base_05_wz";
    level.rm_refs[399] = "cer_camo_base_05_zm";
    level.rm_refs[400] = "cer_camo_base_06_mp";
}
function private rm_catalog_4()
{
    level.rm_refs[401] = "cer_camo_base_06_wz";
    level.rm_refs[402] = "cer_camo_base_06_zm";
    level.rm_refs[403] = "cer_camo_base_07_mp";
    level.rm_refs[404] = "cer_camo_base_07_wz";
    level.rm_refs[405] = "cer_camo_base_07_zm";
    level.rm_refs[406] = "cer_camo_base_08_mp";
    level.rm_refs[407] = "cer_camo_base_08_wz";
    level.rm_refs[408] = "cer_camo_base_08_zm";
    level.rm_refs[409] = "cer_camo_base_09_mp";
    level.rm_refs[410] = "cer_camo_base_09_wz";
    level.rm_refs[411] = "cer_camo_base_09_zm";
    level.rm_refs[412] = "cer_camo_bravo_01";
    level.rm_refs[413] = "cer_camo_bravo_01_wz";
    level.rm_refs[414] = "cer_camo_bravo_01_zm";
    level.rm_refs[415] = "cer_camo_bravo_02";
    level.rm_refs[416] = "cer_camo_bravo_02_wz";
    level.rm_refs[417] = "cer_camo_bravo_02_zm";
    level.rm_refs[418] = "cer_camo_bravo_03";
    level.rm_refs[419] = "cer_camo_bravo_03_wz";
    level.rm_refs[420] = "cer_camo_bravo_03_zm";
    level.rm_refs[421] = "cer_camo_bravo_04";
    level.rm_refs[422] = "cer_camo_bravo_04_wz";
    level.rm_refs[423] = "cer_camo_bravo_04_zm";
    level.rm_refs[424] = "cer_camo_bravo_05";
    level.rm_refs[425] = "cer_camo_bravo_05_wz";
    level.rm_refs[426] = "cer_camo_bravo_05_zm";
    level.rm_refs[427] = "cer_camo_bravo_06";
    level.rm_refs[428] = "cer_camo_bravo_06_wz";
    level.rm_refs[429] = "cer_camo_bravo_06_zm";
    level.rm_refs[430] = "cer_camo_bravo_07";
    level.rm_refs[431] = "cer_camo_bravo_07_wz";
    level.rm_refs[432] = "cer_camo_bravo_07_zm";
    level.rm_refs[433] = "cer_camo_bravo_08";
    level.rm_refs[434] = "cer_camo_bravo_08_wz";
    level.rm_refs[435] = "cer_camo_bravo_08_zm";
    level.rm_refs[436] = "cer_camo_bravo_09";
    level.rm_refs[437] = "cer_camo_bravo_09_wz";
    level.rm_refs[438] = "cer_camo_bravo_09_zm";
    level.rm_refs[439] = "cer_camo_bravo_10";
    level.rm_refs[440] = "cer_camo_bravo_10_wz";
    level.rm_refs[441] = "cer_camo_bravo_10_zm";
    level.rm_refs[442] = "cer_camo_bravo_11";
    level.rm_refs[443] = "cer_camo_bravo_11_wz";
    level.rm_refs[444] = "cer_camo_bravo_11_zm";
    level.rm_refs[445] = "cer_camo_bravo_12";
    level.rm_refs[446] = "cer_camo_bravo_12_wz";
    level.rm_refs[447] = "cer_camo_bravo_12_zm";
    level.rm_refs[448] = "cer_camo_bravo_13";
    level.rm_refs[449] = "cer_camo_bravo_13_wz";
    level.rm_refs[450] = "cer_camo_bravo_13_zm";
    level.rm_refs[451] = "cer_camo_charlie_01";
    level.rm_refs[452] = "cer_camo_charlie_01_wz";
    level.rm_refs[453] = "cer_camo_charlie_01_zm";
    level.rm_refs[454] = "cer_camo_charlie_02";
    level.rm_refs[455] = "cer_camo_charlie_02_wz";
    level.rm_refs[456] = "cer_camo_charlie_02_zm";
    level.rm_refs[457] = "cer_camo_charlie_03";
    level.rm_refs[458] = "cer_camo_charlie_03_wz";
    level.rm_refs[459] = "cer_camo_charlie_03_zm";
    level.rm_refs[460] = "cer_camo_charlie_04";
    level.rm_refs[461] = "cer_camo_charlie_04_wz";
    level.rm_refs[462] = "cer_camo_charlie_04_zm";
    level.rm_refs[463] = "cer_camo_charlie_05";
    level.rm_refs[464] = "cer_camo_charlie_05_wz";
    level.rm_refs[465] = "cer_camo_charlie_05_zm";
    level.rm_refs[466] = "cer_camo_charlie_06";
    level.rm_refs[467] = "cer_camo_charlie_06_wz";
    level.rm_refs[468] = "cer_camo_charlie_06_zm";
    level.rm_refs[469] = "cer_camo_charlie_07";
    level.rm_refs[470] = "cer_camo_charlie_07_wz";
    level.rm_refs[471] = "cer_camo_charlie_07_zm";
    level.rm_refs[472] = "cer_camo_charlie_08";
    level.rm_refs[473] = "cer_camo_charlie_08_wz";
    level.rm_refs[474] = "cer_camo_charlie_08_zm";
    level.rm_refs[475] = "cer_camo_charlie_09";
    level.rm_refs[476] = "cer_camo_charlie_09_wz";
    level.rm_refs[477] = "cer_camo_charlie_09_zm";
    level.rm_refs[478] = "cer_camo_charlie_10";
    level.rm_refs[479] = "cer_camo_charlie_10_wz";
    level.rm_refs[480] = "cer_camo_charlie_10_zm";
    level.rm_refs[481] = "cer_camo_charlie_11";
    level.rm_refs[482] = "cer_camo_charlie_11_wz";
    level.rm_refs[483] = "cer_camo_charlie_11_zm";
    level.rm_refs[484] = "cer_camo_charlie_12";
    level.rm_refs[485] = "cer_camo_charlie_12_wz";
    level.rm_refs[486] = "cer_camo_charlie_12_zm";
    level.rm_refs[487] = "cer_camo_charlie_13";
    level.rm_refs[488] = "cer_camo_charlie_13_wz";
    level.rm_refs[489] = "cer_camo_charlie_13_zm";
    level.rm_refs[490] = "cer_camo_charlie_14";
    level.rm_refs[491] = "cer_camo_charlie_14_wz";
    level.rm_refs[492] = "cer_camo_charlie_14_zm";
    level.rm_refs[493] = "cer_camo_charlie_15";
    level.rm_refs[494] = "cer_camo_charlie_15_wz";
    level.rm_refs[495] = "cer_camo_charlie_15_zm";
    level.rm_refs[496] = "cer_camo_comp_01_mp";
    level.rm_refs[497] = "cer_camo_comp_01_wz";
    level.rm_refs[498] = "cer_camo_comp_01_zm";
    level.rm_refs[499] = "cer_camo_comp_02_mp";
    level.rm_refs[500] = "cer_camo_comp_02_wz";
}
function private rm_catalog_5()
{
    level.rm_refs[501] = "cer_camo_comp_02_zm";
    level.rm_refs[502] = "cer_camo_comp_03_mp";
    level.rm_refs[503] = "cer_camo_comp_03_wz";
    level.rm_refs[504] = "cer_camo_comp_03_zm";
    level.rm_refs[505] = "cer_camo_comp_04_mp";
    level.rm_refs[506] = "cer_camo_comp_04_wz";
    level.rm_refs[507] = "cer_camo_comp_04_zm";
    level.rm_refs[508] = "cer_camo_delta_01";
    level.rm_refs[509] = "cer_camo_delta_01_wz";
    level.rm_refs[510] = "cer_camo_delta_01_zm";
    level.rm_refs[511] = "cer_camo_delta_02";
    level.rm_refs[512] = "cer_camo_delta_02_wz";
    level.rm_refs[513] = "cer_camo_delta_02_zm";
    level.rm_refs[514] = "cer_camo_delta_03";
    level.rm_refs[515] = "cer_camo_delta_03_wz";
    level.rm_refs[516] = "cer_camo_delta_03_zm";
    level.rm_refs[517] = "cer_camo_delta_04";
    level.rm_refs[518] = "cer_camo_delta_04_wz";
    level.rm_refs[519] = "cer_camo_delta_04_zm";
    level.rm_refs[520] = "cer_camo_delta_05";
    level.rm_refs[521] = "cer_camo_delta_05_wz";
    level.rm_refs[522] = "cer_camo_delta_05_zm";
    level.rm_refs[523] = "cer_camo_delta_06";
    level.rm_refs[524] = "cer_camo_delta_06_wz";
    level.rm_refs[525] = "cer_camo_delta_06_zm";
    level.rm_refs[526] = "cer_camo_delta_07";
    level.rm_refs[527] = "cer_camo_delta_07_wz";
    level.rm_refs[528] = "cer_camo_delta_07_zm";
    level.rm_refs[529] = "cer_camo_delta_08";
    level.rm_refs[530] = "cer_camo_delta_08_wz";
    level.rm_refs[531] = "cer_camo_delta_08_zm";
    level.rm_refs[532] = "cer_camo_delta_09";
    level.rm_refs[533] = "cer_camo_delta_09_wz";
    level.rm_refs[534] = "cer_camo_delta_09_zm";
    level.rm_refs[535] = "cer_camo_delta_10";
    level.rm_refs[536] = "cer_camo_delta_10_wz";
    level.rm_refs[537] = "cer_camo_delta_10_zm";
    level.rm_refs[538] = "cer_camo_delta_11";
    level.rm_refs[539] = "cer_camo_delta_11_wz";
    level.rm_refs[540] = "cer_camo_delta_11_zm";
    level.rm_refs[541] = "cer_camo_echo_01";
    level.rm_refs[542] = "cer_camo_echo_01_wz";
    level.rm_refs[543] = "cer_camo_echo_01_zm";
    level.rm_refs[544] = "cer_camo_echo_02";
    level.rm_refs[545] = "cer_camo_echo_02_wz";
    level.rm_refs[546] = "cer_camo_echo_02_zm";
    level.rm_refs[547] = "cer_camo_echo_03";
    level.rm_refs[548] = "cer_camo_echo_03_wz";
    level.rm_refs[549] = "cer_camo_echo_03_zm";
    level.rm_refs[550] = "cer_camo_echo_04";
    level.rm_refs[551] = "cer_camo_echo_04_wz";
    level.rm_refs[552] = "cer_camo_echo_04_zm";
    level.rm_refs[553] = "cer_camo_echo_05";
    level.rm_refs[554] = "cer_camo_echo_05_wz";
    level.rm_refs[555] = "cer_camo_echo_05_zm";
    level.rm_refs[556] = "cer_camo_echo_06";
    level.rm_refs[557] = "cer_camo_echo_06_wz";
    level.rm_refs[558] = "cer_camo_echo_06_zm";
    level.rm_refs[559] = "cer_camo_echo_07";
    level.rm_refs[560] = "cer_camo_echo_07_wz";
    level.rm_refs[561] = "cer_camo_echo_07_zm";
    level.rm_refs[562] = "cer_camo_echo_08";
    level.rm_refs[563] = "cer_camo_echo_08_wz";
    level.rm_refs[564] = "cer_camo_echo_08_zm";
    level.rm_refs[565] = "cer_camo_echo_09";
    level.rm_refs[566] = "cer_camo_echo_09_wz";
    level.rm_refs[567] = "cer_camo_echo_09_zm";
    level.rm_refs[568] = "cer_camo_echo_10";
    level.rm_refs[569] = "cer_camo_echo_10_wz";
    level.rm_refs[570] = "cer_camo_echo_10_zm";
    level.rm_refs[571] = "cer_camo_echo_11";
    level.rm_refs[572] = "cer_camo_echo_11_wz";
    level.rm_refs[573] = "cer_camo_echo_11_zm";
    level.rm_refs[574] = "cer_camo_echo_12";
    level.rm_refs[575] = "cer_camo_echo_12_wz";
    level.rm_refs[576] = "cer_camo_echo_12_zm";
    level.rm_refs[577] = "cer_camo_echo_13";
    level.rm_refs[578] = "cer_camo_echo_13_wz";
    level.rm_refs[579] = "cer_camo_echo_13_zm";
    level.rm_refs[580] = "cer_camo_foxtrot_01";
    level.rm_refs[581] = "cer_camo_foxtrot_01_wz";
    level.rm_refs[582] = "cer_camo_foxtrot_01_zm";
    level.rm_refs[583] = "cer_camo_foxtrot_02";
    level.rm_refs[584] = "cer_camo_foxtrot_02_wz";
    level.rm_refs[585] = "cer_camo_foxtrot_02_zm";
    level.rm_refs[586] = "cer_camo_foxtrot_03";
    level.rm_refs[587] = "cer_camo_foxtrot_03_wz";
    level.rm_refs[588] = "cer_camo_foxtrot_03_zm";
    level.rm_refs[589] = "cer_camo_foxtrot_04";
    level.rm_refs[590] = "cer_camo_foxtrot_04_wz";
    level.rm_refs[591] = "cer_camo_foxtrot_04_zm";
    level.rm_refs[592] = "cer_camo_foxtrot_05";
    level.rm_refs[593] = "cer_camo_foxtrot_05_wz";
    level.rm_refs[594] = "cer_camo_foxtrot_05_zm";
    level.rm_refs[595] = "cer_camo_foxtrot_06";
    level.rm_refs[596] = "cer_camo_foxtrot_06_wz";
    level.rm_refs[597] = "cer_camo_foxtrot_06_zm";
    level.rm_refs[598] = "cer_camo_foxtrot_07";
    level.rm_refs[599] = "cer_camo_foxtrot_07_wz";
    level.rm_refs[600] = "cer_camo_foxtrot_07_zm";
}
function private rm_catalog_6()
{
    level.rm_refs[601] = "cer_camo_foxtrot_08";
    level.rm_refs[602] = "cer_camo_foxtrot_08_wz";
    level.rm_refs[603] = "cer_camo_foxtrot_08_zm";
    level.rm_refs[604] = "cer_camo_foxtrot_09";
    level.rm_refs[605] = "cer_camo_foxtrot_09_wz";
    level.rm_refs[606] = "cer_camo_foxtrot_09_zm";
    level.rm_refs[607] = "cer_camo_foxtrot_10";
    level.rm_refs[608] = "cer_camo_foxtrot_10_wz";
    level.rm_refs[609] = "cer_camo_foxtrot_10_zm";
    level.rm_refs[610] = "cer_camo_golf_01";
    level.rm_refs[611] = "cer_camo_golf_01_wz";
    level.rm_refs[612] = "cer_camo_golf_01_zm";
    level.rm_refs[613] = "cer_camo_golf_02";
    level.rm_refs[614] = "cer_camo_golf_02_wz";
    level.rm_refs[615] = "cer_camo_golf_02_zm";
    level.rm_refs[616] = "cer_camo_golf_03";
    level.rm_refs[617] = "cer_camo_golf_03_wz";
    level.rm_refs[618] = "cer_camo_golf_03_zm";
    level.rm_refs[619] = "cer_camo_golf_04";
    level.rm_refs[620] = "cer_camo_golf_04_wz";
    level.rm_refs[621] = "cer_camo_golf_04_zm";
    level.rm_refs[622] = "cer_camo_golf_05";
    level.rm_refs[623] = "cer_camo_golf_05_wz";
    level.rm_refs[624] = "cer_camo_golf_05_zm";
    level.rm_refs[625] = "cer_camo_golf_06";
    level.rm_refs[626] = "cer_camo_golf_06_wz";
    level.rm_refs[627] = "cer_camo_golf_06_zm";
    level.rm_refs[628] = "cer_camo_golf_07";
    level.rm_refs[629] = "cer_camo_golf_07_wz";
    level.rm_refs[630] = "cer_camo_golf_07_zm";
    level.rm_refs[631] = "cer_camo_golf_08";
    level.rm_refs[632] = "cer_camo_golf_08_wz";
    level.rm_refs[633] = "cer_camo_golf_08_zm";
    level.rm_refs[634] = "cer_camo_golf_09";
    level.rm_refs[635] = "cer_camo_golf_09_wz";
    level.rm_refs[636] = "cer_camo_golf_09_zm";
    level.rm_refs[637] = "cer_camo_golf_10";
    level.rm_refs[638] = "cer_camo_golf_10_wz";
    level.rm_refs[639] = "cer_camo_golf_10_zm";
    level.rm_refs[640] = "cer_camo_golf_11";
    level.rm_refs[641] = "cer_camo_golf_11_wz";
    level.rm_refs[642] = "cer_camo_golf_11_zm";
    level.rm_refs[643] = "cer_camo_golf_12";
    level.rm_refs[644] = "cer_camo_golf_12_wz";
    level.rm_refs[645] = "cer_camo_golf_12_zm";
    level.rm_refs[646] = "cer_camo_hotel_01";
    level.rm_refs[647] = "cer_camo_hotel_01_wz";
    level.rm_refs[648] = "cer_camo_hotel_01_zm";
    level.rm_refs[649] = "cer_camo_hotel_02";
    level.rm_refs[650] = "cer_camo_hotel_02_wz";
    level.rm_refs[651] = "cer_camo_hotel_02_zm";
    level.rm_refs[652] = "cer_camo_hotel_03";
    level.rm_refs[653] = "cer_camo_hotel_03_wz";
    level.rm_refs[654] = "cer_camo_hotel_03_zm";
    level.rm_refs[655] = "cer_camo_hotel_04";
    level.rm_refs[656] = "cer_camo_hotel_04_wz";
    level.rm_refs[657] = "cer_camo_hotel_04_zm";
    level.rm_refs[658] = "cer_camo_hotel_05";
    level.rm_refs[659] = "cer_camo_hotel_05_wz";
    level.rm_refs[660] = "cer_camo_hotel_05_zm";
    level.rm_refs[661] = "cer_camo_hotel_06";
    level.rm_refs[662] = "cer_camo_hotel_06_wz";
    level.rm_refs[663] = "cer_camo_hotel_06_zm";
    level.rm_refs[664] = "cer_camo_hotel_07";
    level.rm_refs[665] = "cer_camo_hotel_07_wz";
    level.rm_refs[666] = "cer_camo_hotel_07_zm";
    level.rm_refs[667] = "cer_camo_hotel_08";
    level.rm_refs[668] = "cer_camo_hotel_08_wz";
    level.rm_refs[669] = "cer_camo_hotel_08_zm";
    level.rm_refs[670] = "cer_camo_hotel_09";
    level.rm_refs[671] = "cer_camo_hotel_09_wz";
    level.rm_refs[672] = "cer_camo_hotel_09_zm";
    level.rm_refs[673] = "cer_camo_hotel_10";
    level.rm_refs[674] = "cer_camo_hotel_10_wz";
    level.rm_refs[675] = "cer_camo_hotel_10_zm";
    level.rm_refs[676] = "cer_camo_incentive_01";
    level.rm_refs[677] = "cer_camo_incentive_02";
    level.rm_refs[678] = "cer_camo_incentive_sat";
    level.rm_refs[679] = "cer_camo_india_01";
    level.rm_refs[680] = "cer_camo_india_01_wz";
    level.rm_refs[681] = "cer_camo_india_01_zm";
    level.rm_refs[682] = "cer_camo_india_02";
    level.rm_refs[683] = "cer_camo_india_02_wz";
    level.rm_refs[684] = "cer_camo_india_02_zm";
    level.rm_refs[685] = "cer_camo_india_03";
    level.rm_refs[686] = "cer_camo_india_03_wz";
    level.rm_refs[687] = "cer_camo_india_03_zm";
    level.rm_refs[688] = "cer_camo_india_04";
    level.rm_refs[689] = "cer_camo_india_04_wz";
    level.rm_refs[690] = "cer_camo_india_04_zm";
    level.rm_refs[691] = "cer_camo_india_05";
    level.rm_refs[692] = "cer_camo_india_05_wz";
    level.rm_refs[693] = "cer_camo_india_05_zm";
    level.rm_refs[694] = "cer_camo_india_06";
    level.rm_refs[695] = "cer_camo_india_06_wz";
    level.rm_refs[696] = "cer_camo_india_06_zm";
    level.rm_refs[697] = "cer_camo_india_07";
    level.rm_refs[698] = "cer_camo_india_07_wz";
    level.rm_refs[699] = "cer_camo_india_07_zm";
    level.rm_refs[700] = "cer_camo_india_08";
}
function private rm_catalog_7()
{
    level.rm_refs[701] = "cer_camo_india_08_wz";
    level.rm_refs[702] = "cer_camo_india_08_zm";
    level.rm_refs[703] = "cer_camo_india_09";
    level.rm_refs[704] = "cer_camo_india_09_wz";
    level.rm_refs[705] = "cer_camo_india_09_zm";
    level.rm_refs[706] = "cer_camo_india_10";
    level.rm_refs[707] = "cer_camo_india_10_wz";
    level.rm_refs[708] = "cer_camo_india_10_zm";
    level.rm_refs[709] = "cer_camo_india_11";
    level.rm_refs[710] = "cer_camo_india_11_wz";
    level.rm_refs[711] = "cer_camo_india_11_zm";
    level.rm_refs[712] = "cer_camo_india_12";
    level.rm_refs[713] = "cer_camo_india_12_wz";
    level.rm_refs[714] = "cer_camo_india_12_zm";
    level.rm_refs[715] = "cer_camo_juliett_01";
    level.rm_refs[716] = "cer_camo_juliett_01_wz";
    level.rm_refs[717] = "cer_camo_juliett_01_zm";
    level.rm_refs[718] = "cer_camo_juliett_02";
    level.rm_refs[719] = "cer_camo_juliett_02_wz";
    level.rm_refs[720] = "cer_camo_juliett_02_zm";
    level.rm_refs[721] = "cer_camo_juliett_03";
    level.rm_refs[722] = "cer_camo_juliett_03_wz";
    level.rm_refs[723] = "cer_camo_juliett_03_zm";
    level.rm_refs[724] = "cer_camo_juliett_04";
    level.rm_refs[725] = "cer_camo_juliett_04_wz";
    level.rm_refs[726] = "cer_camo_juliett_04_zm";
    level.rm_refs[727] = "cer_camo_juliett_05";
    level.rm_refs[728] = "cer_camo_juliett_05_wz";
    level.rm_refs[729] = "cer_camo_juliett_05_zm";
    level.rm_refs[730] = "cer_camo_juliett_06";
    level.rm_refs[731] = "cer_camo_juliett_06_wz";
    level.rm_refs[732] = "cer_camo_juliett_06_zm";
    level.rm_refs[733] = "cer_camo_juliett_07";
    level.rm_refs[734] = "cer_camo_juliett_07_wz";
    level.rm_refs[735] = "cer_camo_juliett_07_zm";
    level.rm_refs[736] = "cer_camo_kilo_01";
    level.rm_refs[737] = "cer_camo_kilo_01_wz";
    level.rm_refs[738] = "cer_camo_kilo_01_zm";
    level.rm_refs[739] = "cer_camo_kilo_02";
    level.rm_refs[740] = "cer_camo_kilo_02_wz";
    level.rm_refs[741] = "cer_camo_kilo_02_zm";
    level.rm_refs[742] = "cer_camo_kilo_03";
    level.rm_refs[743] = "cer_camo_kilo_03_wz";
    level.rm_refs[744] = "cer_camo_kilo_03_zm";
    level.rm_refs[745] = "cer_camo_kilo_04";
    level.rm_refs[746] = "cer_camo_kilo_04_wz";
    level.rm_refs[747] = "cer_camo_kilo_04_zm";
    level.rm_refs[748] = "cer_camo_kilo_05";
    level.rm_refs[749] = "cer_camo_kilo_05_wz";
    level.rm_refs[750] = "cer_camo_kilo_05_zm";
    level.rm_refs[751] = "cer_camo_kilo_06";
    level.rm_refs[752] = "cer_camo_kilo_06_wz";
    level.rm_refs[753] = "cer_camo_kilo_06_zm";
    level.rm_refs[754] = "cer_camo_kilo_07";
    level.rm_refs[755] = "cer_camo_kilo_07_wz";
    level.rm_refs[756] = "cer_camo_kilo_07_zm";
    level.rm_refs[757] = "cer_camo_lima_01";
    level.rm_refs[758] = "cer_camo_lima_01_wz";
    level.rm_refs[759] = "cer_camo_lima_01_zm";
    level.rm_refs[760] = "cer_camo_lima_02";
    level.rm_refs[761] = "cer_camo_lima_02_wz";
    level.rm_refs[762] = "cer_camo_lima_02_zm";
    level.rm_refs[763] = "cer_camo_lima_03";
    level.rm_refs[764] = "cer_camo_lima_03_wz";
    level.rm_refs[765] = "cer_camo_lima_03_zm";
    level.rm_refs[766] = "cer_camo_lima_04";
    level.rm_refs[767] = "cer_camo_lima_04_wz";
    level.rm_refs[768] = "cer_camo_lima_04_zm";
    level.rm_refs[769] = "cer_camo_lima_05";
    level.rm_refs[770] = "cer_camo_lima_05_wz";
    level.rm_refs[771] = "cer_camo_lima_05_zm";
    level.rm_refs[772] = "cer_camo_lima_06";
    level.rm_refs[773] = "cer_camo_lima_06_wz";
    level.rm_refs[774] = "cer_camo_lima_06_zm";
    level.rm_refs[775] = "cer_camo_lima_07";
    level.rm_refs[776] = "cer_camo_lima_07_wz";
    level.rm_refs[777] = "cer_camo_lima_07_zm";
    level.rm_refs[778] = "cer_camo_lima_08";
    level.rm_refs[779] = "cer_camo_lima_08_wz";
    level.rm_refs[780] = "cer_camo_lima_08_zm";
    level.rm_refs[781] = "cer_camo_lima_09";
    level.rm_refs[782] = "cer_camo_lima_09_wz";
    level.rm_refs[783] = "cer_camo_lima_09_zm";
    level.rm_refs[784] = "cer_camo_mike_01";
    level.rm_refs[785] = "cer_camo_mike_01_wz";
    level.rm_refs[786] = "cer_camo_mike_01_zm";
    level.rm_refs[787] = "cer_camo_mike_02";
    level.rm_refs[788] = "cer_camo_mike_02_wz";
    level.rm_refs[789] = "cer_camo_mike_02_zm";
    level.rm_refs[790] = "cer_camo_mike_03";
    level.rm_refs[791] = "cer_camo_mike_03_wz";
    level.rm_refs[792] = "cer_camo_mike_03_zm";
    level.rm_refs[793] = "cer_camo_mike_04";
    level.rm_refs[794] = "cer_camo_mike_04_wz";
    level.rm_refs[795] = "cer_camo_mike_04_zm";
    level.rm_refs[796] = "cer_camo_pap_garnet_01";
    level.rm_refs[797] = "cer_camo_pap_garnet_02";
    level.rm_refs[798] = "cer_camo_pap_garnet_03";
    level.rm_refs[799] = "cer_camo_parachute_03_wz";
    level.rm_refs[800] = "cer_camo_ranked_mp_s1_01";
}
function private rm_catalog_8()
{
    level.rm_refs[801] = "cer_camo_ranked_mp_s2_01";
    level.rm_refs[802] = "cer_camo_ranked_mp_s2_02";
    level.rm_refs[803] = "cer_camo_ranked_mp_s2_03";
    level.rm_refs[804] = "cer_camo_ranked_mp_s2_04";
    level.rm_refs[805] = "cer_camo_ranked_mp_s2_05";
    level.rm_refs[806] = "cer_camo_ranked_mp_s2_06";
    level.rm_refs[807] = "cer_camo_ranked_mp_s5_01";
    level.rm_refs[808] = "cer_camo_ranked_mp_s5_02";
    level.rm_refs[809] = "cer_camo_ranked_mp_s5_03";
    level.rm_refs[810] = "cer_camo_ranked_mp_s5_04";
    level.rm_refs[811] = "cer_camo_ranked_mp_s5_05";
    level.rm_refs[812] = "cer_camo_ranked_mp_s5_06";
    level.rm_refs[813] = "cer_camo_ranked_mp_s6_01";
    level.rm_refs[814] = "cer_camo_ranked_mp_s6_02";
    level.rm_refs[815] = "cer_camo_ranked_mp_s6_03";
    level.rm_refs[816] = "cer_camo_ranked_mp_s6_04";
    level.rm_refs[817] = "cer_camo_ranked_mp_s6_05";
    level.rm_refs[818] = "cer_camo_ranked_mp_s6_06";
    level.rm_refs[819] = "cer_camo_ranked_wz_s1_01";
    level.rm_refs[820] = "cer_camo_ranked_wz_s2_03";
    level.rm_refs[821] = "cer_camo_ranked_wz_s2_04";
    level.rm_refs[822] = "cer_camo_ranked_wz_s2_05";
    level.rm_refs[823] = "cer_camo_ranked_wz_s2_06";
    level.rm_refs[824] = "cer_camo_ranked_wz_s2_07";
    level.rm_refs[825] = "cer_camo_ranked_wz_s2_08";
    level.rm_refs[826] = "cer_camo_ranked_wz_s2_09";
    level.rm_refs[827] = "cer_camo_ranked_wz_s3_01";
    level.rm_refs[828] = "cer_camo_ranked_wz_s4_01";
    level.rm_refs[829] = "cer_camo_ranked_wz_s5_01";
    level.rm_refs[830] = "cer_camo_ranked_wz_s6_01";
    level.rm_refs[831] = "cer_camo_special_cdlbre";
    level.rm_refs[832] = "cer_camo_special_cdlclo";
    level.rm_refs[833] = "cer_camo_special_cdlfal";
    level.rm_refs[834] = "cer_camo_special_cdlfaz";
    level.rm_refs[835] = "cer_camo_special_cdlgur";
    level.rm_refs[836] = "cer_camo_special_cdlher";
    level.rm_refs[837] = "cer_camo_special_cdllau";
    level.rm_refs[838] = "cer_camo_special_cdlopt";
    level.rm_refs[839] = "cer_camo_special_cdlrav";
    level.rm_refs[840] = "cer_camo_special_cdlrok";
    level.rm_refs[841] = "cer_camo_special_cdlsur";
    level.rm_refs[842] = "cer_camo_special_cdlthi";
    level.rm_refs[843] = "cer_camo_special_cdlult";
    level.rm_refs[844] = "cer_camo_special_ev420";
    level.rm_refs[845] = "cer_camo_special_ev420blk";
    level.rm_refs[846] = "cer_camo_special_evbacklog";
    level.rm_refs[847] = "cer_camo_special_evbacklogblk";
    level.rm_refs[848] = "cer_camo_special_evghost";
    level.rm_refs[849] = "cer_camo_special_evghostblk";
    level.rm_refs[850] = "cer_camo_special_evgummy";
    level.rm_refs[851] = "cer_camo_special_evs45";
    level.rm_refs[852] = "cer_camo_special_evs45blk";
    level.rm_refs[853] = "cer_camo_special_evs55jab";
    level.rm_refs[854] = "jup_camo_02a";
    level.rm_refs[855] = "jup_camo_02b";
    level.rm_refs[856] = "jup_camo_02c";
    level.rm_refs[857] = "jup_camo_02d";
    level.rm_refs[858] = "jup_camo_02e";
    level.rm_refs[859] = "jup_camo_02f";
    level.rm_refs[860] = "jup_camo_03a";
    level.rm_refs[861] = "jup_camo_03b";
    level.rm_refs[862] = "jup_camo_03c";
    level.rm_refs[863] = "jup_camo_03d";
    level.rm_refs[864] = "jup_camo_03e";
    level.rm_refs[865] = "jup_camo_03f";
    level.rm_refs[866] = "jup_camo_03g";
    level.rm_refs[867] = "jup_camo_03h";
    level.rm_refs[868] = "jup_camo_03p";
    level.rm_refs[869] = "jup_camo_06a";
    level.rm_refs[870] = "jup_camo_06b";
    level.rm_refs[871] = "jup_camo_06c";
    level.rm_refs[872] = "jup_camo_06d";
    level.rm_refs[873] = "jup_camo_06e";
    level.rm_refs[874] = "jup_camo_06f";
    level.rm_refs[875] = "jup_camo_06g";
    level.rm_refs[876] = "jup_camo_06h";
    level.rm_refs[877] = "jup_camo_06i";
    level.rm_refs[878] = "jup_camo_06j";
    level.rm_refs[879] = "jup_camo_07a";
    level.rm_refs[880] = "jup_camo_07b";
    level.rm_refs[881] = "jup_camo_07c";
    level.rm_refs[882] = "jup_camo_07d";
    level.rm_refs[883] = "jup_camo_07e";
    level.rm_refs[884] = "jup_camo_07f";
    level.rm_refs[885] = "jup_camo_07g";
    level.rm_refs[886] = "jup_camo_07h";
    level.rm_refs[887] = "jup_camo_07i";
    level.rm_refs[888] = "jup_camo_07j";
    level.rm_refs[889] = "jup_camo_08a";
    level.rm_refs[890] = "jup_camo_09a";
    level.rm_refs[891] = "jup_camo_09b";
    level.rm_refs[892] = "jup_camo_09c";
    level.rm_refs[893] = "jup_camo_09d";
    level.rm_refs[894] = "jup_camo_09e";
    level.rm_refs[895] = "jup_camo_09f";
    level.rm_refs[896] = "jup_camo_09g";
    level.rm_refs[897] = "jup_camo_09h";
    level.rm_refs[898] = "jup_camo_09i";
    level.rm_refs[899] = "jup_camo_10a";
    level.rm_refs[900] = "jup_camo_10b";
}
function private rm_catalog_9()
{
    level.rm_refs[901] = "jup_camo_10c";
    level.rm_refs[902] = "jup_camo_10d";
    level.rm_refs[903] = "jup_camo_10e";
    level.rm_refs[904] = "jup_camo_10f";
    level.rm_refs[905] = "jup_camo_10g";
    level.rm_refs[906] = "jup_camo_10h";
    level.rm_refs[907] = "jup_camo_10i";
    level.rm_refs[908] = "jup_camo_10j";
    level.rm_refs[909] = "jup_camo_10k";
    level.rm_refs[910] = "jup_camo_10l";
    level.rm_refs[911] = "jup_camo_11a";
    level.rm_refs[912] = "jup_camo_11b";
    level.rm_refs[913] = "jup_camo_11c";
    level.rm_refs[914] = "jup_camo_11d";
    level.rm_refs[915] = "jup_camo_11e";
    level.rm_refs[916] = "jup_camo_11f";
    level.rm_refs[917] = "jup_camo_11g";
    level.rm_refs[918] = "jup_camo_11h";
    level.rm_refs[919] = "jup_camo_11i";
    level.rm_refs[920] = "jup_camo_11j";
    level.rm_refs[921] = "jup_camo_11k";
    level.rm_refs[922] = "jup_camo_11l";
    level.rm_refs[923] = "jup_camo_11m";
    level.rm_refs[924] = "jup_camo_11n";
    level.rm_refs[925] = "jup_camo_13a";
    level.rm_refs[926] = "jup_camo_13b";
    level.rm_refs[927] = "jup_camo_13c";
    level.rm_refs[928] = "jup_camo_13d";
    level.rm_refs[929] = "jup_camo_13e";
    level.rm_refs[930] = "jup_camo_13f";
    level.rm_refs[931] = "jup_camo_13h";
    level.rm_refs[932] = "jup_camo_13i";
    level.rm_refs[933] = "jup_camo_13j";
    level.rm_refs[934] = "jup_camo_13k";
    level.rm_refs[935] = "jup_camo_13l";
    level.rm_refs[936] = "jup_camo_13m";
    level.rm_refs[937] = "jup_camo_14a";
    level.rm_refs[938] = "jup_camo_14b";
    level.rm_refs[939] = "jup_camo_14c";
    level.rm_refs[940] = "jup_camo_14d";
    level.rm_refs[941] = "jup_camo_14e";
    level.rm_refs[942] = "jup_camo_14f";
    level.rm_refs[943] = "jup_camo_14g";
    level.rm_refs[944] = "jup_camo_14h";
    level.rm_refs[945] = "jup_camo_14i";
    level.rm_refs[946] = "jup_camo_14j";
    level.rm_refs[947] = "jup_camo_14k";
    level.rm_refs[948] = "jup_camo_14l";
    level.rm_refs[949] = "jup_camo_15a";
    level.rm_refs[950] = "jup_camo_16a";
    level.rm_refs[951] = "jup_camo_16b";
    level.rm_refs[952] = "jup_camo_16c";
    level.rm_refs[953] = "jup_camo_16d";
    level.rm_refs[954] = "jup_camo_16e";
    level.rm_refs[955] = "jup_camo_16f";
    level.rm_refs[956] = "jup_camo_16g";
    level.rm_refs[957] = "jup_camo_16h";
    level.rm_refs[958] = "jup_camo_16i";
    level.rm_refs[959] = "jup_camo_16j";
    level.rm_refs[960] = "jup_camo_16k";
    level.rm_refs[961] = "jup_camo_16l";
    level.rm_refs[962] = "jup_camo_16m";
    level.rm_refs[963] = "jup_camo_17a";
    level.rm_refs[964] = "jup_camo_17b";
    level.rm_refs[965] = "jup_camo_17c";
    level.rm_refs[966] = "jup_camo_17d";
    level.rm_refs[967] = "jup_camo_17e";
    level.rm_refs[968] = "jup_camo_17f";
    level.rm_refs[969] = "jup_camo_17g";
    level.rm_refs[970] = "jup_camo_18a";
    level.rm_refs[971] = "jup_camo_18b";
    level.rm_refs[972] = "jup_camo_18c";
    level.rm_refs[973] = "jup_camo_18d";
    level.rm_refs[974] = "jup_camo_18e";
    level.rm_refs[975] = "jup_camo_19a";
    level.rm_refs[976] = "jup_camo_19b";
    level.rm_refs[977] = "jup_camo_19c";
    level.rm_refs[978] = "jup_camo_19d";
    level.rm_refs[979] = "jup_camo_19e";
    level.rm_refs[980] = "jup_camo_19f";
    level.rm_refs[981] = "jup_camo_19g";
    level.rm_refs[982] = "jup_camo_19h";
    level.rm_refs[983] = "jup_camo_19i";
    level.rm_refs[984] = "jup_camo_19j";
    level.rm_refs[985] = "jup_camo_19k";
    level.rm_refs[986] = "jup_camo_19l";
    level.rm_refs[987] = "jup_camo_19m";
    level.rm_refs[988] = "jup_camo_20d";
    level.rm_refs[989] = "jup_camo_20f";
    level.rm_refs[990] = "jup_camo_20g";
    level.rm_refs[991] = "jup_camo_20h";
    level.rm_refs[992] = "jup_camo_21a";
    level.rm_refs[993] = "jup_camo_22a";
    level.rm_refs[994] = "jup_camo_22b";
    level.rm_refs[995] = "jup_camo_22c";
    level.rm_refs[996] = "jup_camo_22d";
    level.rm_refs[997] = "jup_camo_22e";
    level.rm_refs[998] = "jup_camo_22f";
    level.rm_refs[999] = "jup_camo_22g";
    level.rm_refs[1000] = "jup_camo_22h";
}
function private rm_catalog_10()
{
    level.rm_refs[1001] = "jup_camo_23a";
    level.rm_refs[1002] = "jup_camo_23d";
    level.rm_refs[1003] = "jup_camo_23e";
    level.rm_refs[1004] = "jup_camo_23f";
    level.rm_refs[1005] = "jup_camo_24a";
    level.rm_refs[1006] = "jup_camo_24b";
    level.rm_refs[1007] = "jup_camo_24c";
    level.rm_refs[1008] = "jup_camo_24d";
    level.rm_refs[1009] = "jup_camo_24e";
    level.rm_refs[1010] = "jup_camo_24f";
    level.rm_refs[1011] = "jup_camo_24i";
    level.rm_refs[1012] = "jup_camo_24j";
    level.rm_refs[1013] = "jup_camo_25a";
    level.rm_refs[1014] = "jup_camo_25b";
    level.rm_refs[1015] = "jup_camo_25c";
    level.rm_refs[1016] = "jup_camo_26a";
    level.rm_refs[1017] = "jup_camo_26b";
    level.rm_refs[1018] = "jup_camo_b2068";
    level.rm_refs[1019] = "jup_camo_b2068_5";
    level.rm_refs[1020] = "jup_camo_comp_01";
    level.rm_refs[1021] = "jup_camo_comp_02";
    level.rm_refs[1022] = "jup_camo_comp_03";
    level.rm_refs[1023] = "jup_camo_comp_04";
    level.rm_refs[1024] = "jup_camo_eventsa";
    level.rm_refs[1025] = "jup_camo_eventsaa";
    level.rm_refs[1026] = "jup_camo_eventsab";
    level.rm_refs[1027] = "jup_camo_eventsac";
    level.rm_refs[1028] = "jup_camo_eventsad";
    level.rm_refs[1029] = "jup_camo_eventsae";
    level.rm_refs[1030] = "jup_camo_eventsb";
    level.rm_refs[1031] = "jup_camo_eventsc";
    level.rm_refs[1032] = "jup_camo_eventsd";
    level.rm_refs[1033] = "jup_camo_eventse";
    level.rm_refs[1034] = "jup_camo_eventsf";
    level.rm_refs[1035] = "jup_camo_eventsg";
    level.rm_refs[1036] = "jup_camo_eventsh";
    level.rm_refs[1037] = "jup_camo_eventsi";
    level.rm_refs[1038] = "jup_camo_eventsj";
    level.rm_refs[1039] = "jup_camo_eventsk";
    level.rm_refs[1040] = "jup_camo_eventsl";
    level.rm_refs[1041] = "jup_camo_eventsm";
    level.rm_refs[1042] = "jup_camo_eventsn";
    level.rm_refs[1043] = "jup_camo_eventsp";
    level.rm_refs[1044] = "jup_camo_eventsr";
    level.rm_refs[1045] = "jup_camo_eventss";
    level.rm_refs[1046] = "jup_camo_eventst";
    level.rm_refs[1047] = "jup_camo_eventsu";
    level.rm_refs[1048] = "jup_camo_eventsv";
    level.rm_refs[1049] = "jup_camo_eventsw";
    level.rm_refs[1050] = "jup_camo_eventsy";
    level.rm_refs[1051] = "jup_camo_eventsz";
    level.rm_refs[1052] = "jup_camo_iw9_v_09";
    level.rm_refs[1053] = "jup_camo_iw9_v_10";
    level.rm_refs[1054] = "jup_camo_iw9_v_11";
    level.rm_refs[1055] = "jup_camo_iw9_v_12";
    level.rm_refs[1056] = "jup_camo_iw9_v_13";
    level.rm_refs[1057] = "jup_camo_iw9_v_14";
    level.rm_refs[1058] = "jup_camo_iw9_v_15";
    level.rm_refs[1059] = "jup_camo_iw9_w_01";
    level.rm_refs[1060] = "jup_camo_n2919_2";
    level.rm_refs[1061] = "jup_camo_n2940_1";
    level.rm_refs[1062] = "jup_camo_n3906_2";
    level.rm_refs[1063] = "jup_camo_n3907_10";
    level.rm_refs[1064] = "jup_camo_n3907_11";
    level.rm_refs[1065] = "jup_camo_n3907_12";
    level.rm_refs[1066] = "jup_camo_n3907_13";
    level.rm_refs[1067] = "jup_camo_n3907_23";
    level.rm_refs[1068] = "jup_camo_n3907_24";
    level.rm_refs[1069] = "jup_camo_n3907_25";
    level.rm_refs[1070] = "jup_camo_n3907_26";
    level.rm_refs[1071] = "jup_camo_n3907_36";
    level.rm_refs[1072] = "jup_camo_n3908_10";
    level.rm_refs[1073] = "jup_camo_n3908_11";
    level.rm_refs[1074] = "jup_camo_n3908_12";
    level.rm_refs[1075] = "jup_camo_n3908_13";
    level.rm_refs[1076] = "jup_camo_n3909_10";
    level.rm_refs[1077] = "jup_camo_n3909_11";
    level.rm_refs[1078] = "jup_camo_n3909_12";
    level.rm_refs[1079] = "jup_camo_n3909_13";
    level.rm_refs[1080] = "jup_camo_n3909_23";
    level.rm_refs[1081] = "jup_camo_n3909_36";
    level.rm_refs[1082] = "jup_camo_n3909_37";
    level.rm_refs[1083] = "jup_camo_n3909_38";
    level.rm_refs[1084] = "jup_camo_n3909_39";
    level.rm_refs[1085] = "jup_camo_n3910_10";
    level.rm_refs[1086] = "jup_camo_n3910_11";
    level.rm_refs[1087] = "jup_camo_n3910_12";
    level.rm_refs[1088] = "jup_camo_n3910_13";
    level.rm_refs[1089] = "jup_camo_n3913_4";
    level.rm_refs[1090] = "jup_camo_n3914_19";
    level.rm_refs[1091] = "jup_camo_n3914_20";
    level.rm_refs[1092] = "jup_camo_n3914_21";
    level.rm_refs[1093] = "jup_camo_n3914_22";
    level.rm_refs[1094] = "jup_camo_n3914_23";
    level.rm_refs[1095] = "jup_camo_n3914_24";
    level.rm_refs[1096] = "jup_camo_n3914_4";
    level.rm_refs[1097] = "jup_camo_n3917_6";
    level.rm_refs[1098] = "jup_camo_n3918_7";
    level.rm_refs[1099] = "jup_camo_n3920_8";
    level.rm_refs[1100] = "jup_camo_n3921_8";
}
function private rm_catalog_11()
{
    level.rm_refs[1101] = "jup_camo_n3924_1";
    level.rm_refs[1102] = "jup_camo_n3925_1";
    level.rm_refs[1103] = "jup_camo_n3929_5";
    level.rm_refs[1104] = "jup_camo_n3930_4";
    level.rm_refs[1105] = "jup_camo_n3936_1";
    level.rm_refs[1106] = "jup_camo_n3938_1";
    level.rm_refs[1107] = "jup_camo_n3939_1";
    level.rm_refs[1108] = "jup_camo_n4907_10";
    level.rm_refs[1109] = "jup_camo_n4907_11";
    level.rm_refs[1110] = "jup_camo_n4907_12";
    level.rm_refs[1111] = "jup_camo_n4907_13";
    level.rm_refs[1112] = "jup_camo_n4907_23";
    level.rm_refs[1113] = "jup_camo_n4907_24";
    level.rm_refs[1114] = "jup_camo_n4907_25";
    level.rm_refs[1115] = "jup_camo_n4907_26";
    level.rm_refs[1116] = "jup_camo_n4908_10";
    level.rm_refs[1117] = "jup_camo_n4908_11";
    level.rm_refs[1118] = "jup_camo_n4908_12";
    level.rm_refs[1119] = "jup_camo_n4908_13";
    level.rm_refs[1120] = "jup_camo_n4908_23";
    level.rm_refs[1121] = "jup_camo_n4909_10";
    level.rm_refs[1122] = "jup_camo_n4909_11";
    level.rm_refs[1123] = "jup_camo_n4909_12";
    level.rm_refs[1124] = "jup_camo_n4909_13";
    level.rm_refs[1125] = "jup_camo_n4909_23";
    level.rm_refs[1126] = "jup_camo_n4909_24";
    level.rm_refs[1127] = "jup_camo_n4909_25";
    level.rm_refs[1128] = "jup_camo_n4909_26";
    level.rm_refs[1129] = "jup_camo_n4910_10";
    level.rm_refs[1130] = "jup_camo_n4910_11";
    level.rm_refs[1131] = "jup_camo_n4910_12";
    level.rm_refs[1132] = "jup_camo_n4910_13";
    level.rm_refs[1133] = "jup_camo_n4910_23";
    level.rm_refs[1134] = "jup_camo_n4914_4";
    level.rm_refs[1135] = "jup_camo_n4917_4";
    level.rm_refs[1136] = "jup_camo_n4918_10";
    level.rm_refs[1137] = "jup_camo_n4920_6";
    level.rm_refs[1138] = "jup_camo_n4922_2";
    level.rm_refs[1139] = "jup_camo_n4923_6";
    level.rm_refs[1140] = "jup_camo_n4924_1";
    level.rm_refs[1141] = "jup_camo_n4931_6";
    level.rm_refs[1142] = "jup_camo_n4931_7";
    level.rm_refs[1143] = "jup_camo_n4931_8";
    level.rm_refs[1144] = "jup_camo_n4931_9";
    level.rm_refs[1145] = "jup_camo_n4933_25";
    level.rm_refs[1146] = "jup_camo_n4933_26";
    level.rm_refs[1147] = "jup_camo_n4933_27";
    level.rm_refs[1148] = "jup_camo_n4934_1";
    level.rm_refs[1149] = "jup_camo_n4935_1";
    level.rm_refs[1150] = "jup_camo_n4942_1";
    level.rm_refs[1151] = "jup_camo_n4943_1";
    level.rm_refs[1152] = "jup_camo_n4945_2";
    level.rm_refs[1153] = "jup_camo_n4945_3";
    level.rm_refs[1154] = "jup_camo_n4945_4";
    level.rm_refs[1155] = "jup_camo_n5907_10";
    level.rm_refs[1156] = "jup_camo_n5907_11";
    level.rm_refs[1157] = "jup_camo_n5907_12";
    level.rm_refs[1158] = "jup_camo_n5907_13";
    level.rm_refs[1159] = "jup_camo_n5907_23";
    level.rm_refs[1160] = "jup_camo_n5907_24";
    level.rm_refs[1161] = "jup_camo_n5907_25";
    level.rm_refs[1162] = "jup_camo_n5907_26";
    level.rm_refs[1163] = "jup_camo_n5908_10";
    level.rm_refs[1164] = "jup_camo_n5908_20";
    level.rm_refs[1165] = "jup_camo_n5909_10";
    level.rm_refs[1166] = "jup_camo_n5909_11";
    level.rm_refs[1167] = "jup_camo_n5909_12";
    level.rm_refs[1168] = "jup_camo_n5909_13";
    level.rm_refs[1169] = "jup_camo_n5909_23";
    level.rm_refs[1170] = "jup_camo_n5909_24";
    level.rm_refs[1171] = "jup_camo_n5909_25";
    level.rm_refs[1172] = "jup_camo_n5909_26";
    level.rm_refs[1173] = "jup_camo_n5914_19";
    level.rm_refs[1174] = "jup_camo_n5914_20";
    level.rm_refs[1175] = "jup_camo_n5914_21";
    level.rm_refs[1176] = "jup_camo_n5914_22";
    level.rm_refs[1177] = "jup_camo_n5914_23";
    level.rm_refs[1178] = "jup_camo_n5914_24";
    level.rm_refs[1179] = "jup_camo_n5914_4";
    level.rm_refs[1180] = "jup_camo_n5915_4";
    level.rm_refs[1181] = "jup_camo_n5918_1";
    level.rm_refs[1182] = "jup_camo_n5920_10";
    level.rm_refs[1183] = "jup_camo_n5920_14";
    level.rm_refs[1184] = "jup_camo_n5920_15";
    level.rm_refs[1185] = "jup_camo_n5920_7";
    level.rm_refs[1186] = "jup_camo_n5922_1";
    level.rm_refs[1187] = "jup_camo_n5923_1";
    level.rm_refs[1188] = "jup_camo_n5924_1";
    level.rm_refs[1189] = "jup_camo_n5926_1";
    level.rm_refs[1190] = "jup_camo_n5927_2";
    level.rm_refs[1191] = "jup_camo_n5928_1";
    level.rm_refs[1192] = "jup_camo_n5930_10";
    level.rm_refs[1193] = "jup_camo_n5930_11";
    level.rm_refs[1194] = "jup_camo_n5930_12";
    level.rm_refs[1195] = "jup_camo_n5930_13";
    level.rm_refs[1196] = "jup_camo_n5931_1";
    level.rm_refs[1197] = "jup_camo_n6905_1";
    level.rm_refs[1198] = "jup_camo_n6907_10";
    level.rm_refs[1199] = "jup_camo_n6907_11";
    level.rm_refs[1200] = "jup_camo_n6907_12";
}
function private rm_catalog_12()
{
    level.rm_refs[1201] = "jup_camo_n6907_13";
    level.rm_refs[1202] = "jup_camo_n6907_23";
    level.rm_refs[1203] = "jup_camo_n6907_24";
    level.rm_refs[1204] = "jup_camo_n6907_25";
    level.rm_refs[1205] = "jup_camo_n6907_26";
    level.rm_refs[1206] = "jup_camo_n6908_10";
    level.rm_refs[1207] = "jup_camo_n6908_11";
    level.rm_refs[1208] = "jup_camo_n6908_23";
    level.rm_refs[1209] = "jup_camo_n6908_24";
    level.rm_refs[1210] = "jup_camo_n6908_25";
    level.rm_refs[1211] = "jup_camo_n6908_26";
    level.rm_refs[1212] = "jup_camo_n6910_10";
    level.rm_refs[1213] = "jup_camo_n6911_19";
    level.rm_refs[1214] = "jup_camo_n6911_20";
    level.rm_refs[1215] = "jup_camo_n6911_21";
    level.rm_refs[1216] = "jup_camo_n6911_22";
    level.rm_refs[1217] = "jup_camo_n6911_23";
    level.rm_refs[1218] = "jup_camo_n6911_24";
    level.rm_refs[1219] = "jup_camo_n6911_4";
    level.rm_refs[1220] = "jup_camo_n6912_1";
    level.rm_refs[1221] = "jup_camo_n6914_7";
    level.rm_refs[1222] = "jup_camo_n6915_1";
    level.rm_refs[1223] = "jup_camo_n6916_10";
    level.rm_refs[1224] = "jup_camo_n6916_12";
    level.rm_refs[1225] = "jup_camo_n6916_13";
    level.rm_refs[1226] = "jup_camo_n6916_7";
    level.rm_refs[1227] = "jup_camo_n6916_8";
    level.rm_refs[1228] = "jup_camo_n6916_9";
    level.rm_refs[1229] = "jup_camo_n6917_1";
    level.rm_refs[1230] = "jup_camo_n6918_1";
    level.rm_refs[1231] = "jup_camo_n6918_2";
    level.rm_refs[1232] = "jup_camo_n6918_6";
    level.rm_refs[1233] = "jup_camo_n6920_1";
    level.rm_refs[1234] = "jup_camo_n6922_1";
    level.rm_refs[1235] = "jup_camo_n6922_2";
    level.rm_refs[1236] = "jup_camo_n6922_3";
    level.rm_refs[1237] = "jup_camo_n6922_4";
    level.rm_refs[1238] = "jup_camo_ob_02a";
    level.rm_refs[1239] = "jup_camo_ob_02b";
    level.rm_refs[1240] = "jup_camo_ob_02c";
    level.rm_refs[1241] = "jup_camo_ob_02d";
    level.rm_refs[1242] = "jup_camo_ob_02e";
    level.rm_refs[1243] = "jup_camo_ob_02f";
    level.rm_refs[1244] = "jup_camo_ob_03a";
    level.rm_refs[1245] = "jup_camo_ob_03b";
    level.rm_refs[1246] = "jup_camo_ob_03c";
    level.rm_refs[1247] = "jup_camo_ob_03d";
    level.rm_refs[1248] = "jup_camo_ob_03e";
    level.rm_refs[1249] = "jup_camo_ob_03f";
    level.rm_refs[1250] = "jup_camo_ob_03g";
    level.rm_refs[1251] = "jup_camo_ob_03h";
    level.rm_refs[1252] = "jup_camo_ob_03p";
    level.rm_refs[1253] = "jup_camo_ob_06a";
    level.rm_refs[1254] = "jup_camo_ob_06b";
    level.rm_refs[1255] = "jup_camo_ob_06c";
    level.rm_refs[1256] = "jup_camo_ob_06d";
    level.rm_refs[1257] = "jup_camo_ob_06e";
    level.rm_refs[1258] = "jup_camo_ob_06f";
    level.rm_refs[1259] = "jup_camo_ob_06g";
    level.rm_refs[1260] = "jup_camo_ob_06h";
    level.rm_refs[1261] = "jup_camo_ob_06i";
    level.rm_refs[1262] = "jup_camo_ob_06j";
    level.rm_refs[1263] = "jup_camo_ob_07a";
    level.rm_refs[1264] = "jup_camo_ob_07b";
    level.rm_refs[1265] = "jup_camo_ob_07c";
    level.rm_refs[1266] = "jup_camo_ob_07d";
    level.rm_refs[1267] = "jup_camo_ob_07e";
    level.rm_refs[1268] = "jup_camo_ob_07f";
    level.rm_refs[1269] = "jup_camo_ob_07g";
    level.rm_refs[1270] = "jup_camo_ob_07h";
    level.rm_refs[1271] = "jup_camo_ob_07i";
    level.rm_refs[1272] = "jup_camo_ob_07j";
    level.rm_refs[1273] = "jup_camo_ob_08a";
    level.rm_refs[1274] = "jup_camo_ob_09a";
    level.rm_refs[1275] = "jup_camo_ob_09b";
    level.rm_refs[1276] = "jup_camo_ob_09c";
    level.rm_refs[1277] = "jup_camo_ob_09d";
    level.rm_refs[1278] = "jup_camo_ob_09e";
    level.rm_refs[1279] = "jup_camo_ob_09f";
    level.rm_refs[1280] = "jup_camo_ob_09g";
    level.rm_refs[1281] = "jup_camo_ob_09h";
    level.rm_refs[1282] = "jup_camo_ob_09i";
    level.rm_refs[1283] = "jup_camo_ob_10a";
    level.rm_refs[1284] = "jup_camo_ob_10b";
    level.rm_refs[1285] = "jup_camo_ob_10c";
    level.rm_refs[1286] = "jup_camo_ob_10d";
    level.rm_refs[1287] = "jup_camo_ob_10e";
    level.rm_refs[1288] = "jup_camo_ob_10f";
    level.rm_refs[1289] = "jup_camo_ob_10g";
    level.rm_refs[1290] = "jup_camo_ob_10h";
    level.rm_refs[1291] = "jup_camo_ob_10i";
    level.rm_refs[1292] = "jup_camo_ob_10j";
    level.rm_refs[1293] = "jup_camo_ob_10k";
    level.rm_refs[1294] = "jup_camo_ob_10l";
    level.rm_refs[1295] = "jup_camo_ob_11a";
    level.rm_refs[1296] = "jup_camo_ob_11b";
    level.rm_refs[1297] = "jup_camo_ob_11c";
    level.rm_refs[1298] = "jup_camo_ob_11d";
    level.rm_refs[1299] = "jup_camo_ob_11e";
    level.rm_refs[1300] = "jup_camo_ob_11f";
}
function private rm_catalog_13()
{
    level.rm_refs[1301] = "jup_camo_ob_11g";
    level.rm_refs[1302] = "jup_camo_ob_11h";
    level.rm_refs[1303] = "jup_camo_ob_11i";
    level.rm_refs[1304] = "jup_camo_ob_11j";
    level.rm_refs[1305] = "jup_camo_ob_11k";
    level.rm_refs[1306] = "jup_camo_ob_11l";
    level.rm_refs[1307] = "jup_camo_ob_11m";
    level.rm_refs[1308] = "jup_camo_ob_11n";
    level.rm_refs[1309] = "jup_camo_ob_13a";
    level.rm_refs[1310] = "jup_camo_ob_13b";
    level.rm_refs[1311] = "jup_camo_ob_13c";
    level.rm_refs[1312] = "jup_camo_ob_13d";
    level.rm_refs[1313] = "jup_camo_ob_13e";
    level.rm_refs[1314] = "jup_camo_ob_13f";
    level.rm_refs[1315] = "jup_camo_ob_13h";
    level.rm_refs[1316] = "jup_camo_ob_13i";
    level.rm_refs[1317] = "jup_camo_ob_13j";
    level.rm_refs[1318] = "jup_camo_ob_13k";
    level.rm_refs[1319] = "jup_camo_ob_13l";
    level.rm_refs[1320] = "jup_camo_ob_13m";
    level.rm_refs[1321] = "jup_camo_ob_14a";
    level.rm_refs[1322] = "jup_camo_ob_14b";
    level.rm_refs[1323] = "jup_camo_ob_14c";
    level.rm_refs[1324] = "jup_camo_ob_14d";
    level.rm_refs[1325] = "jup_camo_ob_14e";
    level.rm_refs[1326] = "jup_camo_ob_14f";
    level.rm_refs[1327] = "jup_camo_ob_14g";
    level.rm_refs[1328] = "jup_camo_ob_14h";
    level.rm_refs[1329] = "jup_camo_ob_14i";
    level.rm_refs[1330] = "jup_camo_ob_14j";
    level.rm_refs[1331] = "jup_camo_ob_14k";
    level.rm_refs[1332] = "jup_camo_ob_14l";
    level.rm_refs[1333] = "jup_camo_ob_15a";
    level.rm_refs[1334] = "jup_camo_ob_16a";
    level.rm_refs[1335] = "jup_camo_ob_16b";
    level.rm_refs[1336] = "jup_camo_ob_16c";
    level.rm_refs[1337] = "jup_camo_ob_16d";
    level.rm_refs[1338] = "jup_camo_ob_16e";
    level.rm_refs[1339] = "jup_camo_ob_16f";
    level.rm_refs[1340] = "jup_camo_ob_16g";
    level.rm_refs[1341] = "jup_camo_ob_16h";
    level.rm_refs[1342] = "jup_camo_ob_16i";
    level.rm_refs[1343] = "jup_camo_ob_16j";
    level.rm_refs[1344] = "jup_camo_ob_16k";
    level.rm_refs[1345] = "jup_camo_ob_16l";
    level.rm_refs[1346] = "jup_camo_ob_16m";
    level.rm_refs[1347] = "jup_camo_ob_17a";
    level.rm_refs[1348] = "jup_camo_ob_17b";
    level.rm_refs[1349] = "jup_camo_ob_17c";
    level.rm_refs[1350] = "jup_camo_ob_17d";
    level.rm_refs[1351] = "jup_camo_ob_17e";
    level.rm_refs[1352] = "jup_camo_ob_17f";
    level.rm_refs[1353] = "jup_camo_ob_17g";
    level.rm_refs[1354] = "jup_camo_ob_18a";
    level.rm_refs[1355] = "jup_camo_ob_18b";
    level.rm_refs[1356] = "jup_camo_ob_18c";
    level.rm_refs[1357] = "jup_camo_ob_18d";
    level.rm_refs[1358] = "jup_camo_ob_18e";
    level.rm_refs[1359] = "jup_camo_ob_19a";
    level.rm_refs[1360] = "jup_camo_ob_19b";
    level.rm_refs[1361] = "jup_camo_ob_19c";
    level.rm_refs[1362] = "jup_camo_ob_19d";
    level.rm_refs[1363] = "jup_camo_ob_19e";
    level.rm_refs[1364] = "jup_camo_ob_19f";
    level.rm_refs[1365] = "jup_camo_ob_19g";
    level.rm_refs[1366] = "jup_camo_ob_19h";
    level.rm_refs[1367] = "jup_camo_ob_19i";
    level.rm_refs[1368] = "jup_camo_ob_19j";
    level.rm_refs[1369] = "jup_camo_ob_19k";
    level.rm_refs[1370] = "jup_camo_ob_19l";
    level.rm_refs[1371] = "jup_camo_ob_19m";
    level.rm_refs[1372] = "jup_camo_ob_20d";
    level.rm_refs[1373] = "jup_camo_ob_20f";
    level.rm_refs[1374] = "jup_camo_ob_20g";
    level.rm_refs[1375] = "jup_camo_ob_20h";
    level.rm_refs[1376] = "jup_camo_ob_21a";
    level.rm_refs[1377] = "jup_camo_ob_22a";
    level.rm_refs[1378] = "jup_camo_ob_22b";
    level.rm_refs[1379] = "jup_camo_ob_22c";
    level.rm_refs[1380] = "jup_camo_ob_22d";
    level.rm_refs[1381] = "jup_camo_ob_22e";
    level.rm_refs[1382] = "jup_camo_ob_22f";
    level.rm_refs[1383] = "jup_camo_ob_22g";
    level.rm_refs[1384] = "jup_camo_ob_22h";
    level.rm_refs[1385] = "jup_camo_ob_23a";
    level.rm_refs[1386] = "jup_camo_ob_23d";
    level.rm_refs[1387] = "jup_camo_ob_23e";
    level.rm_refs[1388] = "jup_camo_ob_23f";
    level.rm_refs[1389] = "jup_camo_ob_24a";
    level.rm_refs[1390] = "jup_camo_ob_24b";
    level.rm_refs[1391] = "jup_camo_ob_24c";
    level.rm_refs[1392] = "jup_camo_ob_24d";
    level.rm_refs[1393] = "jup_camo_ob_24e";
    level.rm_refs[1394] = "jup_camo_ob_24f";
    level.rm_refs[1395] = "jup_camo_ob_24h";
    level.rm_refs[1396] = "jup_camo_ob_24i";
    level.rm_refs[1397] = "jup_camo_ob_25a";
    level.rm_refs[1398] = "jup_camo_ob_25b";
    level.rm_refs[1399] = "jup_camo_ob_25c";
    level.rm_refs[1400] = "jup_camo_ob_25i";
}
function private rm_catalog_14()
{
    level.rm_refs[1401] = "jup_camo_ob_26a";
    level.rm_refs[1402] = "jup_camo_ob_26b";
    level.rm_refs[1403] = "jup_camo_ob_comp_01";
    level.rm_refs[1404] = "jup_camo_ob_comp_02";
    level.rm_refs[1405] = "jup_camo_ob_comp_03";
    level.rm_refs[1406] = "jup_camo_ob_comp_04";
    level.rm_refs[1407] = "jup_camo_ob_iw9_10a";
    level.rm_refs[1408] = "jup_camo_ob_iw9_10b";
    level.rm_refs[1409] = "jup_camo_ob_iw9_10c";
    level.rm_refs[1410] = "jup_camo_ob_iw9_10d";
    level.rm_refs[1411] = "jup_camo_ob_iw9_10e";
    level.rm_refs[1412] = "jup_camo_ob_iw9_10f";
    level.rm_refs[1413] = "jup_camo_ob_iw9_10g";
    level.rm_refs[1414] = "jup_camo_ob_iw9_10h";
    level.rm_refs[1415] = "jup_camo_ob_iw9_10i";
    level.rm_refs[1416] = "jup_camo_ob_iw9_10j";
    level.rm_refs[1417] = "jup_camo_ob_iw9_10k";
    level.rm_refs[1418] = "jup_camo_ob_iw9_10l";
    level.rm_refs[1419] = "jup_camo_ob_iw9_10m";
    level.rm_refs[1420] = "jup_camo_ob_iw9_10n";
    level.rm_refs[1421] = "jup_camo_ob_iw9_10o";
    level.rm_refs[1422] = "jup_camo_ob_iw9_10p";
    level.rm_refs[1423] = "jup_camo_ob_iw9_10q";
    level.rm_refs[1424] = "jup_camo_ob_iw9_10s";
    level.rm_refs[1425] = "jup_camo_ob_iw9_10t";
    level.rm_refs[1426] = "jup_camo_ob_iw9_10v";
    level.rm_refs[1427] = "jup_camo_ob_iw9_11a";
    level.rm_refs[1428] = "jup_camo_ob_iw9_11b";
    level.rm_refs[1429] = "jup_camo_ob_iw9_11c";
    level.rm_refs[1430] = "jup_camo_ob_iw9_11d";
    level.rm_refs[1431] = "jup_camo_ob_iw9_11e";
    level.rm_refs[1432] = "jup_camo_ob_iw9_11f";
    level.rm_refs[1433] = "jup_camo_ob_iw9_11g";
    level.rm_refs[1434] = "jup_camo_ob_iw9_11h";
    level.rm_refs[1435] = "jup_camo_ob_iw9_11i";
    level.rm_refs[1436] = "jup_camo_ob_iw9_11j";
    level.rm_refs[1437] = "jup_camo_ob_iw9_11k";
    level.rm_refs[1438] = "jup_camo_ob_iw9_11l";
    level.rm_refs[1439] = "jup_camo_ob_iw9_11m";
    level.rm_refs[1440] = "jup_camo_ob_iw9_11n";
    level.rm_refs[1441] = "jup_camo_ob_iw9_11o";
    level.rm_refs[1442] = "jup_camo_ob_iw9_11p";
    level.rm_refs[1443] = "jup_camo_ob_iw9_11q";
    level.rm_refs[1444] = "jup_camo_ob_iw9_11s";
    level.rm_refs[1445] = "jup_camo_ob_iw9_11t";
    level.rm_refs[1446] = "jup_camo_ob_iw9_11v";
    level.rm_refs[1447] = "jup_camo_ob_iw9_12a";
    level.rm_refs[1448] = "jup_camo_ob_iw9_12b";
    level.rm_refs[1449] = "jup_camo_ob_iw9_12c";
    level.rm_refs[1450] = "jup_camo_ob_iw9_12d";
    level.rm_refs[1451] = "jup_camo_ob_iw9_12e";
    level.rm_refs[1452] = "jup_camo_ob_iw9_12f";
    level.rm_refs[1453] = "jup_camo_ob_iw9_12g";
    level.rm_refs[1454] = "jup_camo_ob_iw9_12h";
    level.rm_refs[1455] = "jup_camo_ob_iw9_12i";
    level.rm_refs[1456] = "jup_camo_ob_iw9_12j";
    level.rm_refs[1457] = "jup_camo_ob_iw9_12k";
    level.rm_refs[1458] = "jup_camo_ob_iw9_12l";
    level.rm_refs[1459] = "jup_camo_ob_iw9_12m";
    level.rm_refs[1460] = "jup_camo_ob_iw9_12n";
    level.rm_refs[1461] = "jup_camo_ob_iw9_12o";
    level.rm_refs[1462] = "jup_camo_ob_iw9_12p";
    level.rm_refs[1463] = "jup_camo_ob_iw9_12q";
    level.rm_refs[1464] = "jup_camo_ob_iw9_12r";
    level.rm_refs[1465] = "jup_camo_ob_iw9_12t";
    level.rm_refs[1466] = "jup_camo_ob_iw9_12v";
    level.rm_refs[1467] = "jup_camo_ob_iw9_13a";
    level.rm_refs[1468] = "jup_camo_ob_iw9_13b";
    level.rm_refs[1469] = "jup_camo_ob_iw9_13c";
    level.rm_refs[1470] = "jup_camo_ob_iw9_13d";
    level.rm_refs[1471] = "jup_camo_ob_iw9_13e";
    level.rm_refs[1472] = "jup_camo_ob_iw9_13f";
    level.rm_refs[1473] = "jup_camo_ob_iw9_13g";
    level.rm_refs[1474] = "jup_camo_ob_iw9_13h";
    level.rm_refs[1475] = "jup_camo_ob_iw9_13i";
    level.rm_refs[1476] = "jup_camo_ob_iw9_13j";
    level.rm_refs[1477] = "jup_camo_ob_iw9_13k";
    level.rm_refs[1478] = "jup_camo_ob_iw9_13l";
    level.rm_refs[1479] = "jup_camo_ob_iw9_13m";
    level.rm_refs[1480] = "jup_camo_ob_iw9_13n";
    level.rm_refs[1481] = "jup_camo_ob_iw9_13o";
    level.rm_refs[1482] = "jup_camo_ob_iw9_13p";
    level.rm_refs[1483] = "jup_camo_ob_iw9_13q";
    level.rm_refs[1484] = "jup_camo_ob_iw9_13t";
    level.rm_refs[1485] = "jup_camo_ob_iw9_13v";
    level.rm_refs[1486] = "jup_camo_ob_iw9_14a";
    level.rm_refs[1487] = "jup_camo_ob_iw9_14b";
    level.rm_refs[1488] = "jup_camo_ob_iw9_14c";
    level.rm_refs[1489] = "jup_camo_ob_iw9_14d";
    level.rm_refs[1490] = "jup_camo_ob_iw9_14e";
    level.rm_refs[1491] = "jup_camo_ob_iw9_14f";
    level.rm_refs[1492] = "jup_camo_ob_iw9_14g";
    level.rm_refs[1493] = "jup_camo_ob_iw9_14h";
    level.rm_refs[1494] = "jup_camo_ob_iw9_14i";
    level.rm_refs[1495] = "jup_camo_ob_iw9_14j";
    level.rm_refs[1496] = "jup_camo_ob_iw9_14k";
    level.rm_refs[1497] = "jup_camo_ob_iw9_14l";
    level.rm_refs[1498] = "jup_camo_ob_iw9_14m";
    level.rm_refs[1499] = "jup_camo_ob_iw9_14o";
    level.rm_refs[1500] = "jup_camo_ob_iw9_14p";
}
function private rm_catalog_15()
{
    level.rm_refs[1501] = "jup_camo_ob_iw9_14q";
    level.rm_refs[1502] = "jup_camo_ob_iw9_14t";
    level.rm_refs[1503] = "jup_camo_ob_iw9_14v";
    level.rm_refs[1504] = "jup_camo_ob_iw9_15a";
    level.rm_refs[1505] = "jup_camo_ob_iw9_15b";
    level.rm_refs[1506] = "jup_camo_ob_iw9_15c";
    level.rm_refs[1507] = "jup_camo_ob_iw9_15d";
    level.rm_refs[1508] = "jup_camo_ob_iw9_15e";
    level.rm_refs[1509] = "jup_camo_ob_iw9_15f";
    level.rm_refs[1510] = "jup_camo_ob_iw9_15g";
    level.rm_refs[1511] = "jup_camo_ob_iw9_15h";
    level.rm_refs[1512] = "jup_camo_ob_iw9_15i";
    level.rm_refs[1513] = "jup_camo_ob_iw9_15j";
    level.rm_refs[1514] = "jup_camo_ob_iw9_15k";
    level.rm_refs[1515] = "jup_camo_ob_iw9_15l";
    level.rm_refs[1516] = "jup_camo_ob_iw9_15m";
    level.rm_refs[1517] = "jup_camo_ob_iw9_15p";
    level.rm_refs[1518] = "jup_camo_ob_iw9_15q";
    level.rm_refs[1519] = "jup_camo_ob_iw9_15t";
    level.rm_refs[1520] = "jup_camo_ob_iw9_15u";
    level.rm_refs[1521] = "jup_camo_ob_iw9_15v";
    level.rm_refs[1522] = "jup_camo_ob_iw9_1a";
    level.rm_refs[1523] = "jup_camo_ob_iw9_1b";
    level.rm_refs[1524] = "jup_camo_ob_iw9_1c";
    level.rm_refs[1525] = "jup_camo_ob_iw9_1d";
    level.rm_refs[1526] = "jup_camo_ob_iw9_1e";
    level.rm_refs[1527] = "jup_camo_ob_iw9_1f";
    level.rm_refs[1528] = "jup_camo_ob_iw9_1g";
    level.rm_refs[1529] = "jup_camo_ob_iw9_1h";
    level.rm_refs[1530] = "jup_camo_ob_iw9_1i";
    level.rm_refs[1531] = "jup_camo_ob_iw9_1j";
    level.rm_refs[1532] = "jup_camo_ob_iw9_1k";
    level.rm_refs[1533] = "jup_camo_ob_iw9_1l";
    level.rm_refs[1534] = "jup_camo_ob_iw9_1m";
    level.rm_refs[1535] = "jup_camo_ob_iw9_1n";
    level.rm_refs[1536] = "jup_camo_ob_iw9_1o";
    level.rm_refs[1537] = "jup_camo_ob_iw9_1p";
    level.rm_refs[1538] = "jup_camo_ob_iw9_1q";
    level.rm_refs[1539] = "jup_camo_ob_iw9_1s";
    level.rm_refs[1540] = "jup_camo_ob_iw9_1t";
    level.rm_refs[1541] = "jup_camo_ob_iw9_1u";
    level.rm_refs[1542] = "jup_camo_ob_iw9_1v";
    level.rm_refs[1543] = "jup_camo_ob_iw9_1w";
    level.rm_refs[1544] = "jup_camo_ob_iw9_2a";
    level.rm_refs[1545] = "jup_camo_ob_iw9_2b";
    level.rm_refs[1546] = "jup_camo_ob_iw9_2c";
    level.rm_refs[1547] = "jup_camo_ob_iw9_2d";
    level.rm_refs[1548] = "jup_camo_ob_iw9_2e";
    level.rm_refs[1549] = "jup_camo_ob_iw9_2f";
    level.rm_refs[1550] = "jup_camo_ob_iw9_2g";
    level.rm_refs[1551] = "jup_camo_ob_iw9_2h";
    level.rm_refs[1552] = "jup_camo_ob_iw9_2i";
    level.rm_refs[1553] = "jup_camo_ob_iw9_2j";
    level.rm_refs[1554] = "jup_camo_ob_iw9_2k";
    level.rm_refs[1555] = "jup_camo_ob_iw9_2l";
    level.rm_refs[1556] = "jup_camo_ob_iw9_2m";
    level.rm_refs[1557] = "jup_camo_ob_iw9_2n";
    level.rm_refs[1558] = "jup_camo_ob_iw9_2o";
    level.rm_refs[1559] = "jup_camo_ob_iw9_2p";
    level.rm_refs[1560] = "jup_camo_ob_iw9_2s";
    level.rm_refs[1561] = "jup_camo_ob_iw9_2t";
    level.rm_refs[1562] = "jup_camo_ob_iw9_2v";
    level.rm_refs[1563] = "jup_camo_ob_iw9_3a";
    level.rm_refs[1564] = "jup_camo_ob_iw9_3b";
    level.rm_refs[1565] = "jup_camo_ob_iw9_3c";
    level.rm_refs[1566] = "jup_camo_ob_iw9_3d";
    level.rm_refs[1567] = "jup_camo_ob_iw9_3e";
    level.rm_refs[1568] = "jup_camo_ob_iw9_3f";
    level.rm_refs[1569] = "jup_camo_ob_iw9_3g";
    level.rm_refs[1570] = "jup_camo_ob_iw9_3h";
    level.rm_refs[1571] = "jup_camo_ob_iw9_3i";
    level.rm_refs[1572] = "jup_camo_ob_iw9_3j";
    level.rm_refs[1573] = "jup_camo_ob_iw9_3k";
    level.rm_refs[1574] = "jup_camo_ob_iw9_3l";
    level.rm_refs[1575] = "jup_camo_ob_iw9_3m";
    level.rm_refs[1576] = "jup_camo_ob_iw9_3n";
    level.rm_refs[1577] = "jup_camo_ob_iw9_3o";
    level.rm_refs[1578] = "jup_camo_ob_iw9_3p";
    level.rm_refs[1579] = "jup_camo_ob_iw9_3s";
    level.rm_refs[1580] = "jup_camo_ob_iw9_3t";
    level.rm_refs[1581] = "jup_camo_ob_iw9_3v";
    level.rm_refs[1582] = "jup_camo_ob_iw9_4a";
    level.rm_refs[1583] = "jup_camo_ob_iw9_4b";
    level.rm_refs[1584] = "jup_camo_ob_iw9_4c";
    level.rm_refs[1585] = "jup_camo_ob_iw9_4d";
    level.rm_refs[1586] = "jup_camo_ob_iw9_4e";
    level.rm_refs[1587] = "jup_camo_ob_iw9_4f";
    level.rm_refs[1588] = "jup_camo_ob_iw9_4g";
    level.rm_refs[1589] = "jup_camo_ob_iw9_4h";
    level.rm_refs[1590] = "jup_camo_ob_iw9_4i";
    level.rm_refs[1591] = "jup_camo_ob_iw9_4j";
    level.rm_refs[1592] = "jup_camo_ob_iw9_4k";
    level.rm_refs[1593] = "jup_camo_ob_iw9_4l";
    level.rm_refs[1594] = "jup_camo_ob_iw9_4m";
    level.rm_refs[1595] = "jup_camo_ob_iw9_4n";
    level.rm_refs[1596] = "jup_camo_ob_iw9_4o";
    level.rm_refs[1597] = "jup_camo_ob_iw9_4p";
    level.rm_refs[1598] = "jup_camo_ob_iw9_4s";
    level.rm_refs[1599] = "jup_camo_ob_iw9_4t";
    level.rm_refs[1600] = "jup_camo_ob_iw9_4v";
}
function private rm_catalog_16()
{
    level.rm_refs[1601] = "jup_camo_ob_iw9_5a";
    level.rm_refs[1602] = "jup_camo_ob_iw9_5b";
    level.rm_refs[1603] = "jup_camo_ob_iw9_5c";
    level.rm_refs[1604] = "jup_camo_ob_iw9_5d";
    level.rm_refs[1605] = "jup_camo_ob_iw9_5e";
    level.rm_refs[1606] = "jup_camo_ob_iw9_5f";
    level.rm_refs[1607] = "jup_camo_ob_iw9_5g";
    level.rm_refs[1608] = "jup_camo_ob_iw9_5h";
    level.rm_refs[1609] = "jup_camo_ob_iw9_5i";
    level.rm_refs[1610] = "jup_camo_ob_iw9_5j";
    level.rm_refs[1611] = "jup_camo_ob_iw9_5k";
    level.rm_refs[1612] = "jup_camo_ob_iw9_5l";
    level.rm_refs[1613] = "jup_camo_ob_iw9_5m";
    level.rm_refs[1614] = "jup_camo_ob_iw9_5n";
    level.rm_refs[1615] = "jup_camo_ob_iw9_5o";
    level.rm_refs[1616] = "jup_camo_ob_iw9_5p";
    level.rm_refs[1617] = "jup_camo_ob_iw9_5s";
    level.rm_refs[1618] = "jup_camo_ob_iw9_5t";
    level.rm_refs[1619] = "jup_camo_ob_iw9_5v";
    level.rm_refs[1620] = "jup_camo_ob_iw9_6a";
    level.rm_refs[1621] = "jup_camo_ob_iw9_6b";
    level.rm_refs[1622] = "jup_camo_ob_iw9_6c";
    level.rm_refs[1623] = "jup_camo_ob_iw9_6d";
    level.rm_refs[1624] = "jup_camo_ob_iw9_6e";
    level.rm_refs[1625] = "jup_camo_ob_iw9_6f";
    level.rm_refs[1626] = "jup_camo_ob_iw9_6g";
    level.rm_refs[1627] = "jup_camo_ob_iw9_6h";
    level.rm_refs[1628] = "jup_camo_ob_iw9_6i";
    level.rm_refs[1629] = "jup_camo_ob_iw9_6j";
    level.rm_refs[1630] = "jup_camo_ob_iw9_6k";
    level.rm_refs[1631] = "jup_camo_ob_iw9_6l";
    level.rm_refs[1632] = "jup_camo_ob_iw9_6m";
    level.rm_refs[1633] = "jup_camo_ob_iw9_6n";
    level.rm_refs[1634] = "jup_camo_ob_iw9_6o";
    level.rm_refs[1635] = "jup_camo_ob_iw9_6p";
    level.rm_refs[1636] = "jup_camo_ob_iw9_6s";
    level.rm_refs[1637] = "jup_camo_ob_iw9_6t";
    level.rm_refs[1638] = "jup_camo_ob_iw9_6v";
    level.rm_refs[1639] = "jup_camo_ob_iw9_7a";
    level.rm_refs[1640] = "jup_camo_ob_iw9_7b";
    level.rm_refs[1641] = "jup_camo_ob_iw9_7c";
    level.rm_refs[1642] = "jup_camo_ob_iw9_7d";
    level.rm_refs[1643] = "jup_camo_ob_iw9_7e";
    level.rm_refs[1644] = "jup_camo_ob_iw9_7f";
    level.rm_refs[1645] = "jup_camo_ob_iw9_7g";
    level.rm_refs[1646] = "jup_camo_ob_iw9_7h";
    level.rm_refs[1647] = "jup_camo_ob_iw9_7i";
    level.rm_refs[1648] = "jup_camo_ob_iw9_7j";
    level.rm_refs[1649] = "jup_camo_ob_iw9_7k";
    level.rm_refs[1650] = "jup_camo_ob_iw9_7l";
    level.rm_refs[1651] = "jup_camo_ob_iw9_7m";
    level.rm_refs[1652] = "jup_camo_ob_iw9_7n";
    level.rm_refs[1653] = "jup_camo_ob_iw9_7o";
    level.rm_refs[1654] = "jup_camo_ob_iw9_7p";
    level.rm_refs[1655] = "jup_camo_ob_iw9_7s";
    level.rm_refs[1656] = "jup_camo_ob_iw9_7t";
    level.rm_refs[1657] = "jup_camo_ob_iw9_7v";
    level.rm_refs[1658] = "jup_camo_ob_iw9_8a";
    level.rm_refs[1659] = "jup_camo_ob_iw9_8b";
    level.rm_refs[1660] = "jup_camo_ob_iw9_8c";
    level.rm_refs[1661] = "jup_camo_ob_iw9_8d";
    level.rm_refs[1662] = "jup_camo_ob_iw9_8e";
    level.rm_refs[1663] = "jup_camo_ob_iw9_8f";
    level.rm_refs[1664] = "jup_camo_ob_iw9_8g";
    level.rm_refs[1665] = "jup_camo_ob_iw9_8h";
    level.rm_refs[1666] = "jup_camo_ob_iw9_8i";
    level.rm_refs[1667] = "jup_camo_ob_iw9_8j";
    level.rm_refs[1668] = "jup_camo_ob_iw9_8k";
    level.rm_refs[1669] = "jup_camo_ob_iw9_8l";
    level.rm_refs[1670] = "jup_camo_ob_iw9_8m";
    level.rm_refs[1671] = "jup_camo_ob_iw9_8o";
    level.rm_refs[1672] = "jup_camo_ob_iw9_8s";
    level.rm_refs[1673] = "jup_camo_ob_iw9_8t";
    level.rm_refs[1674] = "jup_camo_ob_iw9_8v";
    level.rm_refs[1675] = "jup_camo_ob_iw9_9a";
    level.rm_refs[1676] = "jup_camo_ob_iw9_9b";
    level.rm_refs[1677] = "jup_camo_ob_iw9_9c";
    level.rm_refs[1678] = "jup_camo_ob_iw9_9d";
    level.rm_refs[1679] = "jup_camo_ob_iw9_9e";
    level.rm_refs[1680] = "jup_camo_ob_iw9_9f";
    level.rm_refs[1681] = "jup_camo_ob_iw9_9g";
    level.rm_refs[1682] = "jup_camo_ob_iw9_9h";
    level.rm_refs[1683] = "jup_camo_ob_iw9_9i";
    level.rm_refs[1684] = "jup_camo_ob_iw9_9j";
    level.rm_refs[1685] = "jup_camo_ob_iw9_9k";
    level.rm_refs[1686] = "jup_camo_ob_iw9_9l";
    level.rm_refs[1687] = "jup_camo_ob_iw9_9m";
    level.rm_refs[1688] = "jup_camo_ob_iw9_9o";
    level.rm_refs[1689] = "jup_camo_ob_iw9_9p";
    level.rm_refs[1690] = "jup_camo_ob_iw9_9s";
    level.rm_refs[1691] = "jup_camo_ob_iw9_9t";
    level.rm_refs[1692] = "jup_camo_ob_iw9_9v";
    level.rm_refs[1693] = "jup_camo_ob_iw9_comp_01";
    level.rm_refs[1694] = "jup_camo_ob_iw9_comp_02";
    level.rm_refs[1695] = "jup_camo_ob_iw9_comp_03";
    level.rm_refs[1696] = "jup_camo_ob_iw9_comp_04";
    level.rm_refs[1697] = "jup_camo_ob_n5910_10";
    level.rm_refs[1698] = "jup_camo_ob_n5910_20";
    level.rm_refs[1699] = "jup_camo_ob_n6908_12";
    level.rm_refs[1700] = "jup_camo_ob_n6908_13";
}
function private rm_catalog_17()
{
    level.rm_refs[1701] = "jup_camo_prest_01";
    level.rm_refs[1702] = "jup_camo_prest_02";
    level.rm_refs[1703] = "jup_camo_prest_03";
    level.rm_refs[1704] = "jup_camo_prest_04";
    level.rm_refs[1705] = "jup_camo_rankeda";
    level.rm_refs[1706] = "jup_camo_rankedb";
    level.rm_refs[1707] = "jup_camo_rankedc";
    level.rm_refs[1708] = "jup_camo_rankedd";
    level.rm_refs[1709] = "jup_camo_rankede";
    level.rm_refs[1710] = "jup_camo_rankedf";
    level.rm_refs[1711] = "jup_camo_rankedg";
    level.rm_refs[1712] = "jup_camo_rankedh";
    level.rm_refs[1713] = "jup_camo_rankedi";
    level.rm_refs[1714] = "jup_camo_rankedj";
    level.rm_refs[1715] = "jup_camo_rankedk";
    level.rm_refs[1716] = "jup_camo_rankedl";
    level.rm_refs[1717] = "jup_camo_rankedm";
    level.rm_refs[1718] = "jup_camo_rankedn";
    level.rm_refs[1719] = "jup_camo_rankedo";
    level.rm_refs[1720] = "jup_camo_rankedp";
    level.rm_refs[1721] = "jup_camo_rankedq";
    level.rm_refs[1722] = "jup_camo_rankedr";
    level.rm_refs[1723] = "jup_camo_rankeds";
    level.rm_refs[1724] = "jup_camo_rankedt";
    level.rm_refs[1725] = "jup_camo_rankedu";
    level.rm_refs[1726] = "jup_camo_special_01a";
    level.rm_refs[1727] = "jup_camo_speciala";
    level.rm_refs[1728] = "jup_camo_specialg";
    level.rm_refs[1729] = "jup_camo_specialh";
    level.rm_refs[1730] = "jup_camo_speciali";
    level.rm_refs[1731] = "jup_camo_specialj";
    level.rm_refs[1732] = "jup_camo_specialk";
    level.rm_refs[1733] = "jup_camo_speciall";
    level.rm_refs[1734] = "jup_camo_specialm";
    level.rm_refs[1735] = "jup_camo_specialo";
    level.rm_refs[1736] = "jup_camo_specialp";
    level.rm_refs[1737] = "jup_camo_specialq";
    level.rm_refs[1738] = "jup_camo_specialr";
    level.rm_refs[1739] = "jup_camo_specials";
    level.rm_refs[1740] = "jup_camo_specialt";
    level.rm_refs[1741] = "jup_camo_specialv";
    level.rm_refs[1742] = "jup_camo_specialw";
    level.rm_refs[1743] = "jup_camo_specialx";
    level.rm_refs[1744] = "jup_camo_specialy";
    level.rm_refs[1745] = "jup_camo_specialz";
    level.rm_refs[1746] = "sat_camo_base_01_mp";
    level.rm_refs[1747] = "sat_camo_base_01_wc";
    level.rm_refs[1748] = "sat_camo_base_01_wz";
    level.rm_refs[1749] = "sat_camo_base_01_zm";
    level.rm_refs[1750] = "sat_camo_base_02_mp";
    level.rm_refs[1751] = "sat_camo_base_02_wc";
    level.rm_refs[1752] = "sat_camo_base_02_wz";
    level.rm_refs[1753] = "sat_camo_base_02_zm";
    level.rm_refs[1754] = "sat_camo_base_03_mp";
    level.rm_refs[1755] = "sat_camo_base_03_wc";
    level.rm_refs[1756] = "sat_camo_base_03_wz";
    level.rm_refs[1757] = "sat_camo_base_03_zm";
    level.rm_refs[1758] = "sat_camo_base_04_mp";
    level.rm_refs[1759] = "sat_camo_base_04_wc";
    level.rm_refs[1760] = "sat_camo_base_04_wz";
    level.rm_refs[1761] = "sat_camo_base_04_zm";
    level.rm_refs[1762] = "sat_camo_base_05_mp";
    level.rm_refs[1763] = "sat_camo_base_05_wc";
    level.rm_refs[1764] = "sat_camo_base_05_wz";
    level.rm_refs[1765] = "sat_camo_base_05_zm";
    level.rm_refs[1766] = "sat_camo_base_06_mp";
    level.rm_refs[1767] = "sat_camo_base_06_wc";
    level.rm_refs[1768] = "sat_camo_base_06_wz";
    level.rm_refs[1769] = "sat_camo_base_06_zm";
    level.rm_refs[1770] = "sat_camo_base_07_mp";
    level.rm_refs[1771] = "sat_camo_base_07_wc";
    level.rm_refs[1772] = "sat_camo_base_07_wz";
    level.rm_refs[1773] = "sat_camo_base_07_zm";
    level.rm_refs[1774] = "sat_camo_base_08_mp";
    level.rm_refs[1775] = "sat_camo_base_08_wc";
    level.rm_refs[1776] = "sat_camo_base_08_wz";
    level.rm_refs[1777] = "sat_camo_base_08_zm";
    level.rm_refs[1778] = "sat_camo_base_09_mp";
    level.rm_refs[1779] = "sat_camo_base_09_wc";
    level.rm_refs[1780] = "sat_camo_base_09_wz";
    level.rm_refs[1781] = "sat_camo_base_09_zm";
    level.rm_refs[1782] = "sat_camo_comp_01_mp";
    level.rm_refs[1783] = "sat_camo_comp_01_wc";
    level.rm_refs[1784] = "sat_camo_comp_01_wz";
    level.rm_refs[1785] = "sat_camo_comp_01_zm";
    level.rm_refs[1786] = "sat_camo_comp_02_mp";
    level.rm_refs[1787] = "sat_camo_comp_02_wc";
    level.rm_refs[1788] = "sat_camo_comp_02_wz";
    level.rm_refs[1789] = "sat_camo_comp_02_zm";
    level.rm_refs[1790] = "sat_camo_comp_03_mp";
    level.rm_refs[1791] = "sat_camo_comp_03_wc";
    level.rm_refs[1792] = "sat_camo_comp_03_wz";
    level.rm_refs[1793] = "sat_camo_comp_03_zm";
    level.rm_refs[1794] = "sat_camo_comp_04_mp";
    level.rm_refs[1795] = "sat_camo_comp_04_wc";
    level.rm_refs[1796] = "sat_camo_comp_04_wz";
    level.rm_refs[1797] = "sat_camo_comp_04_zm";
    level.rm_refs[1798] = "sat_camo_comp_05";
    level.rm_refs[1799] = "sat_camo_event_camo_s2_coop_anim";
    level.rm_refs[1800] = "sat_camo_event_camo_s2_coop_static";
}
function private rm_catalog_18()
{
    level.rm_refs[1801] = "sat_camo_event_camo_s2_final";
    level.rm_refs[1802] = "sat_camo_event_camo_s2_mp_anim";
    level.rm_refs[1803] = "sat_camo_event_camo_s2_mp_static";
    level.rm_refs[1804] = "sat_camo_event_camo_s2_wz_anim";
    level.rm_refs[1805] = "sat_camo_event_camo_s2_wz_static";
    level.rm_refs[1806] = "sat_camo_event_camo_s2_zm_anim";
    level.rm_refs[1807] = "sat_camo_event_camo_s2_zm_static";
    level.rm_refs[1808] = "sat_camo_event_camo_s3_5_mam";
    level.rm_refs[1809] = "sat_camo_event_camo_s3_5_mp_freerun_01";
    level.rm_refs[1810] = "sat_camo_event_camo_s3_5_mp_freerun_02";
    level.rm_refs[1811] = "sat_camo_event_camo_s3_ashwood_anim";
    level.rm_refs[1812] = "sat_camo_event_camo_s3_ashwood_static";
    level.rm_refs[1813] = "sat_camo_event_camo_s3_outpost_01";
    level.rm_refs[1814] = "sat_camo_event_camo_s3_outpost_02";
    level.rm_refs[1815] = "sat_camo_event_camo_s4_5_zm_hornet_01";
    level.rm_refs[1816] = "sat_camo_event_camo_s4_5_zm_hornet_02";
    level.rm_refs[1817] = "sat_camo_event_camo_s4_merc_anim_01";
    level.rm_refs[1818] = "sat_camo_event_camo_s4_merc_anim_02";
    level.rm_refs[1819] = "sat_camo_event_camo_s4_merc_anim_03";
    level.rm_refs[1820] = "sat_camo_event_camo_s4_merc_anim_04";
    level.rm_refs[1821] = "sat_camo_event_camo_s4_merc_anim_05";
    level.rm_refs[1822] = "sat_camo_event_camo_s4_merc_static_01";
    level.rm_refs[1823] = "sat_camo_event_camo_s4_merc_static_02";
    level.rm_refs[1824] = "sat_camo_event_camo_s4_merc_static_03";
    level.rm_refs[1825] = "sat_camo_event_camo_s4_merc_static_04";
    level.rm_refs[1826] = "sat_camo_event_camo_s4_zm_nuked_01";
    level.rm_refs[1827] = "sat_camo_event_camo_s4_zm_nuked_02";
    level.rm_refs[1828] = "sat_camo_event_camo_s5_5_mp_freerun_01";
    level.rm_refs[1829] = "sat_camo_event_camo_s5_5_mp_freerun_02";
    level.rm_refs[1830] = "sat_camo_event_camo_s5_light_01";
    level.rm_refs[1831] = "sat_camo_event_camo_s5_light_02";
    level.rm_refs[1832] = "sat_camo_event_camo_s5_metal_01";
    level.rm_refs[1833] = "sat_camo_event_camo_s5_metal_02";
    level.rm_refs[1834] = "sat_camo_event_camo_s6_haunt_anim_09";
    level.rm_refs[1835] = "sat_camo_event_camo_s6_haunt_static_01";
    level.rm_refs[1836] = "sat_camo_event_camo_s6_haunt_static_02";
    level.rm_refs[1837] = "sat_camo_event_camo_s6_haunt_static_03";
    level.rm_refs[1838] = "sat_camo_event_camo_s6_haunt_static_04";
    level.rm_refs[1839] = "sat_camo_event_camo_s6_haunt_static_05";
    level.rm_refs[1840] = "sat_camo_event_camo_s6_haunt_static_06";
    level.rm_refs[1841] = "sat_camo_event_camo_s6_haunt_static_07";
    level.rm_refs[1842] = "sat_camo_event_camo_s6_haunt_static_08";
    level.rm_refs[1843] = "sat_camo_event_ranked_s25_crim_1st";
    level.rm_refs[1844] = "sat_camo_event_ranked_s25_crim_top10";
    level.rm_refs[1845] = "sat_camo_event_ranked_s25_diam_1st";
    level.rm_refs[1846] = "sat_camo_event_ranked_s25_diam_top10";
    level.rm_refs[1847] = "sat_camo_event_ranked_s25_gold_1st";
    level.rm_refs[1848] = "sat_camo_event_ranked_s25_gold_top10";
    level.rm_refs[1849] = "sat_camo_event_ranked_s25_irid_1st";
    level.rm_refs[1850] = "sat_camo_event_ranked_s25_irid_top10";
    level.rm_refs[1851] = "sat_camo_event_ranked_s25_plat_1st";
    level.rm_refs[1852] = "sat_camo_event_ranked_s25_plat_top10";
    level.rm_refs[1853] = "sat_camo_event_ranked_s25_t250_1st";
    level.rm_refs[1854] = "sat_camo_event_ranked_s25_t250_top25";
    level.rm_refs[1855] = "sat_camo_event_ranked_s3_5_crim_1st";
    level.rm_refs[1856] = "sat_camo_event_ranked_s3_5_crim_top10";
    level.rm_refs[1857] = "sat_camo_event_ranked_s3_5_diam_1st";
    level.rm_refs[1858] = "sat_camo_event_ranked_s3_5_diam_top10";
    level.rm_refs[1859] = "sat_camo_event_ranked_s3_5_gold_1st";
    level.rm_refs[1860] = "sat_camo_event_ranked_s3_5_gold_top10";
    level.rm_refs[1861] = "sat_camo_event_ranked_s3_5_irid_1st";
    level.rm_refs[1862] = "sat_camo_event_ranked_s3_5_irid_top10";
    level.rm_refs[1863] = "sat_camo_event_ranked_s3_5_plat_1st";
    level.rm_refs[1864] = "sat_camo_event_ranked_s3_5_plat_top10";
    level.rm_refs[1865] = "sat_camo_event_ranked_s3_5_t250_1st";
    level.rm_refs[1866] = "sat_camo_event_ranked_s3_5_t250_top25";
    level.rm_refs[1867] = "sat_camo_event_ranked_s4_5_crim_top25";
    level.rm_refs[1868] = "sat_camo_event_ranked_s4_5_crim_top5";
    level.rm_refs[1869] = "sat_camo_event_ranked_s4_5_diam_top25";
    level.rm_refs[1870] = "sat_camo_event_ranked_s4_5_diam_top5";
    level.rm_refs[1871] = "sat_camo_event_ranked_s4_5_gold_top25";
    level.rm_refs[1872] = "sat_camo_event_ranked_s4_5_gold_top5";
    level.rm_refs[1873] = "sat_camo_event_ranked_s4_5_irid_top25";
    level.rm_refs[1874] = "sat_camo_event_ranked_s4_5_irid_top5";
    level.rm_refs[1875] = "sat_camo_event_ranked_s4_5_plat_top25";
    level.rm_refs[1876] = "sat_camo_event_ranked_s4_5_plat_top5";
    level.rm_refs[1877] = "sat_camo_event_ranked_s4_5_t250_top25";
    level.rm_refs[1878] = "sat_camo_event_ranked_s4_5_t250_top5";
    level.rm_refs[1879] = "sat_camo_event_ranked_s5_5_crim_top25";
    level.rm_refs[1880] = "sat_camo_event_ranked_s5_5_crim_top5";
    level.rm_refs[1881] = "sat_camo_event_ranked_s5_5_diam_top25";
    level.rm_refs[1882] = "sat_camo_event_ranked_s5_5_diam_top5";
    level.rm_refs[1883] = "sat_camo_event_ranked_s5_5_gold_top25";
    level.rm_refs[1884] = "sat_camo_event_ranked_s5_5_gold_top5";
    level.rm_refs[1885] = "sat_camo_event_ranked_s5_5_irid_top25";
    level.rm_refs[1886] = "sat_camo_event_ranked_s5_5_irid_top5";
    level.rm_refs[1887] = "sat_camo_event_ranked_s5_5_plat_top25";
    level.rm_refs[1888] = "sat_camo_event_ranked_s5_5_plat_top5";
    level.rm_refs[1889] = "sat_camo_event_ranked_s5_5_t250_top25";
    level.rm_refs[1890] = "sat_camo_event_ranked_s5_5_t250_top5";
    level.rm_refs[1891] = "sat_camo_event_ranked_s6_crim_top25";
    level.rm_refs[1892] = "sat_camo_event_ranked_s6_crim_top5";
    level.rm_refs[1893] = "sat_camo_event_ranked_s6_diam_top25";
    level.rm_refs[1894] = "sat_camo_event_ranked_s6_diam_top5";
    level.rm_refs[1895] = "sat_camo_event_ranked_s6_gold_top25";
    level.rm_refs[1896] = "sat_camo_event_ranked_s6_gold_top5";
    level.rm_refs[1897] = "sat_camo_event_ranked_s6_irid_top25";
    level.rm_refs[1898] = "sat_camo_event_ranked_s6_irid_top5";
    level.rm_refs[1899] = "sat_camo_event_ranked_s6_plat_top25";
    level.rm_refs[1900] = "sat_camo_event_ranked_s6_plat_top5";
}
function private rm_catalog_19()
{
    level.rm_refs[1901] = "sat_camo_event_ranked_s6_t250_top25";
    level.rm_refs[1902] = "sat_camo_event_ranked_s6_t250_top5";
    level.rm_refs[1903] = "sat_camo_event_ranked_wz_s25_crim_1st";
    level.rm_refs[1904] = "sat_camo_event_ranked_wz_s25_crim_top10";
    level.rm_refs[1905] = "sat_camo_event_ranked_wz_s25_diam_1st";
    level.rm_refs[1906] = "sat_camo_event_ranked_wz_s25_diam_top10";
    level.rm_refs[1907] = "sat_camo_event_ranked_wz_s25_gold_1st";
    level.rm_refs[1908] = "sat_camo_event_ranked_wz_s25_gold_top10";
    level.rm_refs[1909] = "sat_camo_event_ranked_wz_s25_irid_1st";
    level.rm_refs[1910] = "sat_camo_event_ranked_wz_s25_irid_top10";
    level.rm_refs[1911] = "sat_camo_event_ranked_wz_s25_plat_1st";
    level.rm_refs[1912] = "sat_camo_event_ranked_wz_s25_plat_top10";
    level.rm_refs[1913] = "sat_camo_event_ranked_wz_s25_t250_1st";
    level.rm_refs[1914] = "sat_camo_event_ranked_wz_s25_t250_top25";
    level.rm_refs[1915] = "sat_camo_event_ranked_wz_s3_5_crim_1st";
    level.rm_refs[1916] = "sat_camo_event_ranked_wz_s3_5_crim_top10";
    level.rm_refs[1917] = "sat_camo_event_ranked_wz_s3_5_diam_1st";
    level.rm_refs[1918] = "sat_camo_event_ranked_wz_s3_5_diam_top10";
    level.rm_refs[1919] = "sat_camo_event_ranked_wz_s3_5_gold_1st";
    level.rm_refs[1920] = "sat_camo_event_ranked_wz_s3_5_gold_top10";
    level.rm_refs[1921] = "sat_camo_event_ranked_wz_s3_5_irid_1st";
    level.rm_refs[1922] = "sat_camo_event_ranked_wz_s3_5_irid_top10";
    level.rm_refs[1923] = "sat_camo_event_ranked_wz_s3_5_plat_1st";
    level.rm_refs[1924] = "sat_camo_event_ranked_wz_s3_5_plat_top10";
    level.rm_refs[1925] = "sat_camo_event_ranked_wz_s3_5_t250_1st";
    level.rm_refs[1926] = "sat_camo_event_ranked_wz_s3_5_t250_top25";
    level.rm_refs[1927] = "sat_camo_event_ranked_wz_s4_5_crim_top25";
    level.rm_refs[1928] = "sat_camo_event_ranked_wz_s4_5_crim_top5";
    level.rm_refs[1929] = "sat_camo_event_ranked_wz_s4_5_diam_top25";
    level.rm_refs[1930] = "sat_camo_event_ranked_wz_s4_5_diam_top5";
    level.rm_refs[1931] = "sat_camo_event_ranked_wz_s4_5_gold_top25";
    level.rm_refs[1932] = "sat_camo_event_ranked_wz_s4_5_gold_top5";
    level.rm_refs[1933] = "sat_camo_event_ranked_wz_s4_5_irid_top25";
    level.rm_refs[1934] = "sat_camo_event_ranked_wz_s4_5_irid_top5";
    level.rm_refs[1935] = "sat_camo_event_ranked_wz_s4_5_plat_top25";
    level.rm_refs[1936] = "sat_camo_event_ranked_wz_s4_5_plat_top5";
    level.rm_refs[1937] = "sat_camo_event_ranked_wz_s4_5_t250_top10";
    level.rm_refs[1938] = "sat_camo_event_ranked_wz_s4_5_t250_top100";
    level.rm_refs[1939] = "sat_camo_event_ranked_wz_s5_5_crim_top25";
    level.rm_refs[1940] = "sat_camo_event_ranked_wz_s5_5_crim_top5";
    level.rm_refs[1941] = "sat_camo_event_ranked_wz_s5_5_diam_top25";
    level.rm_refs[1942] = "sat_camo_event_ranked_wz_s5_5_diam_top5";
    level.rm_refs[1943] = "sat_camo_event_ranked_wz_s5_5_gold_top25";
    level.rm_refs[1944] = "sat_camo_event_ranked_wz_s5_5_gold_top5";
    level.rm_refs[1945] = "sat_camo_event_ranked_wz_s5_5_irid_top25";
    level.rm_refs[1946] = "sat_camo_event_ranked_wz_s5_5_irid_top5";
    level.rm_refs[1947] = "sat_camo_event_ranked_wz_s5_5_plat_top25";
    level.rm_refs[1948] = "sat_camo_event_ranked_wz_s5_5_plat_top5";
    level.rm_refs[1949] = "sat_camo_event_ranked_wz_s5_5_t250_top10";
    level.rm_refs[1950] = "sat_camo_event_ranked_wz_s5_5_t250_top100";
    level.rm_refs[1951] = "sat_camo_event_ranked_wz_s6_crim_top25";
    level.rm_refs[1952] = "sat_camo_event_ranked_wz_s6_crim_top5";
    level.rm_refs[1953] = "sat_camo_event_ranked_wz_s6_diam_top25";
    level.rm_refs[1954] = "sat_camo_event_ranked_wz_s6_diam_top5";
    level.rm_refs[1955] = "sat_camo_event_ranked_wz_s6_gold_top25";
    level.rm_refs[1956] = "sat_camo_event_ranked_wz_s6_gold_top5";
    level.rm_refs[1957] = "sat_camo_event_ranked_wz_s6_irid_top25";
    level.rm_refs[1958] = "sat_camo_event_ranked_wz_s6_irid_top5";
    level.rm_refs[1959] = "sat_camo_event_ranked_wz_s6_plat_top25";
    level.rm_refs[1960] = "sat_camo_event_ranked_wz_s6_plat_top5";
    level.rm_refs[1961] = "sat_camo_event_ranked_wz_s6_t250_top10";
    level.rm_refs[1962] = "sat_camo_event_ranked_wz_s6_t250_top100";
    level.rm_refs[1963] = "sat_camo_event_s0_mp_1st";
    level.rm_refs[1964] = "sat_camo_event_s0_mp_top10";
    level.rm_refs[1965] = "sat_camo_event_s1_5_daisy";
    level.rm_refs[1966] = "sat_camo_event_s1_5_zm_1st";
    level.rm_refs[1967] = "sat_camo_event_s1_5_zm_top10";
    level.rm_refs[1968] = "sat_camo_event_s1_bo7launch";
    level.rm_refs[1969] = "sat_camo_event_s1_naughty";
    level.rm_refs[1970] = "sat_camo_event_s1_zm_1st";
    level.rm_refs[1971] = "sat_camo_event_s1_zm_top10";
    level.rm_refs[1972] = "sat_camo_event_s2_5_challenges01";
    level.rm_refs[1973] = "sat_camo_event_s2_5_challenges02";
    level.rm_refs[1974] = "sat_camo_event_s2_5_fieldrep";
    level.rm_refs[1975] = "sat_camo_event_s2_5_minipass";
    level.rm_refs[1976] = "sat_camo_event_s2_5_zm_1st";
    level.rm_refs[1977] = "sat_camo_event_s2_5_zm_top10";
    level.rm_refs[1978] = "sat_camo_event_s2_doa_1st";
    level.rm_refs[1979] = "sat_camo_event_s2_doa_top10";
    level.rm_refs[1980] = "sat_camo_event_s2_mp_1st";
    level.rm_refs[1981] = "sat_camo_event_s2_mp_top10";
    level.rm_refs[1982] = "sat_camo_event_s2_zm_1st";
    level.rm_refs[1983] = "sat_camo_event_s2_zm_top10";
    level.rm_refs[1984] = "sat_camo_event_s3_wz_iron_top25";
    level.rm_refs[1985] = "sat_camo_event_s3_wz_iron_top5";
    level.rm_refs[1986] = "sat_camo_event_s5_5_freerun_01";
    level.rm_refs[1987] = "sat_camo_exotic_01";
    level.rm_refs[1988] = "sat_camo_exotic_02";
    level.rm_refs[1989] = "sat_camo_exotic_03";
    level.rm_refs[1990] = "sat_camo_exotic_04";
    level.rm_refs[1991] = "sat_camo_exotic_05";
    level.rm_refs[1992] = "sat_camo_exotic_06";
    level.rm_refs[1993] = "sat_camo_exotic_07";
    level.rm_refs[1994] = "sat_camo_exotic_08";
    level.rm_refs[1995] = "sat_camo_exotic_09";
    level.rm_refs[1996] = "sat_camo_exotic_10";
    level.rm_refs[1997] = "sat_camo_incentive_cpg";
    level.rm_refs[1998] = "sat_camo_incentive_email";
    level.rm_refs[1999] = "sat_camo_incentive_evergreen_01";
    level.rm_refs[2000] = "sat_camo_incentive_evergreen_02";
}
function private rm_catalog_20()
{
    level.rm_refs[2001] = "sat_camo_pap_firefly_01";
    level.rm_refs[2002] = "sat_camo_pap_firefly_02";
    level.rm_refs[2003] = "sat_camo_pap_firefly_03";
    level.rm_refs[2004] = "sat_camo_pap_global_04";
    level.rm_refs[2005] = "sat_camo_pap_hornet_01";
    level.rm_refs[2006] = "sat_camo_pap_hornet_02";
    level.rm_refs[2007] = "sat_camo_pap_hornet_03";
    level.rm_refs[2008] = "sat_camo_pap_locust_01";
    level.rm_refs[2009] = "sat_camo_pap_locust_02";
    level.rm_refs[2010] = "sat_camo_pap_locust_03";
    level.rm_refs[2011] = "sat_camo_pap_mantis_01";
    level.rm_refs[2012] = "sat_camo_pap_mantis_02";
    level.rm_refs[2013] = "sat_camo_pap_mantis_03";
    level.rm_refs[2014] = "sat_camo_pap_ruby_01";
    level.rm_refs[2015] = "sat_camo_pap_ruby_02";
    level.rm_refs[2016] = "sat_camo_pap_ruby_03";
    level.rm_refs[2017] = "sat_camo_pap_scorpion_01";
    level.rm_refs[2018] = "sat_camo_pap_scorpion_02";
    level.rm_refs[2019] = "sat_camo_pap_scorpion_03";
    level.rm_refs[2020] = "sat_camo_plevel1000";
    level.rm_refs[2021] = "sat_camo_prestige_001";
    level.rm_refs[2022] = "sat_camo_prestige_002";
    level.rm_refs[2023] = "sat_camo_prestige_003";
    level.rm_refs[2024] = "sat_camo_prestige_004";
    level.rm_refs[2025] = "sat_camo_prestige_005";
    level.rm_refs[2026] = "sat_camo_prestige_006";
    level.rm_refs[2027] = "sat_camo_prestige_007";
    level.rm_refs[2028] = "sat_camo_prestige_008";
    level.rm_refs[2029] = "sat_camo_prestige_009";
    level.rm_refs[2030] = "sat_camo_prestige_010";
    level.rm_refs[2031] = "sat_camo_prestige_011";
    level.rm_refs[2032] = "sat_camo_prestige_012";
    level.rm_refs[2033] = "sat_camo_prestige_013";
    level.rm_refs[2034] = "sat_camo_prestige_014";
    level.rm_refs[2035] = "sat_camo_prestige_015";
    level.rm_refs[2036] = "sat_camo_prestige_016";
    level.rm_refs[2037] = "sat_camo_prestige_017";
    level.rm_refs[2038] = "sat_camo_prestige_018";
    level.rm_refs[2039] = "sat_camo_prestige_019";
    level.rm_refs[2040] = "sat_camo_prestige_020";
    level.rm_refs[2041] = "sat_camo_prestige_021";
    level.rm_refs[2042] = "sat_camo_prestige_022";
    level.rm_refs[2043] = "sat_camo_prestige_023";
    level.rm_refs[2044] = "sat_camo_prestige_024";
    level.rm_refs[2045] = "sat_camo_prestige_025";
    level.rm_refs[2046] = "sat_camo_prestige_026";
    level.rm_refs[2047] = "sat_camo_prestige_027";
    level.rm_refs[2048] = "sat_camo_prestige_028";
    level.rm_refs[2049] = "sat_camo_prestige_029";
    level.rm_refs[2050] = "sat_camo_prestige_030";
    level.rm_refs[2051] = "sat_camo_prestige_031";
    level.rm_refs[2052] = "sat_camo_prestige_032";
    level.rm_refs[2053] = "sat_camo_prestige_033";
    level.rm_refs[2054] = "sat_camo_prestige_034";
    level.rm_refs[2055] = "sat_camo_prestige_035";
    level.rm_refs[2056] = "sat_camo_prestige_036";
    level.rm_refs[2057] = "sat_camo_prestige_037";
    level.rm_refs[2058] = "sat_camo_prestige_038";
    level.rm_refs[2059] = "sat_camo_prestige_039";
    level.rm_refs[2060] = "sat_camo_prestige_040";
    level.rm_refs[2061] = "sat_camo_prestige_041";
    level.rm_refs[2062] = "sat_camo_prestige_042";
    level.rm_refs[2063] = "sat_camo_prestige_043";
    level.rm_refs[2064] = "sat_camo_prestige_044";
    level.rm_refs[2065] = "sat_camo_prestige_045";
    level.rm_refs[2066] = "sat_camo_prestige_046";
    level.rm_refs[2067] = "sat_camo_prestige_047";
    level.rm_refs[2068] = "sat_camo_prestige_048";
    level.rm_refs[2069] = "sat_camo_prestige_049";
    level.rm_refs[2070] = "sat_camo_prestige_050";
    level.rm_refs[2071] = "sat_camo_prestige_051";
    level.rm_refs[2072] = "sat_camo_prestige_052";
    level.rm_refs[2073] = "sat_camo_prestige_053";
    level.rm_refs[2074] = "sat_camo_prestige_054";
    level.rm_refs[2075] = "sat_camo_prestige_055";
    level.rm_refs[2076] = "sat_camo_prestige_056";
    level.rm_refs[2077] = "sat_camo_prestige_057";
    level.rm_refs[2078] = "sat_camo_prestige_058";
    level.rm_refs[2079] = "sat_camo_prestige_059";
    level.rm_refs[2080] = "sat_camo_prestige_060";
    level.rm_refs[2081] = "sat_camo_prestige_061";
    level.rm_refs[2082] = "sat_camo_prestige_062";
    level.rm_refs[2083] = "sat_camo_prestige_063";
    level.rm_refs[2084] = "sat_camo_prestige_064";
    level.rm_refs[2085] = "sat_camo_prestige_065";
    level.rm_refs[2086] = "sat_camo_prestige_066";
    level.rm_refs[2087] = "sat_camo_prestige_067";
    level.rm_refs[2088] = "sat_camo_prestige_068";
    level.rm_refs[2089] = "sat_camo_prestige_069";
    level.rm_refs[2090] = "sat_camo_prestige_070";
    level.rm_refs[2091] = "sat_camo_prestige_071";
    level.rm_refs[2092] = "sat_camo_prestige_072";
    level.rm_refs[2093] = "sat_camo_prestige_073";
    level.rm_refs[2094] = "sat_camo_prestige_074";
    level.rm_refs[2095] = "sat_camo_prestige_075";
    level.rm_refs[2096] = "sat_camo_prestige_076";
    level.rm_refs[2097] = "sat_camo_prestige_077";
    level.rm_refs[2098] = "sat_camo_prestige_078";
    level.rm_refs[2099] = "sat_camo_prestige_079";
    level.rm_refs[2100] = "sat_camo_prestige_080";
}
function private rm_catalog_21()
{
    level.rm_refs[2101] = "sat_camo_prestige_081";
    level.rm_refs[2102] = "sat_camo_prestige_082";
    level.rm_refs[2103] = "sat_camo_prestige_083";
    level.rm_refs[2104] = "sat_camo_prestige_084";
    level.rm_refs[2105] = "sat_camo_prestige_085";
    level.rm_refs[2106] = "sat_camo_prestige_086";
    level.rm_refs[2107] = "sat_camo_prestige_087";
    level.rm_refs[2108] = "sat_camo_prestige_088";
    level.rm_refs[2109] = "sat_camo_prestige_089";
    level.rm_refs[2110] = "sat_camo_prestige_090";
    level.rm_refs[2111] = "sat_camo_prestige_091";
    level.rm_refs[2112] = "sat_camo_prestige_092";
    level.rm_refs[2113] = "sat_camo_prestige_093";
    level.rm_refs[2114] = "sat_camo_prestige_094";
    level.rm_refs[2115] = "sat_camo_prestige_095";
    level.rm_refs[2116] = "sat_camo_prestige_096";
    level.rm_refs[2117] = "sat_camo_prestige_097";
    level.rm_refs[2118] = "sat_camo_prestige_098";
    level.rm_refs[2119] = "sat_camo_prestige_099";
    level.rm_refs[2120] = "sat_camo_prestige_100";
    level.rm_refs[2121] = "sat_camo_prestige_101";
    level.rm_refs[2122] = "sat_camo_prestige_102";
    level.rm_refs[2123] = "sat_camo_prestige_103";
    level.rm_refs[2124] = "sat_camo_prestige_104";
    level.rm_refs[2125] = "sat_camo_prestige_105";
    level.rm_refs[2126] = "sat_camo_prestige_106";
    level.rm_refs[2127] = "sat_camo_prestige_107";
    level.rm_refs[2128] = "sat_camo_prestige_108";
    level.rm_refs[2129] = "sat_camo_prestige_109";
    level.rm_refs[2130] = "sat_camo_prestige_110";
    level.rm_refs[2131] = "sat_camo_prestige_111";
    level.rm_refs[2132] = "sat_camo_prestige_112";
    level.rm_refs[2133] = "sat_camo_prestige_113";
    level.rm_refs[2134] = "sat_camo_prestige_114";
    level.rm_refs[2135] = "sat_camo_prestige_115";
    level.rm_refs[2136] = "sat_camo_prestige_116";
    level.rm_refs[2137] = "sat_camo_prestige_117";
    level.rm_refs[2138] = "sat_camo_prestige_118";
    level.rm_refs[2139] = "sat_camo_prestige_119";
    level.rm_refs[2140] = "sat_camo_prestige_120";
    level.rm_refs[2141] = "sat_camo_prestige_121";
    level.rm_refs[2142] = "sat_camo_prestige_122";
    level.rm_refs[2143] = "sat_camo_prestige_123";
    level.rm_refs[2144] = "sat_camo_prestige_124";
    level.rm_refs[2145] = "sat_camo_prestige_125";
    level.rm_refs[2146] = "sat_camo_prestige_126";
    level.rm_refs[2147] = "sat_camo_prestige_127";
    level.rm_refs[2148] = "sat_camo_prestige_128";
    level.rm_refs[2149] = "sat_camo_prestige_129";
    level.rm_refs[2150] = "sat_camo_prestige_130";
    level.rm_refs[2151] = "sat_camo_prestige_131";
    level.rm_refs[2152] = "sat_camo_prestige_132";
    level.rm_refs[2153] = "sat_camo_prestige_133";
    level.rm_refs[2154] = "sat_camo_prestige_134";
    level.rm_refs[2155] = "sat_camo_prestige_135";
    level.rm_refs[2156] = "sat_camo_prestige_136";
    level.rm_refs[2157] = "sat_camo_prestige_137";
    level.rm_refs[2158] = "sat_camo_prestige_138";
    level.rm_refs[2159] = "sat_camo_prestige_139";
    level.rm_refs[2160] = "sat_camo_prestige_140";
    level.rm_refs[2161] = "sat_camo_prestige_141";
    level.rm_refs[2162] = "sat_camo_prestige_142";
    level.rm_refs[2163] = "sat_camo_prestige_143";
    level.rm_refs[2164] = "sat_camo_prestige_144";
    level.rm_refs[2165] = "sat_camo_prestige_145";
    level.rm_refs[2166] = "sat_camo_prestige_146";
    level.rm_refs[2167] = "sat_camo_prestige_147";
    level.rm_refs[2168] = "sat_camo_prestige_148";
    level.rm_refs[2169] = "sat_camo_prestige_149";
    level.rm_refs[2170] = "sat_camo_prestige_150";
    level.rm_refs[2171] = "sat_camo_prestige_151";
    level.rm_refs[2172] = "sat_camo_prestige_152";
    level.rm_refs[2173] = "sat_camo_prestige_153";
    level.rm_refs[2174] = "sat_camo_prestige_154";
    level.rm_refs[2175] = "sat_camo_prestige_155";
    level.rm_refs[2176] = "sat_camo_prestige_156";
    level.rm_refs[2177] = "sat_camo_prestige_157";
    level.rm_refs[2178] = "sat_camo_prestige_158";
    level.rm_refs[2179] = "sat_camo_prestige_159";
    level.rm_refs[2180] = "sat_camo_prestige_160";
    level.rm_refs[2181] = "sat_camo_prestige_161";
    level.rm_refs[2182] = "sat_camo_prestige_162";
    level.rm_refs[2183] = "sat_camo_prestige_163";
    level.rm_refs[2184] = "sat_camo_prestige_164";
    level.rm_refs[2185] = "sat_camo_prestige_165";
    level.rm_refs[2186] = "sat_camo_prestige_166";
    level.rm_refs[2187] = "sat_camo_prestige_167";
    level.rm_refs[2188] = "sat_camo_prestige_168";
    level.rm_refs[2189] = "sat_camo_prestige_169";
    level.rm_refs[2190] = "sat_camo_prestige_170";
    level.rm_refs[2191] = "sat_camo_prestige_171";
    level.rm_refs[2192] = "sat_camo_prestige_172";
    level.rm_refs[2193] = "sat_camo_prestige_173";
    level.rm_refs[2194] = "sat_camo_prestige_174";
    level.rm_refs[2195] = "sat_camo_prestige_175";
    level.rm_refs[2196] = "sat_camo_prestige_176";
    level.rm_refs[2197] = "sat_camo_prestige_177";
    level.rm_refs[2198] = "sat_camo_prestige_178";
    level.rm_refs[2199] = "sat_camo_prestige_179";
    level.rm_refs[2200] = "sat_camo_prestige_180";
}
function private rm_catalog_22()
{
    level.rm_refs[2201] = "sat_camo_prestige_181";
    level.rm_refs[2202] = "sat_camo_prestige_182";
    level.rm_refs[2203] = "sat_camo_prestige_183";
    level.rm_refs[2204] = "sat_camo_prestige_184";
    level.rm_refs[2205] = "sat_camo_prestige_185";
    level.rm_refs[2206] = "sat_camo_prestige_186";
    level.rm_refs[2207] = "sat_camo_prestige_187";
    level.rm_refs[2208] = "sat_camo_prestige_188";
    level.rm_refs[2209] = "sat_camo_prestige_189";
    level.rm_refs[2210] = "sat_camo_prestige_190";
    level.rm_refs[2211] = "sat_camo_prestige_191";
    level.rm_refs[2212] = "sat_camo_prestige_192";
    level.rm_refs[2213] = "sat_camo_prog_doa_01";
    level.rm_refs[2214] = "sat_camo_prog_manticore_01";
    level.rm_refs[2215] = "sat_camo_prog_s1_5_br_anim";
    level.rm_refs[2216] = "sat_camo_prog_s1_5_br_static";
    level.rm_refs[2217] = "sat_camo_prog_s1_5_resurge_anim";
    level.rm_refs[2218] = "sat_camo_prog_s1_5_resurge_static";
    level.rm_refs[2219] = "sat_camo_prog_s2_5_bo_challenge";
    level.rm_refs[2220] = "sat_camo_prog_s2_br_anim";
    level.rm_refs[2221] = "sat_camo_prog_s2_br_static";
    level.rm_refs[2222] = "sat_camo_prog_s2_resurge_anim";
    level.rm_refs[2223] = "sat_camo_prog_s2_resurge_static";
    level.rm_refs[2224] = "sat_camo_prog_s2_wz_iron_trials";
    level.rm_refs[2225] = "sat_camo_prog_s3_5_endgame_anim";
    level.rm_refs[2226] = "sat_camo_prog_s3_5_endgame_static";
    level.rm_refs[2227] = "sat_camo_prog_s3_5_freerun";
    level.rm_refs[2228] = "sat_camo_prog_s3_5_scr_anim";
    level.rm_refs[2229] = "sat_camo_prog_s3_blackout_anim";
    level.rm_refs[2230] = "sat_camo_prog_s3_blackout_static";
    level.rm_refs[2231] = "sat_camo_prog_s3_br_anim";
    level.rm_refs[2232] = "sat_camo_prog_s3_br_static";
    level.rm_refs[2233] = "sat_camo_prog_s3_endgame_anim";
    level.rm_refs[2234] = "sat_camo_prog_s3_endgame_static";
    level.rm_refs[2235] = "sat_camo_prog_s3_resurge_anim";
    level.rm_refs[2236] = "sat_camo_prog_s3_resurge_static";
    level.rm_refs[2237] = "sat_camo_prog_s3_wz_classified";
    level.rm_refs[2238] = "sat_camo_prog_s3blk_anim_01";
    level.rm_refs[2239] = "sat_camo_prog_s3blk_static_01";
    level.rm_refs[2240] = "sat_camo_prog_s3blk_static_02";
    level.rm_refs[2241] = "sat_camo_prog_s3blk_static_03";
    level.rm_refs[2242] = "sat_camo_prog_s3blk_static_04";
    level.rm_refs[2243] = "sat_camo_prog_s3blk_static_05";
    level.rm_refs[2244] = "sat_camo_prog_s4_5_cquest_01win";
    level.rm_refs[2245] = "sat_camo_prog_s4_5_cquest_05wins";
    level.rm_refs[2246] = "sat_camo_prog_s4_5_cquest_08wins";
    level.rm_refs[2247] = "sat_camo_prog_s4_5_cquest_10wins";
    level.rm_refs[2248] = "sat_camo_prog_s4_5_endgame_anim";
    level.rm_refs[2249] = "sat_camo_prog_s4_5_endgame_static";
    level.rm_refs[2250] = "sat_camo_prog_s4_5_relics";
    level.rm_refs[2251] = "sat_camo_prog_s4_5_relics_02";
    level.rm_refs[2252] = "sat_camo_prog_s4_blackout_anim";
    level.rm_refs[2253] = "sat_camo_prog_s4_blackout_static";
    level.rm_refs[2254] = "sat_camo_prog_s4_br_anim";
    level.rm_refs[2255] = "sat_camo_prog_s4_br_static";
    level.rm_refs[2256] = "sat_camo_prog_s4_endgame_anim";
    level.rm_refs[2257] = "sat_camo_prog_s4_endgame_static";
    level.rm_refs[2258] = "sat_camo_prog_s4_resurge_anim";
    level.rm_refs[2259] = "sat_camo_prog_s4_resurge_static";
    level.rm_refs[2260] = "sat_camo_prog_s4_wz_victory";
    level.rm_refs[2261] = "sat_camo_prog_s4blk_anim_06";
    level.rm_refs[2262] = "sat_camo_prog_s4blk_static_01";
    level.rm_refs[2263] = "sat_camo_prog_s4blk_static_02";
    level.rm_refs[2264] = "sat_camo_prog_s4blk_static_03";
    level.rm_refs[2265] = "sat_camo_prog_s4blk_static_04";
    level.rm_refs[2266] = "sat_camo_prog_s4blk_static_05";
    level.rm_refs[2267] = "sat_camo_prog_s5_5_wz_newfeats";
    level.rm_refs[2268] = "sat_camo_prog_s5_blackout_anim";
    level.rm_refs[2269] = "sat_camo_prog_s5_blackout_static";
    level.rm_refs[2270] = "sat_camo_prog_s5_br_anim";
    level.rm_refs[2271] = "sat_camo_prog_s5_br_static";
    level.rm_refs[2272] = "sat_camo_prog_s5_resurge_anim";
    level.rm_refs[2273] = "sat_camo_prog_s5_resurge_static";
    level.rm_refs[2274] = "sat_camo_prog_s5_wz_newfeats";
    level.rm_refs[2275] = "sat_camo_prog_s5blk_anim_06";
    level.rm_refs[2276] = "sat_camo_prog_s5blk_static_01";
    level.rm_refs[2277] = "sat_camo_prog_s5blk_static_02";
    level.rm_refs[2278] = "sat_camo_prog_s5blk_static_03";
    level.rm_refs[2279] = "sat_camo_prog_s5blk_static_04";
    level.rm_refs[2280] = "sat_camo_prog_s5blk_static_05";
    level.rm_refs[2281] = "sat_camo_prog_s6_blackout_anim";
    level.rm_refs[2282] = "sat_camo_prog_s6_blackout_static";
    level.rm_refs[2283] = "sat_camo_prog_s6_br_anim";
    level.rm_refs[2284] = "sat_camo_prog_s6_br_static";
    level.rm_refs[2285] = "sat_camo_prog_s6_hms_01";
    level.rm_refs[2286] = "sat_camo_prog_s6_resurge_anim";
    level.rm_refs[2287] = "sat_camo_prog_s6_resurge_static";
    level.rm_refs[2288] = "sat_camo_prog_s6_wz_newfeats";
    level.rm_refs[2289] = "sat_camo_prog_s6blk_anim_06";
    level.rm_refs[2290] = "sat_camo_prog_s6blk_static_01";
    level.rm_refs[2291] = "sat_camo_prog_s6blk_static_02";
    level.rm_refs[2292] = "sat_camo_prog_s6blk_static_03";
    level.rm_refs[2293] = "sat_camo_prog_s6blk_static_04";
    level.rm_refs[2294] = "sat_camo_prog_s6blk_static_05";
    level.rm_refs[2295] = "sat_camo_prog_seasonal_01";
    level.rm_refs[2296] = "sat_camo_prog_seasonal_02";
    level.rm_refs[2297] = "sat_camo_prog_seasonal_03";
    level.rm_refs[2298] = "sat_camo_prog_seasonal_04";
    level.rm_refs[2299] = "sat_camo_prog_seasonal_05";
    level.rm_refs[2300] = "sat_camo_prog_seasonal_06";
}
function private rm_catalog_23()
{
    level.rm_refs[2301] = "sat_camo_prog_seasonal_07";
    level.rm_refs[2302] = "sat_camo_prog_seasonal_08";
    level.rm_refs[2303] = "sat_camo_prog_seasonal_09";
    level.rm_refs[2304] = "sat_camo_prog_seasonal_10";
    level.rm_refs[2305] = "sat_camo_prog_seasonal_11";
    level.rm_refs[2306] = "sat_camo_prog_seasonal_12";
    level.rm_refs[2307] = "sat_camo_ranked_mp_s2_01";
    level.rm_refs[2308] = "sat_camo_ranked_mp_s2_02";
    level.rm_refs[2309] = "sat_camo_ranked_mp_s2_03";
    level.rm_refs[2310] = "sat_camo_ranked_mp_s2_04";
    level.rm_refs[2311] = "sat_camo_ranked_mp_s2_05";
    level.rm_refs[2312] = "sat_camo_ranked_mp_s2_06";
    level.rm_refs[2313] = "sat_camo_ranked_mp_s2_base";
    level.rm_refs[2314] = "sat_camo_ranked_mp_s3_01";
    level.rm_refs[2315] = "sat_camo_ranked_mp_s3_02";
    level.rm_refs[2316] = "sat_camo_ranked_mp_s3_03";
    level.rm_refs[2317] = "sat_camo_ranked_mp_s3_04";
    level.rm_refs[2318] = "sat_camo_ranked_mp_s3_05";
    level.rm_refs[2319] = "sat_camo_ranked_mp_s3_06";
    level.rm_refs[2320] = "sat_camo_ranked_mp_s4_01";
    level.rm_refs[2321] = "sat_camo_ranked_mp_s4_02";
    level.rm_refs[2322] = "sat_camo_ranked_mp_s4_03";
    level.rm_refs[2323] = "sat_camo_ranked_mp_s4_04";
    level.rm_refs[2324] = "sat_camo_ranked_mp_s4_05";
    level.rm_refs[2325] = "sat_camo_ranked_mp_s4_06";
    level.rm_refs[2326] = "sat_camo_ranked_mp_s5_01";
    level.rm_refs[2327] = "sat_camo_ranked_mp_s5_02";
    level.rm_refs[2328] = "sat_camo_ranked_mp_s5_03";
    level.rm_refs[2329] = "sat_camo_ranked_mp_s5_04";
    level.rm_refs[2330] = "sat_camo_ranked_mp_s5_05";
    level.rm_refs[2331] = "sat_camo_ranked_mp_s5_06";
    level.rm_refs[2332] = "sat_camo_ranked_mp_s6_01";
    level.rm_refs[2333] = "sat_camo_ranked_mp_s6_02";
    level.rm_refs[2334] = "sat_camo_ranked_mp_s6_03";
    level.rm_refs[2335] = "sat_camo_ranked_mp_s6_04";
    level.rm_refs[2336] = "sat_camo_ranked_mp_s6_05";
    level.rm_refs[2337] = "sat_camo_ranked_mp_s6_06";
    level.rm_refs[2338] = "sat_camo_ranked_wz_s2_01";
    level.rm_refs[2339] = "sat_camo_ranked_wz_s2_02";
    level.rm_refs[2340] = "sat_camo_ranked_wz_s2_03";
    level.rm_refs[2341] = "sat_camo_ranked_wz_s2_04";
    level.rm_refs[2342] = "sat_camo_ranked_wz_s2_05";
    level.rm_refs[2343] = "sat_camo_ranked_wz_s2_06";
    level.rm_refs[2344] = "sat_camo_ranked_wz_s2_base";
    level.rm_refs[2345] = "sat_camo_ranked_wz_s3_01";
    level.rm_refs[2346] = "sat_camo_ranked_wz_s3_02";
    level.rm_refs[2347] = "sat_camo_ranked_wz_s3_03";
    level.rm_refs[2348] = "sat_camo_ranked_wz_s3_04";
    level.rm_refs[2349] = "sat_camo_ranked_wz_s3_05";
    level.rm_refs[2350] = "sat_camo_ranked_wz_s3_06";
    level.rm_refs[2351] = "sat_camo_ranked_wz_s4_01";
    level.rm_refs[2352] = "sat_camo_ranked_wz_s4_02";
    level.rm_refs[2353] = "sat_camo_ranked_wz_s4_03";
    level.rm_refs[2354] = "sat_camo_ranked_wz_s4_04";
    level.rm_refs[2355] = "sat_camo_ranked_wz_s4_05";
    level.rm_refs[2356] = "sat_camo_ranked_wz_s4_06";
    level.rm_refs[2357] = "sat_camo_ranked_wz_s5_01";
    level.rm_refs[2358] = "sat_camo_ranked_wz_s5_02";
    level.rm_refs[2359] = "sat_camo_ranked_wz_s5_03";
    level.rm_refs[2360] = "sat_camo_ranked_wz_s5_04";
    level.rm_refs[2361] = "sat_camo_ranked_wz_s5_05";
    level.rm_refs[2362] = "sat_camo_ranked_wz_s5_06";
    level.rm_refs[2363] = "sat_camo_ranked_wz_s6_01";
    level.rm_refs[2364] = "sat_camo_ranked_wz_s6_02";
    level.rm_refs[2365] = "sat_camo_ranked_wz_s6_03";
    level.rm_refs[2366] = "sat_camo_ranked_wz_s6_04";
    level.rm_refs[2367] = "sat_camo_ranked_wz_s6_05";
    level.rm_refs[2368] = "sat_camo_ranked_wz_s6_06";
    level.rm_refs[2369] = "sat_camo_relic_firefly_01";
    level.rm_refs[2370] = "sat_camo_relic_firefly_02";
    level.rm_refs[2371] = "sat_camo_relic_firefly_03";
    level.rm_refs[2372] = "sat_camo_relic_hornet_01";
    level.rm_refs[2373] = "sat_camo_relic_hornet_02";
    level.rm_refs[2374] = "sat_camo_relic_hornet_03";
    level.rm_refs[2375] = "sat_camo_relic_locust_01";
    level.rm_refs[2376] = "sat_camo_relic_locust_02";
    level.rm_refs[2377] = "sat_camo_relic_locust_03";
    level.rm_refs[2378] = "sat_camo_relic_mantis_01";
    level.rm_refs[2379] = "sat_camo_relic_mantis_02";
    level.rm_refs[2380] = "sat_camo_relic_mantis_03";
    level.rm_refs[2381] = "sat_camo_relic_ruby_01";
    level.rm_refs[2382] = "sat_camo_relic_ruby_02";
    level.rm_refs[2383] = "sat_camo_relic_ruby_03";
    level.rm_refs[2384] = "sat_camo_special_cdl_breach";
    level.rm_refs[2385] = "sat_camo_special_cdl_cloud9";
    level.rm_refs[2386] = "sat_camo_special_cdl_falcons";
    level.rm_refs[2387] = "sat_camo_special_cdl_faze";
    level.rm_refs[2388] = "sat_camo_special_cdl_guerrillas";
    level.rm_refs[2389] = "sat_camo_special_cdl_heretics";
    level.rm_refs[2390] = "sat_camo_special_cdl_launch";
    level.rm_refs[2391] = "sat_camo_special_cdl_optic";
    level.rm_refs[2392] = "sat_camo_special_cdl_ravens";
    level.rm_refs[2393] = "sat_camo_special_cdl_rokkr";
    level.rm_refs[2394] = "sat_camo_special_cdl_surge";
    level.rm_refs[2395] = "sat_camo_special_cdl_thieves";
    level.rm_refs[2396] = "sat_camo_special_cdl_ultra";
    level.rm_refs[2397] = "sat_camo_temp_01";
    level.rm_refs[2398] = "sat_camo_unique_01_mp";
    level.rm_refs[2399] = "sat_camo_unique_01_wc";
    level.rm_refs[2400] = "sat_camo_unique_01_wz";
}
function private rm_catalog_24()
{
    level.rm_refs[2401] = "sat_camo_unique_01_zm";
    level.rm_refs[2402] = "sat_camo_unique_02_mp";
    level.rm_refs[2403] = "sat_camo_unique_02_wc";
    level.rm_refs[2404] = "sat_camo_unique_02_wz";
    level.rm_refs[2405] = "sat_camo_unique_02_zm";
    level.rm_refs[2406] = "sat_camo_unique_03_mp";
    level.rm_refs[2407] = "sat_camo_unique_03_wc";
    level.rm_refs[2408] = "sat_camo_unique_03_wz";
    level.rm_refs[2409] = "sat_camo_unique_03_zm";
    level.rm_refs[2410] = "sat_camo_unique_pmaster100";
    level.rm_refs[2411] = "sat_camo_unique_pmaster150";
    level.rm_refs[2412] = "sat_camo_unique_pmaster200";
}
