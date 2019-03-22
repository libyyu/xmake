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
-- @file        gcc.lua
--

-- imports
import("core.base.option")
import("core.project.config")
import("core.project.project")
import("core.language.language")
import("detect.tools.find_ccache")

-- init it
function init(self)

    -- init mxflags
    self:set("mxflags", "-fmessage-length=0"
                      , "-pipe"
                      , "-fpascal-strings"
                      , "-DIBOutlet=__attribute__((iboutlet))"
                      , "-DIBOutletCollection(ClassName)=__attribute__((iboutletcollection(ClassName)))"
                      , "-DIBAction=void)__attribute__((ibaction)")

    -- init shflags
    self:set("shflags", "-shared")

    -- add -fPIC for shared
    if not is_plat("windows", "mingw") then
        self:add("shflags", "-fPIC")
        self:add("shared.cxflags", "-fPIC")
    end

    -- init flags map
    self:set("mapflags",
    {
        -- warnings
        ["-W1"] = "-Wall"
    ,   ["-W2"] = "-Wall"
    ,   ["-W3"] = "-Wall"

         -- strip
    ,   ["-s"]  = "-s"
    ,   ["-S"]  = "-S"
    })

    -- for macho target
    if is_plat("macosx") or is_plat("iphoneos") then
        self:add("mapflags", 
        {
            ["-s"] = "-Wl,-x"
        ,   ["-S"] = "-Wl,-S"
        })
    end

    -- init buildmodes
    self:set("buildmodes",
    {
        ["object:sources"] = false
    })
end

-- make the strip flag
function nf_strip(self, level)

    -- the maps
    local maps = 
    {   
        debug = "-S"
    ,   all   = "-s"
    }

    -- for macho target
    local plat = config.plat()
    if plat == "macosx" or plat == "iphoneos" then
        maps.all   = "-Wl,-x"
        maps.debug = "-Wl,-S"
    end

    -- make it
    return maps[level]
end

-- make the symbol flag
function nf_symbol(self, level)

    -- the maps
    local maps = 
    {   
        debug  = "-g"
    ,   hidden = "-fvisibility=hidden"
    }

    -- make it
    return maps[level] 
end

-- make the warning flag
function nf_warning(self, level)

    -- the maps
    local maps = 
    {   
        none  = "-w"
    ,   less  = "-Wall"
    ,   more  = "-Wall"
    ,   all   = "-Wall"
    ,   error = "-Werror"
    }

    -- make it
    return maps[level]
end

-- make the optimize flag
function nf_optimize(self, level)

    -- the maps
    local maps = 
    {   
        none       = "-O0"
    ,   fast       = "-O1"
    ,   faster     = "-O2"
    ,   fastest    = "-O3"
    ,   smallest   = "-Os"
    ,   aggressive = "-Ofast"
    }

    -- make it
    return maps[level] 
end

-- make the vector extension flag
function nf_vectorext(self, extension)

    -- the maps
    local maps = 
    {   
        mmx   = "-mmmx"
    ,   sse   = "-msse"
    ,   sse2  = "-msse2"
    ,   sse3  = "-msse3"
    ,   ssse3 = "-mssse3"
    ,   avx   = "-mavx"
    ,   avx2  = "-mavx2"
    ,   neon  = "-mfpu=neon"
    }

    -- make it
    return maps[extension] 
end

-- make the language flag
function nf_language(self, stdname)

    -- the stdc maps
    if _g.cmaps == nil then
        _g.cmaps = 
        {
            -- stdc
            ansi        = "-ansi"
        ,   c89         = "-std=c89"
        ,   gnu89       = "-std=gnu89"
        ,   c99         = "-std=c99"
        ,   gnu99       = "-std=gnu99"
        ,   c11         = "-std=c11"
        ,   gnu11       = "-std=gnu11"
        }
    end

    -- the stdc++ maps
    if _g.cxxmaps == nil then
        _g.cxxmaps = 
        {
            cxx98       = "-std=c++98"
        ,   gnuxx98     = "-std=gnu++98"
        ,   cxx11       = "-std=c++11"
        ,   gnuxx11     = "-std=gnu++11"
        ,   cxx14       = "-std=c++14"
        ,   gnuxx14     = "-std=gnu++14"
        ,   cxx17       = "-std=c++17"
        ,   gnuxx17     = "-std=gnu++17"
        ,   cxx1z       = "-std=c++1z"
        ,   gnuxx1z     = "-std=gnu++1z"
        ,   cxx2a       = "-std=c++2a"
        ,   gnuxx2a     = "-std=gnu++2a"
        }
        local cxxmaps2 = {}
        for k, v in pairs(_g.cxxmaps) do
            cxxmaps2[k:gsub("xx", "++")] = v
        end
        table.join2(_g.cxxmaps, cxxmaps2)
    end

    -- select maps
    local maps = _g.cmaps
    if self:kind() == "cxx" or self:kind() == "mxx" then
        maps = _g.cxxmaps
    elseif self:kind() == "sc" then
        maps = {}
    end

    -- make it
    return maps[stdname]
end

-- make the define flag
function nf_define(self, macro)
    return "-D" .. macro
end

-- make the undefine flag
function nf_undefine(self, macro)
    return "-U" .. macro
end

-- make the includedir flag
function nf_includedir(self, dir)
    return "-I" .. os.args(dir)
end

-- make the link flag
function nf_link(self, lib)
    return "-l" .. lib
end

-- make the syslink flag
function nf_syslink(self, lib)
    return nf_link(self, lib)
end

-- make the linkdir flag
function nf_linkdir(self, dir)
    return "-L" .. os.args(dir)
end

-- make the rpathdir flag
function nf_rpathdir(self, dir)
    if self:has_flags("-Wl,-rpath=" .. dir, "ldflags") then
        return "-Wl,-rpath=" .. os.args(dir:gsub("@[%w_]+", function (name)
            local maps = {["@loader_path"] = "$ORIGIN", ["@executable_path"] = "$ORIGIN"}
            return maps[name]
        end))
    elseif self:has_flags("-Xlinker -rpath -Xlinker " .. dir, "ldflags") then
        return "-Xlinker -rpath -Xlinker " .. os.args(dir:gsub("%$ORIGIN", "@loader_path"))
    end
end

-- make the framework flag
function nf_framework(self, framework)
    return "-framework " .. framework
end

-- make the frameworkdir flag
function nf_frameworkdir(self, frameworkdir)
    return "-F " .. os.args(frameworkdir)
end

-- make the c precompiled header flag
function nf_pcheader(self, pcheaderfile, target)
    if self:kind() == "cc" then
        local pcoutputfile = target:pcoutputfile("c")
        if self:name() == "clang" then
            return "-include " .. os.args(pcheaderfile) .. " -include-pch " .. os.args(pcoutputfile)
        else
            return "-include " .. path.filename(pcheaderfile) .. " -I" .. os.args(path.directory(pcoutputfile))
        end
    end
end

-- make the c++ precompiled header flag
function nf_pcxxheader(self, pcheaderfile, target)
    if self:kind() == "cxx" then
        local pcoutputfile = target:pcoutputfile("cxx")
        if self:name() == "clang" then
            return "-include " .. os.args(pcheaderfile) .. " -include-pch " .. os.args(pcoutputfile)
        else
            return "-include " .. path.filename(pcheaderfile) .. " -I" .. os.args(path.directory(pcoutputfile))
        end
    end
end

-- make the link arguments list
function linkargv(self, objectfiles, targetkind, targetfile, flags)

    -- add rpath for dylib (macho), .e.g -install_name @rpath/file.dylib
    local flags_extra = {}
    if targetkind == "shared" and targetfile:endswith(".dylib") then
        table.insert(flags_extra, "-install_name")
        table.insert(flags_extra, "@rpath/" .. path.filename(targetfile))
    end

    -- add `-Wl,--out-implib,outputdir/libxxx.a` for xxx.dll on mingw/gcc
    if targetkind == "shared" and config.plat() == "mingw" then
        table.insert(flags_extra, "-Wl,--out-implib," .. os.args(path.join(path.directory(targetfile), path.basename(targetfile) .. ".lib")))
    end

    -- make link args
    return self:program(), table.join("-o", targetfile, objectfiles, flags, flags_extra)
end

-- link the target file
function link(self, objectfiles, targetkind, targetfile, flags)

    -- ensure the target directory
    os.mkdir(path.directory(targetfile))

    -- link it
    os.runv(linkargv(self, objectfiles, targetkind, targetfile, flags))
end

-- get compile info
--
-- e.g.
--
-- ! xxx.gch
-- . xxx.h
-- .. xxx.h
-- ... xxx.h
-- In file included from src/xxx.c:43:
-- src/main.c:2:9 warning: xczx
--   ..
--
-- . xxx.h
-- Multiple include guards may be useful for:
-- /usr/include/bits/long-double.h
-- /usr/include/bits/sigaction.h
-- /usr/include/string
--
function _get_compile_info(outdata)

    -- filter dependent header info and get compile output 
    local results = {}
    for _, line in ipairs(outdata:split("\n")) do
        if not line:startswith("!") and -- ! xxx.h
           not line:startswith(".") and -- ... xxx.h
           not (path.is_absolute(line) and not line:find(':', 3, true)) and -- /usr/xxx/string, C:\xx\string
           not line:find("%.%a+$") and -- src/xxx.[h|hpp|c|..]
           not (line:endswith(':') and not line:find("%d")) then -- Multiple include guards may be useful for:
            table.insert(results, line)
        end
    end
    return results
end

-- get include deps
function _get_include_deps(outdata)

    -- translate it
    local results = {}
    local uniques = {}
    for _, line in ipairs(outdata:split("\n")) do

        -- get includefile, e.g. '! xxx.gch' or '... xxx.h'
        if line:startswith("!") or line:startswith(".") then
            local includefile = line:split("%s")[2]
            if includefile then

                -- get the relative
                includefile = path.relative(includefile, project.directory())

                -- save it if belong to the project
                if path.absolute(includefile):startswith(os.projectdir()) then

                    -- insert it and filter repeat
                    if not uniques[includefile] then
                        table.insert(results, includefile)
                        uniques[includefile] = true
                    end
                end
            end
        end
    end
    return results
end

-- make the complie arguments list for the precompiled header
function _compargv1_pch(self, pcheaderfile, pcoutputfile, flags)

    -- remove "-include xxx.h" and "-include-pch xxx.pch"
    local pchflags = {}
    local include = false
    for _, flag in ipairs(flags) do
        if not flag:find("-include", 1, true) then
            if not include then
                table.insert(pchflags, flag)
            end
            include = false
        else
            include = true
        end
    end

    -- compile header.h as c++?
    if self:kind() == "cxx" then
        table.insert(pchflags, "-x")
        table.insert(pchflags, "c++-header")
    end

    -- make complie arguments list
    return self:program(), table.join("-c", pchflags, "-o", pcoutputfile, pcheaderfile)
end

-- make the complie arguments list
function _compargv1(self, sourcefile, objectfile, flags)

    -- precompiled header?
    local extension = path.extension(sourcefile)
    if (extension:startswith(".h") or extension == ".inl") then
        return _compargv1_pch(self, sourcefile, objectfile, flags)
    end

    -- get ccache
    local ccache = nil
    if config.get("ccache") then
        ccache = find_ccache()
    end

    -- make argv
    local argv = table.join("-c", flags, "-o", objectfile, sourcefile)

    -- uses cache?
    local program = self:program()
    if ccache then
            
        -- parse the filename and arguments, .e.g "xcrun -sdk macosx clang"
        if not os.isexec(program) then
            argv = table.join(program:split("%s"), argv)
        else 
            table.insert(argv, 1, program)
        end
        return ccache, argv
    end

    -- no cache
    return program, argv
end

-- complie the source file
function _compile1(self, sourcefile, objectfile, dependinfo, flags)

    -- ensure the object directory
    os.mkdir(path.directory(objectfile))

    -- compile it
    local outdata, errdata = try
    {
        function ()

            -- support -H? some old gcc does not support it at same time
            if _g._HAS_H == nil then
                _g._HAS_H = self:has_flags("-H", "cxflags")
            end

            -- generate includes file
            local compflags = flags
            if dependinfo and _g._HAS_H then
                compflags = table.join(flags, "-H")
            end

            -- do compile
            return os.iorunv(_compargv1(self, sourcefile, objectfile, compflags))
        end,
        catch
        {
            function (errors)

                -- try removing the old object file for forcing to rebuild this source file
                os.tryrm(objectfile)

                -- parse and strip errors
                local lines = _get_compile_info(errors)
                if not option.get("verbose") then

                    -- find the start line of error
                    local start = 0
                    for index, line in ipairs(lines) do
                        if line:find("error:", 1, true) or line:find("错误：", 1, true) then
                            start = index
                            break
                        end
                    end

                    -- get 16 lines of errors
                    if start > 0 then
                        lines = table.slice(lines, start, start + ifelse(#lines - start > 16, 16, #lines - start))
                    end
                end

                -- raise compiling errors
                raise(#lines > 0 and table.concat(lines, "\n") or "")
            end
        },
        finally
        {
            function (ok, outdata, errdata)

                -- show warnings?
                if ok and errdata and #errdata > 0 and (option.get("diagnosis") or option.get("warning")) then
                    local lines = _get_compile_info(errdata)
                    if #lines > 0 then
                        local warnings = table.concat(table.slice(lines, 1, ifelse(#lines > 8, 8, #lines)), "\n")
                        cprint("${color.warning}%s", warnings)
                    end
                end
            end
        }
    }

    -- generate the dependent includes
    local depdata = errdata
    if dependinfo and self:kind() ~= "as" and depdata then
        dependinfo.files = dependinfo.files or {}
        table.join2(dependinfo.files, _get_include_deps(depdata))
    end
end

-- make the complie arguments list
function compargv(self, sourcefiles, objectfile, flags)

    -- only support single source file now
    assert(type(sourcefiles) ~= "table", "'object:sources' not support!")

    -- for only single source file
    return _compargv1(self, sourcefiles, objectfile, flags)
end

-- complie the source file
function compile(self, sourcefiles, objectfile, dependinfo, flags)

    -- only support single source file now
    assert(type(sourcefiles) ~= "table", "'object:sources' not support!")

    -- for only single source file
    _compile1(self, sourcefiles, objectfile, dependinfo, flags)
end

