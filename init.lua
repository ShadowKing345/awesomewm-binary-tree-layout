--[[

    Index file.

--]]
--------------------------------------------------
local relPath = (...):match ".*"

--------------------------------------------------
local M = {
    binaryTreeLayout = require(relPath .. ".binaryTreeLayout"),
    binaryTree = require(relPath .. ".binaryTree"),
}

return setmetatable(M, {
    __call = function(...)
        return M.binaryTreeLayout(...)
    end
})
