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
-- @file        main.lua
--

-- imports
import("core.base.option")
import("core.base.task")
import("core.project.config")
import("core.base.global")
import("core.project.project")
import("core.platform.platform")
import("core.platform.environment")
import("devel.debugger")

-- run target 
function _do_run_target(target)
    if target:targetkind() == "binary" then

        -- get the absolute target file path
        local targetfile = path.absolute(target:targetfile())

        -- enter the target directory
        local oldir = os.cd(path.directory(target:targetfile()))

        -- add search directories for all dependent shared libraries on windows
        if is_plat("windows") or (is_plat("mingw") and is_host("windows")) then
            local searchdirs = {}
            for _, linkdir in ipairs(target:get("linkdirs")) do
                if not searchdirs[linkdir] then
                    searchdirs[linkdir] = true
                    os.addenv("PATH", linkdir)
                end
            end
            for _, dep in ipairs(target:orderdeps()) do
                if dep:targetkind() == "shared" then
                    local depdir = dep:targetdir()
                    if not path.is_absolute(depdir) then
                        depdir = path.absolute(depdir, os.projectdir())
                    end
                    if not searchdirs[depdir] then
                        searchdirs[depdir] = true
                        os.addenv("PATH", depdir)
                    end
                end
            end
        end

        -- debugging?
        if option.get("debug") then
            debugger.run(targetfile, option.get("arguments"))
        else
            os.execv(targetfile, option.get("arguments"))
        end

        -- restore the previous directory
        os.cd(oldir)
    end
end

-- run target 
function _on_run_target(target)

    -- has been disabled?
    if target:get("enabled") == false then
        return 
    end

    -- build target with rules
    local done = false
    for _, r in ipairs(target:orderules()) do
        local on_run = r:script("run")
        if on_run then
            on_run(target, {origin = _do_run_target})
            done = true
        end
    end
    if done then return end

    -- do run
    _do_run_target(target)
end

-- run the given target 
function _run(target)

    -- the target scripts
    local scripts =
    {
        target:script("run_before")
    ,   function (target)

            -- has been disabled?
            if target:get("enabled") == false then
                return 
            end

            -- run rules
            for _, r in ipairs(target:orderules()) do
                local before_run = r:script("run_before")
                if before_run then
                    before_run(target)
                end
            end
        end
    ,   target:script("run", _on_run_target)
    ,   function (target)

            -- has been disabled?
            if target:get("enabled") == false then
                return 
            end

            -- run rules
            for _, r in ipairs(target:orderules()) do
                local after_run = r:script("run_after")
                if after_run then
                    after_run(target)
                end
            end
        end
    ,   target:script("run_after")
    }

    -- run the target scripts
    for i = 1, 5 do
        local script = scripts[i]
        if script ~= nil then
            script(target, {origin = (i == 3 and _do_run_target or nil)})
        end
    end
end

-- run the all dependent targets
function _run_deps(target)

    -- run target deps
    for _, dep in ipairs(target:orderdeps()) do
        _run(dep)
    end
end

-- main
function main()

    -- get the target name
    local targetname = option.get("target")

    -- build it first
    task.run("build", {target = targetname, all = option.get("all")})

    -- enter project directory
    local oldir = os.cd(project.directory())

    -- enter the running environment
    environment.enter("run")

    -- run the given target?
    if targetname then
        _run_deps(project.target(targetname))
        _run(project.target(targetname))
    else
        -- run default or all binary targets
        for _, target in pairs(project.targets()) do
            local default = target:get("default")
            if (default == nil or default == true or option.get("all")) and target:get("kind") == "binary" then
                _run_deps(target)
                _run(target)
            end
        end
    end

    -- leave the running environment
    environment.leave("run")

    -- leave project directory
    os.cd(oldir)
end

