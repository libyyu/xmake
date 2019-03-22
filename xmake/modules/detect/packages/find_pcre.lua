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
-- @file        find_pcre.lua
--

-- imports
import("lib.detect.vcpkg")
import("lib.detect.pkg_config")

-- find pcre 
--
-- @param opt   the package options. e.g. see the options of find_package()
--
-- @return      see the return value of find_package()
--
function main(opt)

    -- find package from vcpkg first
    local result = vcpkg.find("pcre", opt)
    if result then
        local links = {}
        for _, link in ipairs(result.links) do
            links[link] = true
        end
        for _, width in ipairs({"", "16", "32"}) do
            if links["pcre" .. width] then
                result.links   = {"pcre" .. width}
                return result
            end
        end
    end

    -- find package from the current host platform
    if opt.plat == os.host() and opt.arch == os.arch() then
        for _, width in ipairs({"", "16", "32"}) do
            local result = pkg_config.find("libpcre" .. width, {brewhint = "pcre"})
            if result then
                return result
            end
        end
    end
end
