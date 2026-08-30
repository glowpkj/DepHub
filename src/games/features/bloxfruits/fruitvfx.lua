-- Local, on-demand cosmetic edits. No polling, remote calls or anti-cheat hooks.
local Feature = {}
Feature.__index = Feature

local rawPalettes = {
    Red = {{255,0,0},{255,70,70},{200,0,0},{255,140,140},{150,0,0},{255,40,40},{220,20,20}},
    Orange = {{255,90,0},{255,140,40},{220,70,0},{255,190,100},{170,50,0},{255,110,20},{230,80,10}},
    Yellow = {{255,220,0},{255,240,80},{220,180,0},{255,250,150},{170,140,0},{255,210,40},{230,190,20}},
    Green = {{0,255,80},{70,255,130},{0,200,60},{140,255,175},{0,150,45},{40,255,100},{20,220,80}},
    Cyan = {{0,230,255},{80,245,255},{0,185,220},{140,250,255},{0,140,180},{30,220,255},{20,200,230}},
    Blue = {{0,100,255},{80,150,255},{0,70,210},{140,190,255},{0,50,160},{40,120,255},{20,90,220}},
    Purple = {{140,0,255},{185,80,255},{100,0,210},{215,140,255},{80,0,160},{160,40,255},{125,20,220}},
    Pink = {{255,0,170},{255,80,195},{210,0,135},{255,140,215},{160,0,105},{255,40,180},{220,20,150}},
    White = {{255,255,255},{235,235,255},{210,210,230},{255,255,255},{180,180,200},{245,245,255},{220,220,240}},
    Black = {{25,25,25},{50,50,50},{10,10,10},{80,80,80},{5,5,5},{35,35,35},{15,15,15}}
}
local palettes = {}
for name, values in pairs(rawPalettes) do
    palettes[name] = {}
    for index, rgb in ipairs(values) do palettes[name][index] = Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end
end
local presetOrder = {"Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "Pink", "White", "Black"}
local labels = {Red="Vermelho", Orange="Laranja", Yellow="Amarelo", Green="Verde", Cyan="Ciano", Blue="Azul", Purple="Roxo", Pink="Rosa", White="Branco", Black="Preto"}
local ids = {}
for id, name in pairs(labels) do ids[name] = id end

-- Register additional fruits with their own folders, palette list and slot rules.
local fruits = {
    Rumble = {
        Folder = "LightningFruitVFXColor",
        Palettes = palettes,
        PresetOrder = presetOrder,
        Forms = {
            Default = {Prefix = "Default_Color", ExistingOnly = true},
            Shifted = {Prefix = "Shifted_Color", Slots = 7}
        }
    }
}
local ORIGINAL = "Original (cor/skin anterior)"
local formIds = {["Normal (Default)"]="Default", ["Transformada (Shifted)"]="Shifted", Ambas="Both"}

local function empty(value) return next(value) == nil end

function Feature.new(context)
    return setmetatable({Player = context.LocalPlayer, Records = {}, Destroyed = false, Busy = false}, Feature)
end

function Feature:GetFruits()
    local names = {}
    for name in pairs(fruits) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function Feature:GetColors(fruit)
    local definition = fruits[fruit]
    if not definition then return {} end
    local names = {ORIGINAL}
    for _, id in ipairs(definition.PresetOrder) do names[#names + 1] = labels[id] or id end
    return names
end

function Feature:_prune()
    for object, record in pairs(self.Records) do
        if not object:IsDescendantOf(self.Player) or empty(record.Owned) then self.Records[object] = nil end
    end
end

function Feature:_resolve(fruit, form)
    local definition = fruits[fruit]
    if not definition then return nil, "Fruta não cadastrada." end
    local forms = form == "Both" and {"Default", "Shifted"} or {form}
    local root = self.Player and self.Player:FindFirstChild(definition.Folder)
    if not root then return nil, "Dados da Rumble ausentes. Equipe/carregue a fruta e tente novamente." end
    local targets = {}
    for _, name in ipairs(forms) do
        local rule = definition.Forms[name]
        if not rule then return nil, "Forma inválida." end
        local object = root:FindFirstChild(name)
        if not object then return nil, "Pasta " .. name .. " ausente. Selecione apenas a forma disponível." end
        local ok, attributes = pcall(object.GetAttributes, object)
        if not ok then return nil, "Não foi possível ler os atributos de " .. name .. "." end
        targets[#targets + 1] = {Object = object, Attributes = attributes, Rule = rule, Form = name}
    end
    return targets
end

-- Before/after journaling makes both applying and restoring reversible on failure.
function Feature:_commit(changes)
    local completed = {}
    for _, change in ipairs(changes) do
        local ok = pcall(function()
            if change.Object:GetAttribute(change.Key) ~= change.Before then error("Attribute changed externally") end
            change.Object:SetAttribute(change.Key, change.After)
        end)
        if not ok then
            local rolledBack = true
            for index = #completed, 1, -1 do
                local previous = completed[index]
                local restored = pcall(function()
                    if previous.Object:GetAttribute(previous.Key) ~= previous.After then error("Attribute changed externally") end
                    previous.Object:SetAttribute(previous.Key, previous.Before)
                end)
                if restored then previous.Record.Owned[previous.Key] = previous.PreviousOwned else rolledBack = false end
            end
            return false, rolledBack and "Não foi possível aplicar. As alterações desta tentativa foram desfeitas." or "Falha parcial. Use Restaurar antes de tentar novamente."
        end
        change.PreviousOwned = change.Record.Owned[change.Key]
        if change.Restore then change.Record.Owned[change.Key] = nil else change.Record.Owned[change.Key] = change.After end
        completed[#completed + 1] = change
    end
    return true, #completed
end

function Feature:Apply(fruit, color, form)
    if self.Destroyed then return false, "Módulo encerrado." end
    if self.Busy then return false, "Aguarde a operação atual." end
    form = formIds[form] or form or "Default"
    if color == ORIGINAL or color == "Original" then return self:Restore(fruit, form) end
    local definition = fruits[fruit]
    local palette = definition and definition.Palettes[ids[color] or color]
    if not palette then return false, "Cor ou fruta não cadastrada." end
    self:_prune()
    local targets, reason = self:_resolve(fruit, form)
    if not targets then return false, reason end
    local changes = {}
    for _, target in ipairs(targets) do
        local object, attributes, rule = target.Object, target.Attributes, target.Rule
        local record = self.Records[object] or {Original = table.clone(attributes), Owned = {}, Fruit = fruit, Form = target.Form}
        for key, applied in pairs(record.Owned) do
            if attributes[key] ~= applied then return false, "As cores mudaram fora do módulo. Use Restaurar para liberar o estado anterior e tente novamente." end
        end
        local slots = {}
        if rule.ExistingOnly then
            for key, value in pairs(attributes) do
                local index = tonumber(key:match("^" .. rule.Prefix .. "(%d+)$"))
                if index then
                    if not palette[index] or typeof(value) ~= "Color3" then return false, "Formato de cores do Default incompatível; nenhum atributo foi alterado." end
                    slots[#slots + 1] = index
                end
            end
            table.sort(slots)
            if #slots == 0 then return false, "Nenhuma cor original encontrada em Default; não vou inventar valores." end
        else
            for index = 1, rule.Slots do slots[#slots + 1] = index end
        end
        for _, index in ipairs(slots) do
            local key = rule.Prefix .. index
            local current = attributes[key]
            if current ~= nil and typeof(current) ~= "Color3" then return false, "Atributo de cor com tipo incompatível: " .. key end
            if current ~= palette[index] then
                changes[#changes + 1] = {Object = object, Key = key, Before = current, After = palette[index], Record = record}
            end
        end
    end
    self.Busy = true
    for _, change in ipairs(changes) do self.Records[change.Object] = change.Record end
    local ok, result = self:_commit(changes)
    self.Busy = false
    self:_prune()
    if not ok then return false, result end
    return true, result == 0 and "Essa paleta já está aplicada." or "Paleta aplicada localmente. A aparência anterior foi preservada."
end

function Feature:Restore(fruit, form)
    if self.Busy then return false, "Aguarde a operação atual." end
    form = formIds[form] or form or "Both"
    if fruit and not fruits[fruit] then return false, "Fruta não cadastrada." end
    if form ~= "Both" and form ~= "Default" and form ~= "Shifted" then return false, "Forma inválida." end
    self:_prune()
    local changes, released, skipped = {}, {}, 0
    for object, record in pairs(self.Records) do
        if (not fruit or record.Fruit == fruit) and (form == "Both" or record.Form == form) then
            local ok, attributes = pcall(object.GetAttributes, object)
            if not ok then return false, "Não foi possível ler o estado para restaurar. Tente novamente." end
            for key, applied in pairs(record.Owned) do
                local original, current = record.Original[key], attributes[key]
                if current == applied and current ~= original then
                    changes[#changes + 1] = {Object = object, Key = key, Before = current, After = original, Record = record, Restore = true}
                else
                    -- Preserve updates made by the game/another script instead of fighting them.
                    released[#released + 1] = {Record = record, Key = key}
                    if current ~= original then skipped += 1 end
                end
            end
        end
    end
    self.Busy = true
    local ok, result = self:_commit(changes)
    self.Busy = false
    if not ok then return false, result end
    for _, item in ipairs(released) do item.Record.Owned[item.Key] = nil end
    self:_prune()
    if skipped > 0 then return true, "Restaurado o que ainda pertencia ao módulo; cores alteradas pelo jogo foram preservadas.", "Warning" end
    return true, result == 0 and "Nenhuma alteração local pendente para restaurar." or "Cor/skin anterior restaurada; atributos criados pelo módulo foram removidos."
end

function Feature:Destroy()
    if self.Destroyed then return end
    local ok, reason = self:Restore(nil, "Both")
    if not ok then return false, reason end
    self.Destroyed = true
    self.Records = {}
    return true
end

return Feature
