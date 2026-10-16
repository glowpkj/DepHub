-- Property layers prevent one feature from restoring over another feature.
local Module = {}
function Module.new(warnError)
    local self = {Records={}, Layers={}}
    local function write(object, key, value)
        local ok, err = pcall(function() object[key]=value end)
        if not ok and warnError then warnError("restore "..key..": "..tostring(err)) end
    end
    function self:Original(object, key)
        local record=self.Records[object]
        return record and record[key] and record[key].Value or object[key]
    end
    function self:Refresh()
        for object, record in pairs(self.Records) do
            for key, saved in pairs(record) do
                local value, priority, claimed=nil,-math.huge,false
                for _, layer in pairs(self.Layers) do
                    local values=layer.Values[object]
                    if values and values[key]~=nil and layer.Priority>priority then
                        value,priority,claimed=values[key],layer.Priority,true
                    end
                end
                if claimed then write(object,key,value)
                else
                    local restored=saved.Value
                    if saved.Restore then
                        local ok, result=pcall(saved.Restore)
                        if ok and result~=nil then restored=result end
                    end
                    write(object,key,restored)
                    record[key]=nil
                end
            end
            if next(record)==nil then self.Records[object]=nil end
        end
    end
    function self:Set(owner, values, priority, restorers)
        for object, properties in pairs(values) do
            local record=self.Records[object] or {};self.Records[object]=record
            for key in pairs(properties) do
                if not record[key] then
                    record[key]={Value=object[key],Restore=restorers and restorers[object] and restorers[object][key]}
                end
            end
        end
        self.Layers[owner]={Values=values,Priority=priority or 0}
        self:Refresh()
    end
    function self:Clear(owner) self.Layers[owner]=nil;self:Refresh() end
    function self:Destroy() self.Layers={};self:Refresh() end
    return self
end
return Module
