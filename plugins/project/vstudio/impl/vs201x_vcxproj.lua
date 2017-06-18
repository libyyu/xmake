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
-- @file        vs201x_vcxproj.lua
--

-- imports
import("core.project.config")
import("vsfile")

-- make compiling flags
function _make_compflags(sourcefile, targetinfo, vcxprojdir)

    -- translate path for -Idir or /Idir, -Fdsymbol.pdb or /Fdsymbol.pdb
    local flags = {}
    for _, flag in ipairs(targetinfo.compflags[sourcefile]) do
        -- -Idir or /Idir
        flag = flag:gsub("[%-|/]I(.*)", function (dir)
                        dir = dir:trim()
                        if not path.is_absolute(dir) then
                            dir = path.relative(path.absolute(dir), vcxprojdir)
                        end
                        return "/I" .. dir
                    end)

        -- -Fdsymbol.pdb or /Fdsymbol.pdb
        flag = flag:gsub("[%-|/]Fd(.*)", function (dir)
                        dir = dir:trim()
                        if not path.is_absolute(dir) then
                            dir = path.relative(path.absolute(dir), vcxprojdir)
                        end
                        return "/Fd" .. dir
                    end)

        -- save flag
        table.insert(flags, flag)
    end

    -- ok?
    return flags
end

-- make linking flags
function _make_linkflags(targetinfo, vcxprojdir, vcxprojfile)
    --modify by ldf
    local arch = targetinfo.arch == "Win32" and "x86" or targetinfo.arch
        
    -- replace -libpath:dir or /libpath:dir, -pdb:symbol.pdb or /pdb:symbol.pdb
    local flags = {}
    local lib_paths = {}
    local lib_files = {}
    for _, flag in ipairs(targetinfo.linkflags) do
        local excluded = false

        -- replace -libpath:dir or /libpath:dir
        if flag:find("[%-|/]libpath:(.*)") then
            excluded = true
            flag = flag:gsub("[%-|/]libpath:(.*)", function (dir)
                            dir = dir:trim()
                            if not path.is_absolute(dir) then
                                dir = path.relative(path.absolute(dir), vcxprojdir)
                            end
                            
                            local path_pre,path_last
                            for k, v in dir:gmatch("(.*)"..arch.."(.*)") do
                                path_pre, path_last = k, v or ""
                            end
                            if path_pre then
                                return path_pre .. targetinfo.mode .. "\\" .. arch .. path_last
                            else
                                return dir
                            end
                        end)
            table.insert(lib_paths,flag)
        end

        -- replace -pdb:symbol.pdb or /pdb:symbol.pdb
        flag = flag:gsub("[%-|/]pdb:(.*)", function (dir)
                        dir = dir:trim()
                        if not path.is_absolute(dir) then
                            dir = path.relative(path.absolute(dir), vcxprojdir)
                        end
                        local path_pre,path_last
                        for k, v in dir:gmatch("(.*)"..arch.."(.*)") do
                            path_pre, path_last = k, v or ""
                        end
                        if path_pre then
                            return "/pdb:" .. path_pre .. targetinfo.mode .. "\\" .. arch .. path_last
                        else
                            return "/pdb:" .. dir
                        end
                        return "/pdb:" .. dir
                    end)

        --remove -machine:x86 or -machine:x64
        flag = flag:gsub("[%-|/]machine:(.*)", function (dir)
                        return ""
                    end)

        --remove default lib
        local excludes_libs = {
            "user32.lib"
            , "kernel32.lib"
            , "gdi32.lib"
            , "winspool.lib"
            , "comdlg32.lib"
            , "advapi32.lib"
            , "shell32.lib"
            , "ole32.lib"
            , "oleaut32.lib"
            , "uuid.lib"
            , "odbc32.lib"
            , "odbccp32.lib"
        }
        for _, lib in ipairs(excludes_libs) do
            if flag:find(lib) then
                excluded = true
                break
            end
        end
        if not excluded and flag:find("(.*).lib") then
            excluded = true
            table.insert(lib_files, flag)
        end

        -- save flag
        if not excluded then
            table.insert(flags, flag)
        end
    end
    
    -- make lib search path
    local str_libdirs = table.concat(lib_paths,";"):trim()
    vcxprojfile:print("<AdditionalLibraryDirectories>%s;%%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>", str_libdirs)
    
    -- make libs
    local str_libfiles = table.concat(lib_files,";"):trim()
    vcxprojfile:print("<AdditionalDependencies>%s;%%(AdditionalDependencies)</AdditionalDependencies>", str_libfiles)
    
    -- make AdditionalOptions
    vcxprojfile:print("<AdditionalOptions>%s %%(AdditionalOptions)</AdditionalOptions>", table.concat(flags, " "):trim())

    -- ok?
    return flags
end

function _make_entrypointsymbol(targetinfo, vcxprojdir)
    local entry_symbol = nil
    for _, flag in ipairs(targetinfo.ldflags) do
        if flag:find("[%-|/]ENTRY:\"(.*)\"") then
            flag:gsub("[%-|/]ENTRY:\"(.*)\"", function(symbol)
                entry_symbol = symbol:trim()
                return ""
            end)
            break
        end
    end
    return entry_symbol
end

-- make header
function _make_header(vcxprojfile, vsinfo)

    -- the versions
    local versions = 
    {
        vs2010 = '4'
    ,   vs2012 = '4'
    ,   vs2013 = '12'
    ,   vs2015 = '14'
    ,   vs2017 = '15'
    }

    -- make header
    vcxprojfile:print("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
    vcxprojfile:enter("<Project DefaultTargets=\"Build\" ToolsVersion=\"%s.0\" xmlns=\"http://schemas.microsoft.com/developer/msbuild/2003\">", assert(versions["vs" .. vsinfo.vstudio_version]))
end

-- make tailer
function _make_tailer(vcxprojfile, vsinfo)
    vcxprojfile:print("<Import Project=\"%$(VCTargetsPath)\\Microsoft.Cpp.targets\" />")
    vcxprojfile:enter("<ImportGroup Label=\"ExtensionTargets\">")
    vcxprojfile:leave("</ImportGroup>")
    vcxprojfile:leave("</Project>")
end

-- make Configurations
function _make_configurations(vcxprojfile, vsinfo, target, vcxprojdir)

    -- the target name
    local targetname = target.name

    -- init configuration type
    local configuration_types =
    {
        binary = "Application"
    ,   shared = "DynamicLibrary"
    ,   static = "StaticLibrary"
    }

    -- the toolset versions
    local toolset_versions = 
    {
        vs2010 = "100"
    ,   vs2012 = "110"
    ,   vs2013 = "120"
    ,   vs2015 = "140"
    ,   vs2017 = "141"
    }

    -- the sdk version
    local sdk_versions = 
    {
        vs2015 = "10.0.10240.0"
    ,   vs2017 = "10.0.14393.0"
    }

    -- make ProjectConfigurations
    vcxprojfile:enter("<ItemGroup Label=\"ProjectConfigurations\">")
    for _, targetinfo in ipairs(target.info) do
        vcxprojfile:enter("<ProjectConfiguration Include=\"%s|%s\">", targetinfo.mode, targetinfo.arch)
            vcxprojfile:print("<Configuration>%s</Configuration>", targetinfo.mode)
            vcxprojfile:print("<Platform>%s</Platform>", targetinfo.arch)
        vcxprojfile:leave("</ProjectConfiguration>")
    end
    vcxprojfile:leave("</ItemGroup>")

    -- make Globals
    vcxprojfile:enter("<PropertyGroup Label=\"Globals\">")
        vcxprojfile:print("<ProjectGuid>{%s}</ProjectGuid>", os.uuid(targetname))
        vcxprojfile:print("<RootNamespace>%s</RootNamespace>", targetname)
        if vsinfo.vstudio_version >= "2015" then
            vcxprojfile:print("<WindowsTargetPlatformVersion>%s</WindowsTargetPlatformVersion>", sdk_versions["vs" .. vsinfo.vstudio_version])
        end
    vcxprojfile:leave("</PropertyGroup>")

    -- import Microsoft.Cpp.Default.props
    vcxprojfile:print("<Import Project=\"%$(VCTargetsPath)\\Microsoft.Cpp.Default.props\" />")

    -- make Configuration
    for _, targetinfo in ipairs(target.info) do
        vcxprojfile:enter("<PropertyGroup Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\" Label=\"Configuration\">", targetinfo.mode, targetinfo.arch)
            vcxprojfile:print("<ConfigurationType>%s</ConfigurationType>", assert(configuration_types[target.kind]))
            vcxprojfile:print("<PlatformToolset>v%s</PlatformToolset>", assert(toolset_versions["vs" .. vsinfo.vstudio_version]))
            vcxprojfile:print("<CharacterSet>MultiByte</CharacterSet>")
        vcxprojfile:leave("</PropertyGroup>")
    end

    -- import Microsoft.Cpp.props
    vcxprojfile:print("<Import Project=\"%$(VCTargetsPath)\\Microsoft.Cpp.props\" />")

    -- make ExtensionSettings
    vcxprojfile:enter("<ImportGroup Label=\"ExtensionSettings\">")
    vcxprojfile:leave("</ImportGroup>")

    -- make PropertySheets
    for _, targetinfo in ipairs(target.info) do
        vcxprojfile:enter("<ImportGroup Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\" Label=\"PropertySheets\">", targetinfo.mode, targetinfo.arch)
            vcxprojfile:print("<Import Project=\"%$(UserRootDir)\\Microsoft.Cpp.%$(Platform).user.props\" Condition=\"exists(\'%$(UserRootDir)\\Microsoft.Cpp.%$(Platform).user.props\')\" Label=\"LocalAppDataPlatform\" />")
        vcxprojfile:leave("</ImportGroup>")
    end

    -- make UserMacros
    vcxprojfile:print("<PropertyGroup Label=\"UserMacros\" />")

    -- make OutputDirectory and IntermediateDirectory
    for _, targetinfo in ipairs(target.info) do
        vcxprojfile:enter("<PropertyGroup Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\">", targetinfo.mode, targetinfo.arch)
            local relative_path = path.relative(path.absolute("$(plat)"), vcxprojdir) --path.relative(path.absolute(config.get("buildir")), vcxprojdir)
            vcxprojfile:print("<OutDir>%s\\%s\\%$(Configuration)\\</OutDir>", relative_path, ifelse(targetinfo.arch == "Win32", "x86", targetinfo.arch) )
            vcxprojfile:print("<IntDir>%$(Configuration)\\</IntDir>")
            if target.kind == "binary" then
                vcxprojfile:print("<LinkIncremental>true</LinkIncremental>")
            end
        vcxprojfile:leave("</PropertyGroup>")
    end
end

-- make source options
function _make_source_options(vcxprojfile, targetinfo, condition)

    -- exists condition?
    condition = condition or ""

    -- get flags string
    local flags = targetinfo.commonflags
    local flagstr = table.concat(flags, " ")

    -- make Optimization
    if flagstr:find("[%-|/]Os") or flagstr:find("[%-|/]O1") then
        vcxprojfile:print("<Optimization%s>MinSpace</Optimization>", condition) 
    elseif flagstr:find("[%-|/]O2") or flagstr:find("[%-|/]Ot") then
        vcxprojfile:print("<Optimization%s>MaxSpeed</Optimization>", condition) 
    elseif flagstr:find("[%-|/]Ox") then
        vcxprojfile:print("<Optimization%s>Full</Optimization>", condition) 
    else
        vcxprojfile:print("<Optimization%s>Disabled</Optimization>", condition) 
    end

    -- make WarningLevel
    if flagstr:find("[%-|/]W1") then
        vcxprojfile:print("<WarningLevel%s>Level1</WarningLevel>", condition) 
    elseif flagstr:find("[%-|/]W2") then
        vcxprojfile:print("<WarningLevel%s>Level2</WarningLevel>", condition) 
    elseif flagstr:find("[%-|/]W3") then
        vcxprojfile:print("<WarningLevel%s>Level3</WarningLevel>", condition) 
    elseif flagstr:find("[%-|/]Wall") then
        vcxprojfile:print("<WarningLevel%s>EnableAllWarnings</WarningLevel>", condition) 
    else
        vcxprojfile:print("<WarningLevel%s>TurnOffAllWarnings</WarningLevel>", condition) 
    end
    if flagstr:find("[%-|/]WX") then
        vcxprojfile:print("<TreatWarningAsError%s>true</TreatWarningAsError>", condition) 
    end

    -- make DebugInformationFormat
    if flagstr:find("[%-|/]Zi") then
        vcxprojfile:print("<DebugInformationFormat%s>ProgramDatabase</DebugInformationFormat>", condition)
    elseif flagstr:find("[%-|/]ZI") then
        vcxprojfile:print("<DebugInformationFormat%s>EditAndContinue</DebugInformationFormat>", condition)
    elseif flagstr:find("[%-|/]Z7") then
        vcxprojfile:print("<DebugInformationFormat%s>OldStyle</DebugInformationFormat>", condition)
    else
        vcxprojfile:print("<DebugInformationFormat%s>None</DebugInformationFormat>", condition)
    end

    -- make RuntimeLibrary
    if flagstr:find("[%-|/]MDd") then
        vcxprojfile:print("<RuntimeLibrary%s>MultiThreadedDebugDLL</RuntimeLibrary>", condition)
    elseif flagstr:find("[%-|/]MD") then
        vcxprojfile:print("<RuntimeLibrary%s>MultiThreadedDLL</RuntimeLibrary>", condition)
    elseif flagstr:find("[%-|/]MTd") then
        vcxprojfile:print("<RuntimeLibrary%s>MultiThreadedDebug</RuntimeLibrary>", condition)
    elseif flagstr:find("[%-|/]MT") then
        vcxprojfile:print("<RuntimeLibrary%s>MultiThreaded</RuntimeLibrary>", condition)
    end

    -- complie as c++ if exists flag: /TP
    if flagstr:find("[%-|/]TP") then
        vcxprojfile:print("<CompileAs%s>CompileAsCpp</CompileAs>", condition)
    end

    -- make AdditionalOptions
    local includedirs = {}
    local predefinitions = {}
    local additional_flags = {}
    local excludes = {"Os", "O0", "O1", "O2", "Ot", "Ox", "W0", "W1", "W2", "W3", "WX", "Wall", "Zi", "ZI", "Z7", "MT", "MTd", "MD", "MDd", "TP", "I", "D" }
    for _, flag in ipairs(flags) do
        local excluded = false
        local is_include_dir = false
        local is_pre_define = false
        for _, exclude in ipairs(excludes) do
            if flag:find("[%-|/]" .. exclude) then
                excluded = true
                is_include_dir = exclude == "I"
                is_pre_define = exclude == "D"
                break
            end
        end
        if not excluded then
            table.insert(additional_flags, flag)
        end
        -- include paths
        if is_include_dir then
            local search_dir = flag:gsub("[%-|/]I(.*)", function(dir)
                dir = dir:trim()
                return dir
            end)
            table.insert(includedirs, search_dir)
        end
        -- pre defines
        if is_pre_define then
            local definition = flag:gsub("[%-|/]D(.*)", function(define)
                define = define:trim()
                return define
            end)
            table.insert(predefinitions, definition)
        end
    end
    -- make include path
    local str_includedirs = table.concat(includedirs,";"):trim()
    vcxprojfile:print("<AdditionalIncludeDirectories>%s;%%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>", str_includedirs)
    
    -- make predefinitions
    local str_predefinitions = table.concat(predefinitions,";"):trim()
    vcxprojfile:print("<PreprocessorDefinitions>%s;%%(PreprocessorDefinitions)</PreprocessorDefinitions>", str_predefinitions)
    

    vcxprojfile:print("<AdditionalOptions%s>%s %%(AdditionalOptions)</AdditionalOptions>", condition, table.concat(additional_flags, " "):trim())
end

-- make common item 
function _make_common_item(vcxprojfile, vsinfo, targetinfo, vcxprojdir)

    -- enter ItemDefinitionGroup 
    vcxprojfile:enter("<ItemDefinitionGroup Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\">", targetinfo.mode, targetinfo.arch)
    
    -- for linker?
    if targetinfo.targetkind == "binary" or targetinfo.targetkind == "shared" then
        vcxprojfile:enter("<Link>")

            -- make linker flags
            _make_linkflags(targetinfo, vcxprojdir, vcxprojfile)
            --local flags = table.concat(_make_linkflags(targetinfo, vcxprojdir, vcxprojfile), " "):trim()

            -- make AdditionalOptions
            --vcxprojfile:print("<AdditionalOptions>%s %%(AdditionalOptions)</AdditionalOptions>", flags)

            -- generate debug infomation?
            local debug = false
            for _, symbol in ipairs(targetinfo.symbols) do
                if symbol == "debug" then
                    debug = true
                    break
                end
            end
            vcxprojfile:print("<GenerateDebugInformation>%s</GenerateDebugInformation>", tostring(debug))

            -- make SubSystem
            vcxprojfile:print("<SubSystem>%s</SubSystem>", ifelse(targetinfo.targetkind == "binary", "Console", ""))
        
            -- make TargetMachine
            vcxprojfile:print("<TargetMachine>%s</TargetMachine>", ifelse(targetinfo.arch == "x64", "MachineX64", "MachineX86"))

            -- make EntryPointSymbol
            local entry_symbol = _make_entrypointsymbol(targetinfo, vcxprojdir)
            if entry_symbol then
                vcxprojfile:print("<EntryPointSymbol>%s</EntryPointSymbol>", entry_symbol)
            end

        vcxprojfile:leave("</Link>")
    end

    -- for compiler?
    vcxprojfile:enter("<ClCompile>")

        -- make source options
        _make_source_options(vcxprojfile, targetinfo)

        -- make ProgramDataBaseFileName (default: empty)
        vcxprojfile:print("<ProgramDataBaseFileName></ProgramDataBaseFileName>") 

    vcxprojfile:leave("</ClCompile>")

    -- leave ItemDefinitionGroup 
    vcxprojfile:leave("</ItemDefinitionGroup>")
end

-- make common items
function _make_common_items(vcxprojfile, vsinfo, target, vcxprojdir)

    -- for each mode and arch
    for _, targetinfo in ipairs(target.info) do

        -- make source flags
        local flags_stats = {}
        local files_count = 0
        local first_flags = nil
        targetinfo.sourceflags = {}
        for sourcekind, sourcebatch in pairs(targetinfo.sourcebatches) do
            if sourcekind == "cc" or sourcekind == "cxx" then
                for _, sourcefile in ipairs(sourcebatch.sourcefiles) do

                    -- make compiler flags
                    local flags = _make_compflags(sourcefile, targetinfo, vcxprojdir)
                    for _, flag in ipairs(flags) do
                        flags_stats[flag] = (flags_stats[flag] or 0) + 1
                    end

                    -- update files count
                    files_count = files_count + 1

                    -- save first flags
                    if first_flags == nil then
                        first_flags = flags
                    end

                    -- save source flags
                    targetinfo.sourceflags[sourcefile] = flags
                end
            end
        end

        -- make common flags
        targetinfo.commonflags = {}
        for _, flag in ipairs(first_flags) do
            if flags_stats[flag] == files_count then
                table.insert(targetinfo.commonflags, flag)
            end
        end

        -- remove common flags from source flags
        local sourceflags = {}
        for sourcefile, flags in pairs(targetinfo.sourceflags) do
            local otherflags = {}
            for _, flag in ipairs(flags) do
                if flags_stats[flag] ~= files_count then
                    table.insert(otherflags, flag)
                end
            end
            sourceflags[sourcefile] = otherflags
        end
        targetinfo.sourceflags = sourceflags

        -- make common item
        _make_common_item(vcxprojfile, vsinfo, targetinfo, vcxprojdir)
    end
end

-- make header file
function _make_header_file(vcxprojfile, includefile, vcxprojdir)
    vcxprojfile:print("<ClInclude Include=\"%s\" />", path.relative(path.absolute(includefile), vcxprojdir))
end

-- make source file for all modes
function _make_source_file_forall(vcxprojfile, vsinfo, sourcefile, sourceinfo, vcxprojdir)

    -- get object file 
    local objectfile = nil
    local arch = nil
    for _, info in ipairs(sourceinfo) do
        objectfile = info.objectfile
        arch = info.arch
        break
    end

    -- enter it
    vcxprojfile:enter("<ClCompile Include=\"%s\">", path.relative(path.absolute(sourcefile), vcxprojdir))

        -- make ObjectFileName
        local arch_find = arch == "Win32" and "x86" or arch
        local objpath = path.relative(path.absolute(objectfile), vcxprojdir)
        local path_pre,path_last
        for k, v in objpath:gmatch("(.*)"..arch_find.."(.*)") do
            path_pre, path_last = k, v
        end
        vcxprojfile:print("<ObjectFileName>%s%$(Configuration)\\%$(Platform)%s</ObjectFileName>", path_pre, path_last)

        -- make AdditionalOptions
        local mergeflags = {}
        for _, info in ipairs(sourceinfo) do
            local flags = table.concat(info.flags, " "):trim()
            if flags ~= "" then 
                mergeflags[flags] = mergeflags[flags] or {}
                mergeflags[flags][info.mode .. '|' .. info.arch] = true
            end
        end
        for flags, mergeinfos in pairs(mergeflags) do

            -- merge mode and arch first
            local count = 0
            for _, mode in ipairs(vsinfo.modes) do
                if mergeinfos[mode .. "|Win32"] and mergeinfos[mode .. "|x64"] then
                    mergeinfos[mode .. "|Win32"] = nil
                    mergeinfos[mode .. "|x64"]   = nil
                    mergeinfos[mode]             = true
                end
                if mergeinfos[mode] then
                    count = count + 1
                end
            end

            -- all modes and archs exist?
            if count == #vsinfo.modes then
                vcxprojfile:print("<AdditionalOptions>%s %%(AdditionalOptions)</AdditionalOptions>", flags)
            else
                for cond, _ in pairs(mergeinfos) do
                    if cond:find('|', 1, true) then
                        -- for mode | arch
                        vcxprojfile:print("<AdditionalOptions Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s\'\">%s %%(AdditionalOptions)</AdditionalOptions>", cond, flags)
                    else
                        -- only for mode
                        vcxprojfile:print("<AdditionalOptions Condition=\"\'%$(Configuration)\'==\'%s\'\">%s %%(AdditionalOptions)</AdditionalOptions>", cond, flags)
                    end
                end
            end
        end

    -- leave it
    vcxprojfile:leave("</ClCompile>")
end

-- make source file for specific modes
function _make_source_file_forspec(vcxprojfile, vsinfo, sourcefile, sourceinfo, vcxprojdir)

    -- add source file
    for _, info in ipairs(sourceinfo) do

        -- enter it
        vcxprojfile:enter("<ClCompile Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\" Include=\"%s\">", info.mode, info.arch, path.relative(path.absolute(sourcefile), vcxprojdir))

        -- make ObjectFileName
        vcxprojfile:print("<ObjectFileName>%s</ObjectFileName>", path.relative(path.absolute(info.objectfile), vcxprojdir))

        -- get source flags
        local flags = table.concat(info.flags, " "):trim()

        -- make AdditionalOptions 
        if flags ~= "" then 
            vcxprojfile:print("<AdditionalOptions>%s %%(AdditionalOptions)</AdditionalOptions>", flags)
        end

        -- leave it
        vcxprojfile:leave("</ClCompile>")
    end
end

-- make source files
function _make_source_files(vcxprojfile, vsinfo, target, vcxprojdir)

    -- enter ItemGroup
    vcxprojfile:enter("<ItemGroup>")

        -- make source file infos
        local sourceinfos = {}
        for _, targetinfo in ipairs(target.info) do
            for sourcekind, sourcebatch in pairs(targetinfo.sourcebatches) do
                if sourcekind == "cc" or sourcekind == "cxx" then
                    local objectfiles = sourcebatch.objectfiles
                    for idx, sourcefile in ipairs(sourcebatch.sourcefiles) do
                        local objectfile    = objectfiles[idx]
                        local flags         = targetinfo.sourceflags[sourcefile]
                        sourceinfos[sourcefile] = sourceinfos[sourcefile] or {}
                        table.insert(sourceinfos[sourcefile], {mode = targetinfo.mode, arch = targetinfo.arch, objectfile = objectfile, flags = flags})
                    end
                end
            end
        end

        -- make source files
        for sourcefile, sourceinfo in pairs(sourceinfos) do
            if #sourceinfo == #target.info then
                _make_source_file_forall(vcxprojfile, vsinfo, sourcefile, sourceinfo, vcxprojdir) 
            else
                _make_source_file_forspec(vcxprojfile, vsinfo, sourcefile, sourceinfo, vcxprojdir) 
            end
        end

    vcxprojfile:leave("</ItemGroup>")

    -- enter header group
    vcxprojfile:enter("<ItemGroup>")

        -- add headers
        for _, includefile in ipairs(target.headerfiles) do
            _make_header_file(vcxprojfile, includefile, vcxprojdir)
        end
    vcxprojfile:leave("</ItemGroup>")
end

-- make vcxproj
function make(vsinfo, target)

    -- the target name
    local targetname = target.name

    -- the vcxproj directory
    local vcxprojdir = path.join(vsinfo.solution_dir, targetname)

    -- open vcxproj file
    local vcxprojfile = vsfile.open(path.join(vcxprojdir, targetname .. ".vcxproj"), "w")

    -- init indent character
    vsfile.indentchar('  ')

    -- make header
    _make_header(vcxprojfile, vsinfo)

    -- make Configurations
    _make_configurations(vcxprojfile, vsinfo, target, vcxprojdir)

    -- make common items
    _make_common_items(vcxprojfile, vsinfo, target, vcxprojdir)

    -- make source files
    _make_source_files(vcxprojfile, vsinfo, target, vcxprojdir)

    -- make tailer
    _make_tailer(vcxprojfile, vsinfo)

    -- exit solution file
    vcxprojfile:close()
end