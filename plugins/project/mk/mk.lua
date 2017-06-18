

-- imports
import("core.base.option")
import("core.tool.tool")
import("core.tool.compiler")
import("core.tool.linker")
import("core.project.config")
import("core.project.project")
import("core.language.language")
import("core.platform.platform")

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

function _make_variables(mkfile, key, values)
    if type(values) == "string" then
        mkfile:print("%s := %s", key, values)
        return
    elseif not values or #values == 0 then
        mkfile:print("%s :=", key)
        return
    end

    for i,v in ipairs(values) do
        if i == 1 then
            mkfile:print("%s := %s", key, v)
        else
            mkfile:print("%s += %s", key, v)
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
        local _, compflags = compiler.compflags(sourcefile, target)
        targetinfo.compflags[sourcefile] = compflags
    end

    targetinfo.links = target:get("links")

    -- ldflags
    targetinfo.ldflags = target:get("ldflags")

    -- includes
    targetinfo.includedirs = target:get("includedirs")

    -- ok
    return targetinfo
end

function _make_prebuilt_links(mkfile, targetinfo)
    for k,v in pairs(targetinfo.links) do
        print(k,v)
    end
end

function _make_target(mkfile, target)
    -- head
    mkfile:print("LOCAL_PATH: = %$(call my-dir)")

    --prebuild link
    _make_prebuilt_links(mkfile, target.info)
end

-- make all
function _make_all(appfile, mkinfo)
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

    appfile:print("# AUTO GENERATOR BY XMAKE, DO'NOT MODIFY.")

    appfile:print("APP_PROJECT_PATH := %s", path.absolute(mkinfo.outputdir):gsub("\\", "/"))

    -- mode
    appfile:print("APP_OPTIM := %s", table.concat( mkinfo.modes, " "):trim())

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
    appfile:print("APP_PLATFORM := %s", "android-14")

    --APP_BUILD_SCRIPT
    appfile:print("APP_BUILD_SCRIPT := %s", "Android.mk")

    --APP_STL
    appfile:print("APP_STL := %s", "gnustl_static")

    --APP_USE_CPP0X
    appfile:print("APP_USE_CPP0X := %s", "true")

    --APP_USE_CPP0X
    _make_variables(appfile, "APP_CPPFLAGS", "true")

    local androidfile = io.open(path.join(mkinfo.outputdir, "Android.mk"), "w")

    androidfile:print("LOCAL_PATH := %$(call my-dir)")

    -- make .vcxproj
    for _, target in pairs(mkinfo.targets) do

        androidfile:print("include %$(LOCAL_PATH)/%s/Android.mk", target.name)

        local target_dir = path.join(mkinfo.outputdir, target.name)

        local mkfile = io.open(path.join(target_dir, "Android.mk"), "w")

        _make_target(mkfile, target)

        -- close the mkfile
        mkfile:close()
    end

    androidfile:close()
end

-- make
function make(outputdir)

    -- enter project directory
    local olddir = os.cd(project.directory())

    -- remove the log mkfile first
    os.rm(_logfile())

    outputdir = path.join(outputdir, "jni")

    --mk info
    local mkinfo = {
        outputdir = outputdir,
    }

    print("plat", config.get("plat"))
    config.set("plat", "android")
    config.changed()
    print("plat", config.get("plat"))

    -- init modes
    local all_modes = {"release","debug"}
    local modes = option.get("mode")
    if modes then
        mkinfo.modes = {}
        for _, mode in ipairs(modes:split(',')) do
            table.insert(mkinfo.modes, mode:trim())
        end
    else
        mkinfo.modes = all_modes
    end

    -- init archs
    local archs = option.get("arch")
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
                config.set("mode", mode)
                config.set("arch", arch)

                -- recheck project options
                project.check(true)

                -- reload platform
                platform.load(config.plat())

                -- reload project
                project.load()
            end

            -- save targets
            for targetname, target in pairs(project.targets()) do

                -- make target with the given mode and arch
                targets[targetname] = targets[targetname] or {}
                local _target = targets[targetname]

                -- init target info
                _target.name = targetname
                _target.kind = target:get("kind")
                _target.scriptdir = target:scriptdir()
                _target.info = _target.info or {}
                table.insert(_target.info, _make_targetinfo(mode, arch, target))

                -- save all sourcefiles and headerfiles
                _target.sourcefiles = table.unique(table.join(_target.sourcefiles or {}, (target:sourcefiles())))
                _target.headerfiles = table.unique(table.join(_target.headerfiles or {}, (target:headerfiles())))
            end
        end
    end

    mkinfo.targets = targets

    -- open the Application.mk
    local appfile = io.open(path.join(outputdir, "Application.mk"), "w")

    -- make all project
    _make_all(appfile, mkinfo)

    -- close the mkfile
    appfile:close()
 
    -- leave project directory
    os.cd(olddir)
end