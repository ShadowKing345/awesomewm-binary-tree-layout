--[[

    Binary Tree Layout.

--]]
--------------------------------------------------
local awful  = require "awful"
local gTable = require "gears.table"
local capi   = { client = client, screen = screen, mouse = mouse, mousegrabber = mousegrabber }

local relPath    = (...):match "(.*).binaryTreeLayout"
local binaryTree = require(relPath .. ".binaryTree")
local utils      = require(relPath .. ".utils")

--------------------------------------------------
---@class BinaryTreeLayout
local M = {
    name       = "binaryTreeLayout",
    trees      = {},
    isVertical = false,
    split      = 0.5,
    mt         = {},
}

---Updates all the information for the clients based on where they are in the tree.
---@param node Node #Node object.
---@param workarea? Workarea #Workarea and gap
function M.updateClientGeometry(node, workarea)
    workarea = workarea or node.workarea
    if not workarea then
        return
    end
    local isVertical = node.isVertical
    node.workarea    = workarea

    if node.data then
        node.data:geometry {
            x      = workarea.x,
            y      = workarea.y,
            width  = workarea.width,
            height = workarea.height,
        }
    else
        local dir = isVertical and {
            pos  = "y",
            size = "height",
        } or {
            pos  = "x",
            size = "width",
        }

        local split       = utils.clamp(workarea[dir.size] * workarea.split, 1, workarea[dir.size])
        local gap         = workarea.gap / 2
        local newWorkarea = gTable.clone(workarea)

        newWorkarea[dir.size] = split

        if node.left then
            newWorkarea[dir.size] = utils.clamp(newWorkarea[dir.size] - gap, 1, workarea[dir.size])
            M.updateClientGeometry(node.left, newWorkarea)
        end

        if node.right then
            newWorkarea[dir.pos]  = newWorkarea[dir.pos] + split + gap
            newWorkarea[dir.size] = workarea[dir.size] - newWorkarea[dir.size]
            M.updateClientGeometry(node.right, newWorkarea)
        end
    end
end

---Gets the node adjacent to the starting node by the direction.
---@param startingNode Node #Starting Node
---@param right boolean #Is the node the "right side" node of the tree. As in is it right.
---@param is_vertical boolean #Is the node vertical.
---@return Node|nil
function M.getNodeByDirection(startingNode, right, is_vertical)
    local node = startingNode
    local prevNode

    repeat
        prevNode = node
        node = node.parent
    until not node or
        ((right and node.left.id == prevNode.id or not right and node.right.id == prevNode.id)
            and node.isVertical == is_vertical)

    return node
end

---Clamps down the value of the split
---@param mouse any #Mouse coords.
---@param workarea Workarea #The workarea for the parent node.
---@param rootWorkarea Workarea #The root or furthest most workarea. Basically screen workarea.
---@param isVertical boolean #Changes if the calculation uses vertical variables.
---@return number
function M.clampSplit(mouse, workarea, rootWorkarea, isVertical)
    local dir = isVertical and {
        pos = "y",
        size = "height",
    } or {
        pos = "x",
        size = "width",
    }

    local amount = utils.clamp(mouse[dir.pos], rootWorkarea[dir.pos], rootWorkarea[dir.size])
    amount = utils.clamp(amount, workarea[dir.pos], workarea[dir.size])

    return amount / workarea[dir.size]
end

---Generates a tag.
---@param p? any #Layout properties.
---@return string
function M._genTag(p)
    return tostring(p and (p.tag or capi.screen[p.screen].selected_tag) or awful.tag.selected(capi.mouse.screen))
end

---Changes the direction for the next split to be vertical.
function M:vertical()
    self.isVertical = true
end

---Changes the direction for the next split to be horizontal.
function M:horizontal()
    self.isVertical = false
end

---Toggles the direction for the next split.
function M:toggle()
    self.isVertical = not self.isVertical
end

---Changes the direction of parent node the current client is on.
---@param c any #The client to use.
---@param isVertical boolean? #Should the node be vertical will just toggle the not specified or not a boolean.
function M:changeDirection(c, isVertical)
    local dir

    if type(isVertical) == "boolean" then
        dir = isVertical
    end

    local tree = self.trees[self._genTag()]

    if not tree then
        return
    end

    local node = tree:find(c or awful.client.focus.history.get(capi.mouse.screen, 1)).parent

    if not node then
        return
    end

    if dir ~= nil then
        node.isVertical = dir
    else
        node.isVertical = not node.isVertical
    end

    M.updateClientGeometry(node)
end

---Method used to arrange the clients.
---@param p any
function M.arrange(p)
    local self     = M
    ---@type Workarea
    local workarea = gTable.clone(p.workarea)
    workarea.gap   = p.useless_gap or 0
    workarea.split = self.split or 0.5

    local tag = self._genTag(p)

    if self.trees[tag] == nil then
        self.trees[tag] = binaryTree()
    end
    local tree = self.trees[tag]

    local changed = #p.clients - (#tree.clients or 0)
    if changed ~= 0 then
        local prevFocus = awful.client.focus.history.get(p.screen, 1)
        local difference = utils.table.tableDiff(p.clients, tree.clients)

        if changed > 0 then

            local baseNode = prevFocus and tree:find(prevFocus) or tree.root

            for _, newClient in ipairs(difference) do
                if baseNode.data then
                    local leftClient = baseNode.data

                    baseNode.data = nil
                    baseNode.isVertical = self.isVertical

                    baseNode:addLeft(binaryTree.newNode { data = leftClient })
                    baseNode = baseNode:addRight(binaryTree.newNode { data = newClient })
                else
                    baseNode.data = newClient
                end
            end
        else
            difference = utils.table.tableDiff(tree.clients, p.clients)
            for _, client in ipairs(difference) do
                tree:remove(client)
            end
        end
    else
        local difference = utils.table.tableDiffIndex(p.clients, tree.clients)

        if #difference < 1 then
            return
        end

        local firstClient  = p.clients[difference[1]]
        local secondClient = p.clients[difference[2]]

        local firstNode  = tree:find(firstClient)
        local secondNode = tree:find(secondClient)

        if not (firstNode and secondNode) then
            return
        end

        firstNode.data  = secondClient
        secondNode.data = firstClient
    end

    tree.clients = p.clients

    M.updateClientGeometry(tree.root, workarea)
end

---Used to resize the clients
---@param client any #The client to resize
---@param amount number #The amount to resize by.
---@param direction any #Which direction to resize.
function M.resize(client, amount, direction)
    if not (client and (amount and amount > 0)) then return end
    direction = direction or "rigth"

    local self = M
    local tree = self.trees[tostring(capi.screen[client.screen].selected_tag or awful.tag.selected(capi.mouse.screen))]

    local isVertical = direction == "up" or direction == "down"
    local rightOrDown = direction == "down" or direction == "right"

    if direction == "up" or direction == "left" then amount = amount * -1 end

    local client_node = tree.root:find(client)
    local node = self.getNodeByDirection(client_node, rightOrDown, isVertical).parent

    if node then
        node.workarea.split = amount
        self.updateClientGeometry(node)
    end
end

---Alteres the split amounts with the mouse drag event.
---@param client any #The client
---@param corner string #The corner direction.
function M.mouse_resize_handler(client, corner)
    local self = M
    local tree = self.trees[self._genTag()]

    local isBottom = corner:match "[^_]+" == "bottom"
    local isRight  = corner:match "([^_]+)$" == "right"

    local clientNode = tree.root:find(client)
    local horizontal = self.getNodeByDirection(clientNode, isRight, false)
    local vertical   = self.getNodeByDirection(clientNode, isBottom, true)

    local prev_coords = {}
    capi.mousegrabber.run(function(mouse)
        for _, button in ipairs(mouse.buttons) do
            if button then
                prev_coords = { x = mouse.x, y = mouse.y }

                if horizontal then
                    horizontal.workarea.split = self.clampSplit(mouse, horizontal.workarea, tree.root.workarea, false)
                    self.updateClientGeometry(horizontal)
                end

                if vertical then
                    vertical.workarea.split = self.clampSplit(mouse, vertical.workarea, tree.root.workarea, true)
                    self.updateClientGeometry(vertical)
                end

                -- setup to be an infinate loop as long as the button is held down.
                return true
            end
        end

        -- check to exit the loop once the button is no longer held down and the mouse moves a bit.
        return prev_coords.x == mouse.x and prev_coords.y == mouse.y
    end, "cross")
end

---Creates a new Binary Tree Layout instance.
---@param args any
---@return BinaryTreeLayout
function M:new(args)
    args = args or {}

    ---@type BinaryTreeLayout
    local layout = {
        name       = args.name or self.name,
        trees      = args.trees or {},
        isVertical = args.isVertical or false,
    }
    gTable.crush(layout, M, true)

    return self
end

--------------------------------------------------
---Metatable call.
---@param ... unknown
---@return BinaryTreeLayout
function M.mt:__call(...)
    return M:new(...)
end

return setmetatable(M, M.mt)
--------------------------------------------------
---@class BinaryTreeLayout #The layout class.
---@field trees table<string, Tree> #Collection of trees.
---@field name string #The name of that will be told to AwesomeWM layout system.
---@field isVertical boolean #Controls if the next node will be vertical or not.
---@field split number #Default split amount.
