------------------------------------------------------------------------------------------
--
--  "Module" that contains all the code for creating the layout incuding layout functions.
--
------------------------------------------------------------------------------------------
-- Since I dont know where you will put this folder I attempt to get the relative location of file in order to import files within the correct folder.
-- Basically I need a relative from file require and this is the easyest alternative.
local gears = require("gears")
local root_path = debug.getinfo(1).source:match("@(.*/)")
local config_path = gears.filesystem.get_configuration_dir()
local relative_path = (root_path:sub(0, #config_path) == config_path) and root_path:sub(#config_path+1) or root_path

-- Imports.
------------------------------------------------------------------------------------------

local awful = require("awful")
local binaryTreeNode = require(relative_path .. "bidirectionalBinaryTreeNode")
local util = require(relative_path .. "util")

-- Global imports. Also keeps the intelesense complaining to one location.
------------------------------------------------------------------------------------------
local capi = {
    client = client,
    screen = screen,
    mouse = mouse,
    mousegrabber = mousegrabber
}

-- Module specific gloabl imports.
------------------------------------------------------------------------------------------
TREES = TREES or {}
-- You can use/modify this variable in other modules instead of always requiring this file.
BINARY_TREE_LAYOUT_GO_VERTICAL = BINARY_TREE_LAYOUT_GO_VERTICAL

-- Layout builder.
local binaryTreeBuilder = {mt = {}}

--[[
    Recursive method that sets the internal client (if any) to the size of the workarea.
    Else marches to the next child nodes.

    @param andChildren: update children nodes as well.
]]
function binaryTreeNode:updateClients(andChildren)
    local workarea = self.workarea
    local split = self.split
    andChildren = andChildren or true

    if self.data then
        local client = self.data
        -- I wish this could be a single method call. Message me if this is a thing.
        client.x = workarea.x + workarea.gap
        client.y = workarea.y + workarea.gap
        client.width = math.max(workarea.width - (workarea.gap * 2), 1)
        client.height = math.max(workarea.height - (workarea.gap * 2), 1)
    else
        if andChildren then
            local leftArea = util.shallowCopy(workarea)
            local rightArea = util.shallowCopy(workarea)

            -- Small line reduction to not have to do 6 assignment calls.
            -- s: size; d: direction. 
            local t = self.is_vertical and {s = "height", d = "y"} or
                          {s = "width", d = "x"}

            leftArea[t.s] = workarea[t.s] * split
            rightArea[t.s] = workarea[t.s] * (1 - split)
            rightArea[t.d] = workarea[t.d] + (workarea[t.s] * split)

            -- While not needed, these fail safes are there to prevent an empty child from updating.
            if self.left then
                self.left.workarea = leftArea
                self.left:updateClients()
            end

            if self.right then
                self.right.workarea = rightArea
                self.right:updateClients()
            end
        end
    end
end

--[[ Toggles the direction the next split will be. ]]
function binaryTreeBuilder.toggleDirection()
    BINARY_TREE_LAYOUT_GO_VERTICAL = not BINARY_TREE_LAYOUT_GO_VERTICAL
end

--[[ Sets the direction of the next split to be horizontal.]]
function binaryTreeBuilder.horizontal() BINARY_TREE_LAYOUT_GO_VERTICAL = false end

--[[ Sets the direction of the next split to be vertical.]]
function binaryTreeBuilder.vertical() BINARY_TREE_LAYOUT_GO_VERTICAL = true end

--[[
    Builds the layout.

    @param args: Additional arguments provided to the builder. Provide it as a table of k,v pairs for additioanl lua nausense.
    @return: The layout obj. (This is what you put in the layouts array.)

    @param startVertical: Starting point of the first split. Default false.
    @param name: Name of the returned layout. Never alter this unless you know what you are doing.
]]
function binaryTreeBuilder:build(args)
    args = args or {}
    BINARY_TREE_LAYOUT_GO_VERTICAL = args.startVertical or
                                         BINARY_TREE_LAYOUT_GO_VERTICAL or false

    local layout = {name = args.name or "binaryTreeLayout"}

    --[[
    Method that creates / destroys nodes in the tree.
    It also swaps clients if a swap event occurs.

    @param p: A manditory table contaning all important information about the current layout.
    ]]
    function layout.arrange(p)
        -- I use workarea rather then geometry as geometry is the actual screen dimentions while workarea is the avaliable space and the relative 0,0 postion for the screen.
        local workarea = util.shallowCopy(p.workarea)
        -- I also just shove in the gap inside since I don't want to cluter the node obj with pointless display info.
        workarea.gap = p.useless_gap or 0

        -- Gets the name of the tag.
        local tag = tostring(p.tag or capi.screen[p.screen].selected_tag or
                                 awful.tag.selected(capi.mouse.screen))

        -- Insures that the tree exists in tag.
        if TREES[tag] == nil then
            TREES[tag] = {root = binaryTreeNode.new(), clients = {}}
        end
        -- Gets the tree.
        local tree = TREES[tag]

        -- Gets the number difference of clients.
        local changed = #p.clients - #tree.clients
        if changed ~= 0 then
            local prevFocus = awful.client.focus.history.get(p.screen, 1)

            -- If client got added.
            if changed > 0 then
                local difference = util.tableDiff(p.clients, tree.clients)

                local baseNode = tree.root
                if prevFocus then
                    baseNode = tree.root:find(prevFocus) or tree.root
                end

                for _, newClient in ipairs(difference) do
                    if baseNode.data then
                        local left_client = baseNode.data

                        baseNode.is_vertical = false

                        baseNode:addLeft(binaryTreeNode.new(left_client))
                        local newNode =
                            baseNode:addRight(binaryTreeNode.new(newClient))

                        baseNode.data = nil
                        baseNode.is_vertical = BINARY_TREE_LAYOUT_GO_VERTICAL

                        baseNode = newNode
                    else
                        baseNode.data = newClient
                    end
                end
            end

            -- If client got removed.
            if changed < 0 then
                local difference = util.tableDiff(tree.clients, p.clients)
                for _, client in ipairs(difference) do
                    tree.root:removeLeaf(client)
                end
            end
        else
            -- If no changes to the number of clients were made there its possible that the position of clients has changed.
            -- Client being set as floting does count as a removal event which saves a lot of heavy lifting from the layout.

            -- Gets number of clients that are different.
            local clientPosDifference =
                util.tableDiffIndex(p.clients, tree.clients)
            if #clientPosDifference > 0 then
                -- This is with the assumption that only 2 clients can ever change.
                -- If more then 2 is possible or you have custom code that allows you to swap multiple.
                -- Please be careful!
                local firstClient = p.clients[clientPosDifference[1]]
                local secondClient = p.clients[clientPosDifference[2]]

                local firstNode = tree.root:find(firstClient)
                local secondNode = tree.root:find(secondClient)
                firstNode.data = secondClient
                secondNode.data = firstClient
            end
        end

        -- overwrites existing client collection with new one.
        tree.clients = p.clients

        -- set clients to match size in node.
        tree.root.workarea = workarea
        tree.root:updateClients(true)

        -- Debug. Uncomment to see structure of binary tree.
        -- tree.root.print(tree.root)
    end

    --[[
    Handles resizing of clients from mouse button (default Mod4 + right click).

    @param client: Actual client that is being resized.
    @param corner: String statement of the corner grabbed. I.E. "top_left", "bottom_right", etc...
    @param x: Unused but provides the current x pos of the mouse.
    @param y: Unused but provides the current y pos of the mouse.
    ]]
    function layout.mouse_resize_handler(client, corner, _, _)
        local tag = tostring(capi.screen[client.screen].selected_tag or
                                 awful.tag.selected(capi.mouse.screen))
        local tree = TREES[tag]

        -- Splits the string into array instance of the words.
        -- Corner will only ever be the corner, never the edge so no just right etc.
        local direction = {}
        for k, _ in string.gmatch(corner, "%a+") do
            table.insert(direction, k)
        end
        -- Gets the direction based on the word provided.
        -- It can only ever be 2 directions so only one check is needed.
        local bottom = direction[1] == "bottom"
        local right = direction[2] == "right"

        local client_node = tree.root:find(client)
        local horizontal = client_node
        local vertical = client_node

        -- This is basically the equivalent of black magic to me and I wrote it.
        -- This is a marching while loop that will only march up to the nodes parenets if the conditions are met.
        -- The oposite of the conditions after the "or" would be considered a valid node.
        local prevNode
        while -- Null check to not throw a null pointer exception. or end up in a null state.
        horizontal.parent and
            ( -- checks the direction being draged. If being dragged to the right then node cannot be a right node.
            -- If being draged to the left then node cannot be a left node.
            ((right and horizontal.parent.right.id == horizontal.id) or
                (not right and horizontal.parent.left.id == horizontal.id)) -- Checks if the node is set to be a vertical node.
            -- A node can be in the correct location based on the draggin direction but can be vertical.
            -- If this is true the end result will be very odd as when you drag it will drag in the wrong direction.
            or horizontal.parent.is_vertical) do
            prevNode = horizontal
            horizontal = horizontal.parent
        end
        -- Not 100% sure why this works but it prevents you from grabbing the right side only for the left node to be grabbed instead.
        horizontal = (prevNode and horizontal.parent) or horizontal.parent or
                         nil

        -- Copy of the horizonal loop but now vertical.
        prevNode = nil
        while vertical.parent and
            (((bottom and vertical.parent.right.id == vertical.id) or
                (not bottom and vertical.parent.left.id == vertical.id)) or
                not vertical.parent.is_vertical) do
            prevNode = vertical
            vertical = vertical.parent
        end
        vertical = (prevNode and vertical.parent) or vertical.parent or nil -- The follow is a boolean tree for the previous while loops provide visual context for a march condition.
        -- Since no march will occur if parent is null it is not included to reduce size.
        --[[
            | P | > | L | R | V |  >&R  | !>&L  |   ( >&R | !>&L ) | V  |  P & ( ( >&R | !>&L ) | V )  |
            +---+---+---+---+---+-------+-------+-----------------------+------------------------------+
            | * |   |   |   |   |       |       |                       |                              |
            | * |   |   |   | * |       |       |          *            |              *               |
            | * |   |   | * |   |       |       |                       |                              |
            | * |   |   | * | * |       |       |          *            |              *               |
            | * |   | * |   |   |       |   *   |          *            |              *               |
            | * |   | * |   | * |       |   *   |          *            |              *               |
            | * |   | * | * |   |       |   *   |          *            |              *               |
            | * |   | * | * | * |       |   *   |          *            |              *               |
            | * | * |   |   |   |       |       |                       |                              |
            | * | * |   |   | * |       |       |                       |                              |
            | * | * |   | * |   |   *   |       |          *            |              *               |
            | * | * |   | * | * |   *   |       |          *            |              *               |
            | * | * | * |   |   |       |       |                       |                              |
            | * | * | * |   | * |       |       |                       |                              |
            | * | * | * | * |   |   *   |       |          *            |              *               |
            | * | * | * | * | * |   *   |       |          *            |              *               |

            Key:
            P: Is parent null.
            >: Is going right.
            L: Is left node.
            R: Is right node.
            V: Is vertical.
            P&((>&R|!>&L)|V): The condition where a march up the parent will be performed.
        ]]

        local prev_coords = {}
        -- name of mouse icon to be used.
        local cursor = "cross"
        -- main loop method that sets the mouse coords and sets the split ratio accordingly.
        -- the update clients method for the node is called to save on resources compared to calling the root.
        capi.mousegrabber.run(function(_mouse)
            for _, v in ipairs(_mouse.buttons) do
                if v then
                    prev_coords = {x = _mouse.x, y = _mouse.y}

                    if horizontal then
                        -- Clamps it between the inner gaps as the gaps act as padding for the window.
                        horizontal.split =
                            util.clamp(_mouse.x - horizontal.workarea.x,
                                       horizontal.workarea.gap,
                                       horizontal.workarea.width -
                                           (horizontal.workarea.gap * 2)) /
                                horizontal.workarea.width
                        horizontal:updateClients(false)
                    end

                    if vertical then
                        vertical.split =
                            util.clamp(_mouse.y - horizontal.workarea.y,
                                       horizontal.workarea.gap,
                                       horizontal.workarea.height -
                                           (horizontal.workarea.gap * 2)) /
                                horizontal.workarea.height
                        vertical:updateClients(false)
                    end

                    -- setup to be an infinate loop as long as the button is held down.
                    return true
                end
            end

            -- check to exit the loop once the button is no longer held down and the mouse moves a bit.
            return prev_coords.x == _mouse.x and prev_coords.y == _mouse.y
        end, cursor)
    end

    return layout
end

function binaryTreeBuilder.mt.__call(...) return binaryTreeBuilder:build(...) end

return setmetatable(binaryTreeBuilder, binaryTreeBuilder.mt)
