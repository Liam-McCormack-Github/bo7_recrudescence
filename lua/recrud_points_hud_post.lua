-- created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
-- Take over from the launcher's cursed_points_hud_post.lua (it draws its own points counter in standard modes).
-- It returns early if LumenCursedPointsP2 already exists, and exposes Disable() once loaded, so handle both load orders.
do
    local theirs = rawget(_G, "LumenCursedPointsP2")
    if type(theirs) == "table" then
        if type(theirs.Disable) == "function" then pcall(theirs.Disable) end
    else
        rawset(_G, "LumenCursedPointsP2", { Disable = function() end, Uninstall = function() end, stub = "recrud" })
    end
end

-- ============================================================================
-- recrud_points_hud_post.lua
-- HUD Bridge for Cursed Mode Floating Points & Zombie 3D Damage Numbers:
-- 1. Filters out Type 6 (points) from the 3D world-anchored DamageNumber container
--    so floating points NEVER spawn at (0, 0, 0) in the map geometry.
-- 2. Embeds a 2D DamageNumber container inside ZMPlayerInfo right next to the
--    essence display (Treyarch's native rbclassic / OG points HUD layout).
-- 3. Dedicated 2D container handles Type 6 points: prepends '+', applies rbclassic
--    upward float animation (+10, +50, +60, +70, +100, +130) from the bottom HUD.
-- 4. Normal 3D weapon damage numbers continue to pop off zombies natively.
-- ============================================================================

local dbg = nil
local function log(msg) end

do end

local clua = rawget(_G, "CLUA")
local lui = rawget(_G, "LUI")
local mb = rawget(_G, "MenuBuilder")

if type(mb) ~= "table" or type(mb.BuildRegisteredType) ~= "function" then
    do end
    return
end

local building_points_container = false

-- Hook GameType to return enablerbclassicpoints = true when building points container
local gt = rawget(_G, "GameType") or (package and package.loaded and package.loaded["ui.utils.gametype"])
if gt then
    if type(gt.getcachedgametypebundle) == "function" then
        local orig_getbundle = gt.getcachedgametypebundle
        gt.getcachedgametypebundle = function()
            local b = orig_getbundle()
            if building_points_container then
                if type(b) == "table" then
                    b.enablerbclassicpoints = true
                elseif type(b) == "userdata" then
                    pcall(function() b.enablerbclassicpoints = true end)
                end
            end
            return b
        end
        do end
    end

    -- Also check for 0x5769CACC0EC054FF key
    for k, v in pairs(gt) do
        local ks = tostring(k):lower()
        if ks:find("5769cacc0ec054ff") then
            local orig_fn = v
            gt[k] = function(...)
                if building_points_container then
                    return true
                end
                return orig_fn(...)
            end
            do end
        end
    end
end

local function matches_type(typeName, target)
    if typeName == nil then return false end
    if typeName == target then return true end
    local s = tostring(typeName):lower()
    if s:find(target:lower(), 1, true) then return true end
    if clua and type(clua.PushXHash) == "function" then
        local h = clua.PushXHash(target)
        if h and typeName == h then return true end
    end
    return false
end

local orig_build = mb.BuildRegisteredType
mb.BuildRegisteredType = function(typeName, params)
    -- ------------------------------------------------------------------------
    -- 1. Building DamageNumber widgets for our 2D classic points container
    -- ------------------------------------------------------------------------
    if building_points_container and matches_type(typeName, "DamageNumber") then
        local widget = orig_build(typeName, params)
        if widget then
            local ok_sae, err_sae = pcall(function() widget.SetupAnchoredElement = function() end end)
            local ok_ogp, err_ogp = pcall(function() widget._isOGPoints = true end)
            local ok_awp, err_awp = pcall(function() widget._anchorWorldPosition = false end)
            local ok_cp, err_cp = pcall(function() widget._isClassicPoints = true end)
            do end

            if widget.UpdateDamageNumber then
                local orig_update = widget.UpdateDamageNumber
                widget.UpdateDamageNumber = function(self, controllerIndex, state, index, is_stacked)
                    -- Only accept Type 6 points (rbclassic)
                    if state and state.stateID ~= 6 then
                        return
                    end
                    pcall(function() self._isOGPoints = true self._isogpoints = true self._anchorWorldPosition = false end)
                    state.element = 0
                    pcall(function() self._anchorWorldPosition = false end)
                    return orig_update(self, controllerIndex, state, index, is_stacked)
                end
            end
        end
        return widget
    end

    -- ------------------------------------------------------------------------
    -- 2. Building normal 3D DamageNumber widgets (world-space container)
    -- ------------------------------------------------------------------------
    if matches_type(typeName, "DamageNumber") then
        local widget = orig_build(typeName, params)
        if widget and widget.UpdateDamageNumber then
            local orig_update = widget.UpdateDamageNumber
            widget.UpdateDamageNumber = function(self, controllerIndex, state, index, is_stacked)
                if not state then
                    return orig_update(self, controllerIndex, state, index, is_stacked)
                end

                -- Suppress Type 6 points in the 3D world container so they never appear in 3D world space
                if state.stateID == 6 then
                    return
                else
                    -- Normal weapon damage number: ensure _isOGPoints / _isogpoints is false so it anchors in 3D
                    self._isOGPoints = false
                    self._isogpoints = false
                    return orig_update(self, controllerIndex, state, index, is_stacked)
                end
            end
        end
        return widget
    end

    -- ------------------------------------------------------------------------
    -- 3. Building ZMPlayerInfo: embed 2D classic points container
    -- ------------------------------------------------------------------------
    if matches_type(typeName, "ZMPlayerInfo") then
        local zmPlayerInfo = orig_build(typeName, params)
        if zmPlayerInfo and not zmPlayerInfo._hasClassicPointsContainer then
            zmPlayerInfo._hasClassicPointsContainer = true
            local ctrl = (params and params.controllerIndex) or 0

            building_points_container = true
            local ok, ptsContainer = pcall(orig_build, "damagenumbercontainer", { controllerIndex = ctrl })
            building_points_container = false

            if ok and ptsContainer then
                ptsContainer.id = "recrud_classic_points_container"
                -- Position right next to essence counter in ZMPlayerInfo (261.48, 395.48, 0, 63)
                ptsContainer:SetAnchorsAndPosition(0, 1, 0, 1, 261.48, 395.48, 0, 63)
                zmPlayerInfo:addElement(ptsContainer)
                do end
            else
                do end
            end
        end
        return zmPlayerInfo
    end

    return orig_build(typeName, params)
end

do end
