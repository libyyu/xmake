

-- imports
import("core.base.option")
import("core.tool.compiler")
import("core.tool.linker")
import("core.project.config")
import("core.project.project")
import("core.language.language")
import("core.platform.platform")

-- the toolchains archs
local toolchains_archs = 
{
    ["armv5te"]     = "armeabi"
,   ["armv6"]       = "armeabi"
,   ["armv7-a"]     = "armeabi-v7a"
,   ["armv8-a"]     = "armeabi-v7a"
,   ["arm64-v8a"]   = "arm64-v8a"
,   ["x86"]         = "x86"
}

-- get log mkfile
function _logfile()

    -- get it
    return vformat("$(buildir)/.build.log")
end

-- mkdir directory
function _mkdir(mkfile, dir)

    if config.get("plat") == "windows" then
        mkfile:print("\t-@mkdir %s > /null 2>&1", dir)
    else
        mkfile:print("\t@mkdir -p %s", dir)
    end
end
-- write variables
function _make_variables(mkfile, key, values, cb)
    cb = cb or function(v) return v end
    if type(values) == "string" then
        mkfile:print("%s := %s", key, cb(values))
        return
    elseif not values or #values == 0 then
        mkfile:print("%s :=", key)
        return
    end

    for i,v in ipairs(values) do
        if i == 1 then
            mkfile:print("%s := %s", key, cb(v))
        else
            mkfile:print("%s += %s", key, cb(v))
        end
    end
end

-- make target info
function _make_targetinfo(mode, arch, target)

    -- init target info
    local targetinfo = { mode = mode, arch = arch }

    -- save symbols
    targetinfo.symbols = target:get("symbols")

    -- save target kind
    targetinfo.targetkind = target:targetkind()

    -- save sourcebatches
    targetinfo.sourcebatches = target:sourcebatches()

    -- save compiler flags
    targetinfo.compflags = {}
    for _, sourcefile in ipairs(target:sourcefiles()) do
        local compflags = compiler.compflags(sourcefile, {target = target})
        targetinfo.compflags[sourcefile] = compflags
    end

    -- links
    local link_map = {}
    targetinfo.links = {}
    for _, v in ipairs( target:get("links") ) do
        table.insert(targetinfo.links, v)
        link_map[v] = true
    end

    -- save linker flags
    local _, linkflags = target:linkflags()
    targetinfo.linkflags = linkflags

    -- linkdirs
    local linkdir_map = {}
    targetinfo.linkdirs = {}
    for _, v in ipairs( target:get("linkdirs") ) do
        table.insert(targetinfo.linkdirs, v)
        linkdir_map[v] = true
    end

    -- deps
    targetinfo.deps = {}
    local deps_map = {}
    for _, v in ipairs(table.copy(target:get("deps"))) do
        table.insert(targetinfo.deps, v)
        local dep = project.target(v)
        deps_map[path.basename(dep:targetfile()):sub(4,-1)] = true
    end
    

    local linkflags = linker.linkflags(target:targetkind(), target:sourcekinds(), {target = target})
    targetinfo.linkflags = linkflags


    for _, flag in ipairs(targetinfo.linkflags) do
        -- replace -libpath:dir or /libpath:dir
        if flag:startswith("-l") then
            local v = flag:sub(3,-1)
            if not link_map[v] then
                table.insert(targetinfo.links, v)
                link_map[v] = true
            end
        end
        if flag:startswith("-L") then
            local dir = flag:sub(3,-1)
            if not linkdir_map[dir] then
                table.insert(targetinfo.linkdirs, dir)
                linkdir_map[dir] = true
            end
        end
    end
    
    -- ldflags
    targetinfo.ldflags = table.copy(target:get("ldflags"))

    -- cxxflags
    targetinfo.cxxflags = table.copy(target:get("cxxflags"))

    -- cxflags
    targetinfo.cxflags = table.copy(target:get("cxflags"))

    -- cflags
    targetinfo.cflags = table.copy(target:get("cflags"))

    -- includes
    targetinfo.includedirs = table.copy(target:get("includedirs"))

    -- defines
    targetinfo.defines = table.copy(target:get("defines"))

    -- target dir
    targetinfo.targetdir = target:get("targetdir")

    -- mkfiledir
    targetinfo.mkfiledir = target.mkfiledir

    -- languages
    targetinfo.languages = table.copy(target:get("languages"))

    -- ok
    return targetinfo
end

function _get_targetinfo(mode, arch, info)
    for _, targetinfo in ipairs( info ) do
        if targetinfo.mode == mode and targetinfo.arch == arch then
            return targetinfo
        end
    end
    return nil
end

function _make_prebuilt_links(mkfile, target, archs)
    local function _is_dep(link, deps)
        for i, dep in ipairs( deps ) do
            local dep_target = project.target(dep)
            if dep_target then
                local basename = dep_target:basename()             
                local name = dep_target:name()
                basename = basename == nil and name or basename
                if basename == link then
                    return true
                end

                if _is_dep(link, dep_target:get("deps")) then
                    return true
                end
            end
        end
        return false
    end

    local function _get_link(link, linkdirs)
        for i, dir in ipairs( linkdirs ) do
            if os.exists(path.join(dir, link)) then
                return path.join(dir, link)
            end
        end
        return link
    end

    local filterlib = {
        ['android'] = true,
        ['log'] = true,
        ['c++_static'] = true,
        ['c++abi'] = true,
        ['jnigraphics'] = true,
    }
    
    local function _make_inner(target, targetinfo, _arch, mode)
        local arch = toolchains_archs[_arch]
        for i, linkname in ipairs( targetinfo.links ) do
            if not filterlib[linkname] then
                local v = mode:sub(1, 1)
                local vmode = mode=="debug" and v:upper() .. mode:sub(2, -1) or ""
                if _is_dep(linkname, targetinfo.deps) then 
                    mkfile:print("\tinclude %$(CLEAR_VARS)")
                    mkfile:print("\tLOCAL_MODULE        := %s", linkname..vmode)
                    mkfile:print("\tLOCAL_SRC_FILES     := %$(LOCAL_PATH)/../%s/obj/local/%s/lib%s.a", linkname, arch, linkname..vmode)
                    mkfile:print("\tTHIRD_MODULS        %s= %$(LOCAL_MODULE)", i==1 and ":" or "+")
                    mkfile:print("\tinclude %$(PREBUILT_STATIC_LIBRARY)")
                else
                    local linkfile = _get_link("lib"..linkname..".a", targetinfo.linkdirs)
                    local rpath = path.relative(linkfile, target.mkfiledir)
                    mkfile:print("\tinclude %$(CLEAR_VARS)")
                    mkfile:print("\tLOCAL_MODULE        := %s", linkname)
                    mkfile:print("\tLOCAL_SRC_FILES     := %$(LOCAL_PATH)/%s", rpath:gsub("\\", "/"):trim())
                    mkfile:print("\tTHIRD_MODULS        %s= %$(LOCAL_MODULE)", begin and ":" or "+")
                    mkfile:print("\tinclude %$(PREBUILT_STATIC_LIBRARY)")
                end
            end
        end
    end

    local function _make_mode(ibegin, iend, mode, mkfile)
        for i, _arch in ipairs( archs ) do        
            if i==1 and ibegin then
                mkfile:print("ifeq (%$(APP_OPTIM)_%$(TARGET_ARCH_ABI),%s_%s)", mode, toolchains_archs[_arch])
                local targetinfo = _get_targetinfo(mode, _arch, target.info)
                if targetinfo then
                    _make_inner(target, targetinfo, _arch, mode)
                end
            else
                mkfile:print("else ifeq (%$(APP_OPTIM)_%$(TARGET_ARCH_ABI),%s_%s)", mode, toolchains_archs[_arch])
                local targetinfo = _get_targetinfo(mode, _arch, target.info)
                if targetinfo then
                    _make_inner(target, targetinfo, _arch, mode)
                end
                if i == #archs and iend then
                    mkfile:print("endif")
                end
            end
        end
    end
    
    mkfile:print("")
    mkfile:print("# preinclude static libs")

    for i, v in ipairs({'release', 'debug'}) do
        _make_mode(i == 1, i == 2, v, mkfile)
    end

    mkfile:print("")
    mkfile:print("include %$(CLEAR_VARS)")
end

function _make_flags(mkfile, targetinfo)
    --LOCAL_ARM_MODE
    local local_arm_mode = config.get("LOCAL_ARM_MODE")
    if local_arm_mode and type(local_arm_mode) == "string" and #local_arm_mode > 0 then
        mkfile:print("LOCAL_ARM_MODE := %s", local_arm_mode)
    end

    mkfile:print("")
    mkfile:print("# flags")
    mkfile:print("LOCAL_CPP_FEATURES := rtti exceptions")
    --mkfile:print("LOCAL_EXPORT_LDFLAGS += --whole-archive")
    mkfile:print("")

    mkfile:print("")
    mkfile:print("# defines")
    for _, define in ipairs( targetinfo.defines ) do
        mkfile:print("LOCAL_CFLAGS += -D %s", define)
    end
    for _, v in ipairs( targetinfo.languages ) do
        if v:find("xx") then
            mkfile:print("LOCAL_CPPFLAGS += -std=%s", v:gsub("xx",function(x) return "++" end)) 
        else
            mkfile:print("LOCAL_CFLAGS += -std=%s", v)
        end
    end
    
    local cxxflags = table.concat( targetinfo.cxxflags, " "):trim()
    if #cxxflags >0 then
        mkfile:print("LOCAL_CPPFLAGS += %s", cxxflags)
    end

    local cxflags = table.concat( targetinfo.cxflags, " "):trim()
    if #cxflags >0 then
        mkfile:print("LOCAL_CFLAGS += %s", cxflags)
        mkfile:print("LOCAL_CPPFLAGS += %s", cxflags)
    end

    mkfile:print("")
end

function _make_includes(mkfile, target)
    local targetinfo = target.info[1]
    mkfile:print("")
    mkfile:print("# includedirs")
    mkfile:print("LOCAL_C_INCLUDES  := %$(LOCAL_PATH)/%s", path.relative(target.scriptdir, path.absolute(target.mkfiledir)):gsub("\\", function(s) return "/" end))
    for i, dir in ipairs( targetinfo.includedirs ) do
        dir = path.relative(path.absolute(dir), path.absolute(target.mkfiledir)):trim()
        dir = dir:gsub("\\", function(s) return "/" end)
        mkfile:print("LOCAL_C_INCLUDES  += %$(LOCAL_PATH)/%s", dir)
    end
    mkfile:print("")
end

function _make_sources(mkfile, target)
    mkfile:print("")
    mkfile:print("# source files")
    for i, file in ipairs( target.sourcefiles ) do
        file = path.relative(path.absolute(file), target.mkfiledir):trim()
        file = file:gsub("\\", function(s) return "/" end)
        if i == 1 then
            mkfile:print("LOCAL_SRC_FILES  := \\")
            mkfile:print("\t%$(LOCAL_PATH)/%s%s", file, i == #target.sourcefiles and "" or "    \\")
        else
            mkfile:print("\t%$(LOCAL_PATH)/%s%s", file, i == #target.sourcefiles and "" or "    \\")
        end
    end
    mkfile:print("")
    mkfile:print("LOCAL_SRC_FILES  +=  %$(THIRD_SRCS) ")
    mkfile:print("")
end

function _make_ldlibs(mkfile, target, archs)
    local function _is_dep(link, deps)
        for i, dep in ipairs( deps ) do
            local dep_target = project.target(dep)
            if dep_target and dep_target:get("kind") == "static" then
                local basename = dep_target:basename()             
                local name = dep_target:name()
                basename = basename == nil and name or basename
                if basename == link then
                    return true
                end
            end
        end
        return false
    end

    local function _get_link(link, linkdirs)
        for i, dir in ipairs( linkdirs ) do
            if os.exists(path.join(dir, link)) then
                return path.join(dir, link)
            end
        end
        return link
    end
   
    local function _make_inner(targetinfo, _arch)
        local arch = toolchains_archs[_arch]
        for i, linkname in ipairs( targetinfo.links ) do
            if _is_dep(linkname, targetinfo.deps) then 
                mkfile:print("\tLOCAL_LDLIBS += %$(LOCAL_PATH)/../%s/obj/local/%s/lib%s.a", linkname, arch, linkname)
            else
                local linkfile = _get_link("lib"..linkname..".a", targetinfo.linkdirs)
                local rpath = path.relative(linkfile, target.mkfiledir)
                mkfile:print("\tLOCAL_LDLIBS += %$(LOCAL_PATH)/%s", rpath:gsub("\\", "/"):trim())
            end
        end
    end

    mkfile:print("")
    mkfile:print("# ldlibs static libs")

    for i, _arch in ipairs( archs ) do        
        if i == 1 then
            mkfile:print("ifeq (%$(TARGET_ARCH_ABI),%s)", toolchains_archs[_arch])
            local targetinfo = _get_targetinfo("release", _arch, target.info)
            if targetinfo then
                _make_inner(targetinfo, _arch)
            end
        else
            mkfile:print("else ifeq (%$(TARGET_ARCH_ABI),%s)", toolchains_archs[_arch])
            local targetinfo = _get_targetinfo("release", _arch, target.info)
            if targetinfo then
                _make_inner(targetinfo, _arch)
            end
            if i == #archs then
                mkfile:print("endif")
            end
        end
    end
    mkfile:print("")
end

function _make_tailer(mkfile, target, archs)
    mkfile:print("")
    mkfile:print("# tailer")
    if target.kind ~= "static" then
        mkfile:print("LOCAL_SHARED_LIBARIES :=\\")
        mkfile:print("libcutils \\")
        mkfile:print("libdl")
        mkfile:print("")
    end
    

    if target.kind ~= "static" then
        mkfile:print("LOCAL_EXPORT_LDFLAGS += --whole-archive")
        mkfile:print("#LOCAL_STATIC_LIBRARIES := %$(THIRD_MODULS)")    
        mkfile:print("LOCAL_WHOLE_STATIC_LIBRARIES := %$(THIRD_MODULS)")    
        mkfile:print("LOCAL_LDLIBS += -landroid -llog -ljnigraphics")     
        mkfile:print("")
    end
    
    mkfile:print("#cmd-strip = $(ndk)/arm-linux-androideabi-4.8/prebuild/strip -s --strip-debug -x $1")
    mkfile:print("")
    mkfile:print("ifeq (%$(APP_OPTIM),release)")
    mkfile:print("\tLOCAL_MODULE  := %s", target.name)
    mkfile:print("else")
    mkfile:print("\tLOCAL_MODULE  := %s", target.name.."Debug")
    if target.name:startswith("Azure") then
        mkfile:print("\tLOCAL_CFLAGS    += -D AZURE_DEBUG")
    end
    mkfile:print("endif")

    if target.kind == "static" then
        mkfile:print("include %$(BUILD_STATIC_LIBRARY)")
    elseif target.kind == "shared" then
        mkfile:print("include %$(BUILD_SHARED_LIBRARY)")
    else
    end
end

function _make_application(appfile, target, mkinfo, mode)
    appfile:print("# AUTO GENERATOR BY XMAKE, DO'NOT MODIFY.")
    appfile:print("APP_PROJECT_PATH := %s", ".")
    -- mode
    appfile:print("APP_OPTIM := %s", mode)

    -- abi
    local abi = {}
    local abi_map = {}
    for _, arch in ipairs(mkinfo.archs) do
        if not abi_map[toolchains_archs[arch]] then
            table.insert(abi, toolchains_archs[arch])
            abi_map[toolchains_archs[arch]] = true
        end
    end
    appfile:print("APP_ABI := %s", table.concat( abi, " "):trim())

    --APP_PLATFORM
    local ndk_sdkver = config.get("ndk_sdkver")
    if not ndk_sdkver then
        ndk_sdkver = 14
    elseif type(ndk_sdkver) == "number" then
        ndk_sdkver = tonumber(ndk_sdkver) or 14
    else
        ndk_sdkver = 14
    end
    appfile:print("APP_PLATFORM := %s", "android-" .. tostring(ndk_sdkver))

    --APP_BUILD_SCRIPT
    appfile:print("APP_BUILD_SCRIPT := %s", "Android.mk")

    --APP_STL
    --appfile:print("APP_STL := %s", "gnustl_static")
    appfile:print("APP_STL := %s", "c++_static")

    --NDK_TOOLCHAIN_VERSION
    local ndk_toolchainver = config.get("NDK_TOOLCHAIN_VERSION")
    if ndk_toolchainver and type(ndk_toolchainver) == "string" and #ndk_toolchainver > 0 then
        appfile:print("NDK_TOOLCHAIN_VERSION := %s", ndk_toolchainver)
    end

    --APP_CPPFLAGS
    appfile:print("APP_CPPFLAGS += %s", "-fexceptions")

    --APP_USE_CPP0X
    local cxxox = false
    for _, v in ipairs( target.info[1].languages ) do
        if v:find("xx") then
            cxxox = true
            break
        end
    end
    if cxxox then
        appfile:print("APP_USE_CPP0X := %s", "true")
    end
end

function _make_application_raw(target, mkinfo, target_dir)
    local results = {}
    for _, mode in ipairs(mkinfo.modes) do
        local v = mode:sub(1, 1)
        local vmode = v:upper() .. mode:sub(2, -1)
        local tmpfile = os.tmpfile() .. ".mk"
        local tmpappfile = io.open(tmpfile, "w")
        _make_application(tmpappfile, target, mkinfo, mode)
        tmpappfile:close()

        local newcontents = nil
        local oldcontents = nil
        local tmpappfile = io.open(tmpfile, "r")
        newcontents = tmpappfile:read("*all")
        tmpappfile:close()

        local appfilename = "Application"..vmode .. ".mk"
        local apppath = path.join(target_dir, appfilename)
        if os.isfile(apppath) then
            local tmpappfile = io.open(apppath, "r")
            oldcontents = tmpappfile:read("*all")
            tmpappfile:close()
        end

        if oldcontents ~= newcontents then
            os.cp(tmpfile, apppath)
            print("\t"..appfilename .. " is changed!")
        end
        if os.exists(tmpfile) then
            os.rm(tmpfile)
        end

        results[#results+1] = appfilename
    end
    return results
end

function _make_target(mkfile, target, archs)
    -- head
    mkfile:print("LOCAL_PATH := %$(call my-dir)")
    mkfile:print("include %$(CLEAR_VARS)")

    --prebuild link
    _make_prebuilt_links(mkfile, target, archs)

    --flags
    _make_flags(mkfile, target.info[1])

    --includes dir
    _make_includes(mkfile, target)

    --source files
    _make_sources(mkfile, target)

    --tailer
    _make_tailer(mkfile, target, archs)
end

function _make_target_gen(target_dir, target, appfilename, genbats, genbashs)
    -- j8
    local j8
    if config.get("j8"..target.name) == true then
        j8 = true
    end

    do
        local filename = "gen" .. path.basename(appfilename) .. ".bat"
        local genbatfile = io.open(path.join(target_dir, filename), "w")
        genbatfile:print(":: AUTO GENERATOR BY XMAKE, DO'NOT MODIFY.")

        genbatfile:print("@echo off")
        genbatfile:print("@IF NOT DEFINED NDK_HOME GOTO :NO_NDK_HOME")

        genbatfile:print("@rem gen %s", target.name)
        genbatfile:print("@echo Compiling NativeCode... %s", target.name)
        if j8 then
            genbatfile:print("\"%NDK_HOME%\\ndk-build.cmd\" -j8 NDK_PROJECT_PATH=. NDK_APPLICATION_MK="..appfilename)
        else 
            genbatfile:print("\"%NDK_HOME%\\ndk-build.cmd\" NDK_PROJECT_PATH=. NDK_APPLICATION_MK="..appfilename)
        end
        genbatfile:print("@if errorlevel 1 goto :BAD")
        genbatfile:print("goto :SUCCESS")
        genbatfile:print("")

        genbatfile:print(":NO_NDK_HOME")
        genbatfile:print("@echo.")
        genbatfile:print("@echo Build [%s] Error, NDK_HOME NOT DEFINED!", target.name)
        genbatfile:print("@echo.")
        genbatfile:print("@pause")
        genbatfile:print("exit /B 1")

        genbatfile:print(":BAD")
        genbatfile:print("@echo.")
        genbatfile:print("@echo Build [%s] Error!", target.name)
        genbatfile:print("@echo.")
        genbatfile:print("@pause")
        genbatfile:print("exit /B 1")


        genbatfile:print("")
        genbatfile:print("")
        genbatfile:print(":SUCCESS")
        genbatfile:print("@echo.")
        genbatfile:print("@echo Build [%s] Done!", target.name)
        genbatfile:print("exit /B 0")

        genbatfile:close()

        genbats[#genbats+1] = filename
    end
    do
        local filename = "gen" .. path.basename(appfilename) .. ".sh"
        local genbashfile = io.open(path.join(target_dir, filename), "w")
        genbashfile:print("## AUTO GENERATOR BY XMAKE, DO'NOT MODIFY.")

        genbashfile:print("if [ ! \"$NDK_HOME\" ]; then")
        genbashfile:print("\techo \"Build [%s] Error, NDK_HOME NOT DEFINED!\"", target.name)
        genbashfile:print("\texit 1")
        genbashfile:print("fi")
        genbashfile:print("# gen %s", target.name)
        genbashfile:print("echo \"Compiling NativeCode... %s\"", target.name)
        if j8 then
            genbashfile:print("if [ \"`uname -s`\" = \"Darwin\" ]; then")
            genbashfile:print("\t%$NDK_HOME/ndk-build -j8 NDK_PROJECT_PATH=. NDK_APPLICATION_MK=%s $* || { echo \"Build [%s] Error!\"; exit 1; }", appfilename, target.name)
            genbashfile:print("else")
            genbashfile:print("\t%$NDK_HOME/ndk-build.cmd -j8 NDK_PROJECT_PATH=. NDK_APPLICATION_MK=%s $* || { echo \"Build [%s] Error!\"; exit 1; }", appfilename, target.name)
            genbashfile:print("fi")
        else
            genbashfile:print("if [ \"`uname -s`\" = \"Darwin\" ]; then")
            genbashfile:print("\t%$NDK_HOME/ndk-build NDK_PROJECT_PATH=. NDK_APPLICATION_MK=%s $* || { echo \"Build [%s] Error!\"; exit 1; }", appfilename, target.name)
            genbashfile:print("else")
            genbashfile:print("\t%$NDK_HOME/ndk-build.cmd NDK_PROJECT_PATH=. NDK_APPLICATION_MK=%s $* || { echo \"Build [%s] Error!\"; exit 1; }", appfilename, target.name)
            genbashfile:print("fi")
        end
        genbashfile:print("echo \"Build [%s] Done!\"", target.name)
        genbashfile:print("exit 0")
        genbashfile:close()

        genbashs[#genbashs+1] = filename
    end
end

function _make_target_raw(target, mkinfo, target_dir)
    local tmpfile = os.tmpfile() .. ".mk"
    local tmpappfile = io.open(tmpfile, "w")
    _make_target(tmpappfile, target, mkinfo.archs)
    -- close file
    tmpappfile:close()

    local newcontents = nil
    local oldcontents = nil
    local tmpappfile = io.open(tmpfile, "r")
    newcontents = tmpappfile:read("*all")
    tmpappfile:close()

    local mkpath = path.join(target_dir, "Android.mk")
    if os.isfile(mkpath) then
        local tmpmkfile = io.open(mkpath, "r")
        oldcontents = tmpmkfile:read("*all")
        tmpmkfile:close()
    end
    if oldcontents ~= newcontents then
        os.cp(tmpfile, mkpath)
        print("\tAndroid.mk is changed!")
    end
    if os.exists(tmpfile) then
        os.rm(tmpfile)
    end
end

-- make all
function _make_all(mkinfo)
    
    local genallbatfile = io.open(path.join(mkinfo.outputdir, "genall.bat"), "w")
    local genallbashfile = io.open(path.join(mkinfo.outputdir, "genall.sh"), "w")
    do
        genallbatfile:print(":: AUTO GENERATOR BY XMAKE, DO'NOT MODIFY.")

        genallbatfile:print("@echo off")
        genallbatfile:print("")
        genallbatfile:print("@set SELF_PATH=%~dp0")
        genallbatfile:print("@set SELF_PATH=%SELF_PATH:~,-1%")
        genallbatfile:print("cd %SELF_PATH%")
        genallbatfile:print("@echo current dir: %SELF_PATH%")
        genallbatfile:print("")
        genallbatfile:print("@echo check NDK_HOME")
        genallbatfile:print("@IF NOT DEFINED NDK_HOME GOTO :NO_NDK_HOME")
        genallbatfile:print("")
    end
    do
        genallbashfile:print("## AUTO GENERATOR BY XMAKE, DO'NOT MODIFY.")
        genallbashfile:print("echo \"\"")
        genallbashfile:print("SELF_PATH=%$(cd `dirname $0`; pwd)")
        genallbashfile:print("cd $SELF_PATH")
        genallbashfile:print("echo \"current dir: $SELF_PATH\"")
        genallbashfile:print("")
        genallbashfile:print("if [ ! \"$NDK_HOME\" ]; then")
        genallbashfile:print("\techo \"Build Error, NDK_HOME NOT DEFINED!\"")
        genallbashfile:print("\texit 1")
        genallbashfile:print("fi")
        genallbashfile:print("")
    end

    -- make all
    -- whether tb is ta's dep target
    local function _is_dep(ta, tb)
        for _, targetinfo in ipairs( ta.info ) do
            for _, v in pairs( targetinfo.deps ) do
                if v == tb.name then
                    return true
                end
            end
        end
        return false
    end
    local function _is_dep_to_all(ta, list)
        for _, v in ipairs(list) do
            if ta ~= v then
                if _is_dep(v, ta) then
                    return true
                end
            end
        end
        return false
    end
    local sorttargets = {}
    for _, target in pairs(mkinfo.targets) do
        sorttargets[#sorttargets+1] = target
    end 
    table.sort(sorttargets, function(ta, tb)
        local a = _is_dep_to_all(ta, sorttargets)
        local b = _is_dep_to_all(tb, sorttargets)
        if a ~= b then
            return a
        elseif _is_dep(ta, tb) then 
            return true
        else
            return false
        end
    end)

    for i=1, #sorttargets-1 do
        for j=#sorttargets, i+1, -1 do
            local ta = sorttargets[j-1]
            local tb = sorttargets[j]
            if _is_dep(ta, tb) then 
                sorttargets[j-1] = tb
                sorttargets[j] = ta
            end
        end
    end

    local function genbatfile_call(f, target, batfilename)
        f:print("@echo gen %s -- %s", target.name, path.basename(batfilename))
        f:print("cd %s", target.name)
        f:print("call " .. batfilename)
        f:print("@if errorlevel 1 goto :BAD")
        f:print("cd ..")
        f:print("")
        f:print("")
    end
    local function genbashfile_call(f, target, bashfilename)
        f:print("echo \"gen %s -- %s\"", target.name, path.basename(bashfilename))
        f:print("cd %s", target.name)
        f:print("sh ".. bashfilename .. " || { echo \"Build Error!\"; exit 1; }")
        f:print("cd ..")
        f:print("")
        f:print("")
    end

    for _, target in ipairs( sorttargets ) do
        if target.kind ~= "binary" then
            print("gen target["..target.name.."].")
            local target_dir = path.join(mkinfo.outputdir, target.name)

            -- make application.mk
            local appfilenames = _make_application_raw(target, mkinfo, target_dir)

            -- make android.mk
            do
                _make_target_raw(target, mkinfo, target_dir)
            end

            -- make target gen
            local genbats = {}
            local genbashs = {}
            for _, v in ipairs(appfilenames) do
                _make_target_gen(target_dir, target, v, genbats, genbashs)    
            end
            
            do
                for _, v in ipairs(genbats) do
                    genbatfile_call(genallbatfile, target, v)
                end
            end
            do
                for _, v in ipairs(genbashs) do
                    genbashfile_call(genallbashfile, target, v)
                end
            end
        end
    end
    do
        genallbatfile:print("goto :SUCCESS")
        genallbatfile:print("")
        genallbatfile:print("")

        genallbatfile:print(":NO_NDK_HOME")
        genallbatfile:print("@echo.")
        genallbatfile:print("@echo Build Error,NO_NDK_HOME NOT FOUND!")
        genallbatfile:print("@pause")
        genallbatfile:print("@echo.")
        genallbatfile:print("exit /B 1")
        genallbatfile:print("")
        genallbatfile:print("")

        genallbatfile:print(":BAD")
        genallbatfile:print("@echo.")
        genallbatfile:print("@echo Build Error!")
        genallbatfile:print("@echo.")
        genallbatfile:print("@pause")
        genallbatfile:print("exit /B 1")


        genallbatfile:print("")
        genallbatfile:print("")
        genallbatfile:print(":SUCCESS")
        genallbatfile:print("@echo.")
        genallbatfile:print("@echo Build Done!")
        genallbatfile:print("exit /B 0")

        genallbatfile:close()
    end
    do
        genallbashfile:print("echo \"Build Done!\"")
        genallbashfile:print("exit 0")
        genallbashfile:close()
    end
end

-- make
function make(outputdir)

    -- enter project directory
    local olddir = os.cd(project.directory())

    -- remove the log mkfile first
    os.rm(_logfile())

    outputdir = outputdir --path.join(outputdir, "jni")

    --mk info
    local mkinfo = {
        outputdir = outputdir,
    }

    -- init modes
    local modes = option.get("modes")
    if modes then
        mkinfo.modes = {}
        for _, mode in ipairs(modes:split(',')) do
            table.insert(mkinfo.modes, mode:trim())
        end
    else
        mkinfo.modes = project.modes()
    end
    if not mkinfo.modes or #mkinfo.modes == 0 then
        mkinfo.modes = { config.mode() }
    end

    -- init archs
    local archs = option.get("archs")
    if archs then
        mkinfo.archs = {}
        for _, arch in ipairs(archs:split(',')) do
            table.insert(mkinfo.archs, arch:trim())
        end
    else
        mkinfo.archs = platform.archs(config.plat())
    end

    -- load targets

    local targets = {}
    for _, mode in ipairs(mkinfo.modes) do
        for _, arch in ipairs(mkinfo.archs) do

            -- reload config, project and platform
            if mode ~= config.mode() or arch ~= config.arch() then
                
                -- modify config
                config.set("mode", mode, {force=true})
                config.set("arch", arch, {force=true})

                project.clear()

                -- recheck project options
                project.check()

                -- reload platform
                platform.load(config.plat())

                -- reload project
                --project.load()
            end

            -- ensure to enter project directory
            os.cd(project.directory())

            -- save targets
            for targetname, target in pairs(project.targets()) do
                print("checking for the %s.%s.%s.%s ... %s", targetname, mode, arch, target:get("kind"), target:targetfile())
                -- make target with the given mode and arch
                targets[targetname] = targets[targetname] or {}
                local _target = targets[targetname]

                -- init target info
                _target.name = targetname
                _target.kind = target:get("kind")
                _target.scriptdir = target:scriptdir()
                _target.info = _target.info or {}
                _target.target = target
                _target.mkfiledir = path.join(mkinfo.outputdir, targetname)
                _target.projectdir = target:get("projectdir")

                table.insert(_target.info, _make_targetinfo(mode, arch, target))

                -- save all sourcefiles and headerfiles
                _target.sourcefiles = table.unique(table.join(_target.sourcefiles or {}, (target:sourcefiles())))
                _target.headerfiles = table.unique(table.join(_target.headerfiles or {}, (target:headerfiles())))
            end
        end
    end

    mkinfo.targets = targets

    -- make all project
    _make_all(mkinfo)
 
    -- leave project directory
    os.cd(olddir)
end