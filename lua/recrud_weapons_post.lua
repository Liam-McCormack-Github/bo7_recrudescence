-- created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
-- In-game Arsenal attachment shop. Uses Gunsmith metadata; writes only through GSC.
local function log(s) end

function RecrudBuildWeaponTab(ci)
  ci=ci or 0
  local emit=log
  local build=(rawget(_G,"RecrudWeaponProbeBuild") or 0)+1
  rawset(_G,"RecrudWeaponProbeBuild",build)
  local noiseSeen={}
  local function log(message) end
  do end
  local api=assert(rawget(_G,"RecrudArsenalAPI"),"Arsenal API unavailable")
  local G,LUI,Engine,MB,ACTIONS=api.G,api.LUI,api.Engine,api.MenuBuilder,api.ACTIONS
  local faults={}
  local function call(t,k,...)
    local f=G(t,k)
    if type(f)~="function" then
      if not faults[k] then faults[k]=true; do end end
      return nil
    end
    local ok,v=pcall(f,...)
    if ok then return v end
    if not faults[k] then faults[k]=true; do end end
    return nil
  end
  local AT,WP,LOOT=rawget(_G,"ATTACHMENT"),rawget(_G,"WEAPON"),rawget(_G,"LOOT")
  do end
  local e=LUI.UIElement.new(); e.id="recrud_weapontab"; e:SetAnchorsAndPosition(0,1,0,1,0,1920,0,1080)
  local panel=LUI.UIElement.new(); panel.id="weapon_cards"; panel:SetAnchorsAndPosition(0,1,0,1,0,1920,0,1080)
  local function text(id,value,size,x1,x2,y1,y2,align)
    local w=LUI.UIStyledText.new(); w.id=id; w:setText(value,0); w:SetFont(api.FONT_HANDLE.PrimaryBold)
    w:SetFontSize(size*api.PT); w:SetMinFontSize(size*api.PT); w:SetWordWrap(false); w:SetAlignment(align or 0)
    w:SetAnchorsAndPosition(0,1,0,1,x1,x2,y1,y2); return w
  end
  local heading=text("weapon_heading","ATTACHMENTS",32,450,1470,782,824,1); e:addElement(heading)
  local subtitle=text("weapon_subtitle","Edit the weapon you are holding. Equip for 10 salvage; removing is free.",18,120,1800,832,872,1); subtitle:SetWordWrap(true); subtitle:SetRGB(0xCCCCCC,0); e:addElement(subtitle)
  local bonuses=text("attachment_bonuses","",18,550,935,310,535); bonuses:SetWordWrap(true); bonuses:SetRGB(0x65E88E,0); e:addElement(bonuses)
  local drawbacks=text("attachment_drawbacks","",18,955,1340,310,535); drawbacks:SetWordWrap(true); drawbacks:SetRGB(0xFF6B6B,0); e:addElement(drawbacks)
  local status=text("weapon_status","",18,550,1350,570,610); e:addElement(status)
  e:addElement(panel)
  local state={equipped={},category=0,page=1,view="root",pending=false,alive=true,options={},conflicts={}}
  local categories={"Optic","Muzzle","Barrel","Underbarrel","Magazine","Rear Grip","Stock","Laser","Fire Mods"}
  local aliases={scope=1,optic=1,muzzle=2,frontpiece=3,barrel=3,underbarrel=4,undermount=4,magazine=5,loader=5,reargrip=6,backpiece=7,stock=7,laser=8,other=8,extra=8,modifier=9,trigger=9,firemod=9,gunperk=9}
  local responses={"Open the Arsenal again.","Hold a weapon and reopen Attachments.","Your held weapon changed. Close the Arsenal and reopen it.","That attachment conflicts with this build.","Already equipped; no salvage charged.","The weapon could not be loaded. No salvage charged.","You need 10 salvage."}
  local function loc(v,fallback)
    if v==nil then return fallback or "" end
    local s=call(Engine,"Localize",v)
    if type(s)~="string" or s=="" then s=type(v)=="string" and v or fallback or "" end
    return s:gsub("\226\150\188","")
  end
  local function setDescription(message,attachment)
    subtitle:setText(message,0)
    bonuses:setText("",0); drawbacks:setText("",0)
    bonuses:SetAlpha(0,0); drawbacks:SetAlpha(0,0)
    if not attachment then return end
    state.effectCache=state.effectCache or {}
    local effects=state.effectCache[attachment.ref]
    if not effects then
      local wt=state.weaponInfo.table or {weapon=state.weaponInfo.ref,assetName=state.weaponInfo.ref.."_mp"}
      -- Same native data and sorting used by the stock Gunsmith pros/cons panel.
      local modifiers=call(AT,"GetModifiersValuesFromAttachementData",ci,{ref=attachment.ref,isClassified=false},wt,wt)
      if type(modifiers)~="table" then
        local model=(G(wt,"assetName") or state.weaponInfo.ref).."+"..attachment.ref
        local slot=call(Engine,"GetAttachmentSlotIndex",model,attachment.ref)
        if type(slot)=="number" and slot>=0 then modifiers=call(rawget(_G,"ClientWeapon"),"getattachmentmodifiers",ci,model,slot) end
      end
      local sorted=type(modifiers)=="table" and call(rawget(_G,"GUNSMITH"),"getsortedmodifiersvalues",modifiers)
      local positive,negative={},{}
      local function collect(items,output,prefix)
        for _,item in ipairs(type(items)=="table" and items or {}) do
          local label=loc(G(item,"name"))
          if label~="" then output[#output+1]=prefix..label end
        end
      end
      collect(G(sorted,"positiveModifiers"),positive,"+ ")
      collect(G(sorted,"negativeModifiers"),negative,"- ")
      effects={positive=table.concat(positive,"\n"),negative=table.concat(negative,"\n")}
      state.effectCache[attachment.ref]=effects
      do end
    end
    bonuses:setText(effects.positive,0); drawbacks:setText(effects.negative,0)
    bonuses:SetAlpha(effects.positive~="" and 1 or 0,0); drawbacks:SetAlpha(effects.negative~="" and 1 or 0,0)
  end
  local function image(w,mat)
    w:SetAlpha(0,0)
    if mat then local ok,m=pcall(api.RegisterMaterial,mat); if ok and m then w:setImage(m,0); w:SetAlpha(1,0) else do end end end
  end
  local function refFor(id) return call(LOOT,"GetItemRef",id,true) or call(LOOT,"getitemreffromid",id,true) end
  -- Same current-weapon model used by the stock in-game weapon UI.
  local function currentNode()
    local ds=rawget(_G,"DataSources")
    local n=G(G(G(G(ds,"alwaysLoaded"),"player"),"currentWeapon"),"name")
    if n then return G(G(G(ds,"alwaysLoaded"),"player"),"currentWeapon") end
    return G(G(rawget(_G,"_DataSources"),"cg"),"player") and G(G(G(rawget(_G,"_DataSources"),"cg"),"player"),"currentWeapon")
  end
  local function value(node,key)
    local field=G(node,key); local getter=G(field,"GetValue")
    if type(getter)=="function" then local ok,v=pcall(getter,field,ci); if ok then return v end end
  end
  local function heldInfo()
    local wt=call(WP,"getweapontableforcurrentweapon",ci)
    local node=currentNode()
    local full=value(node,"name") or call(rawget(_G,"Game"),"GetCurrentWeaponRef",ci,false)
    if full=="" or full=="none" then full=call(rawget(_G,"Game"),"GetCurrentWeaponRef",ci,false) end
    local ref=G(wt,"weapon") or call(rawget(_G,"Game"),"GetCurrentWeaponRef",ci,false)
    if type(ref)~="string" or ref=="" then ref=type(full)=="string" and full:match("^[^+ ]+") or nil end
    ref=(ref and call(WP,"GetBaseRef",ref,false)) or ref
    if ref=="none" or ref=="" then ref=nil end
    return {ref=ref,key=full or ref,name=loc(ref and call(WP,"GetName",ref,wt),"Held weapon"),image=value(node,"image") or (ref and call(WP,"getimage",ref)),table=wt}
  end
  state.weaponInfo=heldInfo()
  do end
  -- Read-only comparison with a user-created known-good build. In particular,
  -- native model generation expands attachextralist and resolves hidden parts;
  -- the .csf only stores the explicitly selected attachment loot IDs.
  local function traceAdditions(ref,label) end
  local function probeSavedBuilds() end
  if rawget(_G,"RecrudSavedBuildProbe") then
    local savedOK,savedError=nil
    if not savedOK then do end end
  end
  local defaultCache={}
  local defaultLogged={}
  local hiddenCache={}
  local extrasBuild,contextExtras
  local function generatedExtras()
    local full=state.weaponInfo.key or state.weaponInfo.ref
    if extrasBuild==full then return contextExtras end
    extrasBuild=full; contextExtras={}
    local active,owners={},{}
    for token in tostring(full):gmatch("%+([^+]+)") do
      local ref=call(AT,"GetRefAndVariantID",token) or token:match("^([^|]+)")
      if ref then active[ref]=true; owners[#owners+1]=ref end
    end
    local function add(ref)
      if type(ref)~="string" or ref=="" then return end
      local ar=call(AT,"GetRefAndVariantID",ref) or ref:match("^([^|]+)")
      if ar then contextExtras[ar]=true end
    end
    local native=call(Engine,"GetWeaponExtraAttachments",full,ci)
    for key,value in pairs(type(native)=="table" and native or {}) do
      local extra=type(key)=="string" and key or type(value)=="string" and value
      local ref=extra and (call(AT,"GetRefAndVariantID",extra) or extra:match("^([^|]+)"))
      if ref and active[ref] then add(ref) end
    end
    -- Same attachextralist expansion as native model assembly; this also works
    -- during a HUD refresh before its extra-attachment table has caught up.
    for _,ref in ipairs(owners) do
      local extras=call(AT,"getattachmentaddition",ref)
      for _,extra in pairs(type(extras)=="table" and extras or {}) do add(extra) end
    end
    return contextExtras
  end
  local function isHidden(ref)
    if generatedExtras()[ref] then return true end
    if hiddenCache[ref]~=nil then return hiddenCache[ref] end
    local bundle=call(AT,"GetBundleByRef",ref)
    local flag=G(bundle,"hideinui")
    local native=call(AT,"shouldhideinui",bundle)
    local hidden=flag==true or flag==1 or native==true or native==1
    hiddenCache[ref]=hidden
    if hidden then do end end
    return hidden
  end
  local function isDefault(ref)
    local b=call(AT,"GetBundleByRef",ref)
    local flag=G(b,"isdefault")
    if flag==true or flag==1 then
      if not defaultLogged[ref] then defaultLogged[ref]=true; do end end
      return true
    end
    local weapon=state.weaponInfo.ref
    if not weapon then return false end
    if not defaultCache[weapon] then
      local defaults={}
      local refs={weapon}
      if weapon and not weapon:match("_mp$") then refs[#refs+1]=weapon.."_mp" end
      for _,base in ipairs(refs) do
        local list=call(Engine,"GetWeaponDefaultAttachments",base)
        for _,v in pairs(type(list)=="table" and list or {}) do
          defaults[type(v)=="string" and v or G(v,"ref") or v]=true
        end
      end
      defaultCache[weapon]=defaults
    end
    if defaultCache[weapon][ref] and not defaultLogged[ref] then defaultLogged[ref]=true; do end end
    return defaultCache[weapon][ref] or false
  end
  local infoCache={}
  local catalogCache={}
  local function attachmentList(weaponRef,typ)
    local byType=catalogCache[weaponRef]
    if not byType then byType={}; catalogCache[weaponRef]=byType end
    if byType[typ] then return byType[typ] end
    local list=call(Engine,"GetWeaponAttachmentsByType",weaponRef,typ)
    if type(list)~="table" then return nil end
    local copy={}
    for _,v in pairs(list) do
      local ref=type(v)=="string" and v or G(v,"ref") or G(v,"attachmentRef") or G(v,"attachment")
      if ref then copy[#copy+1]=ref end
    end
    byType[typ]=copy
    return copy
  end
  local function attachmentInfo(ref)
    if type(ref)~="string" or ref=="" or ref=="none" then return nil end
    if isHidden(ref) then return nil end
    if infoCache[ref] then return infoCache[ref] end
    local b=call(AT,"GetBundleByRef",ref) or call(Engine,"GetScriptBundle","attachmentdata:"..ref)
    if not b then if not faults[ref] then faults[ref]=true; do end end; return nil end
    local category=call(AT,"getcategoryrefbyattachref",ref)
    if not category then
      local cb=call(Engine,"GetScriptBundle",G(b,"category"))
      category=cb and G(cb,"ref")
      if cb and G(cb,"parent") then local parent=call(Engine,"GetScriptBundle",G(cb,"parent")); category=(parent and G(parent,"ref")) or category end
    end
    local cat=aliases[tostring(category)]
    local id=tonumber(G(b,"lootid") or G(b,"lootID") or call(LOOT,"getitemid",ref))
    if not cat or not id or id<=0 or id>=1048576 then
      if not faults[ref] then faults[ref]=true; do end end
      return nil
    end
    local info={id=id,ref=ref,category=cat,name=loc(call(AT,"getnameunlocalized",ref) or G(b,"name") or G(b,"displayname"),"Attachment"),desc=loc(call(AT,"getDesc",ref) or G(b,"description")),image=call(AT,"getimage",ref) or G(b,"image")}
    infoCache[ref]=info
    return info
  end
  local function attachmentForId(id) if id and id>0 then return attachmentInfo(refFor(id)) end end
  local function getOptions(ref)
    local result,seen={},{}
    for i=1,9 do result[i]={} end
    if not ref then return result end
    local refs={ref}; if state.weaponInfo.key and state.weaponInfo.key~=ref then refs[#refs+1]=state.weaponInfo.key end
    if type(ref)=="string" and not ref:match("_mp$") and not ref:match("_zm$") then refs[#refs+1]=ref.."_mp" end
    for _,weaponRef in ipairs(refs) do
      for typ=0,16 do
        local list=attachmentList(weaponRef,typ)
        if type(list)=="table" then
          for _,v in pairs(list) do
            local ar=type(v)=="string" and v or G(v,"ref") or G(v,"attachmentRef") or G(v,"attachment")
            local a=attachmentInfo(ar)
            if a and not isDefault(a.ref) and not seen[a.id] then
              local missing=call(Engine,"getattachmentsrequiredforunlock",state.weaponInfo.key or ref,a.ref)
              local hidden=false
              a.requiredLocked=false
              if type(missing)=="table" and next(missing) then
                hidden=true; a.requiredLocked=true
                for _,required in pairs(missing) do
                  local category=call(AT,"getcategoryrefbyattachref",required)
                  if category~="conversionkit" and category~="receiver" then hidden=false end
                end
                do end
              end
              if not hidden then
                seen[a.id]=true; result[a.category][#result[a.category]+1]=a
                do end
              end
            end
          end
        end
      end
    end
    for _,list in ipairs(result) do table.sort(list,function(a,b) return a.name<b.name end) end
    local counts={}; for i,list in ipairs(result) do counts[i]=#list end
    do end
    return result
  end
  -- Native Gunsmith tables retain attachment refs/variants from the held build.
  -- Read them before contacting the shop, so a network reply cannot erase the build.
  local function readEquipped(info)
    local result={}
    local function add(ref)
      local a=attachmentInfo(ref)
      if a and not isDefault(a.ref) then result[a.category]=a.id end
    end
    local parsed
    if type(info.key)=="string" and type(G(WP,"generateweapontablefromweaponstring"))=="function" then
      local ref=info.ref or state.weaponInfo.ref
      parsed=call(WP,"generateweapontablefromweaponstring",ref,info.key,{shouldIncludeAllAttachments=false,shouldConvertVariantIDToNumber=true},ci)
    end
    -- Generated conversion extras must not look like separately equipped,
    -- removable purchases. Prefer the same explicit-selection parser as Gunsmith.
    local explicit=G(parsed,"attachments")
    local attachments=type(explicit)=="table" and explicit or G(info.table,"attachments")
    if type(attachments)=="table" then
      for _,a in pairs(attachments) do if type(a)=="string" or not G(a,"defaultAttachment") then add(type(a)=="string" and a or G(a,"ref")) end end
    end
    if type(explicit)~="table" and type(info.key)=="string" then
      for token in info.key:gmatch("%+([^+]+)") do
        local ref=call(AT,"GetRefAndVariantID",token) or token:match("^([^|]+)")
        add(ref)
      end
    end
    return result,parsed
  end
  state.equipped=readEquipped(state.weaponInfo)
  for cat,id in pairs(state.equipped) do do end end
  -- Same hashed dvar reader used by the working recrud_gsc_log_post bridge.
  local readSignature
  local function readReply()
    local D,C=rawget(_G,"Dvar"),rawget(_G,"CLUA")
    local reader=D and D["0x254084d7ca2317bb"]
    local hash=C and G(C,"PushXHashDvar")
    if type(reader)~="function" or type(hash)~="function" then
      if readSignature~="unavailable" then readSignature="unavailable"; do end end
      return nil
    end
    local ok,v=pcall(function() return reader(hash("recrud_weap_reply")) end)
    local signature=tostring(ok)..":"..type(v)..":"..tostring(v)
    if signature~=readSignature then readSignature=signature; do end end
    if ok then
      state.removedMask=tonumber(tostring(v):match("^%d+|(%d+)")) or 0
      state.authoritativeBuild=tostring(v):match("^%d+|%d+|(.+)$")
      return tonumber(tostring(v):match("^(%d+)"))
    end
  end
  local function contains(list,value)
    for _,v in pairs(type(list)=="table" and list or {}) do if v==value then return true end end
    return false
  end
  local function ruleBlocks(blocker,other)
    local weapon=state.weaponInfo.key or state.weaponInfo.ref
    return contains(call(Engine,"GetAttachmentsBlocked",weapon,blocker),other)
      or contains(call(Engine,"GetAttachmentSlotsBlocked",weapon,blocker),call(Engine,"GetAttachmentSlot",weapon,other))
      or contains(call(Engine,"GetAttachmentBaseTypesBlocked",weapon,blocker),call(Engine,"GetAttachmentBaseType",weapon,other))
  end
  local function activeRefs()
    local refs={}
    for _,id in pairs(state.equipped) do local ref=refFor(id); if ref then refs[#refs+1]=ref end end
    for token in tostring(state.weaponInfo.key or ""):gmatch("%+([^+]+)") do
      local ref=call(AT,"GetRefAndVariantID",token) or token:match("^([^|]+)")
      local category=call(AT,"getcategoryrefbyattachref",ref)
      if not aliases[tostring(category)] then refs[#refs+1]=ref end
    end
    return refs
  end
  local function lockedByKit(a)
    if state.equipped[a.category]==a.id then return false end
    for _,ref in ipairs(activeRefs()) do
      local category=call(AT,"getcategoryrefbyattachref",ref)
      if ref~=a.ref and aliases[tostring(category)]~=a.category then
        if ruleBlocks(ref,a.ref) or (category=="conversionkit" and ruleBlocks(a.ref,ref)) then
          do end; return true
        end
      end
    end
    return false
  end
  local function replacesOtherSlots(a)
    for _,ref in ipairs(activeRefs()) do
      local category=aliases[tostring(call(AT,"getcategoryrefbyattachref",ref))]
      if ref~=a.ref and category and category~=a.category and ruleBlocks(a.ref,ref) and not ruleBlocks(ref,a.ref) then
        do end; return true
      end
    end
    return false
  end
  local tick=0
  local function nowMs()
    local value=call(Engine,"GetMilliseconds")
    return type(value)=="number" and value or tick*32
  end
  local sendQ={}
  local selectionIndex
  local function encode(seq,arg) return 16777216+seq*65536+(arg or 0) end
  local function request(op,arg)
    if not state.alive or state.pending then do end; return end
    local now=nowMs()
    if op==3 and now<(state.nextEditAtMs or 0) then do end; return end
    local selection
    if op==3 then
      selection=selectionIndex and selectionIndex(arg or 0)
      if selection==nil then do end; status:setText("Select the attachment category again to refresh.",0); return end
      state.nextEditAtMs=now+300
    end
    state.pending=true; state.started=tick; state.startedAtMs=now; state.waitLogStage=1; state.operation=op; state.argument=arg or 0; state.lastDvar=readReply()
    status:setText(op==3 and "Applying attachment..." or "Loading weapons...",0)
    if op==3 then
      -- One selection has no chunk ordering requirement: dispatch immediately.
      local ok,err=pcall(function() Engine.NotifyServer("bongo_item_unlock_status_is_locked",encode(10,selection)) end)
      if not ok then state.pending=false; do end; status:setText("Attachment request could not be sent.",0); return end
      do end
    else sendQ[#sendQ+1]=encode(op==0 and 8 or 9,arg) end
    state.requestNo=(state.requestNo or 0)+1
    do end
  end
  local panelRows=1
  local function layoutRows(rows)
    panelRows=rows
    local lift=(rows-1)*140
    local effectsBottom=math.max(330,math.min(535,760-lift))
    bonuses:SetAnchorsAndPosition(0,1,0,1,550,935,310,effectsBottom)
    drawbacks:SetAnchorsAndPosition(0,1,0,1,955,1340,310,effectsBottom)
    heading:SetAnchorsAndPosition(0,1,0,1,450,1470,782-lift,824-lift)
    subtitle:SetAnchorsAndPosition(0,1,0,1,120,1800,832-lift,872-lift)
    if api.LayoutRows then api.LayoutRows(rows,15) end
    do end
  end
  local tiles={}
  local function clear()
    for _,tile in ipairs(tiles) do panel[tile.id]=nil end
    panel:closeChildren(); tiles={}
  end
  local function card(id,i,n,label,mat,detail,fn,enabled,onfocus,price,equipped,locked,replaces)
    local width,stride=100,110
    local row=math.floor((i-1)/15)
    local col=(i-1)%15
    local columns=math.min(15,n-row*15)
    local x=960-columns*stride/2+4+col*stride
    local y=903-(panelRows-1)*140+row*130
    local c=LUI.UIButton.new(); c.id=id; c:SetAnchorsAndPosition(0,1,0,1,x,x+width,y,y+120)
    c.gridRow=row; c.gridColumn=col
    local ok,base=pcall(function() return MB.BuildRegisteredType("TileButtonBase",{controllerIndex=ci}) end)
    if ok and base then
      base.id="BACKING"
      pcall(function() base.blur:SetVisible(false) end)
      pcall(function() base.fuiicon:SetVisible(false) end)
      base:SetAnchorsAndPosition(0,0,0,0,0,0,0,0); c:addElement(base)
    end
    local bordered=pcall(function()
      local border=MB.BuildRegisteredType("TileButtonBorder",{controllerIndex=ci})
      border.id="gradient"; border:SetAnchorsAndPosition(0,0,0,0,0,0,0,0); c:addElement(border)
    end)
    do end
    if not ok or not base or not bordered then
      local fallback=MB.BuildRegisteredType("footerbuttonbackground",{controllerIndex=ci})
      fallback:SetAnchorsAndPosition(0,1,0,1,0,width,0,120); c:addElement(fallback)
    end
    local icon=LUI.UIImage.new(); icon.id=id.."_icon"; icon:SetAnchorsAndPosition(0,1,0,1,12,88,20,96); image(icon,mat); c:addElement(icon)
    local bottom=text(id.."_detail",(price~=nil or equipped or locked) and "" or detail or "",11,3,width-3,96,117,1)
    bottom:SetWordWrap(true); c:addElement(bottom)
    if price~=nil or equipped or locked then bottom:setText("",0) end
    c.chrome=api.CardChrome(c,ci); c.chrome.update(price,equipped,locked)
    local warning=LUI.UIImage.new(); warning.id=id.."_warning"
    warning:SetAnchorsAndPosition(0,1,0,1,72,96,3,27)
    image(warning,"icon_gunsmith_warning"); warning:SetRGB(0xFFB400,0)
    warning:SetAlpha(replaces and not locked and not equipped and 1 or 0,0)
    c:addElement(warning); c.conflictWarning=warning
    if enabled==false then if locked then icon:SetAlpha(.35,0) else c:SetAlpha(.4,0) end end
    local acted=-1
    local function action()
      if c.probeDetails and acted~=tick then c.probeDetails() end
      do end
      if state.pending or enabled==false or acted==tick then return end
      acted=tick; fn()
    end
    local function focus()
      do end
      if ok and base then pcall(function() ACTIONS.AnimateSequence(base,"buttonOver") end) end
      if onfocus then onfocus() end
    end
    c:addEventHandler("button_action",action); c:addEventHandler("button_over",focus)
    c:addEventHandler("button_up",function() if ok and base then pcall(function() ACTIONS.AnimateSequence(base,"buttonUp") end) end end)
    local mouse=MB.BuildRegisteredType("MouseButtonArea",{controllerIndex=ci}); mouse:SetAnchorsAndPosition(0,0,0,0,0,0,0,0)
    mouse:addEventHandler("mousedownleft",action); mouse:addEventHandler("mouseenter",focus); c:addElement(mouse)
    panel[id]=c; panel:addElement(c); tiles[#tiles+1]=c
    return c
  end
  local function finish()
    for i,c in ipairs(tiles) do
      local up=tiles[i-15]
      local down=tiles[i+15]
      if not down and c.gridRow<panelRows-1 then down=tiles[#tiles] end
      c.navigation={left=tiles[i-1],right=tiles[i+1],up=up,down=down}
    end
    if tiles[1] then
      local ok,err=pcall(function() ACTIONS.GainFocus(panel,tiles[1].id,ci) end)
      do end
    end
  end
  local showSlots,showChoices
  showSlots=function()
    do end; state.view="slots"; clear(); layoutRows(1)
    local info=state.weaponInfo; state.options=getOptions(info.ref)
    heading:setText(string.upper(info.name),0); subtitle:setText("Choose an attachment slot. Equip for 10 salvage; removing is free.",0)
    setDescription("Editing the weapon you are holding. Unsupported categories are unavailable for this weapon.")
    for category=1,9 do
      local equipped=attachmentForId(state.equipped[category]); local available=#state.options[category]>0
      card("weap_category_"..category,category,9,categories[category],equipped and equipped.image,equipped and "EQUIPPED" or (available and categories[category] or "UNAVAILABLE"),function() request(2,category) end,available or equipped~=nil,function()
        heading:setText(categories[category],0)
        setDescription(equipped and equipped.name or (available and "Choose an attachment for this slot." or "Unavailable for this weapon."),equipped)
      end,nil,equipped~=nil,false)
    end
    finish()
  end
  showChoices=function()
    do end; state.view="choices"; clear()
    local list={}
    local equipped=state.equipped[state.category]
    local found=false
    for _,a in ipairs(state.options[state.category] or {}) do list[#list+1]=a; if a.id==equipped then found=true end end
    if equipped and equipped>0 and not found and not isDefault(refFor(equipped)) then
      local a=attachmentForId(equipped); if a then list[#list+1]=a end
    end
    local count=#list+1
    layoutRows(math.max(1,math.ceil(count/15)))
    heading:setText(string.upper(categories[state.category] or "ATTACHMENTS"),0)
    subtitle:setText("Equip for 10 salvage. Click the equipped attachment to remove it free.",0)
    setDescription("Choose an attachment. Click an equipped attachment to remove it for free.")
    for i,a in ipairs(list) do
      local selected=equipped==a.id
      local locked=not selected and (state.conflicts[a.id] or a.requiredLocked or lockedByKit(a))
      local replaces=not selected and not locked and replacesOtherSlots(a)
      local attachmentCard=card("weap_attach_"..a.id,i,count,"",a.image,selected and "EQUIPPED" or "10 SALVAGE",function() do end; request(3,selected and 0 or a.id) end,not locked,function()
        heading:setText(a.name,0); setDescription(a.desc,a)
      end,10,selected,locked,replaces)
      attachmentCard.probeDetails=function()
        do end
        do end
        do end
        local missing=call(Engine,"getattachmentsrequiredforunlock",state.weaponInfo.key or state.weaponInfo.ref,a.ref)
        for _,required in pairs(type(missing)=="table" and missing or {}) do do end end
        for _,ref in ipairs(activeRefs()) do
          local activeBlocks,selectedBlocks=ruleBlocks(ref,a.ref),ruleBlocks(a.ref,ref)
          if activeBlocks or selectedBlocks then do end end
        end
      end
    end
    card("weap_back",count,count,"","ui_map_icon_ob_quest_exfil","BACK",showSlots,true,function()
      heading:setText("BACK",0); setDescription("Return to attachment slots.")
    end)
    finish()
  end
  local function refHash(ref,seed,multiplier)
    local alphabet="abcdefghijklmnopqrstuvwxyz0123456789_"
    local value=seed
    for i=1,#ref do
      local digit=alphabet:find(ref:sub(i,i),1,true)
      if not digit then return nil end
      value=(value*multiplier+digit)%65521
    end
    return value
  end
  local function bitmapForPlan(token,plan)
    local D,C=rawget(_G,"Dvar"),rawget(_G,"CLUA")
    local reader=D and D["0x254084d7ca2317bb"]
    local hash=C and G(C,"PushXHashDvar")
    if type(reader)~="function" or type(hash)~="function" then return nil end
    local ok,raw=pcall(function() return reader(hash("recrud_weap_catalog")) end)
    if not ok then return nil end
    local version,count,encoded=tostring(raw):match("^(%d+)|(%d+)|(.+)$")
    count=tonumber(count)
    if tonumber(version)~=token or not count or count<1 or count>144 or #encoded~=count*6 then return nil end
    local alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
    local function unpack16(offset)
      local value=0
      for i=offset,offset+2 do
        local digit=alphabet:find(encoded:sub(i,i),1,true)
        if not digit then return nil end
        value=value*64+digit-1
      end
      if value>=65521 then return nil end
      return value
    end
    local indices={}
    for index=0,count-1 do
      local h1,h2=unpack16(index*6+1),unpack16(index*6+4)
      if not h1 or not h2 then return nil end
      local key=h1..":"..h2
      if indices[key]~=nil then return nil end
      indices[key]=index
    end
    local words={};for i=1,math.ceil(count/16) do words[i]=0 end
    for _,part in ipairs(plan) do
      local index=indices[part.h1..":"..part.h2]
      if index==nil then return nil end
      local word=math.floor(index/16)+1
      local bit=2^(index%16)
      if math.floor(words[word]/bit)%2==1 then return nil end
      words[word]=words[word]+bit
    end
    return words,indices
  end
  selectionIndex=function(id)
    if state.lastSerial==nil then return nil end
    local token=state.lastSerial%128
    local _,indices=bitmapForPlan(token,{})
    if not indices then return nil end
    if id==0 then return token*256 end
    local ref=refFor(id)
    if type(ref)~="string" then return nil end
    local h1,h2=refHash(ref,1,33),refHash(ref,7,131)
    if not h1 or not h2 then return nil end
    local index=indices[h1..":"..h2]
    if index==nil then return nil end
    return token*256+index+1
  end

  local function onServer(v)
    local refreshStarted=nowMs()
    do end
    if not state.alive or not state.pending or type(v)~="number" or math.floor(v/1048576)~=5 then do end; return end
    local payload=v%1048576
    local serial=math.floor(payload/1024)
    if serial==state.lastSerial then do end; return end
    local mode=math.floor(payload/128)%8
    local result=math.floor(payload/16)%8
    local category=payload%16
    do end
    if mode==6 then do end; return end
    if mode~=3 and mode~=(state.operation==0 and 0 or state.operation==2 and 2 or 4) then do end; return end
    state.lastSerial=serial; state.pending=false
    do end
    if mode==3 then
      if result==4 then
        local id=state.argument>0 and state.argument or state.equipped[state.category]
        if id then
          state.conflicts[id]=true
          do end
          showChoices()
        end
        status:setText("",0)
      else status:setText(responses[result] or "The attachment could not be changed.",0) end
      return
    end
    if mode==4 then
      for i=1,9 do if math.floor((state.removedMask or 0)/2^(i-1))%2==1 then state.equipped[i]=0 end end
      state.equipped[category]=state.argument; state.conflicts={}
    end
    state.category=category
    status:setText(mode==4 and (state.argument==0 and "Attachment removed — free." or "Attachment changed — 10 salvage.") or "",0)
    if state.authoritativeBuild then
      local previous=state.weaponInfo.key
      state.weaponInfo.key=state.authoritativeBuild
      local equipped,parsed=readEquipped({key=state.authoritativeBuild,ref=state.weaponInfo.ref})
      state.equipped=equipped
      state.weaponInfo.table=parsed -- never retain an old conversion's HUD table
      if previous~=state.authoritativeBuild then state.conflicts={}; state.effectCache={} end
      state.options={}
      local slots={};for i=1,9 do slots[i]=tostring(state.equipped[i] or 0) end
      do end
    end
    if mode==2 or mode==4 then state.options=getOptions(state.weaponInfo.ref) end
    if mode==0 then showSlots()
    elseif mode==2 then state.page=1; showChoices()
    elseif mode==4 then showChoices() end
    do end
  end
  do end
  local waitMarks={1000,5000,10000}
  local tm=LUI.UITimer.new({interval=32,event="recrud_weapon_tick"}); e:addElement(tm)
  e:registerEventHandler("recrud_weapon_tick",function()
    tick=tick+1
    if state.pending then
      local v=readReply()
      if v and v~=state.lastDvar then
        state.lastDvar=v; onServer(v)
      end
    end
    if #sendQ>0 and nowMs()>=(state.nextSendAtMs or 0) then
      state.nextSendAtMs=nowMs()+32
      local v=table.remove(sendQ,1)
      do end
      local ok,err=pcall(function() Engine.NotifyServer("bongo_item_unlock_status_is_locked",v) end)
      do end
      if not ok then sendQ={}; state.pending=false; status:setText("Could not contact the attachment shop.",0); do end end
    end
    if state.pending then
      local elapsed=nowMs()-state.startedAtMs
      local threshold=waitMarks[state.waitLogStage or 1]
      if threshold and elapsed>=threshold then
        state.waitLogStage=(state.waitLogStage or 1)+1
        do end
      end
      if elapsed>15000 then do end; state.pending=false; sendQ={}; status:setText("Shop response timed out. Select Attachments again to refresh.",0) end
    end
  end)
  local close=e.close
  e.close=function(self,...)
    do end
    if api.LayoutRows then api.LayoutRows(1) end
    state.alive=false; sendQ={}
    local ok,err=pcall(function() Engine.NotifyServer("bongo_item_unlock_status_is_locked",encode(12)) end)
    do end
    return close(self,...)
  end
  rawset(_G,"RecrudWeaponsLive",{e=e,root=function() if not state.pending then showSlots(); request(0) end end})
  -- Retain the Arsenal's salvage header.
  local headerOK,headerError=pcall(function()
    local root=rawget(_G,"RecrudArsenalRoot"); local si=rawget(_G,"RecrudStockInfo")
    local cd=si and G(si.mi,"menucurrencydata")
    do end
    if root and root.currencyheader and cd then api.PurchaseMenuUtils.setzmtabcurrency(root.currencyheader,cd,ci) end
  end)
  do end
  showSlots(); request(0)
  do end
  return e
end
