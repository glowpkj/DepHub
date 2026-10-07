local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Teams=game:GetService("Teams")

local AutoTeam={}
AutoTeam.__index=AutoTeam

function AutoTeam.new()
    local events=ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage:WaitForChild("Events",8)
    local remote=events and (events:FindFirstChild("SelectTeam") or events:WaitForChild("SelectTeam",8))
    assert(remote and remote:IsA("RemoteEvent"),"Noob Piece: Events/SelectTeam unavailable")
    local self=setmetatable({
        Player=Players.LocalPlayer,
        Remote=remote,
        Enabled=false,
        Selected="Noob",
        Connections={}
    },AutoTeam)

    self.Connections[#self.Connections+1]=self.Player.CharacterAdded:Connect(function()
        if self.Enabled then
            task.defer(function()
                self:Apply()
            end)
        end
    end)

    return self
end

function AutoTeam:GetTeams()
    local values={}
    local seen={}

    for _,team in ipairs(Teams:GetChildren()) do
        if team:IsA("Team") and not seen[team.Name] then
            seen[team.Name]=true
            values[#values+1]=team.Name
        end
    end

    if not seen.Noob then
        values[#values+1]="Noob"
    end

    table.sort(values)
    return values
end

function AutoTeam:SetSelected(name)
    if type(name)~="string" or name=="" then
        return false
    end

    self.Selected=name

    if self.Enabled then
        self:Apply()
    end

    return true
end

function AutoTeam:Apply()
    if not self.Enabled then return false end
    self.Remote:FireServer(self.Selected)
    return true
end

function AutoTeam:SetEnabled(enabled)
    self.Enabled=enabled==true

    if self.Enabled then
        self:Apply()
    end
end

function AutoTeam:Destroy()
    self.Enabled=false

    for _,connection in ipairs(self.Connections) do
        pcall(connection.Disconnect,connection)
    end

    table.clear(self.Connections)
end

return AutoTeam

