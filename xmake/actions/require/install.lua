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
-- @file        package.lua
--

-- imports
import("core.base.option")
import("core.base.task")
import("core.project.project")
import("lib.detect.find_tool")
import("impl.package")
import("impl.repository")
import("impl.environment")

-- register the required local package
function _register_required_package(instance, requireinfo)

    -- disable it if this package is optional and missing
    if _g.optional_missing[instance:name()] then
        requireinfo:enable(false)
    else
        -- add this package info
        requireinfo:clear()
        requireinfo:add(instance:fetch())

        -- add all dependent packages info 
        local orderdeps = instance:orderdeps()
        if orderdeps then
            local total = #orderdeps
            for idx, _ in ipairs(orderdeps) do
                local dep = orderdeps[total + 1 - idx]
                if dep then
                    requireinfo:add((dep:fetch()))
                end
            end
        end

        -- save this package version
        requireinfo:version_set(instance:version_str())

        -- enable this require info
        requireinfo:enable(true)
    end

    -- save this require info and flush the whole cache file
    requireinfo:save()
end

-- register all required local packages
function _register_required_packages(packages)
    local registered_in_group = {}
    for _, instance in ipairs(packages) do

        -- only register the first package in same group
        local group = instance:group()
        if not group or not registered_in_group[group] then

            -- do not register binary package
            if instance:kind() ~= "binary" then
                local requireinfo = project.require(instance:alias() or instance:name())
                if requireinfo then
                    _register_required_package(instance, requireinfo)
                end
            end

            -- mark as registered in group
            if group then
                registered_in_group[group] = true
            end
        end
    end
end

-- check missing packages
function _check_missing_packages(packages)

    -- get all missing packages
    local packages_missing = {}
    local optional_missing = {}
    for _, instance in ipairs(packages) do
        if not instance:exists() and (#instance:urls() > 0 or instance:from("system")) then
            if instance:optional() then
                optional_missing[instance:name()] = instance
            else
                table.insert(packages_missing, instance:name())
            end
        end
    end

    -- raise tips
    if #packages_missing > 0 then
        raise("The packages(%s) not found!", table.concat(packages_missing, ", "))
    end

    -- save the optional missing packages
    _g.optional_missing = optional_missing
end

-- install packages
function main(requires)

    -- avoid to run this task repeatly
    if _g.installed then return end
    _g.installed = true

    -- init requires
    local requires_extra = nil
    if not requires then
        requires, requires_extra = project.requires_str()
    end
    if not requires or #requires == 0 then
        return 
    end

    -- get extra info
    local extra =  option.get("extra")
    local extrainfo = nil
    if extra then
        local tmpfile = os.tmpfile() .. ".lua"
        io.writefile(tmpfile, "{" .. extra .. "}")
        extrainfo = io.load(tmpfile)
        os.tryrm(tmpfile)
    end

    -- force to use the given requires extra info
    if extrainfo then
        requires_extra = requires_extra or {}
        for _, require_str in ipairs(requires) do
            requires_extra[require_str] = extrainfo
        end
    end

    -- enter environment 
    environment.enter()

    -- pull all repositories first if not exists
    --
    -- attempt to install git from the builtin-packages first if git not found
    --
    if find_tool("git") and not repository.pulled() then
        task.run("repo", {update = true})
    end

    -- install packages
    local packages = package.install_packages(requires, {requires_extra = requires_extra})
    if packages then

        -- check missing packages
        _check_missing_packages(packages)

        -- register all required local packages
        _register_required_packages(packages)
    end

    -- leave environment
    environment.leave()
end

