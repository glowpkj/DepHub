-- DepHub bindings only. All UI elements are created by the vendored Linoria library.
local env=type(getgenv)=="function" and getgenv() or _G
local Adapter={}
local function loadNative()
    local base=(env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
    local source=game:HttpGet(base.."library/linoria.lua?ui=0.1.0")
    local chunk,err=loadstring(source);assert(chunk,err)
    return chunk()
end
function Adapter.new(options)
    options=options or {}
    local previous=env.__DEPHUB_LINORIA
    if previous and type(previous.Destroy)=="function" then previous:Destroy(previous.Backend==options.Backend) end
    local native=loadNative()
    local self={Destroyed=false,Open=false,Pages={},Controls={},Connections={},Backend=options.Backend,Library=native,Index=0,Mode=options.Mode or options.Id}
    local ok,window=pcall(native.CreateWindow,native,(options.Title or "DEPHUB").." | "..tostring(options.Subtitle or self.Mode or ""))
    if not ok then native:Unload();error(window) end
    self.NativeWindow=window;self.ScreenGui=native.ScreenGui
    function self:Notify(title,message,duration)
        if not self.Destroyed then native:Notify(tostring(title)..": "..tostring(message or ""),duration or 4) end
    end
    function self:SafeCall(callback,...)
        if self.Destroyed then return false,"unloaded" end
        if type(callback)~="function" then return true end
        local success,result=pcall(callback,...)
        if not success or result==false then
            self:Notify("ERRO",success and "Operacao recusada." or tostring(result))
            return false,result
        end
        return true,result
    end
    local function key(text)
        self.Index=self.Index+1
        return tostring(self.Mode or "DepHub").."/"..self.Index.."/"..text
    end
    function self:CreateTab(name,label)
        name=tostring(name):upper()
        if self.Pages[name] then return self.Pages[name] end
        local page={Raw=window:AddTab(label or name),Count=0,Name=name}
        self.Pages[name]=page
        self.FirstPage=self.FirstPage or name
        return page
    end
    function self:OpenPage(name)
        local page=self.Pages[tostring(name):upper()] or self.Pages[self.FirstPage]
        if page then page.Raw:ShowTab();self.CurrentPage=page.Name end
    end
    function self:GetPage(name) return self.Pages[tostring(name):upper()] end
    function self:CreateSection(page,title)
        page=page or self:CreateTab("MAIN","Main")
        page.Count=page.Count+1
        local raw=page.Count%2==1 and page.Raw:AddLeftGroupbox(title) or page.Raw:AddRightGroupbox(title)
        return {Raw=raw,Page=page,Title=title}
    end
    local function section(value)
        if value then return value end
        if not self.CurrentSection then self.CurrentSection=self:CreateSection(self:CreateTab("MAIN","Main"),"Recursos") end
        return self.CurrentSection
    end
    local function bind(raw,info,kind)
        local control={Raw=raw,Muted=true,Accepted=raw.Value,Type=kind}
        function control:GetValue() return raw.Value end
        function control:Get() return raw.Value end
        function control:SetValue(value,silent)
            if self.Destroyed or self.Window.Destroyed then return false end
            if kind=="Slider" then
                value=tonumber(value)
                if not value or value~=value or math.abs(value)==math.huge then return false end
            elseif kind=="Toggle" then value=value==true
            elseif kind=="Dropdown" and value~=nil and not table.find(raw.Values,value) then return false end
            self.Muted=silent==true
            raw:SetValue(value)
            if silent then self.Accepted=raw.Value end
            self.Muted=false
            return kind~="Toggle" and true or raw.Value==value
        end
        function control:Set(value,fire) return self:SetValue(value,fire==false) end
        control.Window=self
        raw:OnChanged(function()
            if control.Muted or self.Destroyed then return end
            local success=self:SafeCall(info.Callback,raw.Value)
            if success then control.Accepted=raw.Value
            else
                control.Muted=true
                if kind=="Color" then raw:SetValueRGB(control.Accepted) else raw:SetValue(control.Accepted) end
                control.Muted=false
            end
        end)
        control.Muted=false
        self.Controls[info.Title or info.Text or tostring(self.Index)]=control
        return control
    end
    function self:CreateToggle(parent,info)
        parent=section(parent)
        return bind(parent.Raw:AddToggle(key(info.Title),{Text=info.Title,Default=info.Default==true,Tooltip=info.Description}),info,"Toggle")
    end
    function self:CreateSlider(parent,info)
        parent=section(parent)
        local decimals=0
        for _,value in ipairs({info.Step or 1,info.Min,info.Default or info.Min}) do
            local fraction=tostring(value):match("%.(%d+)");decimals=math.max(decimals,fraction and #fraction or 0)
        end
        return bind(parent.Raw:AddSlider(key(info.Title),{Text=info.Title,Default=tonumber(info.Default) or info.Min,Min=info.Min,Max=info.Max,Rounding=math.min(decimals,4)}),info,"Slider")
    end
    function self:CreateDropdown(parent,info)
        parent=section(parent)
        local values=info.Values or {}
        local raw=parent.Raw:AddDropdown(key(info.Title),{Text=info.Title,Values=values,Default=table.find(values,info.Default),Multi=false})
        local control=bind(raw,info,"Dropdown")
        function control:GetValues() return table.clone(raw.Values) end
        function control:SetValues(nextValues,selected,silent)
            if self.Window.Destroyed then return false end
            raw.Values=table.clone(nextValues)
            if not table.find(raw.Values,selected) then selected=raw.Values[1] end
            return self:SetValue(selected,silent)
        end
        return control
    end
    function self:CreateInput(parent,info)
        parent=section(parent)
        return bind(parent.Raw:AddInput(key(info.Title),{Text=info.Title,Default=info.Default or "",Placeholder=info.Placeholder,Finished=false}),info,"Input")
    end
    function self:CreateColor(parent,info)
        parent=section(parent)
        local id=key(info.Title)
        parent.Raw:AddLabel(info.Title):AddColorPicker(id,{Default=info.Default,Title=info.Title})
        local raw=native.Options[id]
        local control=bind(raw,info,"Color")
        function control:SetValue(value,silent)
            if self.Window.Destroyed then return false end
            self.Muted=silent==true;raw:SetValueRGB(value)
            if silent then self.Accepted=raw.Value end
            self.Muted=false;return true
        end
        return control
    end
    function self:CreateKeybind(parent,info)
        parent=section(parent)
        local id=key(info.Title)
        parent.Raw:AddLabel(info.Title):AddKeyPicker(id,{Default=info.Default and info.Default.Name or "RightControl",Mode="Toggle",Text=info.Title,NoUI=true})
        local raw=native.Options[id]
        window.CustomKeybind=true
        raw:OnClick(function()
            self:Toggle()
            self:SafeCall(info.Callback,Enum.KeyCode[raw.Value])
        end)
        return raw
    end
    function self:CreateButton(parent,info)
        parent=section(parent)
        local raw=parent.Raw:AddButton(info.Title,function()
            local success,message=self:SafeCall(info.Callback)
            if success and type(message)=="string" then self:Notify("DEPHUB",message) end
        end)
        local control={Raw=raw}
        function control:SetVisible(value) raw.Outer.Visible=value==true;parent.Raw:Resize() end
        self.Controls[info.Title]=control
        return control
    end
    function self:CreateLabel(parent,info)
        parent=section(parent)
        local raw=parent.Raw:AddLabel("")
        raw.TextLabel.TextWrapped=true
        raw.TextLabel.TextYAlignment=Enum.TextYAlignment.Top
        local control={Raw=raw,Text=""}
        function control:Set(text)
            if self.Window.Destroyed then return false end
            text=tostring(text or "");self.Text=text
            local lines=0
            for line in (text.."\n"):gmatch("(.-)\n") do lines=lines+math.max(1,math.ceil(#line/32)) end
            raw.TextLabel.Text=text
            raw.TextLabel.Size=UDim2.new(1,-4,0,math.max(15,lines*15))
            parent.Raw:Resize();return true
        end
        control.Window=self
        control:Set((info.Title and info.Title.."\n" or "")..tostring(info.Text or ""))
        return control
    end
    function self:AddSection(text)
        self.CurrentSection=self:CreateSection(self:CreateTab("MAIN",options.Subtitle or "Main"),text)
        return self.CurrentSection
    end
    function self:AddToggle(text,value,callback,parent) return self:CreateToggle(parent,{Title=text,Default=value,Callback=callback}) end
    function self:AddFeature(text,value,callback) return self:AddToggle(text,value,callback),section() end
    function self:AddSlider(text,min,max,step,value,callback,parent) return self:CreateSlider(parent,{Title=text,Min=min,Max=max,Step=step,Default=value,Callback=callback}) end
    function self:AddButton(text,callback,parent) return self:CreateButton(parent,{Title=text,Callback=callback}) end
    function self:AddStatus(title,parent) return self:CreateLabel(parent,{Title=title,Text=""}) end
    function self:SetOpen(value)
        if self.Destroyed then return false end
        self.Open=value==true;window:SetVisible(self.Open);return true
    end
    function self:IsOpen() return window.Holder.Visible end
    function self:Toggle() self:SetOpen(not self:IsOpen()) end
    function self:SetToggleKey(value) window.ToggleKey=value end
    function self:Destroy(preserveBackend)
        if self.Destroyed then return end
        self.Destroyed=true
        for _,connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
        self.Connections={}
        native:Unload()
        if not preserveBackend and self.Backend and type(self.Backend.Destroy)=="function" then pcall(self.Backend.Destroy,self.Backend) end
        if env.__DEPHUB_LINORIA==self then env.__DEPHUB_LINORIA=nil end
        if env.__DEPHUB_FRONTEND==self then env.__DEPHUB_FRONTEND=nil end
        if env.__DEPHUB and env.__DEPHUB.Frontend==self then env.__DEPHUB.Frontend=nil end
    end
    native:OnUnload(function() if not self.Destroyed then self:Destroy() end end)
    env.__DEPHUB_LINORIA=self
    local initialized,reason=pcall(function()
        if not options.Mode then
            self:CreateTab("MAIN",options.Subtitle or "Main")
            local menu=self:CreateSection(self:CreateTab("MENU","Menu"),"Interface")
            self:CreateKeybind(menu,{Title="Abrir / fechar",Default=Enum.KeyCode.RightControl})
            self:CreateButton(menu,{Title="Descarregar DepHub",Callback=function() self:Destroy() end})
        end
        self:SetOpen(options.Open~=false)
    end)
    if not initialized then self:Destroy();error(reason) end
    return self
end
return Adapter
