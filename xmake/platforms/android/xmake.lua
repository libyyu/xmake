--!A cross-platform build utility based on Lua
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
-- Copyright (C) 2015 - 2018, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        xmake.lua
--

-- define platform
platform("android")

    -- set os
    set_os("android")

    -- set hosts
    set_hosts("macosx", "linux", "windows")

    -- set archs
    set_archs("armv5te", "armv7-a", "arm64-v8a", "mips")

    -- set formats
    set_formats {static = "lib$(name).a", object = "$(name).o", shared = "lib$(name).so", symbol = "$(name).sym"}

    -- on check
    on_check("check")

    -- on load
    on_load("load")

    -- set menu
    set_menu {
                config = 
                {   
                    {category = "Android NDK Configuration"                               }
                ,   {nil, "ndk",            "kv", nil,          "The NDK Directory"       }
                ,   {nil, "ndk_sdkver",     "kv", "auto",       "The SDK Version for NDK" }
                }

            ,   global = 
                {   
                    {}
                ,   {nil, "ndk",            "kv", nil,          "The NDK Directory"       }
                ,   {nil, "ndk_sdkver",     "kv", "auto",       "The SDK Version for NDK" }
                }
            }



