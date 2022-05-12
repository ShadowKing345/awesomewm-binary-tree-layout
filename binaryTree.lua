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
    if M.root then
        return M.root:find(data)
    end
    return nil
end

---Removes a node with the given data.
---@param data any
function M:remove(data)

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
