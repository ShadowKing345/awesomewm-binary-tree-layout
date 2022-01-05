------------------------------------------------------------------------------------------
--
--  Builder that creates a widget used to see the layout direction.
--
------------------------------------------------------------------------------------------
local wiboxLib = require("wibox")
local awful = require("awful")
local gears = require("gears")
local gtable = require("gears.table")
local beautilful = require("beautiful")
local relative_path = TREES.relative_path
local layout = require(relative_path)
local button = require("awful.button")

local widget = {mt = {}}

-- Default style
local function defaultStyle()
  local style = {
    icons = {
      horizontal = gears.filesystem.get_configuration_dir() .. relative_path:gsub("[.]", "/") .. "/horizontal_icon.svg",
      vertical = gears.filesystem.get_configuration_dir() .. relative_path:gsub("[.]", "/") .. "/vertical_icon.svg",
    },
    tooltip = {
      padding = {vertical = 3, horizontal = 5},
      margin = 0,
      timeout = 0,
      font = "Sans 12",
      border_width = 2,
      set_position = nil,
      color = {border = "#404040", text = "#aaaaaa", wiboxLib = "#202020"},
      shape = nil,
    },
    colors = {},
  }

  return gtable.merge(style, beautilful["binaryTreeLayoutWidget"] or {})
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
  widget:toggleDirection()
end))

--[[
  Creates a custom tooltip widget.

  @param style: The style that should be used.
  @return: A widget that acts like a tooltip.
]]
local function tooltip(style)
  local wibox = wiboxLib {
    visible = false,
    ontop = true,
    border_width = style.border_width,
    border_color = style.color.border,
    shape = style.shape,
    bg = style.color.wibox,
    fg = style.color.text,
  }

  wibox:set_bg(style.color.wibox)
  wibox:set_fg(style.color.text)

  local tb = wiboxLib.widget.textbox()
  tb:set_align("center")

  wibox:set_widget(tb)
  tb:set_font(style.font)

  local ttp = {wibox = wibox, tip = nil, widget = tb}
  function ttp:set_geometry()
    local wibox_sizes = self.wibox:geometry()
    local w, h = self.widget:get_preferred_size()
    local requested_width = w + 2 * style.padding.horizontal
    local requested_height = h + 2 * style.padding.vertical

    if wibox_sizes.width ~= requested_width or wibox_sizes.height ~= requested_height then
      self.wibox:geometry({width = requested_width, height = requested_height})
    end
  end

  function ttp.show()
    ttp.wibox.visible = true
  end

  function ttp.hide()
    ttp.wibox.visible = false
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

-- Toggles direction.
function widget:toggleDirection()
  if not self.wibox then self:init() end
  layout.toggleDirection()
  self.imagebox.image = (BINARY_TREE_LAYOUT_GO_VERTICAL and self.style.icons.vertical) or self.style.icons.horizontal
  self.ttp:set_text(parse_string(self.args.toolTipString))
end

-- Toggles direction to be horizontal.
function widget:horizontal()
  if not self.wibox then self:init() end
  layout.horizontal()
  self.imagebox.image = self.style.icons.horizontal
  self.ttp:set_text(parse_string(self.args.toolTipString))
end

-- Toggles direction to be vertical.
function widget:vertical()
  if not self.wibox then self:init() end
  layout.vertical()
  self.imagebox.image = self.style.icons.vertical
  self.ttp:set_text(parse_string(self.args.toolTipString))
end

-- Widget initialiser. Will generate the correct widget from the data set in the args variable.
function widget:init()
  local wibox = {}
  local imagebox = wiboxLib.widget.imagebox((BINARY_TREE_LAYOUT_GO_VERTICAL and self.style.icons.vertical) or self.style.icons.horizontal)
  wibox = wiboxLib.widget({imagebox, layout = wiboxLib.layout.fixed.horizontal})
  self.imagebox = imagebox

  self.ttp = tooltip(self.style.tooltip)
  self.ttp:add_to_object(wibox)
  self.ttp:set_text(parse_string(self.args.toolTipString))

  wibox:buttons(self.args.buttons)

  self.wibox = wibox
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
function widget.new(args)
  args = args or {}
  widget.args = args
  widget.args.buttons = gears.table.join(defaultButtons, args.buttons or {})
  widget.style = gtable.merge(defaultStyle(), args.style or {})
  widget.toolTipString = args.toolTipString or defaultToolTipString

  if not widget.wibox then widget:init() end
  return widget.wibox
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
function widget.mt:__call(...)
  return widget.new(...)
end

return setmetatable(widget, widget.mt)
