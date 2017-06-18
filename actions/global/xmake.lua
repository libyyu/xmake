--!The Make-like Build Utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2017, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        xmake.lua
--

-- define task
task("global")

    -- set category
    set_category("action")

    -- on run
    on_run("main")

    -- set menu
    set_menu {
                -- usage
                usage = "xmake global|g [options] [target]"

                -- description
            ,   description = "Configure the global options for xmake."

                -- xmake g
            ,   shortname = 'g'

                -- options
            ,   options = 
                {
                    {'c', "clean",      "k", nil,         "Clean the cached configure and configure all again."           }

                ,   {}

                ,   {nil, "make",       "kv", "auto",   "Set the make path."                                        }
                ,   {nil, "ccache",     "kv", "auto",   "Enable or disable the c/c++ compiler cache." 
                                                    ,   "    --ccache=[y|n]"                                        }

                ,   {}
                ,   {nil, "dg",         "kv", "auto",   "The Debugger"                                              }
                ,   {}

                    -- show platform menu options
                ,   function () 

                        -- import platform menu
                        import("core.platform.menu")

                        -- get global menu options
                        return menu.options("global")
                    end

                }
            }



