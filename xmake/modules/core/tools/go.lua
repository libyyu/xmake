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
-- Copyright (C) 2015 - 2019, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        go.lua
--

-- imports
import("core.base.option")
import("core.project.config")
import("core.project.project")

-- init it
function init(self)
    
    -- init arflags
    self:set("arflags", "grc")

    -- init the file formats
    self:set("formats", { static = "$(name).a" })

    -- init buildmodes
    self:set("buildmodes",
    {
        ["object:sources"] = true
    })
end

-- make the optimize flag
function nf_optimize(self, level)

    -- the maps
    local maps = 
    {   
        none = "-N"
    }

    -- make it
    return maps[level] 
end

-- make the symbol flag
function nf_symbol(self, level, target, mapkind)

    -- only for compiler
    if mapkind ~= "object" then
        return 
    end

    -- the maps
    local maps = 
    {   
        debug = "-E"
    }

    -- make it
    return maps[level] 
end

-- make the strip flag
function nf_strip(self, level)

    -- the maps
    local maps = 
    {   
        debug = "-s"
    ,   all   = "-s"
    }

    -- make it
    return maps[level] 
end

-- make the includedir flag
function nf_includedir(self, dir)
    return "-I " .. os.args(dir)
end

-- make the linkdir flag
function nf_linkdir(self, dir)
    return "-L " .. os.args(dir)
end

-- make the link arguments list
function linkargv(self, objectfiles, targetkind, targetfile, flags)

    -- make it
    if targetkind == "static" then
        return self:program(), table.join("tool", "pack", flags, targetfile, objectfiles)
    else
        return self:program(), table.join("tool", "link", flags, "-o", targetfile, objectfiles)
    end
end

-- link the target file
function link(self, objectfiles, targetkind, targetfile, flags)

    -- ensure the target directory
    os.mkdir(path.directory(targetfile))

    -- link it
    os.runv(linkargv(self, objectfiles, targetkind, targetfile, flags))
end

-- make the complie arguments list
function compargv(self, sourcefiles, objectfile, flags)
    return self:program(), table.join("tool", "compile", flags, "-o", objectfile, sourcefiles)
end

-- complie the source file
function compile(self, sourcefiles, objectfile, dependinfo, flags)

    -- ensure the object directory
    os.mkdir(path.directory(objectfile))

    -- compile it
    os.runv(compargv(self, sourcefiles, objectfile, flags))
end

