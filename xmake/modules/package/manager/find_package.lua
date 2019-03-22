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
-- @file        find_package.lua
--

-- imports
import("core.base.semver")
import("core.base.option")
import("core.project.config")

-- find package with the builtin rule
--
-- opt.system:
--   nil: find local or system packages
--   true: only find system package
--   false: only find local packages
--
function _find_package_with_builtin_rule(package_name, opt)

    -- we cannot find it from xmake repo and package directories if only find system packages
    local managers = {}
    if opt.system ~= true then
        table.insert(managers, "xmake")
    end

    -- find system package if be not disabled
    if opt.system ~= false then

        -- find it from homebrew
        if not is_host("windows") and (opt.mode == nil or opt.mode == "release") then
            table.insert(managers, "brew")
        end

        -- find it from vcpkg (support multi-platforms/architectures)
        table.insert(managers, "vcpkg")

        -- find it from conan (support multi-platforms/architectures)
        table.insert(managers, "conan")

        -- only support the current host platform and architecture
        if opt.plat == os.host() and opt.arch == os.arch() and (opt.mode == nil or opt.mode == "release") then

            -- find it from pkg-config
            table.insert(managers, "pkg_config")

            -- find it from system
            table.insert(managers, "system")
        end
    end

    -- find package from the given package manager
    local result = nil
    for _, manager_name in ipairs(managers) do
        dprint("finding %s from %s ..", package_name, manager_name)
        result = import("package.manager." .. manager_name .. ".find_package", {anonymous = true})(package_name, opt)
        if result then
            break
        end
    end

    -- check result?
    if result and not result.includedirs then
        result = nil
    end

    -- ok?
    return result
end

-- find package 
function _find_package(manager_name, package_name, opt)

    -- find package from the given package manager
    local result = nil
    if manager_name then

        -- trace
        dprint("finding %s from %s ..", package_name, manager_name)

        -- find it
        result = import("package.manager." .. manager_name .. ".find_package", {anonymous = true})(package_name, opt)
    else 

        -- find package from the given custom "detect.packages.find_xxx" script
        local builtin = false
        local find_package = import("detect.packages.find_" .. package_name, {anonymous = true, try = true})
        if find_package then

            -- trace
            dprint("finding %s from find_%s ..", package_name, package_name)

            -- find it
            result = find_package(table.join(opt, { find_package = function (...)
                                                        builtin = true
                                                        return _find_package_with_builtin_rule(...)
                                                    end}))
        end

        -- find package with the builtin rule
        if not result and not builtin then
            result = _find_package_with_builtin_rule(package_name, opt)
        end
    end

    -- found?
    if result then
    
        -- remove repeat
        result.linkdirs    = table.unique(result.linkdirs)
        result.includedirs = table.unique(result.includedirs)

        -- check valid version
        if result.version then
            local version = try { function () return semver.new(result.version) end }
            if version then
                result.version = version:rawstr()
            else 
                result.version = nil
            end
        end
    end

    -- ok?
    return result
end

-- find package using the package manager
--
-- @param name  the package name
--              e.g. zlib 1.12.x (try all), xmake::zlib 1.12.x, brew::zlib, brew::pcre/libpcre16, vcpkg::zlib, conan::OpenSSL/1.0.2n@conan/stable
-- @param opt   the options
--              e.g. { verbose = false, force = false, plat = "iphoneos", arch = "arm64", mode = "debug", version = "1.0.x", 
--                     linkdirs = {"/usr/lib"}, includedirs = "/usr/include", links = {"ssl"}, includes = {"ssl.h"}
--                     packagedirs = {"/tmp/packages"}, system = true}
--
-- @return      {links = {"ssl", "crypto", "z"}, linkdirs = {"/usr/local/lib"}, includedirs = {"/usr/local/include"}}
--
-- @code 
--
-- local package = find_package("openssl")
-- local package = find_package("openssl", {version = "1.0.*"})
-- local package = find_package("openssl", {plat = "iphoneos"})
-- local package = find_package("openssl", {linkdirs = {"/usr/lib", "/usr/local/lib"}, includedirs = "/usr/local/include", version = "1.0.1"})
-- local package = find_package("openssl", {linkdirs = {"/usr/lib", "/usr/local/lib", links = {"ssl", "crypto"}, includes = {"ssl.h"}})
-- 
-- @endcode
--
function main(name, opt)

    -- get the copied options
    opt = table.copy(opt)
    opt.plat = opt.plat or config.get("plat") or os.host()
    opt.arch = opt.arch or config.get("arch") or os.arch()
    opt.mode = opt.mode or config.mode() or "release"

    -- get package manager name
    local manager_name, package_name = unpack(name:split("::", true))
    if package_name == nil then
        package_name = manager_name
        manager_name = nil
    else
        manager_name = manager_name:lower():trim()
    end

    -- get package name and require version
    local require_version = nil
    package_name, require_version = unpack(package_name:trim():split("%s+"))
    opt.version = require_version or opt.version

    -- find package
    result = _find_package(manager_name, package_name, opt)

    -- match version?
    if opt.version and result then
        if not result.version or not semver.satisfies(result.version, opt.version) then
            result = nil
        end
    end

    -- ok?
    return result
end
