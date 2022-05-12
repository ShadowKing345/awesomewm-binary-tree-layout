--[[

    Binary Tree Layout.

--]]
--------------------------------------------------
local awful = require "awful"
local gTable = require "gears.table"
local capi = { client = client, screen = screen, mouse = mouse, mousegrabber = mousegrabber }

local relPath = (...):match "(.*).binaryTreeLayout"
local binaryTree = require(relPath .. ".binaryTree")
local utils = require(relPath .. ".utils")

--------------------------------------------------
---@class BinaryTreeLayout
local M = {
    name       = "binaryTreeLayout",
    trees      = {},
    isVertical = false,
    mt         = {},
}

---Updates all the information for the clients based on where they are in the tree.
---@param node Node #Node object.
---@param workarea any #Workarea and gap
function M.updateClientGeometry(node, workarea)
    local splitSize = node.isVertical and workarea.height / 2 or workarea.width / 2
    if node.data then
        node.data:geometry {
            x      = workarea.x,
            y      = workarea.y,
            width  = workarea.width,
            height = workarea.height,
        }
    else
        local gap = workarea.gap / 2
        local newWorkarea = gTable.clone(workarea)

        if node.isVertical then
            newWorkarea.height = splitSize
        else
            newWorkarea.width = splitSize
        end

        if node.left then
            if node.isVertical then
                newWorkarea.height = newWorkarea.height - gap
            else
                newWorkarea.width = newWorkarea.width - gap
            end
            M.updateClientGeometry(node.left, newWorkarea)
        end

        if node.right then
            if node.isVertical then
                newWorkarea.y = newWorkarea.y + splitSize + gap
            else
                newWorkarea.x = newWorkarea.x + splitSize + gap
            end
            M.updateClientGeometry(node.right, newWorkarea)
        end
    end
end

function M:isVertical()
    self.isVertical = true
end

function M:horizontal()
    self.isVertical = false
end

function M:toggle()
    self.isVertical = not self.isVertical
end

---Method used to arrange the clients.
---@param p any
function M.arrange(p)
    local self     = M
    local workarea = gTable.clone(p.workarea)
    workarea.gap   = p.useless_gap or 0

    local tag = tostring(p.tag or capi.screen[p.screen].selected_tag or awful.tag.selected(capi.mouse.screen))

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

                    baseNode:addLeft(binaryTree.newNode { data = leftClient, isVertical = self.isVertical })
                    local newNode = baseNode:addRight(binaryTree.newNode {
                        data = newClient,
                        isVertical = self.isVertical,
                    })

                    baseNode.data = nil
                    baseNode = newNode
                else
                    baseNode.data = newClient
                end
            end
        elseif changed < 0 then
            difference = utils.table.tableDiff(tree.clients, p.clients)
            for _, client in ipairs(difference) do
                tree:remove(client)
            end
        else
            local firstClient  = p.clients[difference[1]]
            local secondClient = p.clients[difference[2]]

            local firstNode  = tree:find(firstClient)
            local secondNode = tree:find(secondClient)

            firstNode.data  = secondClient
            secondNode.data = firstClient
        end
    else
    end

    tree.clients = p.clients

    M.updateClientGeometry(tree.root, workarea)
end

---Used to resize the clients
---@param client any #The client to resize
---@param amount number #The amount to resize by.
---@param direction any #Which direction to resize.
function M.resize(client, amount, direction)
    print(utils.toJson(client, true), utils.toJson(amount, true), utils.toJson(direction, true))
end

function M.mouse_resize_handler(client, corner, x, y)
    print(utils.toJson(client, true), utils.toJson(corner, true), utils.toJson(x, true), utils.toJson(y, true))
end

---Creates a new Binary Tree Layout instance.
---@param args any
---@return table
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
function M.mt:__call(...)
    return M:new(...)
end

return setmetatable(M, M.mt)
--------------------------------------------------
---@class BinaryTreeLayout #The layout class.
---@field trees table<string, Tree> #Collection of trees.
---@field name string #The name of that will be told to AwesomeWM layout system.
---@field isVertical boolean #Controls if the next node will be vertical or not.
