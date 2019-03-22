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
import("core.base.option")
import("core.project.config")
import("lib.detect.cache")
import("package.manager.find_package")

-- find package using the package manager
--
-- @param name  the package name
--              e.g. zlib 1.12.x (try all), xmake::zlib 1.12.x, brew::zlib, brew::pcre/libpcre16, vcpkg::zlib, conan::OpenSSL/1.0.2n@conan/stable
-- @param opt   the options
--              e.g. { verbose = false, force = false, plat = "iphoneos", arch = "arm64", mode = "debug", version = "1.0.x", 
--                     linkdirs = {"/usr/lib"}, includedirs = "/usr/include", links = {"ssl"}, includes = {"ssl.h"}
--                     packagedirs = {"/tmp/packages"}, system = true, cachekey = "xxxx"}
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

    -- init cache key
    local key = "find_package_" .. opt.plat .. "_" .. opt.arch
    if opt.version then
        key = key .. "_" .. opt.version
    end
    if opt.cachekey then
        key = key .. "_" .. opt.cachekey
    end
    if opt.mode then
        key = key .. "_" .. opt.mode
    end

    -- attempt to get result from cache first
    local cacheinfo = cache.load(key) 
    local result = cacheinfo[name]
    if result ~= nil and not opt.force then
        return result and result or nil
    end

    -- find package
    result = find_package(name, opt)

    -- cache result
    cacheinfo[name] = result and result or false
    cache.save(key, cacheinfo)

    -- trace
    if opt.verbose or option.get("verbose") then
        if result then
            cprint("checking for the %s ... ${color.success}%s", name, result.version and result.version or "${text.success}")
            dprint(result)
        else
            cprint("checking for the %s ... ${color.nothing}${text.nothing}", name)
        end
    end

    -- ok?
    return result
end
