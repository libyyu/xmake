-- set name
set_name("widgetapp_qt")

-- set description
set_description("The Widget Application (Qt)")

-- set project directory
set_projectdir("project")

-- add macros
add_macros("targetname", "$(targetname)")

-- add macro files
add_macrofiles("xmake.lua")

