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
-- @file        debugger.lua
--

-- define module
local debugger = debugger or {}

-- load modules
local io        = require("base/io")
local path      = require("base/path")
local utils     = require("base/utils")
local table     = require("base/table")
local string    = require("base/string")
local config    = require("project/config")
local sandbox   = require("sandbox/sandbox")
local platform  = require("platform/platform")
local tool      = require("tool/tool")

-- get the current tool
function debugger:_tool()

    -- get it
    return self._TOOL
end

-- load the debugger 
function debugger.load()

    -- get it directly from cache dirst
    if debugger._INSTANCE then
        return debugger._INSTANCE
    end

    -- new instance
    local instance = table.inherit(debugger)

    -- load the debugger tool 
    local result, errors = tool.load("dg")
    if not result then 
        return nil, errors
    end
        
    -- save tool
    instance._TOOL = result

    -- save this instance
    debugger._INSTANCE = instance

    -- ok
    return instance
end

-- get properties of the tool
function debugger:get(name)

    -- get it
    return self:_tool().get(name)
end

-- run the debugged program with arguments
function debugger:run(shellname, argv)

    -- run it
    return sandbox.load(self:_tool().run, shellname, argv)
end

-- return module
return debugger
