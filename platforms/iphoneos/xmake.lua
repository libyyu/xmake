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

-- define platform
platform("iphoneos")

    -- set os
    set_os("ios")

    -- set hosts
    set_hosts("macosx")

    -- set archs
    set_archs("armv7", "armv7s", "arm64", "i386", "x86_64")

    -- set tooldirs
    set_tooldirs("/usr/bin", "/usr/local/bin", "/opt/bin", "/opt/local/bin")

    -- on check
    on_check("check")

    -- on load
    on_load("load")

    -- set menu
    set_menu {
                config = 
                {   
                    {}   
                ,   {nil, "xcode_dir",      "kv", "auto",       "the xcode application directory"   }
                ,   {nil, "xcode_sdkver",   "kv", "auto",       "the sdk version for xcode"         }
                ,   {nil, "target_minver",  "kv", "auto",       "the target minimal version"        }
                ,   {}
                ,   {nil, "mobileprovision","kv", "auto",       "The Provisioning Profile File"     }
                ,   {nil, "codesign",       "kv", "auto",       "The Code Signing Indentity"        }
                ,   {nil, "entitlements",   "kv", "auto",       "The Code Signing Entitlements"     }
                }

            ,   global = 
                {   
                    {}
                ,   {nil, "xcode_dir",      "kv", "auto",       "the xcode application directory"   }
                ,   {}
                ,   {nil, "mobileprovision","kv", "auto",       "The Provisioning Profile File"     }
                ,   {nil, "codesign",       "kv", "auto",       "The Code Signing Indentity"        }
                ,   {nil, "entitlements",   "kv", "auto",       "The Code Signing Entitlements"     }
                }
            }






