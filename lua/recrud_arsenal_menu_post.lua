-- created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
-- recrud_arsenal_menu_post.lua
-- 1:1 copy of the stock "zmarsenalmenu" (decompiled zmarsenalmenu.dec.lua), owned by us.
-- Hooks MenuBuilder.BuildRegisteredType so the stock arsenal interact builds OUR copy.
-- Hash literals (N#0x..) are rebuilt with the same bytecode trick as ui/LUIFPSCounter.lua.
local function log(m) end
local HC={}
local function uleb(n) local t={} repeat local b=n%128; n=math.floor(n/128); if n>0 then b=b+128 end; t[#t+1]=string.char(b) until n==0; return table.concat(t) end
local function H(hex,kind)
  kind=kind or 0
  local ck=hex..":"..kind
  if HC[ck] then return HC[ck] end
  local h=hex:gsub("^0*",""); h=string.rep("0",16-#h)..h
  local b8={}
  for i=8,1,-1 do b8[#b8+1]=string.char(tonumber(h:sub(i*2-1,i*2),16)) end
  local kgc=string.char(4,kind)..table.concat(b8)
  local bc=string.char(0x28,0,0,0)..string.char(0x4d,0,2,0)
  local body=string.char(0,0,2,0)..uleb(1)..uleb(0)..uleb(2)..bc..kgc
  local chunk=string.char(27).."LJ"..string.char(0x84)..uleb(0x1a)..uleb(#body)..body..string.char(0)
  local f=assert(load(chunk))
  HC[ck]=f()
  return HC[ck]
end
local xh=rawget(_G,"xhash") or rawget(_G,"PushXHash")
local CL=rawget(_G,"CLUA")
if type(xh)~="function" and type(CL)=="table" then xh=CL.PushXHash end
local function G(t,k)
  if t==nil then return nil end
  local okv,v=pcall(function() return t[k] end); if not okv then v=nil end
  if v==nil and type(xh)=="function" then local ok,hk=pcall(xh,k); if ok then local o2,v2=pcall(function() return t[hk] end); if o2 then v=v2 end end end
  return v
end

local function P(t,depth)
  if type(t)~="table" or depth<=0 then return t end
  return setmetatable({},{__index=function(_,k)
    local v=G(t,k)
    if type(v)=="table" and getmetatable(v)==nil then return P(v,depth-1) end
    return v
  end,__newindex=function(_,k,v) t[k]=v end})
end
local ACTIONS,LUI,MenuBuilder=P(rawget(_G,"ACTIONS"),1),P(rawget(_G,"LUI"),2),P(rawget(_G,"MenuBuilder"),1)
local SWATCHES,Engine,FONT_HANDLE,BLEND_MODE,CONDITIONS=P(rawget(_G,"SWATCHES"),3),P(rawget(_G,"Engine"),1),P(rawget(_G,"FONT_HANDLE"),1),P(rawget(_G,"BLEND_MODE"),1),P(rawget(_G,"CONDITIONS"),1)
local RegisterMaterial,_DataSources,PurchaseMenuUtils,STREAMING,_PT=rawget(_G,"RegisterMaterial"),P(rawget(_G,"_DataSources"),4),P(rawget(_G,"PurchaseMenuUtils"),1),P(rawget(_G,"STREAMING"),1),rawget(_G,"_PT")
local rul=rawget(_G,"requireUnlessHotload")
if type(rul)=="function" then
  for _,m in ipairs({
    {"ui.generated.widgets.buttons.mousebuttonarea","MouseButtonArea"},
    {"ui.generated.widgets.frontend.mp.playmenu.menutab","MenuTab"},
    {"ui.generated.widgets.footerbuttonbackground","footerbuttonbackground"},
    {"ui.generated.widgets.buttons.tilebuttonbase","TileButtonBase"},
    {"ui.generated.widgets.buttons.tilebuttonborder","TileButtonBorder"},
    {"ui.generated.widgets.ingame.zm.upgrademenus.zmpurchasemenucurrencyheader","zmpurchasemenucurrencyheader"}}) do
    local ok,e=pcall(rul,m[1],m[2]); do end
  end
end
local function DSP(name)
  local ds=rawget(_G,"_DataSources")
  return G(G(G(ds,"in_game"),"purchase_menu"),name)
end
local function layoutArsenalRows(rows,columns)
  rows=math.max(1,math.min(7,math.floor(tonumber(rows) or 1)))
  columns=math.max(9,math.min(15,math.floor(tonumber(columns) or 9)))
  local half=518+(columns-9)*55
  local lift=(rows-1)*140
    local root=rawget(_G,"RecrudArsenalRoot")
    if not root then return end
    local function place(w,x1,x2,y1,y2)
      if w then w:SetAnchorsAndPosition(0.5,0.5,1,0,x1,x2,y1-lift,y2-lift) end
    end
    place(root.Tabs,-374,374,-364.5,-326.5)
    place(root.tabsbackground,-half,half,-361.5,-289.5)
    place(root[H("15421612502BD66C",0)],-half,half,-361.5,-289.5)
    place(root[H("1E93E6A615CCD9CD",0)],-half-34,half+34,-400.5,-193.5)
    -- Each row count owns a fixed panel. Never scale the stock pattern vertically.
    if root.gridbackground then
      root.gridbackground:SetAlpha(rows==1 and 1 or 0,0)
      root.gridbackground:SetFixedAspectRatioImageNoTile(columns==9)
      root.gridbackground:SetAnchorsAndPosition(0.5,0.5,1,0,-half,half,-305.5,169.5)
    end
    for count,panel in pairs(root.RecrudRowPanels or {}) do
      local height=475+(count-1)*140
      panel:SetAnchorsAndPosition(0.5,0.5,1,0,-half,half,169.5-height,169.5)
      panel:SetAlpha(count==rows and 1 or 0,0)
    end
end
local function step(m) end
local function MAT(name,h)
  local ok,m=pcall(RegisterMaterial,h)
  do end
  if ok then return m end
end
-- Stock Ammo Mods cost/equipped/lock chrome, shared by Attachments and Augments.
local function arsenalCost(n)
  local si=rawget(_G,"RecrudStockInfo")
  local currency
  for _,tab in ipairs(si and si.tabs or {}) do
    local cd=G(tab,"currencydata")
    if tostring(G(cd,"currencyname")):find("salvage") then currency=cd; break end
    for _,item in ipairs(G(tab,"items") or {}) do
      cd=G(item,"currencydata")
      if tostring(G(cd,"currencyname")):find("salvage") then currency=cd; break end
    end
    if currency then break end
  end
  local ref=G(currency,"iconstringcountref")
  if ref then local ok,v=pcall(Engine.Localize,ref,n); if ok and type(v)=="string" then return v end end
  return tostring(n)
end
local function arsenalCardChrome(c,ci)
  local function img(id,material,x1,x2,y1,y2,top)
    local w=LUI.UIImage.new(); w.id=id
    w:setImage(RegisterMaterial(material),0)
    if top then w:SetAnchorsAndPosition(0,1,0,1,x1,x2,y1,y2)
    else w:SetAnchorsAndPosition(0,1,1,0,x1,x2,y1,y2) end
    c:addElement(w); return w
  end
  local bg=img("costbg","v_ui_elmnt_tech_generic_button_bg",0,0,-34,-10)
  bg:SetRGB(1907997,0)
  local cost=LUI.UIStyledText.new(); cost.id="cost"
  cost:SetRGB(0xF5F5F5,0); cost:SetScale(0.1,0); cost:SetFont(FONT_HANDLE.SecondaryBold)
  cost:SetFontSize(14*_PT); cost:SetMinFontSize(14*_PT); cost:SetWordWrap(false)
  cost:SetAlignment(2); cost:SetVerticalAlignment(1)
  cost:SetAnchorsAndPosition(1,0,1,0,-91,-10,-22,-9); c:addElement(cost)
  local banner=img("equippedbacker",H("2114ECF72889A498",3),0,100,-12,0,true)
  local label=LUI.UIStyledText.new(); label.id="EquippedText"
  label:SetRGB(0,0); label:SetScale(-0.35,0); label:SetFont(FONT_HANDLE.PrimaryBold)
  label:SetFontSize(15*_PT); label:SetMinFontSize(15*_PT); label:SetWordWrap(false)
  label:SetAnchorsAndPosition(0,1,0,1,3.5,83.5,-12,0); label:setText("EQUIPPED",0); c:addElement(label)
  local checkbox=img("checkbox","ui_hud_portrait_border_square",82,98,1,17,true)
  local check=img("checkMark","sat_ui_common_checkmark",83,98,1,16,true)
  local lock=img("lock","sat_ui_icon_social_lock",83,98,2,17,true)
  local frame={}
  for i,b in ipairs({{0,100,0,1},{0,100,119,120},{0,1,0,120},{99,100,0,120}}) do
    frame[i]=img("equipped_edge_"..i,"ui_default_white",b[1],b[2],b[3],b[4],true)
    frame[i]:SetRGB(0x963CFF,0)
  end
  local function update(price,equipped,locked)
    local showPrice=price~=nil and not equipped and not locked
    cost:setText(showPrice and arsenalCost(price) or "",0)
    bg:SetAlpha(showPrice and 1 or 0,0)
    banner:SetAlpha(equipped and 1 or 0,0); label:SetAlpha(equipped and 1 or 0,0)
    checkbox:SetAlpha(equipped and 1 or 0,0); check:SetAlpha(equipped and 1 or 0,0)
    lock:SetAlpha(locked and 1 or 0,0)
    for _,edge in ipairs(frame) do edge:SetAlpha(equipped and 1 or 0,0) end
  end
  update(nil,false,false)
  return {update=update,cost=cost,lock=lock,banner=banner,check=check}
end

local SEQF="ui/generated/luielems/ingame/zm/menus/sat/zmarsenalmenu.lua"
local States = {
	DefaultState = function ( e, ev )
		e._sequences = {
			DefaultSequence = function ( x )
				do end
				local ok,err=pcall(function() x.promptcontainer:AnimateSequenceBinary( SEQF, 0, 2 ) end)
				if not ok then do end end
			end,
			ZH = function ( x ) end
		}
		e._sequenceLengths = { ZH = 0, DefaultSequence = 0 }
	end
}

-- Read-only stock Ammo Mod timing: native dispatch -> replicated mod -> card chrome.
local function installAmmoTiming(root,ci) end

local function OurArsenalMenu( f1_arg1 )
	local f1_arg0 = (f1_arg1 and f1_arg1.controllerIndex) or 0
	local aCTIONS = ACTIONS
	local lUI = LUI
	local menuBuilder = MenuBuilder
	local uIElement = lUI.UIElement.new( f1_arg1 )
	uIElement.id = "zmarsenalmenu" uIElement.__states = States
	-- (stock state/sequences omitted: they need the stock binary sequence file)
	local f1_local4 = lUI.ValidateControllerIndex( uIElement, f1_arg0 )
	local f1_local5 = "__registrationindex"
	local f1_local6 = f1_arg1 and f1_arg1.registrationIndex
	uIElement[f1_local5] = f1_local6
	uIElement.SoundSet = "zmIngame"
	do
		local pit,pict=G(lUI,"promptinputtype"),G(lUI,"prompticontype")
		do end
		if type(pit)=="table" then local n=0; for k2,v2 in pairs(pit) do if n<8 then n=n+1; do end end end end
	end
	do end; uIElement:SetPrompts( {
		{
			buttonRef = "button_secondary",
			labeltext = "lua_menu/exit",
			inputtype = 2, -- LUI.promptinputtype.gamepad_only
			gamepadicontype = 1 -- LUI.prompticontype.button_ref_icon
		},
		{
			buttonRef = "button_primary",
			labeltext = "LUA_MENU/PURCHASE",
			priority = 2,
			inputtype = 2, -- LUI.promptinputtype.gamepad_only
			gamepadicontype = 1 -- LUI.prompticontype.button_ref_icon
		},
		{
			buttonRef = "button_dpad_horizontal",
			labeltext = "lua_menu/select",
			priority = 3,
			inputtype = 2, -- LUI.promptinputtype.gamepad_only
			gamepadicontype = 1 -- LUI.prompticontype.button_ref_icon
		}
	} )
	do end; local MouseButtonArea = nil
	
	MouseButtonArea = menuBuilder.BuildRegisteredType( "MouseButtonArea", {
		controllerIndex = f1_local4
	} )
	MouseButtonArea.id = "MouseButtonArea"
	aCTIONS.ScaleFullscreen( MouseButtonArea )
	MouseButtonArea:SetAnchorsAndPosition( 0, 0, 0, 0, 0, 0, 0, 0 )
	uIElement:addElement( MouseButtonArea )
	uIElement.MouseButtonArea = MouseButtonArea
	
	local fullscreendarkening = nil
	
	fullscreendarkening = lUI.UIImage.new()
	fullscreendarkening.id = "fullscreendarkening"
	aCTIONS.ScaleFullscreen( fullscreendarkening )
	fullscreendarkening:SetRGB( G(G(rawget(_G,"SWATCHES"),"hud"),"vhuddark") or 0, 0 )
	fullscreendarkening:SetAlpha( 0.3, 0 )
	fullscreendarkening:setImage( RegisterMaterial( "ui_default_white" ), 0 )
	uIElement:addElement( fullscreendarkening )
	uIElement.fullscreendarkening = fullscreendarkening
	
	local f1_local9 = nil
	f1_local9 = lUI.UIImage.new()
	f1_local9.id = H("1E93E6A615CCD9CD",0)
	f1_local9:SetRGB( 0, 0 )
	do local mm=MAT("2A2A27",H("2A2A27EC0876F040",3)); if mm then f1_local9:setImage( mm, 0 ) end end
	f1_local9:SetAnchorsAndPosition( 0.5, 0.5, 1, 0, -552, 552, -400.5, -193.5 )
	uIElement:addElement( f1_local9 )
	uIElement[H("1E93E6A615CCD9CD",0)] = f1_local9
	local tabsbackground = nil
	
	tabsbackground = lUI.UIImage.new()
	tabsbackground.id = "tabsbackground"
	tabsbackground:SetAlpha( 0.55, 0 )
	do local mm=MAT("570A03",H("570A038958E924A7",3)); if mm then tabsbackground:setImage( mm, 0 ) end end
	tabsbackground:SetAnchorsAndPosition( 0.5, 0.5, 1, 0, -518, 518, -361.5, -289.5 )
	uIElement:addElement( tabsbackground )
	uIElement.tabsbackground = tabsbackground
	
	local f1_local11 = nil
	f1_local11 = lUI.UIImage.new()
	f1_local11.id = H("15421612502BD66C",0)
	do local mm=MAT("570A03",H("570A038958E924A7",3)); if mm then f1_local11:setImage( mm, 0 ) end end
	do local bm=BLEND_MODE.screen; do end; if bm~=nil then f1_local11:SetBlendMode( bm ) end end
	f1_local11:SetAnchorsAndPosition( 0.5, 0.5, 1, 0, -518, 518, -361.5, -289.5 )
	uIElement:addElement( f1_local11 )
	uIElement[H("15421612502BD66C",0)] = f1_local11
	local gridbackground = nil
	
	gridbackground = lUI.UIImage.new()
	gridbackground.id = "gridbackground"
	do local mm=MAT("28B6C4",H("28B6C4EFF251A76C",3)); if mm then gridbackground:setImage( mm, 0 ) end end
	gridbackground:SetFixedAspectRatioImageNoTile( true )
	gridbackground:SetAnchorsAndPosition( 0.5, 0.5, 1, 0, -518, 518, -305.5, 169.5 )
	uIElement:addElement( gridbackground )
	uIElement.gridbackground = gridbackground

	-- Dedicated 2..7-row panels assembled from the stock material at its original
	-- 1036x475 UI scale. Keep the caps once and repeat only the middle strip.
	-- SetVMin/Max are the same native cropping API used by stock atlas widgets.
	uIElement.RecrudRowPanels = {}
	local panelMaterial=RegisterMaterial(H("28B6C4EFF251A76C",3))
	for rows=2,7 do
		local panel=lUI.UIElement.new()
		panel.id="arsenal_panel_rows_"..rows
		local height=475+(rows-1)*140
		panel:SetAnchorsAndPosition(0.5,0.5,1,0,-518,518,169.5-height,169.5)
		local function strip(id,y,height,vmin,vmax)
			local image=lUI.UIImage.new()
			image.id=id; image:setImage(panelMaterial,0)
			image:SetVMin(vmin,0); image:SetVMax(vmax,0)
			image:SetAnchorsAndPosition(0,0,0,1,0,0,y,y+height)
			panel:addElement(image)
		end
		strip("top",0,175,0,175/475)
		for row=1,rows do
			strip("middle_"..row,175+(row-1)*140,140,175/475,315/475)
		end
		strip("bottom",height-160,160,315/475,1)
		panel:SetAlpha(0,0)
		uIElement:addElement(panel)
		uIElement.RecrudRowPanels[rows]=panel
	end
	
	local f1_local13 = nil
	do end; if not Engine.InFrontend() then
		f1_local13 = lUI.TabManager.new( {
			tabHeight = -48,
			spacing = 4,
			wrap = false,
			buildTab = function ()
				return menuBuilder.BuildRegisteredType( "MenuTab", {
					controllerIndex = f1_arg0
				} )
			end,
			controllerIndex = f1_local4
		} )
		f1_local13.id = "Tabs"
		f1_local13:SetAnchorsAndPosition( 0.5, 0.5, 1, 0, -374, 374, -364.5, -326.5 )
		uIElement:addElement( f1_local13 )
		uIElement.Tabs = f1_local13
	end
	local headerbacker = nil
	
	headerbacker = lUI.UIImage.new()
	headerbacker.id = "headerbacker"
	headerbacker:setImage( RegisterMaterial( "sat_ui_purchase_menu_header" ), 0 )
	headerbacker:SetAnchorsAndPosition( 0.5, 0.5, 0, 1, -359, 359, -15, 126 )
	uIElement:addElement( headerbacker )
	uIElement.headerbacker = headerbacker
	
	local currencybanner = nil
	
	currencybanner = lUI.UIImage.new()
	currencybanner.id = "currencybanner"
	currencybanner:setImage( RegisterMaterial( "sat_ui_purchase_menu_banner_zm" ), 0 )
	currencybanner:Setup3SliceHorizontalImage( 120, 0.3 )
	currencybanner:SetAnchorsAndPosition( 0.5, 0.5, 0, 1, -244, 244, 73, 164 )
	uIElement:addElement( currencybanner )
	uIElement.currencybanner = currencybanner
	
	do end; local currencyheader = nil
	
	currencyheader = menuBuilder.BuildRegisteredType( "zmpurchasemenucurrencyheader", {
		controllerIndex = f1_local4
	} )
	currencyheader.id = "currencyheader"
	currencyheader:SetScale( -0.3, 0 )
	currencyheader:SetAnchorsAndPosition( 0.5, 0.5, 0, 1, -178, 178, 105.5, 131.5 )
	uIElement:addElement( currencyheader )
	uIElement.currencyheader = currencyheader
	
	do end; local header = nil
	
	header = lUI.UIStyledText.new()
	header.id = "header"
	header:SetRGB( 11522303, 0 )
	header:setText( Engine.Localize( H("3C4443055ED7EECF",3) ), 0 )
	do local cs=G(G(lUI,"CaseStyle"),"Uppercase"); do end; if cs~=nil then header:setCaseStyle( cs ) end end
	do local fh=FONT_HANDLE.PrimaryBold; do end; if fh~=nil then header:SetFont( fh ) end end
	header:SetFontSize( 70 * _PT )
	header:SetMinFontSize( 70 * _PT )
	header:SetWordWrap( false )
	header:SetTracking( 1, 0 )
	header:SetAlignment( 1 )
	header:SetAnchorsAndPosition( 0.5, 0.5, 0, 1, -312, 312, 0, 62 )
	uIElement:addElement( header )
	uIElement.header = header
	
	local f1_local18 = nil
	f1_local18 = lUI.UIHorizontalStackedLayout.new( {
		controller = f1_local4
	} )
	uIElement.promptcontainer = f1_local18
	f1_local18.id = "promptcontainer"
	f1_local18:SetAlpha( 0.9, 0 )
	f1_local18:SetAlignment( 1 )
	f1_local18:SetVerticalAlignment( 0 )
	f1_local18:SetAnchorsAndPosition( 0.5, 0.5, 1, 0, -64.5, 63.5, -42, 30 )
	f1_local18:SetSpacing( 25 )
	uIElement:addElement( f1_local18 )
	uIElement:addEventHandler( "gamepad_button", function ( f5_arg0, f5_arg1 )
		local f5_local0 = f5_arg1.controller or f1_arg0
		if CONDITIONS.ButtonSecondary( f1_arg0, f5_arg1 ) then
			aCTIONS.PlaySoundSetSound( f5_arg0, "close", false )
			aCTIONS.scriptnotifybydatasource( f5_local0, DSP("current_menu_close_notify"), 1 )
		end
	end )
	MouseButtonArea:addEventHandler( "mousedownleft", function ( f4_arg0, f4_arg1 )
		do end
		aCTIONS.scriptnotifybydatasource( f4_arg1.controller or f1_arg0, DSP("current_menu_close_notify"), 1 )
	end )
	rawset(_G,"RecrudArsenalRoot",uIElement)
	do local ok,err=nil; if not ok then do end end end
	do end; DSP("current_menu_id"):AddSubscriber( uIElement, f1_local4, function ()
		do end; PurchaseMenuUtils.preloadmenu( uIElement, f1_local4 ); do end
		do end
				do
					local T=uIElement.Tabs
					local origSet=T and T.SetTabs
					if origSet then
						T.SetTabs=function(self,list,...)
							for i,t in ipairs(list) do do end end
							do
								local keep={}
								for i,t in ipairs(list) do
									local nm=tostring(t.name)
									if not string.find(nm,"Weapon Rarity",1,true) then keep[#keep+1]=t end
								end
								if #keep>0 then for i=#list,1,-1 do list[i]=nil end; for i,t in ipairs(keep) do list[i]=t end end
							end
							local aug={
								disabled=false, name="Augments", hasDefaultFocus=false,
								focusFunction=function(a,b,c,d)
									do end
										local live=rawget(_G,"RecrudAugLive")
										if live and uIElement.activeTabWidget==live.e then live.root() return end
									local ok,err=pcall(function()
										local dw=G(rawget(_G,"TAB"),"destroybuiltwidget")
										if type(dw)=="function" then local ok2=pcall(dw,uIElement,"activeTabWidget"); do end else do end end
										local w=MenuBuilder.BuildRegisteredType("recrud_augtab",{controllerIndex=f1_local4})
										uIElement.activeTabWidget=w
											do end
										uIElement:addElement(w)
									end)
									if not ok then do end end
								end,
								loseFocusFunction=function() end
							}
                            list[#list+1]={disabled=false,name="Attachments",hasDefaultFocus=false,
                              focusFunction=function()
                                local live=rawget(_G,"RecrudWeaponsLive")
                                if live and uIElement.activeTabWidget==live.e then live.root(); return end
                                local ok,err=pcall(function()
                                  local destroy=G(rawget(_G,"TAB"),"destroybuiltwidget")
                                  if type(destroy)=="function" then destroy(uIElement,"activeTabWidget") end
                                  local w=MenuBuilder.BuildRegisteredType("recrud_weapontab",{controllerIndex=f1_local4})
                                  uIElement.activeTabWidget=w; uIElement:addElement(w)
                                end)
                                if not ok then do end end
                              end,loseFocusFunction=function() end}
							list[#list+1]=aug
                            list[#list+1]={disabled=false,name="Camos",hasDefaultFocus=false,
                              focusFunction=function()
                                if uIElement.RecrudCamoBuilding then do end; return end
                                local live=rawget(_G,"RecrudCamosLive")
                                if live and uIElement.activeTabWidget==live.e then live.root(); return end
                                uIElement.RecrudCamoBuilding=true
                                local ok,err=pcall(function()
                                  local destroy=G(rawget(_G,"TAB"),"destroybuiltwidget")
                                  if type(destroy)=="function" then destroy(uIElement,"activeTabWidget") end
                                  local w=MenuBuilder.BuildRegisteredType("recrud_camotab",{controllerIndex=f1_local4})
                                  uIElement.activeTabWidget=w; uIElement:addElement(w)
                                end)
                                uIElement.RecrudCamoBuilding=false
                                if not ok then do end end
                              end,loseFocusFunction=function() end}

								rawset(_G,"RecrudStockTabs",list)
							return origSet(self,list,...)
						end
					end
					pcall(function()
						local mi=PurchaseMenuUtils.getactivemenuinfo(f1_local4)
						rawset(_G,"RecrudStockInfo",{mi=mi,tabs=PurchaseMenuUtils.setupmenutabinfo(G(mi,"ref"))})
					end)
					PurchaseMenuUtils.createzmtabs( uIElement, f1_local4 )
					if origSet then T.SetTabs=origSet end
				end
				do end
	end )
	do
		local seen={}
		for _,ev in ipairs({"mousedown","mouseup","mousemove","mouseenter","gain_focus","lose_focus","gamepad_button","Pause"}) do
			pcall(function() uIElement:addEventHandler(ev,function(a,e) if (seen[ev] or 0)<3 then seen[ev]=(seen[ev] or 0)+1; do end end end) end)
		end
	end
	do end; uIElement.inputRule = {
		mouseInput = true,
		kbmEscapeToClose = true,
		predicate = function ( f2_arg0 )
			if f2_arg0.name == "Pause" then
				return true
			elseif f2_arg0.name ~= "gamepad_button" then
				return false
			elseif f2_arg0.button == "back" or f2_arg0.button == "move_right" or f2_arg0.button == "move_left" or f2_arg0.button == "forward" then
				return false
			elseif f2_arg0.qualifier == "gamepad" and (f2_arg0.button == "right" or f2_arg0.button == "left" or f2_arg0.button == "up" or f2_arg0.button == "down") then
				return false
			elseif f2_arg0.button == "start" then
				return false
			else
				return true
			end
		end,
		closeNotify = DSP("current_menu_close_notify")
	}
	aCTIONS.ScaleFullscreen( uIElement )
	do end; aCTIONS.SetPromptsContainer( uIElement, uIElement.promptcontainer, f1_local4 )
	do end; pcall(function() STREAMING.addstreamerhint( f1_local4, uIElement, "upgradesequenceitem" ) end)
	do end; pcall(function() aCTIONS.AnimateSequence( uIElement, "DefaultSequence" ) end)
	if CONDITIONS.IsChinese() then
		do end
	end
	return uIElement
end



function RecrudEquipAugmentPressed()
  do end
end

local function installArsenalInputRouting()
  local HI=rawget(_G,"HUD_INPUT")
  if type(HI)~="table" or rawget(_G,"RecrudHIWrapped") then return end
  rawset(_G,"RecrudHIWrapped",true)
  local function slot(name) local k=name; if HI[k]==nil and type(xh)=="function" then k=xh(name) end return k end
  local kr,kg=slot("routinginputfor"),slot("routeinput")
  local rf,ro=HI[kr],HI[kg]
  do end
  local n=0
  HI[kr]=function(a,...)
    local r=rf(a,...)
    local sa=tostring(a)
    if sa:find("zmarsenalmenu") or a==xh("zmarsenalmenu") then
      if n<4 then n=n+1; do end end
      return true
    end
    return r
  end
  HI[kg]=function(el,ctrl,rule,...)
    do end
    return ro(el,ctrl,rule,...)
  end
end

-- ===== Augments page v4: everything is driven by the bottom panel buttons + the tab strip (mouse and controller) =====
local AUG_CATS={
  {key="perks",label="Perk-a-Colas",tab="Perks",tag="",kind="perk",columns=7,items={}},
  {key="fields",label="Field Upgrades",tab="Field Upgrades",tag="",kind="field",columns=5,items={}},
  {key="ammo",label="Ammo Mods",tab="Ammo",tag="",kind="ammo",columns=8,items={}},
}
local PERK_ICON={specialty_juggernog="juggernaut",specialty_staminup="staminup",specialty_speedcola="speedloader",specialty_deadshot="deadshot",
  specialty_death_perception="deathperception",specialty_quickrevive="quickrevive",specialty_elemental_pop="elemental_pop",specialty_phd_flopper="phdslider",
  specialty_m_mod="melee_macchiato_purchasemenu",specialty_vulture_aid="vultureaid_purchasemenu",specialty_d_mod="double_tap_purchasemenu",
  specialty_z_mod="mulekick",specialty_w_mod="wisp_tea_purchasemenu",specialty_y_mod="widows_wine_purchasemenu"}
local FIELD_ICON={super_aether_shroud="aether_shroud",super_dark_flare="dark_flare",super_energy_mine="energy_mine",super_frenzied_guard="frenzied_guard",
  super_frost_blast="frost_blast",super_healing_aura="healing_aura",super_toxic_growth="toxic_growth",super_tesla_storm="lightning_links",super_wiley_fox="bunny",
  super_mary_paris="time_stopper"}
local AMMO_ICON={brainrot="ui_icon_zm_purchasemenu_ammomod_brainrot",cryofreeze="ui_icon_zm_purchasemenu_ammomod_cryofreeze",deadwire="ui_icon_zm_purchasemenu_ammomod_deadwire",
  napalmburst="ui_icon_zm_purchasemenu_ammomod_napalmburst",shatterblast="ui_icon_zm_purchasemenu_ammomod_shatterblast",
  fw_ammomod="ui_icon_zombie_purchasemenu_ammomod_fireworks",lightray="ui_icon_zombie_purchasemenu_ammomod_lightray",shadowvortex="ui_icon_zombie_purchasemenu_ammomod_shadowvortex"}
local function iconOf(kind,it)
  if type(it)=="table" and it[5] then return it[5] end
  return "ui_shared_transparent"
end
local COST_MAJOR,COST_MINOR=250,100
local TILE_W,TILE_H,TILE_STRIDE=100,120,110

function RecrudBuildAugTab(ci)
  ci=ci or 0
  local lUI=LUI
  local e=lUI.UIElement.new()
  e.id="recrud_augtab"
  e:SetAnchorsAndPosition(0,1,0,1,0,1920,0,1080)
  do end
  local function F(t,k) if type(t)~="table" then return nil end return G(t,k) end
  local function try(label,getter,nameOf,descOf,iconGet)
    local real
    local ok,err=pcall(function()
      local list=getter()
      if type(list)~="table" then do end return end
      real={}
      for i,p in ipairs(list) do
        local ref=tostring(F(p,"ref"))
        local raw=nameOf(p)
        local okn,loc=pcall(function() return Engine.Localize(raw) end)
        local name=(okn and type(loc)=="string" and loc~="" and loc) or (type(raw)=="string" and raw) or ref
        name=tostring(name):gsub("\226\150\188","")
        local dd=descOf and descOf(p)
        local okd,dl=pcall(function() return Engine.Localize(dd) end)
        local desc=(okd and type(dl)=="string" and dl~="" and dl) or (type(dd)=="string" and dd) or ""
        desc=desc:gsub("\226\150\188","")
        local ic=iconGet and iconGet(p,name,ref) or nil
        if i<=3 then do end end
        real[#real+1]={ref,name,desc,p,ic}
      end
      do end
    end)
    if not ok then do end return nil end
    return real
  end
  local stockImg,salCD={},nil
  local okStock,errStock=pcall(function()
    local PMU=rawget(_G,"PurchaseMenuUtils")
    do end
    local si=rawget(_G,"RecrudStockInfo")
    local mi=si and si.mi
    do end
    local tabs=si and si.tabs or {}
    do end
    local n=0
    for ti,tab in ipairs(tabs) do
      local tcd=F(tab,"currencydata")
      local items=F(tab,"items") or {}
      do end
      if tcd and tostring(F(tcd,"currencyname")):find("salvage") and not salCD then salCD=tcd end
      for ii,item in ipairs(items) do
        local nm=F(item,"shortdisplayname") or F(item,"displayname")
        local okl,l=pcall(Engine.Localize,nm)
        local key=(okl and type(l)=="string" and l~="" and l) or tostring(nm)
        key=key:gsub("h88","")
        local img=F(item,"image"); local iref=F(item,"itemref")
        if img then stockImg[key:lower()]=img; if iref then stockImg[tostring(iref):lower()]=img end end
        local cd=F(item,"currencydata")
        if cd and not salCD and tostring(F(cd,"currencyname")):find("salvage") then salCD=cd end
        n=n+1
        if n<=24 then do end end
      end
    end
    do end
  end)
  if not okStock then do end end
  local function call(gname,fname,...)
    local T=rawget(_G,gname)
    local fn=T and G(T,fname)
    if type(fn)~="function" then error(gname.."."..fname.." missing") end
    return fn(...)
  end
  local perks=try("perk",function() return call("ZMPERK","getperklist") end,
    function(p) local d=F(p,"data"); return F(d,"name") or F(d,"displayname") end,
    function(p) return F(F(p,"data"),"description") end,
    function(p) local d=F(p,"data"); return F(d,"image") or F(d,"icon") end)
  AUG_CATS[1].items=perks or {}
  local fields=try("field",function() return call("SUPER","getallfieldupgrades",0,nil,true) end,
    function(p) local d=F(p,"superBundle") or F(p,"data"); return F(d,"name") or F(d,"displayname") end,
    function(p) local d=F(p,"superBundle") or F(p,"data"); return F(d,"description") end,
    function(p) local d=F(p,"superBundle") or F(p,"data"); return F(p,"image") or F(d,"image") or F(d,"icon") or F(d,"hudicon") end)
  AUG_CATS[2].items=fields or {}
  local ammos=try("ammo",function() return call("WEAPON","getammomodlist") end,
    function(p) local d=F(p,"data") or p; return F(d,"displayname") or F(d,"name") end,
    function(p) local d=F(p,"data") or p; return F(d,"description") end,
    function(p,name,ref) local d=F(p,"data") or p; return stockImg[tostring(name):lower()] or stockImg[tostring(ref):lower()] or F(d,"hudicon") or F(d,"image") end)
  AUG_CATS[3].items=ammos or {}

  local function txt(id,s,size,a1,a2,a3,a4,x1,x2,y1,y2,align)
    local t=lUI.UIStyledText.new(); t.id=id; t:setText(s,0)
    t:SetFont(FONT_HANDLE.PrimaryBold); t:SetFontSize(size*_PT); t:SetMinFontSize(size*_PT); t:SetWordWrap(false)
    t:SetAlignment(align or 0); t:SetAnchorsAndPosition(a1,a2,a3,a4,x1,x2,y1,y2)
    return t
  end
  local Dvar=P(rawget(_G,"Dvar"),1)
  local function dv(n) local ok,v=pcall(function() return Dvar.GetDvarString(n) end); if ok and type(v)=="string" then return v end return "" end
  local function vis(w,v) pcall(function() w:SetVisible(v) end) end
  local function short(x) x=tostring(x):gsub("attempt","ATTEMPT"):gsub("^.-lua\"%]:",""); return x:sub(1,90) end

  -- Hover details share the panel header, like stock Ammo Mods.
  local descHdr=txt("augdesc2","AUGMENTS",32,0,1,0,1,120,1800,782,824,1); e:addElement(descHdr)
  local desc=txt("augdesc","",18,0,1,0,1,120,1800,832,872,1); desc:SetWordWrap(true); e:addElement(desc)
  pcall(function() desc:SetRGB(13421772,0) end)
  local dName,dDesc=descHdr,desc
  -- Equipped icon/slots remain in the preview area.
  local det=lUI.UIElement.new(); det.id="aug_detail"
  det:SetAnchorsAndPosition(0,1,0,1,540,1380,150,660)
  e:addElement(det)
  local aIcon=lUI.UIImage.new(); aIcon.id="aug_icon"; aIcon:SetAnchorsAndPosition(0,1,0,1,10,150,170,310); det:addElement(aIcon)
  -- equipped grid for the hovered perk/field upgrade/ammo mod
  local grid=lUI.UIElement.new(); grid.id="eq_grid"; grid:SetAnchorsAndPosition(0,1,0,1,300,830,160,420); det:addElement(grid)
  grid:addElement(txt("g_maj","MAJOR AUGMENTS",16,0,1,0,0,0,520,0,24,0))
  grid:addElement(txt("g_min","MINOR AUGMENTS",16,0,1,0,0,0,520,130,154,0))
  local slotT={maj={},min={}}
  for _,kind in ipairs({"maj","min"}) do
    local y1=(kind=="maj") and 28 or 158
    for i=1,4 do
      local x1=(i-1)*100
      local c=lUI.UIElement.new(); c.id=kind..i; c:SetAnchorsAndPosition(0,1,0,1,x1,x1+90,y1,y1+90)
      pcall(function()
        local bg=MenuBuilder.BuildRegisteredType("footerbuttonbackground",{controllerIndex=ci})
        bg:SetAnchorsAndPosition(0,1,0,1,0,90,0,90); c:addElement(bg)
      end)
      local ic=lUI.UIImage.new(); ic.id=kind..i.."_icon"; ic:SetAnchorsAndPosition(0,1,0,1,8,82,8,82); ic:SetAlpha(0); c:addElement(ic)
      local t=txt(kind..i.."_t","EMPTY",13,0,1,0,1,0,90,35,55,1); c:addElement(t)
      pcall(function() t:SetRGB(8421504,0) end)
      grid:addElement(c)
      slotT[kind][i]={t=t,ic=ic}
    end
  end

  -- ===== state =====
  local own,eq={},{}
  local srvEq,srvOwn,tmpEq,tmpOwn=rawget(_G,"RecrudAugEq"),rawget(_G,"RecrudAugOwn"),{},{}
  if not srvEq then srvEq={}; rawset(_G,"RecrudAugEq",srvEq) end
  if not srvOwn then srvOwn={}; rawset(_G,"RecrudAugOwn",srvOwn) end
  local function h20of(k) local hx=tostring(k):match("#x%x(%x+)"); if not hx or #hx<5 then return nil end return tonumber(hx:sub(-5),16) end
  setmetatable(eq,{__index=function(_,k) local h=h20of(k); return h and srvEq[h] or nil end})
  setmetatable(own,{__index=function(_,k) local h=h20of(k); return h and (srvOwn[h] or srvEq[h]) or nil end})
  local lastSig=""
  local cur,selAug,curCat=nil,nil,nil
  local state="root"
  local tiles={}
  local augTiles={}
  local pan=lUI.UIElement.new(); pan.id="aug_panel"; pan:SetAnchorsAndPosition(0,1,0,1,0,1920,0,1080); e:addElement(pan)

  local function setSet(str) local t={} for w in tostring(str or ""):gmatch("[^,]+") do t[w]=true end return t end
  local function loc(x) local ok,l=pcall(function() return Engine.Localize(x) end); local r=(ok and type(l)=="string" and l~="" and l) or (type(x)=="string" and x) or ""; r=r:gsub("\226\150\188",""); return r end
  local function augsOf(it)
    if it.augs then return it.augs end
    local list={}
    it.augs=list
    pcall(function()
      local p=it[4]
      local d=F(p,"data") or F(p,"superBundle")
      local al=F(d,"augmentlist")
      if type(al)~="table" then return end
      for i,a in ipairs(al) do
        local bn=F(a,"augmentbundle")
        if bn~=nil then
          local okb,b=pcall(function() return Engine.GetScriptBundle(bn) end)
          if okb and type(b)=="table" then
            local key=tostring(bn)
            pcall(function()
              for kk,vv in pairs(b) do
                if tostring(kk):find("2f682d22020061fb",1,true) then key=tostring(vv); break end
              end
            end)
            pcall(function()
              local n=(rawget(_G,"RecrudHTn") or 0)+1; rawset(_G,"RecrudHTn",n)
              if n<=300 then do end end
              if n<=3 then
                local c=0
                for k,v in pairs(b) do c=c+1; if c<=40 then local tv=type(v); do end end end
              end
              if n==1 then
                for _,nm in ipairs({"napalmburst_petrol","napalmburst_contact_burn","napalmburst_damage_boost","none","salvage"}) do
                  do end
                end
              end
            end)
            local nm=loc(F(b,"displayname")); if nm=="" then nm=key end
            local isM=F(b,"ismajor") and true or false
            if not nm:lower():find("extra slot",1,true) then
              list[#list+1]={key=key,name=nm,desc=loc(F(b,"description")),icon=F(b,"icon"),major=isM}
            end
          end
        end
      end
    end)
    return list
  end
  local function mat(n) local ok,m=pcall(RegisterMaterial,n); if ok then return m end end
  local function refreshSlots()
    local list=cur and augsOf(cur) or {}
    for _,kind in ipairs({"maj","min"}) do
      local wantMajor=(kind=="maj")
      local owned={}
      for _,a in ipairs(list) do if a.major==wantMajor and eq[a.key] then owned[#owned+1]=a end end
      for _,a in ipairs(list) do if a.major==wantMajor and own[a.key] and not eq[a.key] then owned[#owned+1]=a end end
      for i=1,4 do
        local a=owned[i]
        local sl=slotT[kind][i]
        if a then
          pcall(function() sl.t:setText("",0) end)
          pcall(function() sl.ic:setImage(mat(a.icon),0) end)
          pcall(function() sl.ic:SetRGB(eq[a.key] and 16777215 or 8421504,0) end)
          pcall(function() sl.ic:SetAlpha(1) end)
        else
          pcall(function() sl.t:setText("EMPTY",0) end)
          pcall(function() sl.ic:SetAlpha(0) end)
        end
      end
    end
  end
  local function costOf(a) return a.major and COST_MAJOR or COST_MINOR end
  local loggedRef=false
  local function costStr(n)
    local ref=salCD and F(salCD,"iconstringcountref")
    if not ref then
      local root=rawget(_G,"RecrudArsenalRoot")
      local hdr=root and root.currencyheader
      ref=hdr and G(hdr,"iconstringcountref")
      if not ref and not loggedRef then loggedRef=true; do end end
    end
    if ref then
      local ok,v=pcall(Engine.Localize,ref,n)
      if ok and type(v)=="string" and v~="" then return v end
    end
    return tostring(n)
  end
  local salvNow=nil
  pcall(function()
    local cur=G(G(G(_DataSources,"in_game"),"currency"),"salvage")
    e:SubscribeToModel(cur:GetModel(ci),function(m) local v=DataModel.GetModelValue(m); if type(v)=="number" then salvNow=v end end)
  end)
  local function salvageNow() return salvNow or 0 end
  -- Mutual exclusion applies to MAJOR augments only, and only to the groups listed here (script audit).
  -- Keep in sync with recrud_aug_partners() in recrud_zm_aug_menu.gsc. Add a group = add a line.
  local ME_GROUPS={
    -- (empty for now: no mutual exclusion; unequip is manual)
  }
  local MEP={}
  pcall(function()
    for _,g in ipairs(ME_GROUPS) do
      local hs={}
      for _,n in ipairs(g) do hs[#hs+1]=h20of(xh(n)) end
      for i,hi in ipairs(hs) do
        MEP[hi]=MEP[hi] or {}
        for j,hj in ipairs(hs) do if i~=j then MEP[hi][#MEP[hi]+1]={h=hj,n=g[j]} end end
      end
      do end
    end
  end)
  local function conflictsOf(a)
    local r={}
    if not a.major then return r end
    local ha=h20of(a.key)
    for _,p in ipairs(ha and MEP[ha] or {}) do
      if srvEq[p.h] then r[#r+1]={name=p.n,pair=p.h} end
    end
    return r
  end
  local function augStatus(a)
    if eq[a.key] then return "EQUIPPED" end
    local me=#conflictsOf(a)>0 and "!ME" or ""
    if own[a.key] then return "OWNED "..me end
    return me
  end
  local function refreshAugTiles()
    for _,t in ipairs(augTiles) do
      pcall(function() t.tag:setText("",0) end)
      if t.card.arsenalChrome then t.card.arsenalChrome.update(not own[t.a.key] and costOf(t.a) or nil,eq[t.a.key] and true or false,false) end
      pcall(function() t.cost:setText((eq[t.a.key] or own[t.a.key]) and "" or costStr(costOf(t.a)),0) end)
      pcall(function() t.ic:SetRGB(eq[t.a.key] and 16777215 or (own[t.a.key] and 13421772 or 10526880),0) end)
    end
  end
  local function setAugDetail(a)
    selAug=a
    dName:setText(a.name,0); dDesc:setText(a.desc,0)
    pcall(function() aIcon:setImage(mat(a.icon),0) end); pcall(function() aIcon:SetAlpha(1) end)
    local st
    if eq[a.key] then st="Equipped - click to unequip" elseif own[a.key] then st="Owned - click to equip" else st="Click to purchase: "..costStr(costOf(a)) end
    if not eq[a.key] then
      local c=conflictsOf(a)
      if #c>0 then
        local nms={}; for _,o in ipairs(c) do nms[#nms+1]=o.name end
        st=st.."  [!] MUTUALLY EXCLUSIVE with "..table.concat(nms,", ")..": it will be unequipped"
      end
    end
    desc:setText((a.desc and a.desc~="" and a.desc.."  " or "")..st,0)
  end
  local function setItemDetail(it)
    cur=it; selAug=nil
    dName:setText(it[2],0); dDesc:setText(it[3]~="" and it[3] or it[1],0)
    pcall(function() aIcon:setImage(mat(iconOf(nil,it)),0) end); pcall(function() aIcon:SetAlpha(1) end)
    refreshSlots()
  end

  local tick=0
  local sendQ={}
  local sendTick=0
  local nextAugEditTick=0
  local lock={}
  local function pollState()
    tick=tick+1
    refreshSlots(); refreshAugTiles()
  end

  -- Select the fixed panel for this row count and move the header above it.
  local panelRows=1
  local function layoutRows(rows)
    panelRows=rows
    local lift=(rows-1)*140
    descHdr:SetAnchorsAndPosition(0,1,0,1,120,1800,782-lift,824-lift)
    desc:SetAnchorsAndPosition(0,1,0,1,120,1800,832-lift,872-lift)
    layoutArsenalRows(rows,15)
  end
  -- Stock tab switches destroy this widget; restore their panel geometry too.
  local originalClose=e.close
  e.close=function(self,...)
    layoutArsenalRows(1)
    return originalClose(self,...)
  end

  -- ===== panel button (stock tile look, UIButton so d-pad focus + A work; mouse handled too) =====
  local lastActId,lastActTick=nil,-1
  local function tile(id,i,n,matname,label,tint,onaction,onfocus,row,rowStep,rowOffset)
    local x1=960-(n*TILE_STRIDE)/2+5+(i-1)*TILE_STRIDE
    local y1=903-(panelRows-1)*140+(row or 0)*(rowStep or 130)+(rowOffset or 0)
    local c=lUI.UIButton.new(); c.id=id; c:SetAnchorsAndPosition(0,1,0,1,x1,x1+TILE_W,y1,y1+TILE_H)
    local base
    local okT=pcall(function()
      base=MenuBuilder.BuildRegisteredType("TileButtonBase",{controllerIndex=ci})
      base.id="BACKING"
      pcall(function() base.blur:SetVisible(false) end); pcall(function() base.fuiicon:SetVisible(false) end)
      base:SetAnchorsAndPosition(0,0,0,0,0,0,0,0); c:addElement(base)
      local bord=MenuBuilder.BuildRegisteredType("TileButtonBorder",{controllerIndex=ci})
      bord.id="gradient"; bord:SetAnchorsAndPosition(0,0,0,0,0,0,0,0); c:addElement(bord)
    end)
    if not okT then
      local img=MenuBuilder.BuildRegisteredType("footerbuttonbackground",{controllerIndex=ci})
      img:SetAnchorsAndPosition(0,1,0,1,0,TILE_W,0,TILE_H); c:addElement(img)
    end
    local ic=lUI.UIImage.new(); ic.id="icon"
    if matname then pcall(function() ic:setImage(mat(matname),0) end) end
    ic:SetAnchorsAndPosition(0,1,0,1,TILE_W*0.12,TILE_W*0.88,TILE_H*0.08,TILE_H*0.08+TILE_W*0.76); c:addElement(ic)
    pcall(function() ic:SetRGB(tint or 16777215,0) end)
    local tag=txt(id.."_tag",label or "",14,0,1,0,1,0,TILE_W,TILE_H*0.80,TILE_H*0.96,1); c:addElement(tag)
    local chrome=arsenalCardChrome(c,ci)
    c.arsenalChrome=chrome
    local cost=chrome.cost
    local function over()
      if base then pcall(function() ACTIONS.AnimateSequence(base,"buttonOver") end) end
      if onfocus then pcall(onfocus) end
    end
    local function up()
      if base then pcall(function() ACTIONS.AnimateSequence(base,"buttonUp") end) end
    end
    local function act()
      if lastActId==id and lastActTick==sendTick then return end
      lastActId=id; lastActTick=sendTick
      do end
      onaction()
    end
    c:addEventHandler("button_over",function() do end; over() end)
    c:addEventHandler("button_up",function() up() end)
    c:addEventHandler("button_action",function() act() end)
    local mouse=MenuBuilder.BuildRegisteredType("MouseButtonArea",{controllerIndex=ci})
    mouse:SetAnchorsAndPosition(0,1,0,1,0,TILE_W,0,TILE_H)
    mouse:addEventHandler("mouseenter",function() over() end)
    mouse:addEventHandler("mouseleave",function() up() end)
    mouse:addEventHandler("mousedownleft",function() act() end)
    c:addElement(mouse)
    pan:addElement(c)
    tiles[#tiles+1]=c
    return c,ic,tag,cost
  end
  local function clearPanel()
    pcall(function() pan:closeChildren() end)
    tiles={}; augTiles={}
  end
  local function focusFirst()
    local t=tiles[1]
    if t then pcall(function() ACTIONS.GainFocus(e,t.id,ci) end) end
  end

  -- ===== tab strip control =====
  local function setTabs(list)
    local root=rawget(_G,"RecrudArsenalRoot")
    local T=root and root.Tabs
    if not (T and T.SetTabs) then do end return end
    local ok,err=pcall(function() T:SetTabs(list) end)
    do end
  end
  local function mkTab(name,isDefault,fn)
    return {disabled=false,name=name,hasDefaultFocus=isDefault,focusFunction=function() pcall(fn) end,loseFocusFunction=function() end}
  end

  local showRoot,showCat,showPerk
  -- level B: all items in a category, stacked with a Back tile at top right
  showCat=function(cat,skipTabs)
    state="cat"; curCat=cat; cur=nil; selAug=nil
    clearPanel()
    layoutRows(1)
    descHdr:setText(string.upper(cat.label),0)
    pcall(function() desc:setText("Choose one to buy augments for.",0) end)
    dName:setText(cat.label,0); dDesc:setText("Hover an item to see what it does and its equipped augments.",20,0)
    pcall(function() dDesc:setText("Hover an item to see what it does and its equipped augments.",0) end)
    pcall(function() aIcon:SetAlpha(0) end)
    refreshSlots()
    local columns=math.min(14,math.max(1,#cat.items))
    local rows=math.max(1,math.ceil(#cat.items/columns))
    layoutRows(rows)
    local n=columns+1
    local itemTiles={}
    for i,it in ipairs(cat.items) do
      local col=(i-1)%columns+1
      local row=math.floor((i-1)/columns)
      itemTiles[i]=tile("it_"..it[1],col,n,iconOf(cat.kind,it),"",nil,function() showPerk(it) end,function() setItemDetail(it) end,row)
    end
    local back=tile("back",n,n,"ui_map_icon_ob_quest_exfil","BACK",nil,function() sendQ[#sendQ+1]=16777216+15*65536; showRoot() end,function()
      dName:setText("Back",0); dDesc:setText("Return to the category list.",0); pcall(function() aIcon:SetAlpha(0) end) end)
    -- Explicit controller links keep vertical movement in the same column.
    for i,c in ipairs(itemTiles) do
      local col=(i-1)%columns+1
      local row=math.floor((i-1)/columns)
      c.navigation={
        left=col>1 and itemTiles[i-1] or nil,
        right=itemTiles[i+1] and col<columns and itemTiles[i+1] or back,
        up=row>0 and itemTiles[i-columns] or nil,
        down=itemTiles[i+columns]
      }
    end
    back.navigation={left=itemTiles[columns] or itemTiles[#itemTiles],down=itemTiles[#itemTiles]}
    focusFirst()
    if not skipTabs then
      local list={}
      for _,c in ipairs(AUG_CATS) do list[#list+1]=mkTab(c.tab..(c.tag~="" and "" or ""),c==cat,function() if state=="cat" and curCat==c then return end if state=="cat" or state=="perk" then showCat(c,true) end end) end
      setTabs(list)
    end
  end
  -- Level C: both augment tiers, with item-to-item navigation unique to this page.
  showPerk=function(it)
    state="perk"; cur=it; selAug=nil
    clearPanel()
    local major,minor={},{}
    for _,a in ipairs(augsOf(it)) do
      local list=a.major and major or minor; list[#list+1]=a
    end
    local columns=math.max(1,math.min(14,math.max(#major,#minor)))
    local majorRows=math.max(1,math.ceil(#major/columns))
    local minorRows=math.max(1,math.ceil(#minor/columns))
    layoutRows(majorRows+minorRows)
    descHdr:setText(string.upper(it[2]),0)
    pcall(function() desc:setText("Choose an augment. Click an equipped augment to remove it free.",0) end)
    setItemDetail(it)
    local n=columns+1
    local rows={}
    local function addTier(list,key,label,startRow,count)
      local y=903-(panelRows-1)*140-15+startRow*145
      local heading=txt("tier_"..key,label,16,0,1,0,1,460,1460,y-23,y-3,1)
      pan:addElement(heading)
      for row=startRow,startRow+count-1 do rows[row+1]={} end
      for i,a in ipairs(list) do
        local row=startRow+math.floor((i-1)/columns)
        local col=(i-1)%columns+1
        local c,ic,tag,cst=tile("aug_"..key.."_"..i,col,n,a.icon,augStatus(a),nil,function()
          selAug=a; setAugDetail(a)
          if RecrudAugBuy then RecrudAugBuy() end
        end,function() setAugDetail(a) end,row,145,-15)
        rows[row+1][col]=c
        augTiles[#augTiles+1]={a=a,ic=ic,tag=tag,cost=cst,card=c}
      end
    end
    addTier(major,"major","MAJOR AUGMENTS",0,majorRows)
    addTier(minor,"minor","MINOR AUGMENTS",majorRows,minorRows)
    local back=tile("back",n,n,"ui_map_icon_ob_quest_exfil","BACK",nil,function()
      sendQ[#sendQ+1]=16777216+15*65536; showCat(curCat)
    end,function()
      dName:setText("Back",0); dDesc:setText("Return to the list.",0); pcall(function() aIcon:SetAlpha(0) end)
    end,0,145,-15)
    rows[1][n]=back
    local function nearest(row,col)
      if not row then return nil end
      if row[col] then return row[col] end
      for distance=1,n do
        if row[col-distance] then return row[col-distance] end
        if row[col+distance] then return row[col+distance] end
      end
    end
    local function horizontal(list,col,step)
      for position=col+step,step<0 and 1 or n,step do if list[position] then return list[position] end end
    end
    for row,list in ipairs(rows) do
      for col,c in pairs(list) do
        c.navigation={left=horizontal(list,col,-1),right=horizontal(list,col,1),up=nearest(rows[row-1],col),down=nearest(rows[row+1],col)}
      end
    end
    refreshAugTiles()
    focusFirst()
    local items=curCat and curCat.items or {it}
    if #items==0 then items={it} end
    local index=1
    for i,item in ipairs(items) do if item==it then index=i; break end end
    local previous=items[(index-2)%#items+1]
    local following=items[index%#items+1]
    local prevTab=mkTab("< "..previous[2],false,function()
      if state=="perk" and cur==it and previous~=it then showPerk(previous) end
    end)
    local nextTab=mkTab(following[2].." >",false,function()
      if state=="perk" and cur==it and following~=it then showPerk(following) end
    end)
    prevTab.disabled=#items<2; nextTab.disabled=#items<2
    setTabs({prevTab,mkTab(it[2],true,function() end),nextTab})
  end
  -- level A: category buttons (tabs = stock tabs)
  showRoot=function(skipTabs)
    state="root"; curCat=nil; cur=nil; selAug=nil
    clearPanel()
    layoutRows(1)
    descHdr:setText("AUGMENTS",0)
    pcall(function() desc:setText("Equip up to 4 major and 4 minor augments for each perk/field upgrade/ammo mod this run.",0) end)
    dName:setText("Augments",0); dDesc:setText("Choose a category below.",0)
    pcall(function() aIcon:SetAlpha(0) end)
    refreshSlots()
    local n=#AUG_CATS
    for i,cat in ipairs(AUG_CATS) do
      local first=cat.items[1]
      tile("cat_"..cat.key,i,n,first and iconOf(cat.kind,first) or nil,cat.tag~="" and cat.tag or cat.tab,nil,function() showCat(cat) end,function()
        dName:setText(cat.label,0); dDesc:setText(#cat.items.." items",0); pcall(function() aIcon:SetAlpha(0) end) end)
    end
    focusFirst()
    if not skipTabs then
      local stock=rawget(_G,"RecrudStockTabs")
      if stock then
        for _,t in ipairs(stock) do t.hasDefaultFocus=(t.name=="Augments") end
        setTabs(stock)
      end
    end
  end

  -- reuse hook: stock "Augments" tab calls this when the page is already alive
  rawset(_G,"RecrudAugLive",{e=e,root=function() if state~="root" then showRoot() end end})

  -- ===== purchase request (Lua -> GSC). Probes kept while the dvar path is being diagnosed =====
  local function probeDvar(tag) end
  RecrudAugBuy=function()
    local a=selAug
    if not a then return end
    if sendTick<nextAugEditTick then do end; return end
    if lock[a.key] then return end
    lock[a.key]=true
    local hex=tostring(a.key):match("#x%x(%x+)")
    if hex and #hex<16 then hex=string.rep("0",16-#hex)..hex end
    if not hex or #hex~=16 then do end; lock[a.key]=nil; return end
    nextAugEditTick=sendTick+6
    if eq[a.key] then
      -- click on an equipped augment = unequip (stays owned)
      local h=h20of(a.key)
      if h then srvEq[h]=nil end
      do end
      for seq=0,3 do
        local chunk=tonumber(hex:sub(seq*4+1,seq*4+4),16)
        sendQ[#sendQ+1]=16777216+2097152+(a.major and 1048576 or 0)+seq*65536+chunk
      end
      sendQ[#sendQ+1]={}; sendQ[#sendQ+1]={unlock=a.key}
      refreshSlots(); refreshAugTiles(); setAugDetail(a)
      return
    end
    local cost=costOf(a)
    if not own[a.key] then
      if salvNow and salvNow<cost then do end; pcall(function() desc:setText("Not enough salvage",0) end); lock[a.key]=nil; return end
    end
    do
      for _,o in ipairs(conflictsOf(a)) do
        if o.pair then srvEq[o.pair]=nil end
        do end
      end
      local h=h20of(a.key)
      if h then
        if not srvOwn[h] and not srvEq[h] and salvNow then salvNow=salvNow-cost end
        srvOwn[h]=true; srvEq[h]=true
      end
    end
    do end
    for seq=0,3 do
      local chunk=tonumber(hex:sub(seq*4+1,seq*4+4),16)
      local v=16777216+(a.major and 1048576 or 0)+seq*65536+chunk
      sendQ[#sendQ+1]=v
    end
    sendQ[#sendQ+1]={}; sendQ[#sendQ+1]={unlock=a.key}
    refreshSlots(); refreshAugTiles(); setAugDetail(a)
  end

  -- server truth arrives on the stock purchase-menu notify omnvar (23-bit messages, see GSC recrud_aug_publish)
  local srvN=0
  local function onSrv(v)
    if type(v)~="number" then return end
    srvN=srvN+1
    if srvN<=40 then do end end
    local t=math.floor(v/1048576); local low=v-t*1048576
    if t==1 then tmpEq,tmpOwn={},{}
    elseif t==2 then tmpEq[low]=true
    elseif t==4 then tmpOwn[low]=true
    elseif t==3 then
      for kk in pairs(tmpEq) do srvEq[kk]=true end
      for kk in pairs(tmpOwn) do srvOwn[kk]=true end
      local ne,no=0,0; for _ in pairs(srvEq) do ne=ne+1 end; for _ in pairs(srvOwn) do no=no+1 end
      do end
      pcall(refreshSlots); pcall(refreshAugTiles); if selAug then pcall(setAugDetail,selAug) end
    end
  end
  pcall(function()
    local pr=G(G(G(_DataSources,"in_game"),"purchase_menu"),"purchase_response_notify")
    e:SubscribeToModel(pr:GetModel(ci),function(m) onSrv(DataModel.GetModelValue(m)) end)
    do end
  end)
  sendQ[#sendQ+1]=16777216+15*65536

  local function showHeader()
    local okH,errH=pcall(function()
      local root=rawget(_G,"RecrudArsenalRoot")
      local hdr=root and root.currencyheader
      if not hdr then error("no currencyheader") end
      local cd=salCD
      if not cd then
        local si=rawget(_G,"RecrudStockInfo")
        cd=si and G(si.mi,"menucurrencydata")
      end
      if not cd then error("no salvage currency data") end
      PurchaseMenuUtils.setzmtabcurrency(hdr,cd,ci)
    end)
    do end
  end
  pcall(showHeader)
  showRoot(true)
  do end
  pcall(function()
    local T=G(lUI,"UITimer")
    local tm=T.new({interval=500,event="recrud_aug_poll"})
    e:addElement(tm)
    e:registerEventHandler("recrud_aug_poll",function() pcall(pollState) end)
    local tm2=T.new({interval=50,event="recrud_aug_send"})
    e:addElement(tm2)
    e:registerEventHandler("recrud_aug_send",function()
      sendTick=sendTick+1
      local v=table.remove(sendQ,1)
      if type(v)=="number" then pcall(function() Engine.NotifyServer("bongo_item_unlock_status_is_locked",v) end)
      elseif type(v)=="table" and v.unlock then lock[v.unlock]=nil end
    end)
    do end
  end)
  pcall(pollState)
  return e
end

local mb=rawget(_G,"MenuBuilder")
if type(mb)~="table" or type(mb.BuildRegisteredType)~="function" then do end return end
local orig=rawget(_G,"RecrudArsenalOrigBuild")
if not orig then orig=mb.BuildRegisteredType; rawset(_G,"RecrudArsenalOrigBuild",orig) end
mb.BuildRegisteredType=function(typeName,params,...)
  if typeName=="recrud_camotab" then
    local builder=rawget(_G,"RecrudBuildCamoTab")
    if type(builder)~="function" then error("Camos tab script unavailable") end
    return builder(params and params.controllerIndex)
  end
  if typeName=="recrud_weapontab" then
    local builder=rawget(_G,"RecrudBuildWeaponTab")
    if type(builder)~="function" then error("Weapons tab script unavailable") end
    return builder(params and params.controllerIndex)
  end
  if typeName=="recrud_augtab" then
    local ok,el=pcall(RecrudBuildAugTab,params and params.controllerIndex)
    if ok then do end return el end
    do end
  end
  if typeName=="zmarsenalmenu" then pcall(installArsenalInputRouting);
    local ok,el=xpcall(function() return OurArsenalMenu(params) end,function(e) local tb=(debug and debug.traceback) and debug.traceback(tostring(e),2) or tostring(e); return tb end)
    if ok and el then do end return el end
    for ln in tostring(el):gsub("attempt","ATTEMPT"):gmatch("[^\n]+") do do end end; do end
  end
  return orig(typeName,params,...)
end
rawset(_G,"RecrudArsenalAPI",{G=G,LUI=LUI,Engine=Engine,MenuBuilder=MenuBuilder,ACTIONS=ACTIONS,
  FONT_HANDLE=FONT_HANDLE,PT=_PT,RegisterMaterial=RegisterMaterial,DSP=DSP,PurchaseMenuUtils=PurchaseMenuUtils,LayoutRows=layoutArsenalRows,CardChrome=arsenalCardChrome,Cost=arsenalCost})
do end
