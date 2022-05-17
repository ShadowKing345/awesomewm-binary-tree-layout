--[[

    Binary Tree.

--]]
--------------------------------------------------
local gTable = require "gears.table"

local relPath = (...):match "(.*).binaryTree"
---@type Node
local node = require(relPath .. ".binaryTreeNode")

--------------------------------------------------
---@class Tree
local M = {
    root    = nil,
    clients = {},
    mt      = {},
}

---Returns the node based on the data provided.
---@param data any
---@return Node|nil
function M:find(data)
    if self.root then
        return self.root:find(data)
    end
    return nil
end

---Removes a node with the given data.
---@param data any
function M:remove(data)
    local n = self.root:find(data)

    if not n then
        return
    end

    if n == self.root then
        n.data = nil
        return
    end

    local parent = n.parent
    if not parent then
        print "How did you just remove a node without a parent that is not root?"
        return
    end

    local isLeft = parent.left.data == data

    print(isLeft)

    local n2 = isLeft and parent.right or parent.left

    if not n2 then
        return
    end

    parent.left = n2.left
    parent.right = n2.right
    parent.data = n2.data
    parent.isVertical = n2.isVertical

end

---Creates a new tree instance.
---@param args any
---@return Tree
function M:new(args)
    args = args or {}

    ---@type Tree
    local tree = {
        root    = args.root or node(),
        clients = args.clients or {},
    }
    gTable.crush(tree, self)

    return tree
end

---Creates a new node
---@param ... unknown
---@return Node
function M.newNode(...)
    return node(...)
end

--------------------------------------------------
function M.mt:__call(...)
    return M:new(...)
end

return setmetatable(M, M.mt)
--------------------------------------------------
---@class Tree #The tree class.
---@field root Node #The root node.
---@field clients any[] #A collection of the clients.
