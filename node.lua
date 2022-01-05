------------------------------------------------------------------------------------------
--
-- Bidirectional Binary Tree Node.
-- Note: Since this tree is bidirectional it is intended that you go back up to the root of the tree from any node.
-- All a tree needs to do is just have a root attribute to be considered a tree of this.
--
------------------------------------------------------------------------------------------
local util = require(TREES.relative_path .. ".util")
local gtable = require("gears.table")

local node = {}
-- Not 100% sure why this works but it prevents certain null pointer exceptions from occuring.
node.__index = node

--[[
  Creates a new node in the tree.

  @param data: The client the node is holding.
  @param left: Left node.
  @param right: Right node.
  @param parent: Parent node.
  @return: Node
]]
function node.new(data, left, right, parent)
  local newNode = {data = data, left = left, right = right, parent = parent, split = 0.5, is_vertical = false, id = util.uuid()}
  return setmetatable(newNode, node)
end

--[[
  Adds left child node.

  @param child: The child node to be added.
  @return: The refereced set child node.
]]
function node:addLeft(child)
  if self ~= nil then
    self.left = child
    child.parent = self
    return self.left
  end
end

--[[
  Adds right child node.

  @param child: The child node to be added.
  @return: The refereced set child node.
]]
function node:addRight(child)
  if self ~= nil then
    self.right = child
    child.parent = self
    return self.right
  end
end

--[[
  Removes the child leaf if the clients matches and sets the other node as it's self effectivly distroying itself in the process.
  If it cannot do that then the children nodes attempt this.

  @param client: The client to match the data for.
]]
function node:removeLeaf(client)
  if self.left then
    if self.left.data == client then
      local newSelf = gtable.copy(self.right, false)
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
      local newSelf = gtable.copy(self.left, false)
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

--[[
  Recursivly finds the node where the client matches.
  Nil is retunred if none can be found.

  @param client: The client to be looked for.
  @return: The node the client is on or nil if it failed to find any.
]]
function node:find(client)
  if self.data then
    return self.data == client and self or nil
  else
    local obj = nil
    if self.left then obj = self.left:find(client) end
    if self.right then obj = obj or self.right:find(client) or nil end
    return obj
  end
end

--[[
  Debug tool used to print the nodes information. With indent padding to help readability.

  @param node: The base node to start printing from.
  @param level: The current level. I.E. indent offset. Default 0
  @param prefix: String prefix before the word Node is printed. Will only display for root node as it gets overwritten for the left and right.
]]
function node.print(n, level, prefix)
  level = level or 0
  prefix = prefix or ""

  if type(n) == "table" then
    print(string.rep(" ", level) .. prefix .. "Node:")
    for k, v in pairs(n) do if k ~= "left" and k ~= "right" then print(string.rep(" ", level + 1) .. tostring(k) .. ": " .. tostring(v)) end end
    if n.left ~= nil and type(n.left) == "table" then n.print(n.left, level + 1, "L_") end
    if n.right ~= nil and type(n.right) == "table" then n.print(n.right, level + 1, "R_") end
  end
end

return node
