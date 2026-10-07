local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local HttpService=game:GetService("HttpService")
local player=Players.LocalPlayer
local env=type(getgenv)=="function" and getgenv() or _G

local probes={
    BloxFruits={{"ReplicatedStorage","Remotes","CommF_"},{"ReplicatedStorage","Remotes","ChangeSetting"},{"Workspace","Characters"}},
    RT3={{"Workspace","Tycoons"},{"Workspace","DropFolder"},{"ReplicatedStorage","Events","Cook","CookInputRequested"},{"ReplicatedStorage","Events","Cook","CookUpdated"}},
    NoobPiece={{"ReplicatedStorage","Events","PlayerAttack"},{"ReplicatedStorage","Events","SelectTeam"},{"ReplicatedStorage","Events","NpcInteract"},{"ReplicatedStorage","Events","OpenDialog"},{"ReplicatedStorage","Events","DialogChoice"},{"ReplicatedStorage","Events","QuestUpdate"}},
    TSB={{"Workspace","Live"},{"Character","Communicate"}}
}
local routes={
    [73956553001240]="VolleyballLegends",[6931042565]="VolleyballLegends",
    [994732206]="BloxFruits",[85211729168715]="BloxFruits",
    [119048529960596]="RT3",[84822469255086]="NoobPiece",
    [10449761463]="TSB",[3808081382]="TSB",
    [142823291]="MM2",[66654135]="MM2",
    [93978595733734]="ViolenceDistrict",[6739698191]="ViolenceDistrict"
}
local character=player and player.Character
local roots={ReplicatedStorage=ReplicatedStorage,Workspace=Workspace,Character=character}
local mode=routes[game.PlaceId] or routes[game.GameId] or "Universal"
local report={
    Schema=1,Mode=mode,PlaceId=game.PlaceId,GameId=game.GameId,
    Timestamp=DateTime.now():ToIsoDate(),
    Character=character~=nil,Humanoid=character and character:FindFirstChildOfClass("Humanoid")~=nil or false,
    Root=character and character:FindFirstChild("HumanoidRootPart")~=nil or false,
    LoaderVersion=env.__DEPHUB and env.__DEPHUB.Version or "not loaded",
    LoaderStatus=env.__DEPHUB_LOADER_STATE and env.__DEPHUB_LOADER_STATE.status or "not loaded",
    Dependencies={},Capabilities={Loadstring=type(loadstring)=="function",Clipboard=type(setclipboard)=="function",Touch=type(firetouchinterest)=="function",Prompt=type(fireproximityprompt)=="function"}
}
for _,segments in ipairs(probes[mode] or {}) do
    local object=roots[segments[1]]
    for index=2,#segments do object=object and object:FindFirstChild(segments[index]) end
    report.Dependencies[#report.Dependencies+1]={Path=table.concat(segments,"/"),Present=object~=nil,Class=object and object.ClassName or "missing"}
end
local backend=env.__DEPHUB and (env.__DEPHUB[mode] or mode=="RT3" and env.__DEPHUB.Runtime)
if type(backend)=="table" then
    report.BackendVersion=backend.Version or "unversioned"
    report.BackendDestroyed=backend.Destroyed==true
end
if mode=="VolleyballLegends" then
    report.ClientBalls={}
    for _,object in ipairs(Workspace:GetChildren()) do
        if object.Name:sub(1,12)=="CLIENT_BALL_" then
            local parts={}
            for _,part in ipairs(object:GetDescendants()) do
                if part.Name=="Cube.001" then parts[#parts+1]={Class=part.ClassName,BasePart=part:IsA("BasePart")} end
            end
            report.ClientBalls[#report.ClientBalls+1]={Name=object.Name,Parts=parts}
        end
    end
    if type(backend)=="table" and type(backend.GetDebugInfo)=="function" then report.BallTracking=backend:GetDebugInfo() end
end
local output=HttpService:JSONEncode(report)
print("[DepHub compatibility] "..output)
if type(setclipboard)=="function" then
    local copied=pcall(setclipboard,output)
    print(copied and "Diagnostico copiado." or "Copie a linha de diagnostico do console.")
end
return report
