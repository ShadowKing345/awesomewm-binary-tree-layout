local random = math.random

local tree = {}
tree.__index = tree

local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function tree.new(data, left, right, parent)
    local node = {data = data, left = left, right = right, parent = parent, split = 0.5, is_vertical = false, id = uuid()}
    return setmetatable(node, tree)
end

function tree:addLeft(child)
    if self ~= nil then
        self.left = child
	child.parent=self
        return self.left
    end
end

function tree:addRight(child)
    if self ~= nil then
        self.right = child
	child.parent=self
        return self.right
    end
end

function tree:removeLeaf(client)
    if self.left then
        if self.left.data == client then
            local newSelf = {data = self.right.data, left = self.right.left, right = self.right.right, is_vertical = self.right.is_vertical}
            self.data = newSelf.data
            self.left = newSelf.left
            self.right = newSelf.right
            self.is_vertical = newSelf.is_vertical
        else
            self.left:removeLeaf(client)
        end
    end
    if self.right then
        if self.right.data == client then
            local newSelf = {data = self.left.data, left = self.left.left, right = self.left.right, is_vertical = self.left.is_vertical}
            self.data = newSelf.data
            self.left = newSelf.left
            self.right = newSelf.right
            self.is_vertical = newSelf.is_vertical
        else
            self.right:removeLeaf(client)
        end
    end
    if not self.right and not self.left then if self.data == client then self.data = nil end end
end

function tree:find(client)
    if self:is_leaf() then
        return self.data == client and self or nil
    else
        local obj = nil
        if self.left then obj = self.left:find(client) end
        if self.right then obj = obj or self.right:find(client) or nil end
        return obj
    end
end

function tree:is_leaf()
    return self.data
end

function tree.print(node, level, path)
    level = level or 0
    path = path or ""

    if type(node) == "table" then
        print(string.rep(" ", level) .. path .. "Node:")
        for k, v in pairs(node) do
            if k ~= "left" and k ~= "right" then print(string.rep(" ", level + 1) .. tostring(k) .. ": " .. tostring(v)) end
        end
        if node.left ~= nil and type(node.left) == "table" then tree.print(node.left, level + 1, "L_") end
        if node.right ~= nil and type(node.right) == "table" then tree.print(node.right, level + 1, "R_") end
    end
end

return tree
