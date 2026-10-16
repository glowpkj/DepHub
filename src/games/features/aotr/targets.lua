local Module={}
local function path(root,...)
    for _,name in ipairs({...}) do root=root and root:FindFirstChild(name) end
    return root
end
Module.Path=path
function Module.Alive(character)
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=path(character,"HumanoidRootPart")
    if not humanoid or humanoid.Health<=0 or not root or not root:IsA("BasePart") then return nil end
    return root,humanoid
end
function Module.Marker(model)
    local marker=path(model,"Marker")
    local hit=path(model,"Hitboxes","Hit")
    if not marker or not hit then return nil end
    local ok,part=pcall(function() return marker.Adornee end)
    if ok and part and part:IsA("BasePart") and part:IsDescendantOf(hit) then return part end
    return nil
end
function Module.Select(workspace,root)
    local folder=path(workspace,"Titans")
    if not folder or not root then return nil,"Waiting: Titans / character" end
    local best,distance=nil,math.huge
    for _,model in ipairs(folder:GetChildren()) do
        local humanoid=model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health>0 then
            -- A boss with no active marker must not fall back to an arbitrary weakpoint.
            local part=model.Name=="Attack_Titan" and Module.Marker(model) or nil
            if model.Name~="Attack_Titan" then part=path(model,"Hitboxes","Hit","Nape") end
            if part and part:IsA("BasePart") then
                local d=(root.Position-part.Position).Magnitude
                if d<distance then best,distance={Model=model,Part=part,Boss=model.Name=="Attack_Titan"},d end
            end
        end
    end
    return best,best and distance or "Waiting: live target / boss marker"
end
return Module
