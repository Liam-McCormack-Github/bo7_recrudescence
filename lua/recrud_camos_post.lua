-- created by Liam McCormack: [https://github.com/Liam-McCormack-Github](https://github.com/Liam-McCormack-Github)
-- Arsenal camo browser. Only a fixed catalog index crosses to the server.
local function log(s) end
function RecrudBuildCamoTab(ci)
  ci=ci or 0
  local api=assert(rawget(_G,"RecrudArsenalAPI"),"Arsenal API unavailable")
  local catalog=assert(rawget(_G,"RecrudCamoCatalog"),"Camo catalog unavailable")
  local G,LUI,Engine,MB,ACTIONS=api.G,api.LUI,api.Engine,api.MenuBuilder,api.ACTIONS
  local WP=rawget(_G,"WEAPON")
  local function call(t,k,...)
    local f=G(t,k); if type(f)~="function" then return nil end
    local ok,v=pcall(f,...); if ok then return v end
    do end; return nil
  end
  local e=LUI.UIElement.new(); e.id="recrud_camotab"; e:SetAnchorsAndPosition(0,1,0,1,0,1920,0,1080)
  local panel=LUI.UIElement.new(); panel.id="camo_cards"; panel:SetAnchorsAndPosition(0,1,0,1,0,1920,0,1080)
  local function text(id,value,size,x1,x2,y1,y2,align)
    local w=LUI.UIStyledText.new(); w.id=id; w:setText(value,0); w:SetFont(api.FONT_HANDLE.PrimaryBold)
    w:SetFontSize(size*api.PT); w:SetMinFontSize(size*api.PT); w:SetWordWrap(false); w:SetAlignment(align or 0)
    w:SetAnchorsAndPosition(0,1,0,1,x1,x2,y1,y2); return w
  end
  local heading=text("camo_heading","CAMOS",32,450,1470,782,824,1); e:addElement(heading)
  local subtitle=text("camo_subtitle","Choose a collection. Camo changes are free.",18,120,1800,832,872,1); subtitle:SetWordWrap(true); subtitle:SetRGB(0xCCCCCC,0); e:addElement(subtitle)
  e:addElement(panel)
  local pager=LUI.UIElement.new(); pager.id="camo_pager"; pager:SetAnchorsAndPosition(0,1,0,1,0,1920,0,1080); e:addElement(pager)
  local state={alive=true,pending=true,ready=false,token=nil,equipped=0,rows=1,page=1,tick=0,cooldown=0,stack={}}
  local cache,tiles={},{}
  local function info(index)
    if cache[index] then return cache[index] end
    local row=catalog[index]
    local b=call(WP,"getcamodataforref",row[1])
    local valid=G(b,"ref")~=nil
    local image=G(b,"image")
    local label=row[2]
    local key=G(b,"name")
    local localized=key and call(Engine,"Localize",key)
    if type(localized)=="string" and localized~="" then label=localized:gsub("[%c]",""):gsub("%^%d","") end
    local hash=call(rawget(_G,"CLUA"),"PushXHash",row[1])
    cache[index]={name=label,image=image,valid=valid,ref=row[1],hash=hash and tostring(hash) or "unavailable"}
    return cache[index]
  end
  local function readReply()
    local D,C=rawget(_G,"Dvar"),rawget(_G,"CLUA")
    local reader=D and D["0x254084d7ca2317bb"]
    local hash=G(C,"PushXHashDvar")
    if type(reader)~="function" or type(hash)~="function" then return nil end
    local ok,v=pcall(function() return reader(hash("recrud_camo_reply")) end)
    if ok then return tostring(v) end
  end
  state.lastReply=readReply()
  local function send(seq,arg)
    local value=16777216+seq*65536+(arg or 0)
    local ok,err=pcall(function() Engine.NotifyServer("bongo_item_unlock_status_is_locked",value) end)
    do end
    return ok
  end
  local groups={
    {key="pap",name="PaP",path="PaP Camos",icon="sat_ui_icon_zm_pap_machine"},
    {key="mastery",name="Mastery",path="Mastery Camos",icon="ui_map_icon_elite_crown"},
    {key="bo7",name="BO7",path="sat",icon="sat_logo_bo7"},
    {key="bo6",name="BO6",path="cer",icon="sat_logo_bo6"},
    {key="mw3",name="MW3",path="jup",icon="sat_logo_mw3"},
    {key="mw2",name="MW2",path="camo",icon="sat_logo_mw2"}
  }
  local function node() return {children={},items={},count=0} end
  for _,g in ipairs(groups) do g.tree=node() end
  local function add(root,index,parts,start)
    root.count=root.count+1; root.sample=root.sample or index
    for n=start,#parts do
      local key=parts[n]
      root.children[key]=root.children[key] or node(); root=root.children[key]
      root.count=root.count+1; root.sample=root.sample or index
    end
    root.items[#root.items+1]=index
  end
  for index,row in ipairs(catalog) do
    local parts={}; for part in row[1]:gmatch("[^_]+") do parts[#parts+1]=part end
    for _,g in ipairs(groups) do
      if g.key==row[3] then add(g.tree,index,parts,2)
      elseif (g.key=="mastery" and row[4]) or (g.key=="pap" and row[5]) then add(g.tree,index,parts,1) end
    end
  end
  local children,leaves
  children=function(n)
    if n.groupedChildren then return n.groupedChildren end
    local list={}
    for _,index in ipairs(n.items) do list[#list+1]={index=index,key=catalog[index][1]} end
    for key,child in pairs(n.children) do list[#list+1]={node=child,key=key} end
    table.sort(list,function(a,b) return a.key<b.key end)
    n.groupedChildren=list; return list
  end
  leaves=function(n)
    if n.flat then return n.flat end
    local list={}
    local function collect(branch)
      for _,index in ipairs(branch.items) do list[#list+1]={index=index,key=catalog[index][1]} end
      for _,child in pairs(branch.children) do collect(child) end
    end
    collect(n)
    table.sort(list,function(a,b) return a.key<b.key end)
    n.flat=list; return list
  end
  -- Ignore reference category boundaries: consecutive, sorted batches of 74.
  -- This plan is built once per tab instance; selectors contain only camo leaves.
  for _,g in ipairs(groups) do
    if g.tree.count>74 then
      local entries=leaves(g.tree)
      local selectors=node(); selectors.count=#entries; selectors.sample=g.tree.sample
      for first=1,#entries,74 do
        local pageNode=node(); pageNode.pageSelector=true
        for i=first,math.min(first+73,#entries) do pageNode.items[#pageNode.items+1]=entries[i].index end
        pageNode.count=#pageNode.items; pageNode.sample=pageNode.items[1]
        local page=math.floor((first-1)/74)+1
        selectors.children[string.format("Page %04d",page)]=pageNode
      end
      g.tree=selectors
      do end
    end
  end
  -- Skip single-child folder chains; the full path stays visible in the heading.
  local function collapse(n,path)
    while #n.items==0 do
      local list=children(n)
      if #list~=1 or not list[1].node then break end
      path=path.." / "..list[1].key; n=list[1].node
    end
    return n,path
  end
  local render,showRoot,openNode
  local updatingTabs=false
  local function setTabs(list)
    local root=rawget(_G,"RecrudArsenalRoot"); local T=root and root.Tabs
    if not (T and T.SetTabs) then return end
    updatingTabs=true
    local ok,err=pcall(function() T:SetTabs(list) end)
    updatingTabs=false
    if not ok then do end end
  end
  local groupNav={entries={},all=true}
  for _,g in ipairs(groups) do groupNav.entries[#groupNav.entries+1]={node=g.tree,path=g.path,label=g.name} end
  local function tab(name,selected,fn)
    return {name=name,disabled=false,hasDefaultFocus=selected,
      focusFunction=function() if not updatingTabs and state.alive then fn() end end,loseFocusFunction=function() end}
  end
  local function updateTabs()
    local root=rawget(_G,"RecrudArsenalRoot")
    -- The native tab focus callback assigns activeTabWidget only AFTER this
    -- builder returns. SetTabs before that assignment reenters the builder.
    if not root or root.activeTabWidget~=e then state.tabsDirty=true; return end
    state.tabsDirty=false
    local nav=state.nav
    if not state.node or not nav then
      local stock=rawget(_G,"RecrudStockTabs")
      if stock then
        for _,t in ipairs(stock) do t.hasDefaultFocus=t.name=="Camos" end
        setTabs(stock)
      end
      return
    end
    local current=state.navIndex
    local function go(index)
      if state.nav~=nav or index==state.navIndex then return end
      local entry=nav.entries[index]
      state.node,state.path=collapse(entry.node,entry.path)
      state.navIndex=index; state.page=1; render()
    end
    local tabs={}
    if nav.all then
      for index,entry in ipairs(nav.entries) do
        local target=index
        tabs[#tabs+1]=tab(entry.label,index==current,function() go(target) end)
      end
    else
      local previous=(current-2)%#nav.entries+1
      local following=current%#nav.entries+1
      tabs={tab("< "..nav.entries[previous].label,false,function() go(previous) end),
        tab(nav.entries[current].label,true,function() end),
        tab(nav.entries[following].label.." >",false,function() go(following) end)}
      tabs[1].disabled=#nav.entries<2; tabs[3].disabled=#nav.entries<2
    end
    setTabs(tabs)
  end
  local function focus(index,label,folder)
    heading:setText(index and not folder and info(index).name or label,0)
    if index and not folder then
      local camo=info(index)
      state.hoverSubtitle=camo.ref.."  |  Hash: "..camo.hash
    elseif folder and index then
      state.hoverSubtitle=label.." — open this collection."
    else state.hoverSubtitle="Return to the previous page." end
    if not state.pending then subtitle:setText(state.hoverSubtitle,0) end
  end
  local function image(w,material)
    if material then
      local ok,m=pcall(api.RegisterMaterial,material)
      if ok and m then w:setImage(m,0); return end
    end
    w:SetAlpha(0,0)
  end
  local function select(index)
    if not state.ready or state.pending or state.tick<state.cooldown then return end
    if not info(index).valid then return end
    local target=state.equipped==index and 0 or index
    state.pending=true; state.started=state.tick
    subtitle:setText(target==0 and "Removing camo..." or "Applying camo...",0)
    do end
    if not send(14,state.token*4096+target) then state.pending=false; subtitle:setText("Camo request failed. Reopen Camos to refresh.",0) end
  end
  local function card(i,total,label,index,fn,folder,materialOverride)
    local row=math.floor((i-1)/15); local column=(i-1)%15
    local columns=math.min(15,total-row*15)
    local x=960-columns*110/2+4+column*110
    local y=903-(state.rows-1)*140+row*130
    local c=LUI.UIButton.new(); c.id="camo_card_"..i; c:SetAnchorsAndPosition(0,1,0,1,x,x+100,y,y+120)
    local base=MB.BuildRegisteredType("TileButtonBase",{controllerIndex=ci}); base:SetAnchorsAndPosition(0,0,0,0,0,0,0,0)
    pcall(function() base.blur:SetVisible(false); base.fuiicon:SetVisible(false) end)
    c:addElement(base)
    local border=MB.BuildRegisteredType("TileButtonBorder",{controllerIndex=ci}); border:SetAnchorsAndPosition(0,0,0,0,0,0,0,0); c:addElement(border)
    local icon=LUI.UIImage.new(); icon:SetAnchorsAndPosition(0,1,0,1,8,92,14,96)
    image(icon,materialOverride or (folder and (label=="BACK" and "ui_map_icon_ob_quest_exfil" or "ui_map_icon_cp_mp_exfil") or (index and info(index).image))); c:addElement(icon)
    local bottom=text(c.id.."_label",label,12,3,97,96,118,1); bottom:SetWordWrap(true); c:addElement(bottom)
    local chrome=api.CardChrome(c,ci)
    c.chrome=chrome
    local locked=index and not folder and not info(index).valid or false
    chrome.update(nil,index and not folder and state.equipped==index or false,locked)
    if locked then icon:SetAlpha(.3,0) end
    local function over()
      pcall(function() ACTIONS.AnimateSequence(base,"buttonOver") end)
      focus(index,label,folder)
    end
    local acted=-1
    local function action()
      if acted==state.tick or locked then return end
      acted=state.tick; fn()
    end
    c:addEventHandler("button_action",action); c:addEventHandler("button_over",over)
    c:addEventHandler("button_up",function() pcall(function() ACTIONS.AnimateSequence(base,"buttonUp") end) end)
    local mouse=MB.BuildRegisteredType("MouseButtonArea",{controllerIndex=ci}); mouse:SetAnchorsAndPosition(0,0,0,0,0,0,0,0)
    mouse:addEventHandler("mousedownleft",action); mouse:addEventHandler("mouseenter",over); c:addElement(mouse)
    c.index=not folder and index or nil
    tiles[#tiles+1]=c; panel[c.id]=c; panel:addElement(c)
  end
  local function back()
    local last=table.remove(state.stack)
    if last then state.node=last.node; state.path=last.path; state.page=last.page; state.nav=last.nav; state.navIndex=last.navIndex; render() else showRoot() end
  end
  local function pageButton(id,label,x,fn)
    local c=LUI.UIButton.new(); c.id=id; c:SetAnchorsAndPosition(0,1,0,1,x,x+100,1038,1068)
    local bg=MB.BuildRegisteredType("footerbuttonbackground",{controllerIndex=ci}); bg:SetAnchorsAndPosition(0,0,0,0,0,0,0,0); c:addElement(bg)
    c:addElement(text(id.."_label",label,18,0,100,2,28,1))
    local acted=-1
    local function action() if acted==state.tick then return end; acted=state.tick; fn() end
    c:addEventHandler("button_action",action)
    local mouse=MB.BuildRegisteredType("MouseButtonArea",{controllerIndex=ci}); mouse:SetAnchorsAndPosition(0,0,0,0,0,0,0,0)
    mouse:addEventHandler("mousedownleft",action); c:addElement(mouse)
    pager[id]=c; pager:addElement(c); return c
  end
  openNode=function(n,path,nav,index)
    state.stack[#state.stack+1]={node=state.node,path=state.path,page=state.page,nav=state.nav,navIndex=state.navIndex}
    state.nav=nav; state.navIndex=index
    state.node,state.path=collapse(n,path); state.page=1; render()
  end
  render=function()
    for _,c in ipairs(tiles) do panel[c.id]=nil end
    panel:closeChildren(); pager:closeChildren(); tiles={}
    state.hoverSubtitle=nil
    pager.camo_prev=nil; pager.camo_next=nil
    local flat=state.node and state.node.count<=74
    local list=state.node and (flat and leaves(state.node) or children(state.node)) or groups
    local siblingNav={entries={}}
    local siblingIndex={}
    if state.node then
      for _,entry in ipairs(list) do
        if entry.node and (entry.node.pageSelector or not (#entry.node.items==1 and next(entry.node.children)==nil)) then
          siblingNav.entries[#siblingNav.entries+1]={node=entry.node,path=state.path.." / "..entry.key,label=entry.key}
          siblingIndex[entry.node]=#siblingNav.entries
        end
      end
    end
    local pages=math.max(1,math.ceil(#list/74)); state.page=math.max(1,math.min(state.page,pages))
    local start=(state.page-1)*74+1; local last=math.min(#list,start+73)
    local count=last-start+1+(state.node and 1 or 0)
    state.rows=math.max(1,math.ceil(count/15)); api.LayoutRows(state.rows,state.node and 15 or 9)
    local lift=(state.rows-1)*140
    heading:SetAnchorsAndPosition(0,1,0,1,450,1470,782-lift,824-lift)
    subtitle:SetAnchorsAndPosition(0,1,0,1,120,1800,832-lift,872-lift)
    heading:setText(state.node and state.path:upper() or "CAMOS",0)
    if not state.pending then subtitle:setText("Camo changes are free. Click the equipped camo to remove it."..(pages>1 and "  "..state.page.." / "..pages or ""),0) end
    for i=start,last do
      local entry=list[i]
      if not state.node then
        local g=entry
        local groupIndex=i
        card(#tiles+1,count,g.name,g.tree.sample,function() openNode(g.tree,g.path,groupNav,groupIndex) end,true,g.icon)
      elseif entry.index then
        local index=entry.index
        card(#tiles+1,count,info(index).name,index,function() select(index) end,false)
      elseif not entry.node.pageSelector and #entry.node.items==1 and next(entry.node.children)==nil then
        local index=entry.node.items[1]
        card(#tiles+1,count,entry.key,index,function() select(index) end,false)
      else
        local child=entry.node; local path=state.path.." / "..entry.key
        card(#tiles+1,count,entry.key,child.sample,function() openNode(child,path,siblingNav,siblingIndex[child]) end,true)
      end
    end
    if state.node then card(#tiles+1,count,"BACK",nil,back,true) end
    for i,c in ipairs(tiles) do c.navigation={left=tiles[i-1],right=tiles[i+1],up=tiles[i-15],down=tiles[i+15]} end
    if pages>1 then
      local prev=pageButton("camo_prev","<",760,function() state.page=(state.page-2)%pages+1; render() end)
      local nextPage=pageButton("camo_next",">",1060,function() state.page=state.page%pages+1; render() end)
      prev.navigation={right=nextPage,up=tiles[#tiles]}; nextPage.navigation={left=prev,up=tiles[#tiles]}
      for _,c in ipairs(tiles) do if not c.navigation.down then c.navigation.down=prev end end
    end
    if tiles[1] then pcall(function() ACTIONS.GainFocus(panel,tiles[1].id,ci) end) end
    updateTabs()
    do end
  end
  showRoot=function() state.node=nil; state.path=nil; state.page=1; state.stack={}; state.nav=nil; state.navIndex=nil; render() end
  local responses={"Open Camos again.","Hold a weapon and reopen Camos.","Your held weapon changed. Reopen Camos.","This camo is unavailable.","Already equipped.","This camo could not be applied. Your weapon was restored."}
  local function poll()
    state.tick=state.tick+1
    if state.tabsDirty then updateTabs() end
    local reply=readReply()
    if reply and reply~=state.lastReply then
      local serial,mode,result,equipped,token=reply:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$")
      if serial then
        state.lastReply=reply; mode=tonumber(mode); result=tonumber(result)
        state.pending=false; state.ready=result==0 or result==4 or result==6; state.token=tonumber(token); state.equipped=tonumber(equipped); state.cooldown=state.tick+6
        for _,c in ipairs(tiles) do if c.index then c.chrome.update(nil,c.index==state.equipped,not info(c.index).valid) end end
        subtitle:setText(result==0 and (state.hoverSubtitle or "Camo changes are free. Click the equipped camo to remove it.") or responses[result] or "Camo request failed.",0)
        do end
      end
    end
    if state.pending and state.started and state.tick-state.started>160 then
      state.pending=false; state.ready=false
      subtitle:setText("Camo response timed out. Select Camos again to refresh.",0); do end
    end
  end
  local timer=LUI.UITimer.new({interval=50,event="recrud_camo_poll"}); e:addElement(timer)
  e:registerEventHandler("recrud_camo_poll",function() if state.alive then local ok,err=pcall(poll); if not ok then do end end end end)
  local function refresh()
    showRoot()
    state.pending=true; state.ready=false; state.started=state.tick; state.lastReply=readReply()
    subtitle:setText("Reading held weapon...",0); send(13,0)
  end
  local close=e.close
  e.close=function(self,...)
    state.alive=false; api.LayoutRows(1); send(13,1)
    return close(self,...)
  end
  rawset(_G,"RecrudCamosLive",{e=e,root=function() if not updatingTabs and (state.node or (not state.ready and not state.pending)) then refresh() end end})
  refresh()
  do end
  return e
end
