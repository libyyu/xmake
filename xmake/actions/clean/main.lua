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
-- @file        main.lua
--

-- imports
import("core.base.option")
import("core.base.task")
import("core.project.rule")
import("core.project.config")
import("core.base.global")
import("core.project.project")
import("core.platform.platform")

-- remove the given files or directories
function _remove(filedirs)

    -- done
    for _, filedir in ipairs(filedirs) do

        -- remove it first
        os.tryrm(filedir)
 
        -- remove it if the parent directory is empty
        local parentdir = path.directory(filedir)
        while parentdir and os.isdir(parentdir) and os.emptydir(parentdir) do
            os.tryrm(parentdir)
            parentdir = path.directory(parentdir)
        end
    end
end

-- do clean target 
function _do_clean_target(target)

    -- is phony?
    if target:isphony() then
        return 
    end

    -- remove the target file 
    _remove(target:targetfile()) 

    -- remove the target dependent file if exists
    _remove(target:dependfile()) 

    -- remove the symbol file 
    _remove(target:symbolfile()) 

    -- remove the c/c++ precompiled header file 
    _remove(target:pcoutputfile("c")) 
    _remove(target:pcoutputfile("cxx")) 

    -- remove the object files 
    _remove(target:objectfiles())

    -- remove the depend files 
    _remove(target:dependfiles())

    -- TODO remove the header files (deprecated)
    local _, dstheaders = target:headers()
    _remove(dstheaders) 

    -- remove all?
    if option.get("all") then 

        -- remove the config.h file
        _remove(target:configheader()) 
    end
end

-- on clean target 
function _on_clean_target(target)

    -- has been disabled?
    if target:get("enabled") == false then
        return 
    end

    -- build target with rules
    local done = false
    for _, r in ipairs(target:orderules()) do
        local on_clean = r:script("clean")
        if on_clean then
            on_clean(target, {origin = _do_clean_target})
            done = true
        end
    end
    if done then return end

    -- do clean
    _do_clean_target(target)
end

-- clean the given target files
function _clean_target(target)

    -- the target scripts
    local scripts =
    {
        target:script("clean_before")
    ,   function (target)

            -- has been disabled?
            if target:get("enabled") == false then
                return 
            end

            -- clean rules
            for _, r in ipairs(target:orderules()) do
                local before_clean = r:script("clean_before")
                if before_clean then
                    before_clean(target)
                end
            end
        end
    ,   target:script("clean", _on_clean_target)
    ,   function (target)

            -- has been disabled?
            if target:get("enabled") == false then
                return 
            end

            -- clean rules
            for _, r in ipairs(target:orderules()) do
                local after_clean = r:script("clean_after")
                if after_clean then
                    after_clean(target)
                end
            end
        end
    ,   target:script("clean_after")
    }

    -- run the target scripts
    for i = 1, 5 do
        local script = scripts[i]
        if script ~= nil then
            script(target, {origin = (i == 3 and _do_clean_target or nil)})
        end
    end
end

-- clean the given target and all dependent targets
function _clean_target_and_deps(target)

    -- this target have been finished?
    if _g.finished[target:name()] then
        return 
    end

    -- remove the target
    _clean_target(target) 
     
    -- exists the dependent targets?
    for _, dep in ipairs(target:get("deps")) do
        _clean_target_and_deps(project.target(dep))
    end

    -- finished
    _g.finished[target:name()] = true
end

-- clean target 
function _clean(targetname)

    -- clean the given target
    if targetname then
        _clean_target_and_deps(project.target(targetname)) 
    else
        -- clean all targets
        for _, target in pairs(project.targets()) do
            _clean_target_and_deps(target) 
        end
    end

    -- remove all
    if option.get("all") then 

        -- remove the configure directory
        _remove(config.directory())
    end
end

-- main
function main()

    -- get the target name
    local targetname = option.get("target")

    -- config it first
    task.run("config", {target = targetname, require = false})

    -- init finished states
    _g.finished = {}

    -- enter project directory
    local oldir = os.cd(project.directory())

    -- clean the current target
    _clean(targetname) 

    -- leave project directory
    os.cd(oldir)
end
