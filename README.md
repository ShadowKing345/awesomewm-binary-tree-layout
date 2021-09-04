# Binary Tree Layout for Awesome Window Manager

<p align="center">
  <img src="icon.svg" alt="icon.svg or a binary tree representation" style="height:400px;"/>
</p>
  
---
The main goal of this micro project is to create a layout system for the Awesome Window Manager (awesomewm for short) that primairly uses a binary tree as its method of storage and manipulation of client windows.

## Table of Contents
[Intoduction](#introduction)
[How Binary Trees Are Used](#how-binary-trees-are-used)
[Why Use A Binary Tree](#why-use-a-binary-tree)
[Wait Where Did I Hear / See This?](#wait-where-did-i-hear-see-this)
[Installation Guide](#installation-guide)

## Introduction
A tree is a data storage method that when graphed looks similar to a tree specifically its roots (cause most of the time you view it upsidedown). From the root node of the tree a branching path is formed that will eventually end on a leaf (a node that contains no children). Binary trees only contain two nodes, often called left and right node.

Commonly trees are used in searching algorithums due to their speed, in a compression method, or for AI in the form of a behaviour tree. In this case binary trees are not used for speeding up searches rather for controlling the splits in sections of the screen.

## How Binary Trees Are Used
To begin with a node in this tree can be both a leaf and a joining node. The way to tell the difference between a branch and leaf is that a leaf will contain the clients information and no children while a branch just has 2 children nodes which are not null/empty. While rare in some cases a branch can have a single child node. If this is true the node should be considered as unstable.

From there certain information about the node is passed along the tree. This information includes:
- Workarea: The boundaries to which a node can hold its content in. (This includes padding refered to as gap in code)
- Split percentage: The percentage amount the split is from the "left" side of the node. (Only used in branches)
- Direction: The direction the split occurs on, Vertical or Horizontal. (Only used in branches)
- Client: The actual client.

With this information the are gets subdivided and the position of the clients are calculated and set resulting in the layout.

Bellow is an example layout and the resuling binary tree.
```
Example Layout:                                                           Resulting Tree:       Key:
+----------------------------------+--------+--------+----------------+         Tree              Number: Identifier of client. (A leaf)
|                                  |        |        |                |          |                *V: Vertical Node.
|                                  |        |    5   |       3        |         Root              *: Horizontal Node.
|                                  |        +--------+----------------+        /   \              / or \: Branch.
|                                  |        |        |                |       1     *V            Root: Starting point for the tree.
|                                  |        |        |                |           /   \
|                                  |   4    |    7   |       6        |          /     2
|               1                  +--------+--------+----------------+         *
|                                  |                                  |       /   \
|                                  |                                  |      /     *V
|                                  |                                  |     *     /  \
|                                  |                 2                |    / \   6    3
|                                  |                                  |   4   *V
|                                  |                                  |      /  \
+----------------------------------+----------------------------------+     5    7
```
## Why Use A Binary Tree
One of the limitations that is commonly found in other forms of layouts is attempting to add a new client and it commonly appearing in the smallest point on the screen, or the largest point. Furthermore, resizing individual clients can result in all the clients in the same row / column also getting resized if that is even possible to do. With a binary tree some of these limitations are reduced.

For example (using the diagram above), if you want to put a client right under application 1 to be vertical simply set the layout to do a vertical split and create the new client. The result will be that area 1 gets cut in half with client 1 being put on top (left) and the new application being put on the bottom split (right). Furthermore, if you want to increase the size of client 2 area start a resize event (mouse drag or keyboard keys (wip)) and drag in the way you want to increase. All the other splits will adjust to respect the new sizes while maintaining the position of the split.

## Wait Where Did I Hear / See This Before?
If you have used text editors such as Neovim, Vim, or Vi, IDE such as Visaul Studio, VSCode, or any Jetbrains IDE, Window managers such as I3, then you most likely have either used or heared of such a method of spliting before.

## Instalation Guide
Warning: This guide assumed you have some knowledge of basic programing, the Lua language, and awesomewm API. If something does not quite make sense try to search for it as I attempted to not use to many complex programming theory.

### Prerequisites:
- Awesome Version 4.3. Not an actual requirement just the development version incase it breaks in a later version.
- None. Assuming I did not accidentally call something that should not be called it should be a standalone addition.

### Step 1: Clone the repo
Clone the repo into a config directory (commonly `$XDG_CONFIG_HOME/awesome/` assuming you made your own custom config)

```shell
git clone https://github.com/ShadowKing345/awesomewm-binary-tree-layout.git binaryTreeLayout
```

Remember the relative path of where the folder is put.

### Step 2: Requireing the file in your rc.lua file.
In your `rc.lua` you must call the require for the layout builder at least once.

```lua
require("binaryTreeLayout") --change to be the correct relative path for you.
```

This is because some logic is performed before the creation of the layout that only occurs during the require call.
You can simply store the resulting table from the require method for later use.

```lua
local binaryTreeLayoutBuilder = require("binaryTreeLayout") --change to be the correct relative path for you.
```
This variable will be used later on in the examples.

If you by any chance call this after any other feature provided such as the widget it will result in a file not found as the internal require calls fail to find other lua files used.

### Step 3: Building the layout.
In order to actually get the layout you will have to call the self build method , providing optional arguments as needed.

```lua
awful.layout.layouts = {
  -- ... Other layouts.
  
  binaryTreeLayoutBuilder({}),
  
  -- ... Other layouts.
 }
 ```
 
 Leaving the table (`{}`) empty will simply result in the default settings being set and is recommended for first time users.
 
 ### Step 4: (Optional) Setting up notifications or the widget.
 Here we will setup the direction change notifications and the widget. If you dont want to do any one you can skip the section.
 
 #### Sending Notification.
 When building the layout one of the arguments that can be passed is send_notifications. If set to true it will result in the change split direction methods (explained later on) to send a notification.

```lua
awful.layout.layouts = {
  -- ... Other layouts.
  
  binaryTreeLayoutBuilder({send_notifications=true}),
  
  -- ... Other layouts.
}
```

#### The Widget.
A widget is provided that allows you to view the next split direction as well as toggle it with a mouse click. You can easily find it with the relative path plus widget and will return a builder that can be called to create the widget with some settings.
 
```lua
local binaryTreeLayoutWidgetBuilder = require("binaryTreeLayout.widget")

-- somewhere in your taskbar (for example).

binaryTreeLayoutWidgetBuilder({}) -- Will return the actual widget.
```

The widget itself provides some methods to control the split direction and the image as well as tooltip text.

```lua
-- widget is not a defined variable fyi. this is just an example.

widget:toggleDirection() -- Toggles the direction and if set send a notification.

-- Note the : is important as a null pointer error will be sent telling you that self is null if you use a dot instead.
```

One the widget is loaded and showing simply clicking it will change the direction and change the icon used.

### Controlling The Direction.
The layout builder provides 3 methods to control the direction.
- horizontal: Sets to split horizontally.
- vertical: Sets to split vertically.
- toggleDirection: Toggles between the two split directions.

These methods can be used to control the direction of the split from code. For example a keybinding can be created to toggle between the two directions.

```lua
-- This is an example function you can put inside of awful.key.
function ()
  binaryTreeLayoutBuilder.toggleDirection() -- Toggles between the two directions.
end
```

If you want to get or set the direction of the next split, a global variable is set in order to provide syncing between tags and screens.

```lua
BINARY_TREE_LAYOUT_GO_VERTICAL 
```

Please be awear that it is recommended to use the provided widget and methods to control the direction of the splits. However if you are confortable writing your own code then the method of changing the direction of the split has been made as simple as possible and documented as much as possible.
