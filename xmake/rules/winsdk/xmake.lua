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

-- define rule: application
rule("win.sdk.application")

    -- add deps
    add_deps("win.sdk.dotnet")

    -- after load
    after_load(function (target)

        -- set kind: binary
        target:set("kind", "binary")

        -- set subsystem: windows
        local subsystem = false
        for _, ldflag in ipairs(target:get("ldflags")) do
            ldflag = ldflag:lower()
            if ldflag:find("[/%-]subsystem:") then
                subsystem = true
                break
            end
        end
        if not subsystem then
            target:add("ldflags", "-subsystem:windows", {force = true})
        end

        -- add links
        target:add("links", "kernel32", "user32", "gdi32", "winspool", "comdlg32", "advapi32")
        target:add("links", "shell32", "ole32", "oleaut32", "uuid", "odbc32", "odbccp32", "comctl32")
        target:add("links", "cfgmgr32", "comdlg32", "setupapi", "strsafe", "shlwapi")
    end)