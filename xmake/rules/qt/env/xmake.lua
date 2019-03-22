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

-- define rule: environment
rule("qt.env")

    -- before load
    before_load(function (target)
        import("detect.sdks.find_qt")
        if not target:data("qt") then
            target:data_set("qt", assert(find_qt(nil, {verbose = true}), "Qt SDK not found!"))
        end
    end)

    -- before run
    before_run(function (target)
        local qt = target:data("qt")
        if qt and (is_plat("windows") or (is_plat("mingw") and is_host("windows"))) then
            os.addenv("PATH", qt.bindir)
        end
    end)

    -- clean files
    after_clean(function (target)
        for _, file in ipairs(target:data("qt.cleanfiles")) do
            os.rm(file)
        end
        target:data_set("qt.cleanfiles", nil)
    end)

