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

-- define module: main
local main = main or {}

-- load modules
local os            = require("base/os")
local log           = require("base/log")
local path          = require("base/path")
local utils         = require("base/utils")
local option        = require("base/option")
local profiler      = require("base/profiler")
local deprecated    = require("base/deprecated")
local privilege     = require("base/privilege")
local task          = require("base/task")
local colors        = require("base/colors")
local project       = require("project/project")
local history       = require("project/history")

-- init the option menu
local menu =
{
    -- title
    title = "${bright}xmake v" .. xmake._VERSION .. ", A cross-platform build utility based on Lua${clear}"

    -- copyright
,   copyright = "Copyright (C) 2015-2018 Ruki Wang, ${underline}tboox.org${clear}, ${underline}xmake.io${clear}\nCopyright (C) 2005-2015 Mike Pall, ${underline}luajit.org${clear}"

    -- the tasks: xmake [task]
,   function () 
        return task.menu(table.join(task.tasks(), project.tasks())) 
    end

}

-- show help and version info
function main._show_help()

    -- show help
    if option.get("help") then
    
        -- print menu
        option.show_menu(option.taskname())

        -- ok
        return true

    -- show version
    elseif option.get("version") then

        -- show title
        if menu.title then
            utils.cprint(menu.title)
        end

        -- show copyright
        if menu.copyright then
            utils.cprint(menu.copyright)
        end

        -- show logo
        option.show_logo()

        -- ok
        return true
    end
end

-- find the root project file
function main._find_root(projectfile)

    -- make all parent directories
    local dirs = {}
    local dir = path.directory(projectfile)
    while os.isdir(dir) do
        table.insert(dirs, 1, dir)
        local parentdir = path.directory(dir)
        if parentdir and parentdir ~= dir and parentdir ~= '.' then
            dir = parentdir
        else 
            break
        end
    end

    -- find the first `xmake.lua` from it's parent directory
    for _, dir in ipairs(dirs) do
        local file = path.join(dir, "xmake.lua")
        if os.isfile(file) then
           return file 
        end
    end
    return projectfile
end

-- the init function for main
function main._init()

    -- get project directory from the argument option
    local opt_projectdir = option.find(xmake._ARGV, "project", "P")

    -- get project file from the argument option
    local opt_projectfile = option.find(xmake._ARGV, "file", "F")

    -- init the project directory
    local projectdir = opt_projectdir or xmake._PROJECT_DIR
    if projectdir and not path.is_absolute(projectdir) then
        projectdir = path.absolute(projectdir)
    elseif projectdir then 
        projectdir = path.translate(projectdir)
    end
    xmake._PROJECT_DIR = projectdir
    assert(projectdir)

    -- init the xmake.lua file path
    local projectfile = opt_projectfile or xmake._PROJECT_FILE
    if projectfile and not path.is_absolute(projectfile) then
        projectfile = path.absolute(projectfile, projectdir)
    end
    xmake._PROJECT_FILE = projectfile
    assert(projectfile)

    -- find the root project file
    if not os.isfile(projectfile) or (not opt_projectdir and not opt_projectfile) then
        projectfile = main._find_root(projectfile) 
    end

    -- update and enter project
    xmake._PROJECT_DIR  = path.directory(projectfile)
    xmake._PROJECT_FILE = projectfile

    -- enter the project directory
    if os.isdir(os.projectdir()) then
        if path.translate(os.projectdir()) ~= path.translate(os.curdir()) then
            utils.warning([[You are working in the project directory(%s) and you can also 
force to build in current directory via run `xmake -P .`]], os.projectdir())
        end
        xmake._WORKING_DIR = os.cd(os.projectdir())
    else
        xmake._WORKING_DIR = os.curdir()
    end

    -- add the directory of the program file (xmake) to $PATH environment
    local programfile = os.programfile()
    if programfile and os.isfile(programfile) then
        os.addenv("PATH", path.directory(programfile))
    else
        os.addenv("PATH", os.programdir())
    end
end

-- the main function
function main.done()

    -- init 
    main._init()

    -- init option 
    local ok, errors = option.init(menu)  
    if not ok then
        utils.error(errors)
        return -1
    end

    -- check run command as root
    if not option.get("root") and (not os.getenv("XMAKE_ROOT") or os.getenv("XMAKE_ROOT") ~= 'y') then
        if os.isroot() then
            if not privilege.store() or os.isroot() then
                utils.error([[Running xmake as root is extremely dangerous and no longer supported.
As xmake does not drop privileges on installation you would be giving all
build scripts full access to your system. 
Or you can add `--root` option or XMAKE_ROOT=y to allow run as root temporarily.
                ]])
                return -1
            end
        end
    end

    -- check deprecated options, TODO it will be removed after v2.3.0
    if option.get("backtrace") then
        deprecated.add("-D or --diagnosis", "--backtrace")
    end

    -- start profiling
    if option.get("profile") then
        profiler:start()
    end

    -- show help?
    if main._show_help() then
        return 0
    end

    -- save command lines to history
    if os.isfile(os.projectfile()) then
        history("local.history"):save("cmdlines", option.cmdline())
    end

    -- get task instance
    local taskname = option.taskname() or "build"
    local taskinst = project.task(taskname) or task.task(taskname) 
    if not taskinst then
        utils.error("do unknown task(%s)!", taskname)
        return -1
    end

    -- run task    
    ok, errors = taskinst:run()
    if not ok then
        utils.error(errors)
        return -1
    end

    -- dump deprecated entries
    deprecated.dump()

    -- stop profiling
    if option.get("profile") then
        profiler:stop()
    end

    -- close log
    log:close()

    -- ok
    return 0
end

-- return module: main
return main
