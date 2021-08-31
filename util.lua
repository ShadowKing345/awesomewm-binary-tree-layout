------------------------------------------------------------------------------------------
--
-- Library of utility functions used.
--
------------------------------------------------------------------------------------------

local random = math.random
local util = {}

-- #region Array Helper Method.
-- Original credit goes to https://github.com/EvandroLG/array.lua for providing array util methods. Thanks EvandrolLG.
-- Also they are here cause I only needed one method table_diff and awesome lua compiler could not see them when installed through lua rocks.
function util.convertToHash(obj)
    local output = {}

    for i = 1, #obj do
        local value = obj[i]
        output[value] = true
    end

    return output
end

function util.tableDiff(obj1, obj2)
    local output = {}
    local hash = util.convertToHash(obj2)

    for i = 1, #obj1 do
        local value = obj1[i]

        if not hash[value] then table.insert(output, value) end
    end

    return output
end
-- #endregion

--[[
    Retuns the index difference of two arrays.
    Basically you can use what is returned as an index to see what is different in the two arrays.
    Note this does not deal with keys just indexes.

    @param tbl1: First Table.
    @param tbl2: Second Table.
    @return Table: object with the indexes that were different.
]]
function util.tableDiffIndex(tbl1, tbl2)
    local indexes = {}
    local r = {}
    for i, v in ipairs(tbl1) do r[i] = v == tbl2[i] end
    for i, v in ipairs(r) do if not v then table.insert(indexes, i) end end

    return indexes
end

--[[
    Simple clamp function (probably better way to do it ngl).

    @param v: Value to be clamped
    @param min: Min value to be set to if less then.
    @param max: Max value to be set to if more then.
    @return: Clamp value.
]]
function util.clamp(v, min, max)
    v = math.max(v, min)
    v = math.min(v, max)
    return v
end

--[[
    Generates a uui. Note sure if this is specification approved however.

    @return: UUID string.
]]
function util.uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

--[[
    Makes a shallow copy of the table. I.E. References in children are kept instead of new obj being created.

    @param tbl: Table to be copied.
    @return: Copied table.
]]
function util.shallowCopy(tbl)
    local result = {}
    for k, v in pairs(tbl) do
        result[k] = v
    end

    for i, v in ipairs(tbl) do
        result[i] = v
    end

    return result
end

return util
