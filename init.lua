local awful = require("awful")
local binary_tree = require("binary_tree.binary_tree")

-- Stops the complaining about global undefined inside the file. Also prevents acidental overwrites
local capi = {client = client, screen = screen, mouse = mouse, mousegrabber = mousegrabber}

-- Global variable so that multiple instance of the layout can have access to the same data.
Trees = Trees or {}

-- Actual layout object returned to the layout manager. Named binary tree
local layout = {name = "Binary Tree"}
-- Vertical toggle.
Go_vertical = false

-- #region Array Helper Method.
-- Original credit goes to https://github.com/EvandroLG/array.lua for providing array util methods. Thanks EvandrolLG.
-- Also they are here cause I only needed one method table_diff and awesome lua compiler could not see them when installed through lua rocks.
local function convert_to_hash(obj)
    local output = {}

    for i = 1, #obj do
        local value = obj[i]
        output[value] = true
    end

    return output
end

local function table_diff(obj1, obj2)
    local output = {}
    local hash = convert_to_hash(obj2)

    for i = 1, #obj1 do
        local value = obj1[i]

        if not hash[value] then table.insert(output, value) end
    end

    return output
end
-- #endregion

local function table_diff_index(tbl1, tbl2)
    local indexes = {}
    local r = {}
    for i, v in ipairs(tbl1) do r[i] = v == tbl2[i] end
    for i, v in ipairs(r) do if not v then table.insert(indexes, i) end end

    return indexes
end

-- simple clamp function (probably better way to do it ngl)
local function clamp(v, min, max)
    v = math.max(v, min)
    v = math.min(v, max)
    return v
end

-- Recursive update of nodes.
function binary_tree:update_clients()
    local workarea = self.workarea
    local split = self.split

    -- if node is a leaf then set client.
    if self:is_leaf() then
        local client = self.data
        if client then
            client.x = workarea.x + workarea.gap
            client.y = workarea.y + workarea.gap
            client.width = math.max(workarea.width - (workarea.gap * 2), 1)
            client.height = math.max(workarea.height - (workarea.gap * 2), 1)
        end
    else
        -- else create new workareas for children
        local left_node
        local right_node

        if self.is_vertical then
            left_node = {x = workarea.x, y = workarea.y, width = workarea.width, height = workarea.height * split, gap = workarea.gap}
            right_node = {
                x = workarea.x,
                y = workarea.y + (workarea.height * split),
                width = workarea.width,
                height = workarea.height * (1 - split),
                gap = workarea.gap
            }
        else
            left_node = {x = workarea.x, y = workarea.y, width = workarea.width * split, height = workarea.height, gap = workarea.gap}
            right_node = {
                x = workarea.x + (workarea.width * split),
                y = workarea.y,
                width = workarea.width * (1 - split),
                height = workarea.height,
                gap = workarea.gap
            }
        end

        -- Failsafes in case somehow these are not actually correct.
        if self.left then
            self.left.workarea = left_node
            self.left:update_clients()
        end
        if self.right then
            self.right.workarea = right_node
            self.right:update_clients()
        end
    end
end

-- #region Controls
function layout.toggle_direction()
    Go_vertical = not Go_vertical
end

function layout.horizontal()
    Go_vertical = false
end

function layout.vertical()
    Go_vertical = true
end
-- #endregion

-- Main method for handling clients getting added to the layout or removed (make float counts as remove event).
-- Furthermore does a swap of clients check and simply swaps them before updating all the clients again.
function layout.arrange(p)
    local workarea = {x = p.workarea.x, y = p.workarea.y, width = p.workarea.width, height = p.workarea.height, gap = p.useless_gap or 0}
    local tag = tostring(p.tag or capi.screen[p.screen].selected_tag or awful.tag.selected(capi.mouse.screen))

    -- Insures that the tree exists in tag.
    if Trees[tag] == nil then Trees[tag] = {root = binary_tree.new(), clients = {}} end
    -- gets the tree
    local tree = Trees[tag]

    -- gets the change in
    local changed = #p.clients - #tree.clients
    local client_pos_difference = table_diff_index(p.clients, tree.clients)

    if changed ~= 0 then
        local prev_focus = awful.client.focus.history.get(p.screen, 1)

        -- If client got added.
        if changed > 0 then
            local difference = table_diff(p.clients, tree.clients)

            local base_node = tree.root
            if prev_focus then base_node = tree.root:find(prev_focus) or tree.root end

            for _, new_client in ipairs(difference) do
                if base_node.data then
                    local left_client = base_node.data

                    base_node.is_vertical = false

                    base_node:addLeft(binary_tree.new(left_client))
                    local new_node = base_node:addRight(binary_tree.new(new_client))

                    base_node.data = nil
                    base_node.is_vertical = Go_vertical

                    base_node = new_node
                else
                    base_node.data = new_client
                end
            end
        end

        -- If client got removed.
        if changed < 0 then
            local difference = table_diff(tree.clients, p.clients)
            for _, client in ipairs(difference) do tree.root:removeLeaf(client) end
        end

        -- Checks to see if there was a difference of positions in the clients
    elseif #client_pos_difference > 0 then
        local first_client = p.clients[client_pos_difference[1]]
        local second_client = p.clients[client_pos_difference[2]]

        local first_node = tree.root:find(first_client)
        local second_node = tree.root:find(second_client)
        first_node.data = second_client
        second_node.data = first_client
    end

    -- overwrites existing client collection with new one.
    tree.clients = p.clients

    -- set clients to match size in node.
    tree.root.workarea = workarea
    tree.root:update_clients()

    -- tree.root.print(tree.root)
end

-- Handles resizing of clients from mouse button (default Mod4 + right click)
function layout.mouse_resize_handler(client, corner, _, _)
    local tag = tostring(capi.screen[client.screen].selected_tag or awful.tag.selected(capi.mouse.screen))
    local tree = Trees[tag]

    local direction = {}
    for k, _ in string.gmatch(corner, "%a+") do table.insert(direction, k) end
    local bottom = direction[1] == "bottom"
    local right = direction[2] == "right"

    local client_node = tree.root:find(client)
    local horizontal = client_node
    local vertical = client_node

    -- This is basically the equivalent of black magic to me and I wrote it.
    -- Gets the upper most node when certain conditions are met.
    local prev_node
    while horizontal.parent
        and (((right and horizontal.parent.right.id == horizontal.id) or (not right and horizontal.parent.left.id == horizontal.id))
            or horizontal.parent.is_vertical) do
        prev_node = horizontal
        horizontal = horizontal.parent
    end
    -- Not 100% sure why this works but it prevents you from grabbing the right side only for the left node to be grabbed instead.
    horizontal = (prev_node and horizontal.parent) or horizontal.parent or nil

    prev_node = nil
    while vertical.parent
        and (((bottom and vertical.parent.right.id == vertical.id) or (not bottom and vertical.parent.left.id == vertical.id))
            or not vertical.parent.is_vertical) do
        prev_node = vertical
        vertical = vertical.parent
    end
    vertical = (prev_node and vertical.parent) or vertical.parent or nil

    local prev_coords = {}
    -- name of mouse icon to be used.
    local cursor = "cross"
    -- main loop method that sets the mouse coords and sets the split ratio accordingly.
    -- the update clients method is called to save on resources.
    capi.mousegrabber.run(function(_mouse)
        for _, v in ipairs(_mouse.buttons) do
            if v then
                prev_coords = {x = _mouse.x, y = _mouse.y}

                if horizontal then
                    horizontal.split = clamp(_mouse.x - horizontal.workarea.x, horizontal.workarea.gap,
                                             horizontal.workarea.width - (horizontal.workarea.gap * 2)) / horizontal.workarea.width
                    horizontal:update_clients()
                end

                if vertical then
                    vertical.split = clamp(_mouse.y - horizontal.workarea.y, horizontal.workarea.gap,
                                           horizontal.workarea.height - (horizontal.workarea.gap * 2)) / horizontal.workarea.height
                    vertical:update_clients()
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
