------------------------------------------------------------------------------------------
--
--  Builder that creates a widget used to see the layout direction.
--
------------------------------------------------------------------------------------------
local wibox = require("wibox")
local gears = require("gears")
local beautilful = require("beautiful")
local util = require(TREES.relative_path .. "/util")
local layout = require(TREES.relative_path)
local tooltip = require("awful.tooltip")
local button = require("awful.button")

local direction_indicator = {mt = {}}

-- Default style
local defaultStyle = {
    icons = {
        horizontal = gears.filesystem.get_configuration_dir() .. TREES.relative_path .. "horizontal_icon.svg",
        vertical = gears.filesystem.get_configuration_dir() .. TREES.relative_path .. "vertical_icon.svg",
    },
}
-- Gets merged with beautilful configs as first overwrite.
defaultStyle = util.mergeTables(l_style, beautilful["binaryTreeLayoutWidget"] or {})

--[[
    Method used to generate string which the tooltip text get set to.

    @return: A string stating the direction the next split will occur on.
]]
local function l_toolTipString()
    return string.format("Currently splitting in the %s direction", (BINARY_TREE_LAYOUT_GO_VERTICAL and "Vertical") or "Horizontal")
end

-- mouse buttons
local l_buttons = gears.table.join(button({}, 1, nil, function()
    TREES.widget:toggleDirection()
end))

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
    local style = util.mergeTables(defaultStyle, args.style or {})
    local toolTipString = args.toolTipString or l_toolTipString
    local buttons = gears.table.join(l_buttons, args.buttons or {})

    local w = TREES.widget
    if not w then
        TREES.widget = wibox.widget({
            {
                id = "image",
                image = (BINARY_TREE_LAYOUT_GO_VERTICAL and style.icons.vertical) or style.icons.horizontal,
                widget = wibox.widget.imagebox,
            },
            layout = wibox.layout.fixed.horizontal,
        })

        TREES.widget.style = style

        function TREES.widget:toggleDirection()
            self.children[1].image = (BINARY_TREE_LAYOUT_GO_VERTICAL and self.style.icons.horizontal) or self.style.icons.vertical
            layout.toggleDirection()
        end

        function TREES.widget:horizontal()
            self.children[1].image = self.style.icons.horizontal
            layout.horizontal()
        end

        function TREES.widget:vertical()
            self.children[1].image = self.style.icons.vertical
           layout.vertical()
        end

        local w_tooltip = tooltip({text = (type(toolTipString) == "function" and toolTipString()) or tostring(toolTipString)})
        w_tooltip.bg = beautilful.bg_normal

        w_tooltip:add_to_object(TREES.widget)

        TREES.widget:connect_signal("mouse::enter", function()
            w_tooltip.text = (type(toolTipString) == "function" and toolTipString()) or tostring(toolTipString)
        end)

        TREES.widget:buttons(buttons)

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
