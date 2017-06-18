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
-- @file        load.lua
--

-- imports
import("core.project.config")

-- load it
function main()

    -- init the file formats
    _g.formats          = {}
    _g.formats.static   = {"lib",   ".a"}
    _g.formats.object   = {"",      ".o"}
    _g.formats.shared   = {"lib",   ".so"}
    _g.formats.binary   = {"",      ".exe"}
    _g.formats.symbol   = {"",      ".pdb"}

    -- init flags for architecture
    local archflags = nil
    local arch = config.get("arch")
    if arch then
        if arch == "x86_64" then archflags = "-m64"
        elseif arch == "i386" then archflags = "-m32"
        else archflags = "-arch " .. arch
        end
    end
    _g.cxflags = { archflags }
    _g.asflags = { archflags }
    _g.ldflags = { archflags }
    _g.shflags = { archflags }

    -- init linkdirs and includedirs
    local sdkdir = config.get("sdk") 
    if sdkdir then
        _g.includedirs = {path.join(sdkdir, "include")}
        _g.linkdirs    = {path.join(sdkdir, "lib")}
    end

    -- ok
    return _g
end


