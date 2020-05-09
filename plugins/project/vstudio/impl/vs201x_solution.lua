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
-- @file        vs201x_solution.lua
--

-- imports
import("core.project.project")
import("core.project.config")
import("vsfile")

-- make header
function _make_header(slnfile, vsinfo)
    slnfile:print("Microsoft Visual Studio Solution File, Format Version %s.00", vsinfo.solution_version)
    slnfile:print("# Visual Studio %s", vsinfo.vstudio_version)
end

-- make projects
function _make_projects(slnfile, vsinfo, nested_folders)

    -- the vstudio tool uuid for vc project
    local vctool = "8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942"

    -- make all targets
    for targetname, target in pairs(project.targets()) do
        if not target:isphony() then

            -- enter project
            slnfile:enter("Project(\"{%s}\") = \"%s\", \"%s\\%s.vcxproj\", \"{%s}\"", vctool, targetname, targetname, targetname, hash.uuid(targetname))

            -- add dependences
            local deps = target:get("deps")
            if deps and #deps >0 then
                slnfile:enter("ProjectSection(ProjectDependencies) = postProject")
                for _, dep in ipairs(deps) do
                    slnfile:print("{%s} = {%s}", hash.uuid(dep), hash.uuid(dep))
                end
                slnfile:leave("EndProjectSection")
            end

            -- leave project
            slnfile:leave("EndProject")

            local vsfolder = target:values("vs.folder")
            if vsfolder and type(vsfolder) == "string" then
                vsfolder = vsfolder:gsub("\\", "/")
                local folders = vsfolder:split("/")
                local pre_name
                for i, name in ipairs(folders) do--thirdpart/demos/aaa
                    nested_folders[name] = nested_folders[name] or {}
                    if pre_name then
                        table.insert(nested_folders[pre_name], name)
                    end
                    if i == #folders then
                        table.insert(nested_folders[name], targetname)
                    end
                    pre_name = name
                end
            end
        end
    end

    -- make nested folders
    vctool = "2150E333-8FDC-42A3-9474-1A3956D46DE8"
    for name, _ in pairs(nested_folders) do
        -- enter project
        slnfile:enter("Project(\"{%s}\") = \"%s\", \"%s\", \"{%s}\"", vctool, name, name, hash.uuid(name))

        -- leave project
        slnfile:leave("EndProject")
    end
end

-- make global
function _make_global(slnfile, vsinfo, nested_folders)
    local function fix_arch(arch)
        return arch == "x86" and "Win32" or arch
    end
    -- enter global
    slnfile:enter("Global")

    -- add solution configuration platforms
    slnfile:enter("GlobalSection(SolutionConfigurationPlatforms) = preSolution")
    for _, mode in ipairs(vsinfo.modes) do
        for _, arch in ipairs(vsinfo.archs) do
            slnfile:print("%s|%s = %s|%s", mode, fix_arch(arch), mode, fix_arch(arch))
        end
    end
    slnfile:leave("EndGlobalSection")

    -- add project configuration platforms
    slnfile:enter("GlobalSection(ProjectConfigurationPlatforms) = postSolution")
    for targetname, target in pairs(project.targets()) do
        if not target:isphony() then
            for _, mode in ipairs(vsinfo.modes) do
                for _, arch in ipairs(vsinfo.archs) do
                    slnfile:print("{%s}.%s|%s.ActiveCfg = %s|%s", hash.uuid(targetname), mode, fix_arch(arch), mode, fix_arch(arch))
                    slnfile:print("{%s}.%s|%s.Build.0 = %s|%s", hash.uuid(targetname), mode, fix_arch(arch), mode, fix_arch(arch))
                end
            end
        end
    end
    slnfile:leave("EndGlobalSection")

    -- add solution properties
    slnfile:enter("GlobalSection(SolutionProperties) = preSolution")
    slnfile:print("HideSolutionNode = FALSE")
    slnfile:leave("EndGlobalSection")

    -- add nested projects
    local flags = {}
    slnfile:enter("GlobalSection(NestedProjects) = preSolution")
    for name, nested_projects in pairs(nested_folders) do
        for _, nested_name in ipairs(nested_projects) do
            if not flags[nested_name] then
                flags[nested_name] = true
                slnfile:print("{%s} = {%s}", hash.uuid(nested_name), hash.uuid(name))
            end
        end
    end
    slnfile:leave("EndGlobalSection")

    -- leave global
    slnfile:leave("EndGlobal")
end

-- make solution
function make(vsinfo)

    -- init solution name
    vsinfo.solution_name = project.name() or "vs" .. vsinfo.vstudio_version

    -- open solution file
    local slnpath = path.join(vsinfo.solution_dir, vsinfo.solution_name .. ".sln")
    local slnfile = vsfile.open(slnpath, "w")

    -- init indent character
    vsfile.indentchar('\t')

    -- make header
    _make_header(slnfile, vsinfo)

    -- make projects
    local nested_folders = {}
    _make_projects(slnfile, vsinfo, nested_folders)

    -- make global
    _make_global(slnfile, vsinfo, nested_folders)

    -- exit solution file
    slnfile:close()

    -- convert gb2312 to utf8
    io.writefile(slnpath, io.readfile(slnpath):convert("gb2312", "utf8"))
end
