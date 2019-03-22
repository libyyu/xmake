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
import("core.project.config")
import("core.base.global")
import("core.project.project")
import("core.platform.platform")
import("core.project.cache")
import("lib.detect.cache", {alias = "detectcache"})
import("scangen")
import("menuconf", {alias = "menuconf_show"})
import("configfiles", {alias = "generate_configfiles"})
import("configheader", {alias = "generate_configheader"})
import("actions.require.install", {alias = "install_requires", rootdir = os.programdir()})

-- filter option 
function _option_filter(name)
    local options = 
    {
        target      = true
    ,   file        = true
    ,   root        = true
    ,   yes         = true
    ,   quiet       = true
    ,   profile     = true
    ,   project     = true
    ,   verbose     = true
    ,   diagnosis   = true
    ,   require     = true
    }
    return not options[name]
end

-- host changed?
function _host_changed(targetname)
    return os.host() ~= config.read("host", targetname)
end

-- need check
function _need_check(changed)

    -- clean?
    if not changed then
        changed = option.get("clean")
    end

    -- get the current mtimes 
    local mtimes = project.mtimes()

    -- get the previous mtimes 
    local configcache = cache("local.config")
    if not changed then
        local mtimes_prev = configcache:get("mtimes")
        if mtimes_prev then 

            -- check for all project files
            for file, mtime in pairs(mtimes) do

                -- modified? reconfig and rebuild it
                local mtime_prev = mtimes_prev[file]
                if not mtime_prev or mtime > mtime_prev then
                    changed = true
                    break
                end
            end
        end
    end

    -- update mtimes
    configcache:set("mtimes", mtimes)

    -- changed?
    return changed
end

-- check dependent target
function _check_target_deps(target)

    -- check 
    for _, depname in ipairs(target:get("deps")) do

        -- check dependent target name
        assert(depname ~= target:name(), "the target(%s) cannot depend self!", depname)

        -- get dependent target
        local deptarget = project.target(depname)

        -- check dependent target name
        assert(deptarget, "unknown target(%s) for %s.deps!", depname, target:name())

        -- check the dependent targets
        _check_target_deps(deptarget)
    end
end

-- check target
function _check_target(targetname)

    -- check
    assert(targetname)

    -- all?
    if targetname == "all" then

        -- check the dependent targets
        for _, target in pairs(project.targets()) do
            _check_target_deps(target)
        end
    else

        -- get target
        local target = project.target(targetname)

        -- check target name
        assert(target, "unknown target: %s", targetname)

        -- check the dependent targets
        _check_target_deps(target)
    end
end

-- main
function main()

    -- avoid to run this task repeatly
    if _g.configured then return end
    _g.configured = true

    -- scan project and generate it if xmake.lua not exists
    if not os.isfile(project.file()) then

        -- need some tips?
        local autogen = true
        if not option.get("quiet") and not option.get("yes") then

            -- show tips
            cprint("${bright color.warning}note: ${clear}xmake.lua not found, try generating it (pass -y to skip confirm)?")
            cprint("please input: n (y/n)")

            -- get answer
            io.flush()
            if io.read() ~= 'y' then
                autogen = false
            end
        end

        -- do not generate it
        if not autogen then
            os.exit() 
        end

        -- scan and generate it automatically
        scangen()
    end

    -- enter menu config
    if option.get("menu") then
        menuconf_show()
    end

    -- the target name
    local targetname = option.get("target") or "all"

    -- get config cache
    local configcache = cache("local.config")

    -- load the project configure
    --
    -- priority: option > option_cache > global > option_default > config_check > project_check > config_cache
    --

    -- get the options
    local options = nil
    for name, value in pairs(option.options()) do
        if _option_filter(name) then
            options = options or {}
            options[name] = value
        end
    end

    -- override configure from the options or cache 
    local options_changed = false
    local options_history = {}
    if not option.get("clean") then
        options_history = configcache:get("options_" .. targetname) or {}
        options = options or options_history
    end
    for name, value in pairs(options) do
            
        -- options is changed by argument options?
        options_changed = options_changed or options_history[name] ~= value

        -- @note override it and mark as readonly (highest priority)
        config.set(name, value, {readonly = true})
    end

    -- merge the cached configure
    --
    -- @note we cannot load cache config when switching platform, arch .. 
    -- so we need known whether options have been changed
    --
    local configcache_loaded = false
    if not options_changed and not option.get("clean") and not _host_changed(targetname) then
        configcache_loaded = config.load(targetname) 
    end

    -- merge the global configure 
    for name, value in pairs(global.options()) do 
        if config.get(name) == nil then
            config.set(name, value)
        end
    end

    -- merge the default options 
    for name, value in pairs(option.defaults()) do
        if _option_filter(name) and config.get(name) == nil then
            config.set(name, value)
        end
    end

    -- merge the project options after default options
    for name, value in pairs(project.get("config")) do
        value = table.unwrap(value)
        assert(type(value) == "string", "set_config(%s): too much values", name)
        if not config.readonly(name) then
            config.set(name, value)
        end
    end

    -- merge the checked configure 
    local recheck = _need_check(options_changed or not configcache_loaded)
    if recheck then

        -- clear detect cache
        detectcache.clear()

        -- check configure
        config.check()

        -- check project options
        project.check()
    end

    -- load platform
    platform.load(config.plat())

    -- translate the build directory
    local buildir = config.get("buildir")
    if buildir and path.is_absolute(buildir) then
        config.set("buildir", path.relative(buildir, project.directory()), {readonly = true, force = true})
    end

    -- install and update requires and config header
    local require_enable = option.boolean(option.get("require"))
    if (recheck or require_enable) and require_enable ~= false then
        install_requires()
    end

    -- check target and ensure to load all targets, @note we must load targets after installing required packages, 
    -- otherwise has_package() will be invalid.
    _check_target(targetname)

    -- update the config header
    if recheck then
        generate_configfiles()
        generate_configheader()
    end

    -- dump config
    if option.get("verbose") then
        config.dump()
    end

    -- save options and configure for the given target
    config.save(targetname)
    configcache:set("options_" .. targetname, options)

    -- save options and configure for each targets if be all
    if targetname == "all" then
        for _, target in pairs(project.targets()) do
            config.save(target:name())
            configcache:set("options_" .. target:name(), options)
        end
    end

    -- flush config cache
    configcache:flush()
end
