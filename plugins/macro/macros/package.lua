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
-- @file        package.lua
--

-- imports
import("core.base.option")
import("core.project.config")
import("core.project.project")
import("core.platform.platform")

-- the options
local options =
{
    {'p', "plat",       "kv",  os.host(),   "Set the platform."                                    }
,   {'f', "config",     "kv",  nil,         "Pass the config arguments to \"xmake config\" .."     }
,   {'o', "outputdir",  "kv",  nil,         "Set the output directory of the package."             }
}

-- package all
--
-- .e.g
-- xmake m package 
-- xmake m package -f "-m debug"
-- xmake m package -p linux
-- xmake m package -p iphoneos -f "-m debug --xxx ..." -o /tmp/xxx
-- xmake m package -f \"--mode=debug\"
--
function main(argv)

    -- parse arguments
    local args = option.parse(argv, options, "Package all architectures for the given the platform."
                                           , ""
                                           , "Usage: xmake macro package [options]")

    -- package all archs
    local plat = args.plat
    for _, arch in ipairs(platform.archs(plat)) do

        -- config it
        os.exec("xmake f -p %s -a %s %s -c %s", plat, arch, args.config or "", ifelse(option.get("verbose"), "-v", ""))

        -- package it
        if args.outputdir then
            os.exec("xmake p -o %s %s", args.outputdir, ifelse(option.get("verbose"), "-v", ""))
        else
            os.exec("xmake p %s", ifelse(option.get("verbose"), "-v", ""))
        end
    end

    -- package universal for iphoneos, watchos ...
    if plat == "iphoneos" or plat == "watchos" then

        -- load configure
        config.load()

        -- load project
        project.load()

        -- enter the project directory
        os.cd(project.directory())

        -- the outputdir directory
        local outputdir = args.outputdir or config.get("buildir")

        -- package all targets
        for _, target in pairs(project.targets()) do

            -- get all modes
            local modedirs = os.match(format("%s/%s.pkg/lib/*", outputdir, target:name()), true)
            for _, modedir in ipairs(modedirs) do
                
                -- get mode
                local mode = path.basename(modedir)

                -- make lipo arguments
                local lipoargs = nil
                for _, arch in ipairs(platform.archs(plat)) do
                    local archfile = format("%s/%s.pkg/lib/%s/%s/%s/%s", outputdir, target:name(), mode, plat, arch, path.filename(target:targetfile())) 
                    if os.isfile(archfile) then
                        lipoargs = format("%s -arch %s %s", lipoargs or "", arch, archfile) 
                    end
                end
                if lipoargs then

                    -- make full lipo arguments
                    lipoargs = format("-create %s -output %s/%s.pkg/lib/%s/%s/universal/%s", lipoargs, outputdir, target:name(), mode, plat, path.filename(target:targetfile()))

                    -- make universal directory
                    os.mkdir(format("%s/%s.pkg/lib/%s/%s/universal", outputdir, target:name(), mode, plat))

                    -- package all archs
                    os.execv("xmake", {"l", "lipo", lipoargs})
                end
            end
        end
    end
end
