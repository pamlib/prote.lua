--//                                  Prote API                                       \\--
--// Protect Instances, Spoof Instances, and Spoof Properties with incredible accuracy \\--

local Prote = {}

local spec = {
    getrawmt = (debug and debug.getmetatable) or getrawmetatable;
    getcons = getconnections or get_signal_cons;
    getnamecall = getnamecallmethod or get_namecall_method;
    makereadonly = setreadonly or (make_writeable and function(table, readonly) if readonly then make_readonly(table) else make_writeable(table) end end);
    newclose = newcclosure or protect_function or function(f) return f end;
}

local tblmap = function(tbl, ret)
    if tbl == nil then return end
    if type(tbl) == "table" then
        local new = {}
        for i, v in next, tbl do
            table.insert(new, #new + 1, ret(i, v))
        end
        return new
    end
end

local tblfilter = function(tbl, ret)
    if tbl == nil then return end
    if type(tbl) == "table" then
        local new = {}
        for i, v in next, tbl do
            if ret(i, v) then
                table.insert(new, #new + 1, v)
            end
        end
        return new
    end
end

local ProtectedInstances = {}
local SpoofedInstances = {}
local SpoofedProperties = {}
local Methods = {
    "FindFirstChild",
    "FindFirstChildWhichIsA",
    "FindFirstChildOfClass",
    "IsA"
}
local AllowedIndexes = {
    "RootPart",
    "Parent"
}
local AllowedNewIndexes = {
    "Jump"
}

local mt = spec.getrawmt(game)
local OldMetaMethods = {}

spec.makereadonly(mt, false)

for i, v in next, mt do
    OldMetaMethods[i] = v
end

local __Namecall = OldMetaMethods.__namecall
local __Index = OldMetaMethods.__index
local __NewIndex = OldMetaMethods.__newindex

mt.__namecall = spec.newclose(function(self, ...)
    if (checkcaller()) then
        return __Namecall(self, ...)
    end
    
    local Method = spec.getnamecall():gsub("%z", function(x)
        return x
    end):gsub("%z", "")

    local Protected = ProtectedInstances[self]

    if (Protected) then
        if table.find(Methods, Method) then
            return Method == "IsA" and false or nil
        end
    end

    if (Method == "GetChildren" or Method == "GetDescendants") then
        return tblfilter(__Namecall(self, ...), function(i, v)
            return not table.find(ProtectedInstances, v)
        end)
    end

    if (Method == "GetFocusedTextBox") then
        if (table.find(ProtectedInstances, __Namecall(self, ...))) then
            return nil
        end
    end

    return __Namecall(self, ...)
end)

mt.__index = spec.newclose(function(Instance_, Index)
    if (checkcaller()) then
        return __Index(Instance_, Index)
    end

    Index = type(Index) == "string" and Index:gsub("%z", function(x)
        return x
    end):gsub("%z", "") or Index
    
    local ProtectedInstance = ProtectedInstances[Instance_]
    local SpoofedInstance = SpoofedInstances[Instance_]
    local SpoofedPropertiesForInstance = SpoofedProperties[Instance_]

    if (SpoofedInstance) then
        if (table.find(AllowedIndexes, Index)) then
            return __Index(Instance_, Index)
        end
        if (Instance_:IsA("Humanoid") and game.PlaceId == 6650331930) then
            for i, v in next, spec.getcons(Instance_:GetPropertyChangedSignal("WalkSpeed")) do
                v:Disable()
            end
        end
        return __Index(SpoofedInstance, Index)
    end

    if (SpoofedPropertiesForInstance) then
        for i, SpoofedProperty in next, SpoofedPropertiesForInstance do
            if (Index == SpoofedProperty.Property) then
                return SpoofedProperty.Value
            end
        end
    end

    if (ProtectedInstance) then
        if (table.find(Methods, Index)) then
            return function()
                return Index == "IsA" and false or nil
            end
        end
    end

    if (Index == "GetChildren" or Index == "GetDescendants") then
        return function()
            return tblfilter(__Index(Instance_, Index)(Instance_), function(i, v)
                return not table.find(ProtectedInstances, v)
            end)
        end
    end

    if (Index == "GetFocusedTextBox") then
        if (table.find(ProtectedInstances, __Index(Instance_, Index)(Instance_))) then
            return function()
                return nil
            end
        end
    end

    return __Index(Instance_, Index)
end)

mt.__newindex = spec.newclose(function(Instance_, Index, Value)
    if (checkcaller()) then
        return __NewIndex(Instance_, Index, Value)
    end

    local SpoofedInstance = SpoofedInstances[Instance_]
    local SpoofedPropertiesForInstance = SpoofedProperties[Instance_]

    if (SpoofedInstance) then
        if (table.find(AllowedNewIndexes, Index)) then
            return __NewIndex(Instance_, Index, Value)
        end
        return __NewIndex(SpoofedInstance, Index, SpoofedInstance[Index])
    end

    if (SpoofedPropertiesForInstance) then
        for i, SpoofedProperty in next, SpoofedPropertiesForInstance do
            if (SpoofedProperty.Property == Index) then
                return Instance_[Index]
            end
        end
    end

    return __NewIndex(Instance_, Index, Value)
end)

spec.makereadonly(mt, true)

for i, v in next, spec.getcons(game:GetService("UserInputService").TextBoxFocused) do
    v:Disable()
end
for i, v in next, spec.getcons(game:GetService("UserInputService").TextBoxFocusReleased) do
    v:Disable()
end

Prote.ProtectInstance = function(Instance_, disallow)
    if (not ProtectedInstances[Instance_]) then
        ProtectedInstances[#ProtectedInstances + 1] = Instance_
        if (syn and syn.protect_gui and not disallow) then
            syn.protect_gui(Instance_)
        end
    end
end

Prote.SpoofInstance = function(Instance_, Instance2)
    if (not SpoofedInstances[Instance_]) then
        SpoofedInstances[Instance_] = Instance2 and Instance2 or Instance_:Clone()
    end
end

Prote.SpoofProperty = function(Instance_, Property, Value)
    for i, v in next, spec.getcons(Instance_:GetPropertyChangedSignal(Property)) do
        v:Disable()
    end
    if (SpoofedProperties[Instance_]) then
        local Properties = tblmap(SpoofedProperties[Instance_], function(i, v)
            return v.Property
        end)
        if (not table.find(Properties, Property)) then
            table.insert(SpoofedProperties[Instance_], {
                Property = Property,
                Value = Value and Value or Instance_[Property]
            })
        end
        return
    end
    SpoofedProperties[Instance_] = {{
        Property = Property,
        Value = Value and Value or Instance_[Property]
    }}
end

return Prote
