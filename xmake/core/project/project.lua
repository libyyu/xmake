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
-- @file        project.lua
--

-- define module: project
local project = project or {}

-- load modules
local os                    = require("base/os")
local io                    = require("base/io")
local path                  = require("base/path")
local task                  = require("base/task")
local utils                 = require("base/utils")
local table                 = require("base/table")
local global                = require("base/global")
local process               = require("base/process")
local deprecated            = require("base/deprecated")
local interpreter           = require("base/interpreter")
local rule                  = require("project/rule")
local target                = require("project/target")
local config                = require("project/config")
local option                = require("project/option")
local requireinfo           = require("project/requireinfo")
local deprecated_project    = require("project/deprecated/project")
local package               = require("package/package")
local platform              = require("platform/platform")
local environment           = require("platform/environment")
local language              = require("language/language")
local sandbox_os            = require("sandbox/modules/os")
local sandbox_module        = require("sandbox/modules/import/core/sandbox/module")

-- the current os is belong to the given os?
function project._api_is_os(interp, ...)

    -- get the current os
    local os = platform.os()
    if not os then return false end

    -- exists this os?
    for _, o in ipairs(table.join(...)) do
        if o and type(o) == "string" and o == os then
            return true
        end
    end
end

-- the current mode is belong to the given modes?
function project._api_is_mode(interp, ...)
    return config.is_mode(...)
end

-- the current platform is belong to the given platforms?
function project._api_is_plat(interp, ...)
    return config.is_plat(...)
end

-- the current platform is belong to the given architectures?
function project._api_is_arch(interp, ...)
    return config.is_arch(...)
end

-- the current kind is belong to the given kinds?
function project._api_is_kind(interp, ...)

    -- get the current kind
    local kind = config.get("kind")
    if not kind then return false end

    -- exists this kind?
    for _, k in ipairs(table.join(...)) do
        if k and type(k) == "string" and k == kind then
            return true
        end
    end
end

-- the current host is belong to the given hosts?
function project._api_is_host(interp, ...)
    return os.is_host(...)
end

-- the current config is belong to the given config values?
function project._api_is_config(interp, name, ...)
    return config.is_value(name, ...)
end

-- some configs are enabled?
function project._api_has_config(interp, ...)
    return config.has(...)
end

-- some packages are enabled?
function project._api_has_package(interp, ...)
    -- only for loading targets
    local requires = project._REQUIRES
    if requires then
        for _, name in ipairs(table.join(...)) do
            local pkg = requires[name]
            if pkg and pkg:enabled() then
                return true
            end
        end
    end
end

-- set config from the given name
function project._api_set_config(interp, name, value)
    if not config.readonly(name) then
        config.set(name, value)
    end
end

-- get config from the given name
function project._api_get_config(interp, name)
    return config.get(name)
end

-- add module directories
function project._api_add_moduledirs(interp, ...)
    sandbox_module.add_directories(...)
end

-- add plugin directories load all plugins from the given directories
function project._api_add_plugindirs(interp, ...)

    -- get all directories
    local plugindirs = {}
    local dirs = table.join(...)
    for _, dir in ipairs(dirs) do
        table.insert(plugindirs, dir .. "/*")
    end

    -- add all plugins
    interp:api_builtin_includes(plugindirs)
end

-- add package directories and load all packages from the given directories
function project._api_add_packagedirs(interp, ...)

    -- get all directories
    local pkgdirs = {}
    local dirs = table.join(...)
    for _, dir in ipairs(dirs) do
        table.insert(pkgdirs, dir .. "/*.pkg")
    end

    -- add all packages
    interp:api_builtin_includes(pkgdirs)
end

-- get interpreter
function project.interpreter()

    -- the interpreter has been initialized? return it directly
    if project._INTERPRETER then
        return project._INTERPRETER
    end

    -- init interpreter
    local interp = interpreter.new()
    assert(interp)

    -- set root directory
    interp:rootdir_set(project.directory())

    -- set root scope
    interp:rootscope_set("target")

    -- define apis for rule
    interp:api_define(rule.apis())

    -- define apis for task
    interp:api_define(task.apis())

    -- define apis for target
    interp:api_define(target.apis())

    -- define apis for option
    interp:api_define(option.apis())

    -- define apis for package
    interp:api_define(package.apis())

    -- define apis for language
    interp:api_define(language.apis())

    -- define apis for project
    interp:api_define
    {
        values =
        {
            -- set_xxx
            "set_project"
        ,   "set_version"
        ,   "set_modes"
            -- add_xxx
        ,   "add_requires"
        ,   "add_repositories"
        }
    ,   custom = 
        {
            -- is_xxx
            {"is_os",                   project._api_is_os            }
        ,   {"is_kind",                 project._api_is_kind          }
        ,   {"is_host",                 project._api_is_host          }
        ,   {"is_mode",                 project._api_is_mode          }
        ,   {"is_plat",                 project._api_is_plat          }
        ,   {"is_arch",                 project._api_is_arch          }
        ,   {"is_config",               project._api_is_config        }
            -- set_xxx
        ,   {"set_config",              project._api_set_config       }
            -- get_xxx
        ,   {"get_config",              project._api_get_config       }
            -- has_xxx
        ,   {"has_config",              project._api_has_config       }
        ,   {"has_package",             project._api_has_package      }
            -- add_xxx
        ,   {"add_moduledirs",          project._api_add_moduledirs   }
        ,   {"add_plugindirs",          project._api_add_plugindirs   }
        ,   {"add_packagedirs",         project._api_add_packagedirs  }
        }
    }

    -- register api: deprecated
    deprecated_project.api_register(interp)

    -- set filter
    interp:filter():register("project", function (variable)

        -- check
        assert(variable)

        -- hack buildir first
        if variable == "buildir" then
            return config.buildir()
        end

        -- attempt to get it directly from the configure
        local result = config.get(variable)
        if not result or type(result) ~= "string" then 

            -- init maps
            local maps = 
            {
                os          = platform.os()
            ,   host        = os.host()
            ,   prefix      = "$(prefix)"
            ,   tmpdir      = function () return os.tmpdir() end
            ,   curdir      = function () return os.curdir() end
            ,   scriptdir   = function () return sandbox_os.scriptdir() end
            ,   globaldir   = global.directory()
            ,   configdir   = config.directory()
            ,   projectdir  = project.directory()
            ,   programdir  = os.programdir()
            }

            -- map it
            result = maps[variable]
            if type(result) == "function" then
                result = result()
            end
        end

        -- ok?
        return result
    end)

    -- save interpreter
    project._INTERPRETER = interp

    -- ok?
    return interp
end

-- get the project file
function project.file()
    return os.projectfile()
end

-- get the project directory
function project.directory()
    return os.projectdir()
end

-- get the project info from the given name
function project.get(name)

    -- load the global project infos
    local infos = project._INFOS 
    if not infos then

        -- load infos
        infos = project._load_scope(nil, true, true)
        project._INFOS = infos
    end

    -- get it
    if infos then
        return infos[name]
    end
end

-- load deps for instance: .e.g option, target and rule
--
-- .e.g 
--
-- a.deps = b
-- b.deps = c
--
-- orderdeps: c -> b -> a
--
function project._load_deps(instance, instances, deps, orderdeps)

    -- get dep instances
    for _, dep in ipairs(table.wrap(instance:get("deps"))) do
        local depinst = instances[dep]
        if depinst then
            project._load_deps(depinst, instances, deps, orderdeps)
            if not deps[dep] then
                deps[dep] = depinst
                table.insert(orderdeps, depinst) 
            end
        end
    end
end

-- load scope from the project file
function project._load_scope(scope_kind, remove_repeat, enable_filter)

    -- get interpreter
    local interp = project.interpreter()
    assert(interp) 

    -- enter the project directory
    local oldir, errors = os.cd(os.projectdir())
    if not oldir then
        return nil, errors
    end

    -- load targets
    local results, errors = interp:load(project.file(), scope_kind, remove_repeat, enable_filter)
    if not results then
        return nil, (errors or "load project file failed!")
    end

    -- leave the project directory
    local ok, errors = os.cd(oldir)
    if not ok then
        return nil, errors
    end

    -- ok
    return results
end

-- load targets 
function project._load_targets()

    -- load all requires first (ensure has_package() works for targets)
    local requires = project.requires()

    -- load targets
    local results, errors = project._load_scope("target", true, true)
    if not results then
        return nil, errors
    end

    -- make targets
    local targets = {}
    for targetname, targetinfo in pairs(results) do
        local t = target.new(targetname, targetinfo, project)
        if t and (t:get("enabled") == nil or t:get("enabled") == true) then
            targets[targetname] = t
        end
    end

    -- load and attach target deps, rules and packages
    for _, t in pairs(targets) do

        -- load deps
        t._DEPS      = t._DEPS or {}
        t._ORDERDEPS = t._ORDERDEPS or {}
        project._load_deps(t, targets, t._DEPS, t._ORDERDEPS)

        -- load rules
        --
        -- .e.g 
        --
        -- a.deps = b
        -- b.deps = c
        --
        -- orderules: c -> b -> a
        --
        t._RULES      = t._RULES or {}
        t._ORDERULES  = t._ORDERULES or {}
        for _, rulename in ipairs(table.wrap(t:get("rules"))) do
            local r = project.rule(rulename) or rule.rule(rulename)
            if r then
                t._RULES[rulename] = r
                for _, deprule in ipairs(r:orderdeps()) do
                    local name = deprule:name()
                    if not t._RULES[name] then
                        t._RULES[name] = deprule
                        table.insert(t._ORDERULES, deprule) 
                    end
                end
                table.insert(t._ORDERULES, r)
            end
        end

        -- laod packages
        t._PACKAGES = t._PACKAGES or {}
        for _, packagename in ipairs(table.wrap(t:get("packages"))) do
            local p = requires[packagename]
            if p then
                table.insert(t._PACKAGES, p)
            end
        end
    end

    -- enter toolchains environment
    environment.enter("toolchains")

    -- do load for each target
    local ok = false
    for _, t in pairs(targets) do
        ok, errors = t:_load()
        if not ok then
            break
        end
    end

    -- leave toolchains environment
    environment.leave("toolchains")

    -- do load failed?
    if not ok then
        return nil, errors
    end

    -- ok
    return targets
end

-- load options
function project._load_options(disable_filter)

    -- load the options from the the project file
    local results, errors = project._load_scope("option", true, not disable_filter)
    if not results then
        return nil, errors
    end

    -- check options
    local options = {}
    for optionname, optioninfo in pairs(results) do
        
        -- init a option instance
        local instance = table.inherit(option)
        assert(instance)

        -- save name and info
        instance._NAME = optionname
        instance._INFO = optioninfo

        -- save it
        options[optionname] = instance

        -- mark add_defines_h_if_ok and add_undefines_h_if_ok as deprecated
        if instance:get("defines_h_if_ok") then
            deprecated.add("add_defines_h(\"%s\")", "add_defines_h_if_ok(\"%s\")", table.concat(table.wrap(instance:get("defines_h_if_ok")), "\", \""))
        end
        if instance:get("undefines_h_if_ok") then
            deprecated.add("add_undefines_h(\"%s\")", "add_undefines_h_if_ok(\"%s\")", table.concat(table.wrap(instance:get("undefines_h_if_ok")), "\", \""))
        end
    end

    -- load and attach options deps
    for _, opt in pairs(options) do
        opt._DEPS      = opt._DEPS or {}
        opt._ORDERDEPS = opt._ORDERDEPS or {}
        project._load_deps(opt, options, opt._DEPS, opt._ORDERDEPS)
    end

    -- ok?
    return options
end

-- load requires
function project._load_requires()

    -- parse requires
    local requires = {}
    local requires_extra = project.get("__extra_requires") or {}
    for _, requirestr in ipairs(table.wrap(project.get("requires"))) do

        -- get the package name
        local packagename = requirestr:split('%s+')[1]

        -- get alias
        local alias = nil
        local extrainfo = requires_extra[requirestr]
        if extrainfo then
            alias = extrainfo.alias
        end

        -- load it from cache first (@note will discard scripts in extrainfo) 
        local instance = requireinfo.load(alias or packagename)
        if not instance then

            -- init a require info instance
            instance = table.inherit(requireinfo)

            -- save name and info
            instance._NAME = packagename
            instance._INFO = { __requirestr = requirestr, __extrainfo = extrainfo }
        end

        -- move scripts of extrainfo  (e.g. on_load ..) 
        if extrainfo then
            for k, v in pairs(extrainfo) do
                if type(v) == "function" then
                    instance._SCRIPTS = instance._SCRIPTS or {}
                    instance._SCRIPTS[k] = v
                    extrainfo[k] = nil
                end
            end

            -- TODO exists deprecated option? show tips
            if extrainfo.option then
                os.raise("`option = {}` is no longger supported in add_requires(), please update xmake.lua")
            end
        end

        -- add require info
        requires[alias or packagename] = instance
    end

    -- ok?
    return requires
end

-- clear project cache to reload targets and options
function project.clear()

    -- clear options status in config file first
    for _, opt in ipairs(table.wrap(project._OPTIONS)) do
        opt:clear()
    end

    -- clear targets and options
    project._TARGETS = nil
    project._OPTIONS = nil
end

-- get the given target
function project.target(name)
    return project.targets()[name]
end

-- get the current configure for targets
function project.targets()

    -- load targets
    if not project._TARGETS then
        local targets, errors = project._load_targets()
        if not targets then
            os.raise(errors)
        end
        project._TARGETS = targets
    end

    -- ok
    return project._TARGETS
end

-- get the given option
function project.option(name)
    return project.options()[name]
end

-- get options
function project.options()

    -- load options and enable filter
    if not project._OPTIONS then
        local options, errors = project._load_options()
        if not options then
            os.raise(errors)
        end
        project._OPTIONS = options
    end

    -- ok
    return project._OPTIONS
end

-- get the given require info
function project.require(name)
    return project.requires()[name]
end

-- get requires info
function project.requires()

    -- load requires 
    if not project._REQUIRES then
        local requires, errors = project._load_requires()
        if not requires then
            os.raise(errors)
        end
        project._REQUIRES = requires
    end

    -- ok
    return project._REQUIRES
end

-- get the given rule
function project.rule(name)
    return project.rules()[name]
end

-- get project rules
function project.rules()
 
    -- return it directly if exists
    if project._RULES then
        return project._RULES 
    end

    -- the project file is not found?
    if not os.isfile(project.file()) then
        return {}
    end

    -- load the rules from the the project file
    local results, errors = project._load_scope("rule", true, true)
    if not results then
        os.raise(errors)
    end

    -- make rule instances
    local rules = {}
    for rulename, ruleinfo in pairs(results) do
        rules[rulename] = rule.new(rulename, ruleinfo)
    end

    -- load rule deps
    local instances = table.join(rule.rules(), rules)
    for _, instance in pairs(instances)  do
        instance._DEPS      = instance._DEPS or {}
        instance._ORDERDEPS = instance._ORDERDEPS or {}
        project._load_deps(instance, instances, instance._DEPS, instance._ORDERDEPS)
    end

    -- save it
    project._RULES = rules

    -- ok?
    return rules
end

-- get the given task
function project.task(name)
    return project.tasks()[name]
end

-- get tasks
function project.tasks()
 
    -- return it directly if exists
    if project._TASKS then
        return project._TASKS 
    end

    -- the project file is not found?
    if not os.isfile(project.file()) then
        return {}, nil
    end

    -- load the tasks from the the project file
    local results, errors = project._load_scope("task", true, true)
    if not results then
       os.raise(errors or "load project tasks failed!")
    end

    -- bind tasks for menu with an sandbox instance
    local ok, errors = task._bind(results, project.interpreter())
    if not ok then
        os.raise(errors)
    end

    -- make task instances
    local tasks = {}
    for taskname, taskinfo in pairs(results) do
        tasks[taskname] = task.new(taskname, taskinfo)
    end

    -- save it
    project._TASKS = tasks

    -- ok?
    return tasks
end

-- get packages
function project.packages()

    -- get it from cache first
    if project._PACKAGES then
        return project._PACKAGES
    end

    -- the project file is not found?
    if not os.isfile(os.projectfile()) then
        return {}, nil
    end

    -- load the packages from the the project file and disable filter, we will process filter after a while
    local results, errors = project._load_scope("package", true, false)
    if not results then
        return nil, errors
    end

    -- save results to cache
    project._PACKAGES = results

    -- ok?
    return results
end

-- get the mtimes
function project.mtimes()
    return project.interpreter():mtimes()
end

-- get the project menu
function project.menu()

    -- attempt to load options from the project file
    local options = nil
    local errors = nil
    if os.isfile(project.file()) then
        options, errors = project._load_options(true)
    end

    -- failed?
    if not options then
        if errors then utils.error(errors) end
        return {}
    end

    -- arrange options by category
    local options_by_category = {}
    for _, opt in pairs(options) do

        -- make the category
        local category = "default"
        if opt:get("category") then category = table.unwrap(opt:get("category")) end
        options_by_category[category] = options_by_category[category] or {}

        -- append option to the current category
        options_by_category[category][opt:name()] = opt
    end

    -- make menu by category
    local menu = {}
    for k, opts in pairs(options_by_category) do

        -- insert options
        local first = true
        for name, opt in pairs(opts) do

            -- show menu?
            if opt:get("showmenu") then

                -- the default value
                local default = "auto"
                if opt:get("default") ~= nil then
                    default = opt:get("default")
                end

                -- is first?
                if first then

                    -- insert a separator
                    table.insert(menu, {})

                    -- not first
                    first = false
                end

                -- append it
                local longname = name
                local descriptions = opt:get("description")
                if descriptions then

                    -- define menu option
                    local menu_options = {nil, longname, "kv", default, descriptions}
                        
                    -- handle set_description("xx", "xx")
                    if type(descriptions) == "table" then
                        for i, description in ipairs(descriptions) do
                            menu_options[4 + i] = description
                        end
                    end

                    -- insert option into menu
                    table.insert(menu, menu_options)
                else
                    table.insert(menu, {nil, longname, "kv", default, nil})
                end
            end
        end
    end

    -- ok?
    return menu
end

-- return module: project
return project
