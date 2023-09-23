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
-- @file        find_qt.lua
--

-- imports
import("lib.detect.cache")
import("lib.detect.find_file")
import("core.base.option")
import("core.base.global")
import("core.project.config")

-- find qt sdk directory
function _find_sdkdir(sdkdir, sdkver)

    -- append target sub-directory
    local subdirs = {}
    if is_plat("linux") then
        table.insert(subdirs, path.join(sdkver or "*", is_arch("x86_64") and "gcc_64" or "gcc_32", "bin"))
        table.insert(subdirs, path.join(sdkver or "*", is_arch("x86_64") and "clang_64" or "clang_32", "bin"))
    elseif is_plat("macosx") then
        table.insert(subdirs, path.join(sdkver or "*", is_arch("x86_64") and "clang_64" or "clang_32", "bin"))
    elseif is_plat("windows") then
        local vs = config.get("vs")
        local isx64 = "x64" == config.get("arch")
        if vs then
            if vs:startswith('vs') then
                vs = vs:sub(3)
            end
            table.insert(subdirs, path.join(sdkver or "*", isx64 and "msvc" .. vs .. "_64" or "msvc" .. vs .. "_32", "bin"))
            table.insert(subdirs, path.join(sdkver or "*", "msvc" .. vs, "bin"))
        end 
        table.insert(subdirs, path.join(sdkver or "*", isx64 and "msvc*_64" or "msvc*_32", "bin"))
        table.insert(subdirs, path.join(sdkver or "*", "msvc*", "bin"))
    elseif is_plat("mingw") then
        table.insert(subdirs, path.join(sdkver or "*", is_arch("x86_64") and "mingw*_64" or "mingw*_32", "bin"))
    elseif is_plat("android") then
        local subdir = "android_*"
        if is_arch("arm64-v8a") then
            subdir = "android_arm64_v8a"
        elseif is_arch("armv7-a") then
            subdir = "android_armv7"
        elseif is_arch("i386") then
            subdir = "android_x86"
        end
        table.insert(subdirs, path.join(sdkver or "*", subdir, "bin"))
    end
    table.insert(subdirs, path.join(sdkver or "*", "*", "bin"))
    table.insert(subdirs, path.join("*", "bin"))
    table.insert(subdirs, "bin")

    -- init the search directories
    local pathes = {}
    if sdkdir then
        table.insert(pathes, sdkdir)
    end
    if is_host("windows") then

        -- add pathes from registry 
        local regs = 
        {
            "HKEY_CLASSES_ROOT\\Applications\\QtProject.QtCreator.c\\shell\\Open\\Command",
            "HKEY_CLASSES_ROOT\\Applications\\QtProject.QtCreator.cpp\\shell\\Open\\Command",
            "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\Applications\\QtProject.QtCreator.c\\shell\\Open\\Command",
            "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\Applications\\QtProject.QtCreator.cpp\\shell\\Open\\Command"
        }
        for _, reg in ipairs(regs) do
            table.insert(pathes, function () 
                local value = val("reg " .. reg)
                if value then
                    local p = value:find("\\Tools\\QtCreator", 1, true)
                    if p then
                        return path.translate(value:sub(1, p - 1))
                    end
                end
            end)
        end

        -- add root logical drive pates, .e.g C:/Qt/Qtx.x.x, D:/Qtx.x.x ..
        for idx, drive in ipairs(winos.logical_drives()) do
            if idx < 5 then
                table.insert(pathes, path.join(drive, "Qt", "Qt*"))
            else
                break
            end
        end
    else
        table.insert(pathes, "~/Qt")
    end

    -- attempt to find qmake
    local qmake = find_file(is_host("windows") and "qmake.exe" or "qmake", pathes, {suffixes = subdirs})
    if qmake then
        return path.directory(path.directory(qmake))
    end
end

-- find qt sdk toolchains
function _find_qt(sdkdir, sdkver)

    -- find qt directory
    sdkdir = _find_sdkdir(sdkdir, sdkver)
    if not sdkdir or not os.isdir(sdkdir) then
        return nil
    end

    -- get the bin directory 
    local bindir = path.join(sdkdir, "bin")
    if not os.isexec(path.join(bindir, "qmake")) then
        return nil
    end

    -- get linkdirs
    local linkdirs = {path.join(sdkdir, "lib")}

    -- get includedirs
    local includedirs = {path.join(sdkdir, "include")}

    -- get sdk version
    sdkver = sdkver or sdkdir:match("(%d+%.?%d*%.?%d*.-)")

    -- get toolchains
    return {sdkdir = sdkdir, bindir = bindir, linkdirs = linkdirs, includedirs = includedirs, sdkver = sdkver}
end

-- find qt sdk toolchains
--
-- @param sdkdir    the qt sdk directory
-- @param opt       the argument options, .e.g {verbose = true, force = false, version = "5.9.1"} 
--
-- @return          the qt sdk toolchains. .e.g {sdkver = ..., sdkdir = ..., bindir = .., linkdirs = ..., includedirs = ..., .. }
--
-- @code 
--
-- local toolchains = find_qt("~/Qt")
-- 
-- @endcode
--
function main(sdkdir, opt)

    -- init arguments
    opt = opt or {}

    local isGenProj = config.get("genproj")

    -- attempt to load cache first
    local key = "detect.sdks.find_qt"
    if is_plat("windows") then
        key = key .. (config.get("arch") and "." .. config.get("arch") or "")
    end 
    local cacheinfo = cache.load(key)
    if not opt.force and cacheinfo.qt and cacheinfo.qt.sdkdir and os.isdir(cacheinfo.qt.sdkdir) then
        return cacheinfo.qt
    end

    if not config.get("__qt__rootdir") then
        local sdkdir = sdkdir or config.get("qt") or global.get("qt") or config.get("sdk")
        config.set("__qt__rootdir", sdkdir, {force = true, readonly = true})
    end

    -- find qt
    local qt = _find_qt(isGenProj and config.get("__qt__rootdir") or (sdkdir or config.get("qt") or global.get("qt") or config.get("sdk")), opt.version or config.get("qt_sdkver"))
    if qt then

        -- save to config
        config.set("qt", qt.sdkdir, {force = true, readonly = true})
        config.set("qt_sdkver", qt.sdkver, {force = true, readonly = true})

        -- trace
        if opt.verbose or option.get("verbose") then
            cprint("checking for the Qt SDK directory ... ${color.success}%s", qt.sdkdir)
            cprint("checking for the Qt SDK version ... ${color.success}%s", qt.sdkver)
        end
    else

        -- trace
        if opt.verbose or option.get("verbose") then
            cprint("checking for the Qt SDK directory ... ${color.nothing}${text.nothing}")
        end
    end

    -- save to cache
    cacheinfo.qt = qt or false
    cache.save(key, cacheinfo)

    -- ok?
    return qt
end
