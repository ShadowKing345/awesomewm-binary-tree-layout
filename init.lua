------------------------------------------------------------------------------------------
--
--  "Module" that contains all the code for creating the layout incuding layout functions.
--
------------------------------------------------------------------------------------------
TREES = TREES or {}

-- Imports.
------------------------------------------------------------------------------------------
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")
local beautiful = require("beautiful")

-- Since I dont know where you will put this folder I attempt to get the relative location of file in order to import files within the correct folder.
-- Basically I need a relative from this file and this is the easy method of getting that path that I managed to find.
if not TREES.relative_path then
  local root_path = debug.getinfo(1).source:match("@(.*/)")
  local config_path = gears.filesystem.get_configuration_dir()
  TREES.relative_path = (root_path:sub(0, #config_path) == config_path) and root_path:sub(#config_path + 1) or root_path
end

local util = require(TREES.relative_path .. "util")
local binaryTreeNode = require(TREES.relative_path .. "bidirectionalBinaryTreeNode")

-- Global imports. Also keeps the intelesense complaining to one location.
------------------------------------------------------------------------------------------
local capi = {client = client, screen = screen, mouse = mouse, mousegrabber = mousegrabber}

BINARY_TREE_LAYOUT_GO_VERTICAL = BINARY_TREE_LAYOUT_GO_VERTICAL

-- Layout builder.
local binaryTreeBuilder = {mt = {}}

--[[
  Recursive method that sets the internal client (if any) to the size of the workarea.
  Else marches to the next child nodes.

  @param andChildren: update children nodes as well.
]]
function binaryTreeNode:updateClients(args)
  args = args or {}
  local workarea = self.workarea
  local split = self.split
  local andChildren = args.andChildren or true
  local respect_client_borders = args.respect_client_borders or false

  if self.data then
    local client = self.data
    local border_width = (respect_client_borders and client.border_width) or beautiful.border_width or 0
    client.x = workarea.x + (not respect_client_borders and border_width or 0)
    client.y = workarea.y + (not respect_client_borders and border_width or 0)
    client.width = workarea.width - (border_width * 2)
    client.height = workarea.height - (border_width * 2)
  else
    if andChildren then
      local leftArea = util.shallowCopy(workarea)
      local rightArea = util.shallowCopy(workarea)

      -- Small line reduction to not have to do 6 assignment calls.
      -- s: size; d: direction.
      local t = self.is_vertical and {s = "height", d = "y"} or {s = "width", d = "x"}

      leftArea[t.s] = workarea[t.s] * split
      rightArea[t.s] = workarea[t.s] * (1 - split)
      rightArea[t.d] = workarea[t.d] + (workarea[t.s] * split)

      -- This is what handles the usless gap. In order to stop shifting to the right with too many windows only the left size gets shrunk the full amount rather then the right side.
      leftArea[t.s] = leftArea[t.s] - workarea.gap

      -- While not needed, these fail safes are there to prevent an empty child from updating.
      if self.left then
        self.left.workarea = leftArea
        self.left:updateClients(args)
      end

      if self.right then
        self.right.workarea = rightArea
        self.right:updateClients(args)
      end
    end
  end
end

--[[ Toggles the direction the next split will be. ]]
function binaryTreeBuilder.toggleDirection()
  BINARY_TREE_LAYOUT_GO_VERTICAL = not BINARY_TREE_LAYOUT_GO_VERTICAL
  if TREES.send_notifications then
    naughty.notify({text = string.format("Next split will be %s.", (BINARY_TREE_LAYOUT_GO_VERTICAL and "Vertical") or "Horizontal")})
  end
end

--[[ Sets the direction of the next split to be horizontal.]]
function binaryTreeBuilder.horizontal()
  BINARY_TREE_LAYOUT_GO_VERTICAL = false
  if TREES.send_notifications then naughty.notify({text = "Next split will be Horizontal."}) end
end

--[[ Sets the direction of the next split to be vertical.]]
function binaryTreeBuilder.vertical()
  BINARY_TREE_LAYOUT_GO_VERTICAL = true
  if TREES.send_notifications then naughty.notify({text = "Next split will be Vertical."}) end
end

--[[Toggles the direction of the branch the focused client is in]]
function binaryTreeBuilder.toggleNodeDirection(client)
  client = client or capi.client.focus

  if not client then return end

  local tag = tostring(capi.screen[client.screen].selected_tag or awful.tag.selected(capi.mouse.screen))
  local tree = TREES[tag]
  local client_node = tree.root:find(client)

  if client_node and client_node.parent then
    client_node.parent.is_vertical = not client_node.parent.is_vertical
    client_node.parent:updateClients(false)
  end
end

-- Default config settings for the builder.
local function configs()
  return {name = "binaryTreeLayout", start_vertical = false, send_notifications = false, debug = false, respect_client_borders = true}
end

--[[
  Builds the layout.

  @param args: Additional arguments provided to the builder. Provide it as a table of k,v pairs for additioanl lua nausense.
  @return: The layout obj. (This is what you put in the layouts array.)

  @param start_vertical: Starting point of the first split. Default false.
  @param name: Name of the returned layout. Never alter this unless you know what you are doing.
  @param send_notifications: If set to true a message will be displayed whenever the layout direction changes.
  @param debug: Prints debug messages into the console.
  @param respect_client_borders: If set to true the layout will apply a border from client.border_width I.E. the clients actual border. If false it will use the border_width set in beautiful instead.
]]
function binaryTreeBuilder.build(args)
  args = util.mergeTables(configs() or {}, args or {})
  BINARY_TREE_LAYOUT_GO_VERTICAL = args.start_vertical or BINARY_TREE_LAYOUT_GO_VERTICAL or false
  TREES.send_notifications = args.send_vertical
  TREES.debug_mode = args.debug

  local layout = {name = args.name}

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
    local tag = tostring(p.tag or capi.screen[p.screen].selected_tag or awful.tag.selected(capi.mouse.screen))

    -- Insures that the tree exists in tag.
    if TREES[tag] == nil then TREES[tag] = {root = binaryTreeNode.new(), clients = {}} end
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
        if prevFocus then baseNode = tree.root:find(prevFocus) or tree.root end

        for _, newClient in ipairs(difference) do
          if baseNode.data then
            local left_client = baseNode.data

            baseNode:addLeft(binaryTreeNode.new(left_client))
            local newNode = baseNode:addRight(binaryTreeNode.new(newClient))

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
        for _, client in ipairs(difference) do tree.root:removeLeaf(client) end
      end
    else
      -- If no changes to the number of clients were made there its possible that the position of clients has changed.
      -- Client being set as floting does count as a removal event which saves a lot of heavy lifting from the layout.

      -- Gets number of clients that are different.
      local clientPosDifference = util.tableDiffIndex(p.clients, tree.clients)
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
    tree.root:updateClients({andChildren = true, respect_client_borders = args.respect_client_borders})

    -- Debug. Prints tree's content to stdout
    if TREES.debug_mode then tree.root.print(tree.root) end
  end

  --[[
      Retuns the node that matches the desired conditions. If fails will return nil.

      @param startingNode: Where you want to start searching.
	    @param right: Boolean of the direction you wish to pull towards. Down if vertical is set to true.
	    @param is_vertical: Set true if you are looking for a vertical node.
	    @return: Node that matches these requirements or nil.
	  ]]
  function layout.getNodeByPullDirection(startingNode, right, is_vertical)
    local node = startingNode
    local prevNode

    repeat
      prevNode = node
      node = node.parent
    until not node or ((right and node.left.id == prevNode.id or not right and node.right.id == prevNode.id) and node.is_vertical == is_vertical)

    return node
  end

  --[[
      Allows you to manually resize a client through code.
      It's expected that this is used as a keybind in the client.

      @param client: The client that you want to change the size of.
      @param amount: The delta amount you want to increase the size of.
      @param direction: The direction you want to increase the size towards.
  ]]
  function layout.resize(client, amount, direction)
    if not client then return end
    if not amount or amount == 0 then return end
    direction = direction or "rigth"
    local tag = tostring(capi.screen[client.screen].selected_tag or awful.tag.selected(capi.mouse.screen))
    local tree = TREES[tag]

    local is_vertical = direction == "up" or direction == "down"
    local right_or_down = direction == "down" or direction == "right"

    if direction == "up" or direction == "left" then amount = amount * -1 end

    local client_node = tree.root:find(client)
    local node = layout.getNodeByPullDirection(client_node, right_or_down, is_vertical)

    if node then
      local bound = node.workarea.gap / node.workarea[is_vertical and "height" or "width"]
      node.split = util.clamp(node.split + amount, bound, 1 - bound)
      node:updateClients({andChildren = false, respect_client_borders = args.respect_client_borders})
    end
  end

  --[[
      Clamps down the splits to the correct gap sensitive value.

      @param mouse: The x, y pos of the mouse.
      @param workarea: The workarea to clamp the split down to. (should contain a gap value)
      @param is_vertical: Is it a vertical clamp or horizontal clamp.
      @return: The split corrected to respect gaps.
    ]]
  function layout.clampSplit(mouse, workarea, is_vertical)
    local t = (is_vertical and {p = "y", s = "height"}) or {p = "x", s = "width"}
    return util.clamp(mouse[t.p] - workarea[t.p], workarea.gap, workarea[t.s] - (workarea.gap * 2)) / workarea[t.s]
  end

  --[[
      Handles resizing of clients from mouse button (default Mod4 + right click).

      @param client: Actual client that is being resized.
      @param corner: String statement of the corner grabbed. I.E. "top_left", "bottom_right", etc...
      @param x: Unused but provides the current x pos of the mouse.
      @param y: Unused but provides the current y pos of the mouse.
    ]]
  function layout.mouse_resize_handler(client, corner, _, _)
    local tag = tostring(capi.screen[client.screen].selected_tag or awful.tag.selected(capi.mouse.screen))
    local tree = TREES[tag]

    -- Splits the string into array instance of the words.
    -- Corner will only ever be the corner, never the edge so no just right etc.
    local direction = {}
    for k, _ in string.gmatch(corner, "%a+") do table.insert(direction, k) end
    -- Gets the direction based on the word provided.
    -- It can only ever be 2 directions so only one check is needed.
    local bottom = direction[1] == "bottom"
    local right = direction[2] == "right"

    local client_node = tree.root:find(client)
    local horizontal = layout.getNodeByPullDirection(client_node, right, false)
    local vertical = layout.getNodeByPullDirection(client_node, bottom, true)

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
            horizontal.split = layout.clampSplit(_mouse, horizontal.workarea, false)
            horizontal:updateClients({andChildren = false, respect_client_borders = args.respect_client_borders})
          end

          if vertical then
            vertical.split = layout.clampSplit(_mouse, vertical.workarea, true)
            vertical:updateClients({andChildren = false, respect_client_borders = args.respect_client_borders})
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

function binaryTreeBuilder.mt.__call(...)
  return binaryTreeBuilder.build(...)
end

return setmetatable(binaryTreeBuilder, binaryTreeBuilder.mt)
