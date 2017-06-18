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

-- define language
language("swift")

    -- set source file kinds
    set_sourcekinds {sc = ".swift"}

    -- set source file flags
    set_sourceflags {sc = "scflags"}

    -- set target kinds
    set_targetkinds {binary = "sc-ld", static = "ar", shared = "sc-sh"}

    -- set target flags
    set_targetflags {binary = "ldflags", static = "arflags", shared = "shflags"}

    -- set mixing kinds
    set_mixingkinds("sc", "mm", "mxx", "cc", "cxx")

    -- on load
    on_load("load")

    -- set name flags
    set_nameflags 
    {
        object =
        {
            "config.includedirs"
        ,   "config.Frameworks"
        ,   "target.symbols"
        ,   "target.warnings"
        ,   "target.optimize:check"
        ,   "target.vectorexts:check"
        ,   "target.languages"
        ,   "target.includedirs"
        ,   "target.defines"
        ,   "target.undefines"
        ,   "target.frameworks"
        ,   "option.symbols"
        ,   "option.warnings"
        ,   "option.optimize:check"
        ,   "option.vectorexts:check"
        ,   "option.languages"
        ,   "option.includedirs"
        ,   "option.defines"
        ,   "option.undefines"
        ,   "option.defines_if_ok"
        ,   "option.undefines_if_ok"
        ,   "option.frameworks"
        ,   "platform.includedirs"
        ,   "platform.defines"
        ,   "platform.undefines"
        ,   "platform.frameworks"
        }
    ,   binary =
        {
            "config.linkdirs"
        ,   "target.linkdirs"
        ,   "target.rpathdirs"
        ,   "target.strip"
        ,   "target.symbols"
        ,   "option.strip"
        ,   "option.symbols"
        ,   "option.linkdirs"
        ,   "option.rpathdirs"
        ,   "platform.linkdirs"
        ,   "platform.rpathdirs"
        ,   "config.links"
        ,   "config.frameworks"
        ,   "target.links"
        ,   "target.frameworks"
        ,   "option.links"
        ,   "option.frameworks"
        ,   "platform.links"
        ,   "platform.frameworks"
        }
    ,   shared =
        {
            "config.linkdirs"
        ,   "target.linkdirs"
        ,   "target.strip"
        ,   "target.symbols"
        ,   "option.strip"
        ,   "option.symbols"
        ,   "option.linkdirs"
        ,   "platform.linkdirs"
        ,   "config.links"
        ,   "config.frameworks"
        ,   "target.links"
        ,   "target.frameworks"
        ,   "option.links"
        ,   "option.frameworks"
        ,   "platform.links"
        ,   "platform.frameworks"
        }
    ,   static = 
        {
            "target.strip"
        ,   "target.symbols"
        }
    }

    -- set menu
    set_menu {
                config = 
                {   
                  {                                                                            }
                , { nil, "sc",         "kv", nil,          "The Swift Compiler"                }
                , { nil, "sc-ld",      "kv", nil,          "The Swift Linker"                  }
                , { nil, "sc-sh",      "kv", nil,          "The Swift Shared Library Linker"   }

                , {                                                                            }
                , { nil, "links",      "kv", nil,          "The Link Libraries"                }
                , { nil, "linkdirs",   "kv", nil,          "The Link Search Directories"       }
                , { nil, "includedirs","kv", nil,          "The Include Search Directories"    }
                , { nil, "frameworks", "kv", nil,          "The Link Frameworks"               }
                }
            } 




