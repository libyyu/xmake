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
-- @file        has_flags.lua
--

-- imports
import("core.base.option")
import("core.project.config")
import("lib.detect.cache")
import("lib.detect.find_tool")

-- has the given flags for the current tool?
--
-- @param name      the tool name
-- @param flags     the flags
-- @param opt       the argument options, .e.g {verbose = false, program = "", toolkind = "[cc|cxx|ld|ar|sh|gc|rc|dc|mm|mxx]"}
--
-- @return          true or false
--
-- @code
-- local ok = has_flags("clang", "-g")
-- local ok = has_flags("clang", {"-g", "-O0"}, {program = "xcrun -sdk macosx clang"})
-- local ok = has_flags("clang", "-g", {toolkind = "cxx"})
-- @endcode
--
function main(name, flags, opt)

    -- init options
    opt = opt or {}

    -- find tool program and version first
    opt.version = true
    local tool = find_tool(name, opt)
    if not tool then
        return false
    end

    -- wrap flags
    flags = table.wrap(flags)

    -- split flag group, .e.g "-I /xxx" => {"-I", "/xxx"}
    local results = {}
    for _, flag in ipairs(flags) do
        flag = flag:trim()
        if #flag > 0 then
            if flag:find(" ", 1, true) then
                table.join2(results, os.argv(flag))
            else
                table.insert(results, flag)
            end
        end
    end
    flags = results

    -- init tool
    opt.toolname   = tool.name
    opt.program    = tool.program
    opt.programver = tool.version

    -- get tool arch 
    --
    -- some tools select arch by path environment, not be flags, .e.g cl.exe of msvc)
    -- so, it will affect the cache result
    --
    local arch = config.get("arch") or os.arch()

    -- init cache key
    local key = tool.program .. "_" .. (tool.version or "") .. "_" .. (opt.toolkind or "") .. "_" .. table.concat(flags, " ") .. "_" .. arch
    
    -- @note avoid detect the same program in the same time if running in the coroutine (.e.g ccache)
    local coroutine_running = coroutine.running()
    if coroutine_running then
        while _g._checking ~= nil and _g._checking == key do
            local curdir = os.curdir()
            coroutine.yield()
            os.cd(curdir)
        end
    end

    -- attempt to get result from cache first
    local cacheinfo = cache.load("lib.detect.has_flags") 
    local result = cacheinfo[key]
    if result ~= nil then
        return result
    end

    -- detect.tools.xxx.has_flags(flags, opt)?
    _g._checking = ifelse(coroutine_running, key, nil)
    local hasflags = import("detect.tools." .. tool.name .. ".has_flags", {try = true})
    local errors = nil
    if hasflags then
        result, errors = hasflags(flags, opt)
    else
        result = try { function () os.runv(tool.program, flags); return true end, catch { function (errs) errors = errs end }}
    end
    _g._checking = nil

    -- trace
    if option.get("verbose") or option.get("diagnosis") or opt.verbose then
        cprint("checking for the flags(%s) %s ... %s", path.filename(tool.program), table.concat(flags, " "), ifelse(result, "${green}ok", "${red}no"))
    end
    if errors and #errors > 0 and option.get("diagnosis") then
        cprint("${yellow}checkinfo:${clear dim} %s", errors:trim())
    end

    -- save result to cache
    cacheinfo[key] = ifelse(result, result, false)
    cache.save("lib.detect.has_flags", cacheinfo)

    -- ok?
    return result
end

