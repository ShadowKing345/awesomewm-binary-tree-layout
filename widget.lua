------------------------------------------------------------------------------------------
--
--  Builder that creates a widget used to see the layout direction.
--
------------------------------------------------------------------------------------------
local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local beautilful = require("beautiful")
local util = require(TREES.relative_path .. "/util")
local layout = require(TREES.relative_path)
local button = require("awful.button")
local timer = require("gears.timer")

local direction_indicator = {mt = {}}

-- Default style
local function defaultStyle()
  local style = {
    icons = {
      horizontal = gears.filesystem.get_configuration_dir() .. TREES.relative_path .. "horizontal_icon.svg",
      vertical = gears.filesystem.get_configuration_dir() .. TREES.relative_path .. "vertical_icon.svg",
    },
    tooltip = {
      padding = {vertical = 3, horizontal = 5},
      margin = 0,
      timeout = 0,
      font = "Sans 12",
      border_width = 2,
      set_position = nil,
      color = {border = "#404040", text = "#aaaaaa", wibox = "#202020"},
      shape = nil,
    },
    colors = {},
  }
  -- Gets merged with beautilful configs as first overwrite.
  return util.mergeTables(style, beautilful["binaryTreeLayoutWidget"] or {})
end

--[[
    Method used to generate string which the tooltip text get set to.

    @return: A string stating the direction the next split will occur on.
]]
local function defaultToolTipString()
  return string.format("Currently splitting in the %s direction", (BINARY_TREE_LAYOUT_GO_VERTICAL and "Vertical") or "Horizontal")
end

--[[
    Helper function to get the tooltip string.

    @param toolTipString: A function that when called will return a string or an object that will be turned into a string.
    @return: The string
]]
local function parse_string(toolTipString)
  return type(toolTipString) == "function" and toolTipString() or tostring(toolTipString)
end

-- mouse buttons
local defaultButtons = gears.table.join(button({}, 1, nil, function()
  TREES.widget:toggleDirection()
end))

--[[
    Creates a custom tooltip widget.

    @param style: The style that should be used.
    @return: A widget that acts like a tooltip.
]]
local function tooltip(style)
  local ttp = {wibox = wibox({type = "tooltip"}), tip = nil}
  local tb = wibox.widget.textbox()
  tb:set_align("center")

  ttp.widget = tb
  ttp.wibox:set_widget(tb)
  tb:set_font(style.font)

  ttp.wibox.visible = false
  ttp.wibox.ontop = true
  ttp.wibox.border_width = style.border_width
  ttp.wibox.border_color = style.color.border
  ttp.wibox.shape = style.shape
  ttp.wibox:set_bg(style.color.wibox)
  ttp.wibox:set_fg(style.color.text)

  function ttp:set_geometry()
    local wibox_sizes = self.wibox:geometry()
    local w, h = self.widget:get_preferred_size()
    local requested_width = w + 2 * style.padding.horizontal
    local requested_height = h + 2 * style.padding.vertical

    if wibox_sizes.width ~= requested_width or wibox_sizes.height ~= requested_height then
      self.wibox:geometry({width = requested_width, height = requested_height})
    end
  end

  local show_timer = timer({timeout = style.timeout})
  show_timer:connect_signal("timeout", function()
    ttp:set_geometry()
    if style.set_position then
      style.set_position(ttp.wibox)
    else
      awful.placement.under_mouse(ttp.wibox)
    end
    awful.placement.no_offscreen(ttp.wibox, {margin = style.margin})
    ttp.wibox.visible = true
    show_timer:stop()
  end)

  function ttp.show()
    if not show_timer.started then show_timer:start() end
  end

  function ttp.hide()
    if show_timer.started then show_timer:stop() end
    if ttp.wibox.visible then ttp.wibox.visible = false end
  end

  function ttp:set_text(text)
    if self.tip ~= text then
      self.widget:set_text(text)
      self.tip = text

      if self.wibox.visible then
        self:set_geometry()
        self.wibox.x = mouse.coords().x - self.wibox.width / 2
        awful.placement.no_offscreen(self.wibox, {margin = style.margin})
      end
    end
  end

  function ttp:add_to_object(object)
    object:connect_signal("mouse::enter", self.show)
    object:connect_signal("mouse::leave", self.hide)
  end

  return ttp
end

--[[
    Builder that returns a widget that displays the direction the next split will occur on.
    The actual widget is stored in a global variable to keep them synced.
    This docs is a copy of the __call docs since I'm not sure which one any lsp will see.

    @param args: Table of settings.
    @param style: Collection of different style options for the widget.
    @param toolTipString: A string or function that should return a string that the text for the tool tip will be set to.
    @return: Widget.
]]
function direction_indicator.new(args)
  args = args or {}
  args.style = util.mergeTables(defaultStyle(), args.style or {})
  args.toolTipString = args.toolTipString or defaultToolTipString
  args.buttons = gears.table.join(defaultButtons, args.buttons or {})

  local w = TREES.widget
  if not w then
    local imagebox = wibox.widget.imagebox((BINARY_TREE_LAYOUT_GO_VERTICAL and args.style.icons.vertical) or args.style.icons.horizontal)
    TREES.widget = wibox.widget({imagebox, layout = wibox.layout.fixed.horizontal})
    TREES.widget.imagebox = imagebox

    TREES.widget.style = args.style
    TREES.widget.ttp = tooltip(args.style.tooltip)
    TREES.widget.ttp:add_to_object(TREES.widget)
    TREES.widget.ttp:set_text(parse_string(args.toolTipString))

    TREES.widget:buttons(args.buttons)

    function TREES.widget:toggleDirection()
      layout.toggleDirection()
      self.imagebox.image = (BINARY_TREE_LAYOUT_GO_VERTICAL and self.style.icons.vertical) or self.style.icons.horizontal
      self.ttp:set_text(parse_string(args.toolTipString))
    end

    function TREES.widget:horizontal()
      layout.horizontal()
      self.imagebox.image = self.style.icons.horizontal
      self.ttp:set_text(parse_string(args.toolTipString))
    end

    function TREES.widget:vertical()
      layout.vertical()
      self.imagebox.image = self.style.icons.vertical
      self.ttp:set_text(parse_string(args.toolTipString))
    end

    w = TREES.widget
  end

  return w
end

--[[
    Builder that returns a widget that displays the direction the next split will occur on.
    The actual widget is stored in a global variable to keep them synced.

    @param args: Table of settings.
    @param style: Collection of different style options for the widget.
    @param toolTipString: A string or function that should return a string that the text for the tool tip will be set to.
    @return: Widget.
]]
function direction_indicator.mt:__call(...)
  return direction_indicator.new(...)
end

return setmetatable(direction_indicator, direction_indicator.mt)
