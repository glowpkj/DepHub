local Factory={}
function Factory.new(context)
    local self={Enabled=false,Destroyed=false,Part=nil,Highlight=nil,Label=nil,Billboard=nil}
    function self:Clear()
        if self.Highlight then self.Highlight:Destroy() end
        if self.Billboard then self.Billboard:Destroy() end
        self.Highlight=nil self.Billboard=nil self.Label=nil self.Part=nil
    end
    function self:SetEnabled(value)
        if self.Destroyed then return false end
        self.Enabled=value==true if not self.Enabled then self:Clear() end return true
    end
    function self:Update(candidate,reference)
        local part=candidate and candidate.Part
        if not self.Enabled or not part or not part.Parent then self:Clear() return end
        if self.Part~=part then
            self:Clear() self.Part=part
            local highlight=Instance.new("Highlight") highlight.Name="DepHubBallHighlight"
            highlight.Adornee=part highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor=Color3.fromRGB(255,195,65) highlight.OutlineColor=Color3.fromRGB(255,255,255)
            highlight.FillTransparency=0.45 highlight.OutlineTransparency=0 highlight.Parent=context.Workspace self.Highlight=highlight
            local gui=Instance.new("BillboardGui") gui.Name="DepHubBallLabel" gui.Adornee=part
            gui.Size=UDim2.fromOffset(150,32) gui.StudsOffsetWorldSpace=Vector3.new(0,2,0)
            gui.AlwaysOnTop=true gui.MaxDistance=2000 gui.Parent=context.Workspace self.Billboard=gui
            local label=Instance.new("TextLabel") label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=1
            label.TextColor3=Color3.fromRGB(255,220,115) label.TextStrokeTransparency=0.25
            label.Font=Enum.Font.GothamBold label.TextSize=15 label.Parent=gui self.Label=label
        end
        self.Label.Text=reference and string.format("BALL  •  %.0f studs",(part.Position-reference).Magnitude) or "BALL"
    end
    function self:Destroy() if self.Destroyed then return end self.Enabled=false self:Clear(); self.Destroyed=true end
    return self
end
return Factory
