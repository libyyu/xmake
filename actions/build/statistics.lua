--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
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
-- @file        statistics.lua
--

-- imports
import("core.base.option")
import("core.project.config")
import("core.platform.platform")
import("core.platform.environment")

-- statistics is enabled?
function _is_enabled()

    -- disable statistics? need not post it
    local stats = (os.getenv("XMAKE_STATS") or ""):lower()
    if stats == "false" then
        return false
    end

    -- is in ci(travis/appveyor/...)? need not post it
    local ci = (os.getenv("CI") or ""):lower()
    if ci == "true" then
        os.setenv("XMAKE_STATS", "false")
        return false
    end

    -- ok
    return true
end

-- post statistics info and only post once everyday when building each project
--
-- clone the xmake-stats(only an empty repo) to update the traffic(git clones) info in github
--
-- the traffic info in github (just be approximate numbers):
--
-- Clones:          the number of projects which build using xmake everyday
-- Unique cloners:  the number of users everyday
--
function post()

    -- get the project directory name
    local projectname = path.basename(os.projectdir())

    -- has been posted today or statistics is disable?
    local outputdir = path.join(os.tmpdir(), "stats", os.date("%y%m%d"), projectname)
    local markfile  = outputdir .. ".mark"
    if os.isdir(outputdir) or os.isfile(markfile) or not _is_enabled() then
        return 
    end

    -- mark as posted first, avoid to post it repeatly
    io.writefile(markfile, "ok")

    -- init argument list
    local argv = {"lua", path.join(os.scriptdir(), "statistics.lua")}
    for _, name in ipairs({"root", "file", "project", "diagnosis", "verbose", "quiet", "yes", "confirm"}) do
        local value = option.get(name)
        if type(value) == "string" then
            table.insert(argv, "--" .. name .. "=" .. value)
        elseif value then
            table.insert(argv, "--" .. name)
        end
    end

    -- try to post it in background
    try
    {
        function ()
            local proc = process.openv("xmake", argv, path.join(os.tmpdir(), projectname .. ".stats.log"))
            if proc ~= nil then
                process.close(proc)
            end
        end
    }
end

-- the main function
function main()

    -- in project?
    if not os.isfile(os.projectfile()) then
        return 
    end

    -- load config
    config.load()

    -- load platform
    platform.load(config.plat())

    -- enter environment
    environment.enter("toolchains")

    -- get the project directory name
    local projectname = path.basename(os.projectdir())

    -- clone the xmake-stats repo to update the traffic(git clones) info in github
    local outputdir = path.join(os.tmpdir(), "stats", os.date("%y%m%d"), projectname)
    if not os.isdir(outputdir) then
        import("devel.git.clone")
        clone("https://github.com/xmake-io/xmake-stats.git", {depth = 1, branch = "master", outputdir = outputdir})
        print("post to traffic ok!")
    end

    -- download the xmake-stats releases to update the release stats info in github
    local releasefile = outputdir .. ".release"
    if not os.isfile(releasefile) then
        import("net.http.download")
        download(format("https://github.com/xmake-io/xmake-stats/releases/download/v%s/%s", xmake:version():shortstr(), os.host()), releasefile)
        print("post to releases ok!")
    end

    -- leave environment
    environment.leave("toolchains")
end
