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
-- @file        vs201x_vcxproj.lua
--

-- imports
import("core.project.config")
import("core.language.language")
import("vsfile")

-- get toolset version
function _get_toolset_ver(targetinfo, vsinfo)

    -- the toolset versions
    local toolset_vers = 
    {
        vs2010 = "v100"
    ,   vs2012 = "v110"
    ,   vs2013 = "v120"
    ,   vs2015 = "v140"
    ,   vs2017 = "v141"
    ,   vs2019 = "v142"
    ,   vs2022 = "v143"
    }

    -- get toolset version from vs version
    local toolset_ver = nil
    local vs_toolset = config.get("vs_toolset")
    if vs_toolset then
        local verinfo = vs_toolset:split('%.')
        toolset_ver = "v" .. verinfo[1] .. (verinfo[2] or "0")
    end
    if not toolset_ver then
        toolset_ver = toolset_vers["vs" .. vsinfo.vstudio_version]
    end

    -- for xp?
    for _, flag in ipairs(targetinfo.linkflags) do
        if flag:lower():find("^[%-/]subsystem:.-,5%.%d+$") then
            toolset_ver = toolset_ver .. "_xp"
            break
        end
    end

    -- done
    return toolset_ver
end

-- get platform sdk version
function _get_platform_sdkver(target, vsinfo)

    -- the default sdk version
    local sdkvers = 
    {
        vs2015 = "10.0.10240.0"
    ,   vs2017 = "10.0.14393.0"
    ,   vs2019 = "10.0.17763.0"
    ,   vs2022 = "10.0.22621.0"
    }

    -- get sdk version for vcvarsall[arch].WindowsSDKVersion
    local sdkver = nil
    for _, targetinfo in ipairs(target.info) do
        sdkver = targetinfo.sdkver
        if sdkver then
            break
        end
    end

    -- done
    return sdkver or sdkvers["vs" .. vsinfo.vstudio_version]
end

-- make compiling command
function _make_compcmd(compargv, sourcefile, objectfile, vcxprojdir)
    local argv = {}
    for _, v in ipairs(compargv) do
        v = v:gsub("__sourcefile__", sourcefile)
        v = v:gsub("__objectfile__", objectfile)
        -- -Idir or /Idir
        v = v:gsub("([%-/]I)(.*)", function (I, dir)
                dir = path.translate(dir:trim())
                --if not path.is_absolute(dir) then
                    dir = path.relative(path.absolute(dir), vcxprojdir)
                --end
                return I .. dir
            end)
        table.insert(argv, v)
    end
    return table.concat(argv, " ")
end

-- make compiling flags
function _make_compflags(sourcefile, targetinfo, vcxprojdir)

    -- translate path for -Idir or /Idir
    local flags = {}
    for _, flag in ipairs(targetinfo.compflags[sourcefile]) do

        -- -Idir or /Idir
        flag = flag:gsub("[%-/]I(.*)", function (dir)
                        dir = path.translate(dir:trim())
                        --if not path.is_absolute(dir) then
                            dir = path.relative(path.absolute(dir), vcxprojdir)
                        --end
                        return "/I" .. dir
                    end)

        -- -Fdsymbol.pdb or /Fdsymbol.pdb
        flag = flag:gsub("[%-/]Fd(.*)", function (dir)
                        dir = path.translate(dir:trim())
                        if not path.is_absolute(dir) then
                            dir = path.relative(path.absolute(dir), vcxprojdir)
                        end
                        dir = path.relative(dir, vcxprojdir)
                        return "/Fd" .. dir
                    end)

        -- save flag
        table.insert(flags, flag)
    end

    -- add -D__config_$(mode)__ and -D__config_$(arch)__ for the config header
    table.insert(flags, "-D__config_" .. targetinfo.mode .. "__")
    table.insert(flags, "-D__config_" .. targetinfo.arch .. "__")

    -- ok?
    return flags
end

-- make linking flags
function _make_linkflags(targetinfo, vcxprojdir)

    -- replace -libpath:dir or /libpath:dir, -pdb:symbol.pdb or /pdb:symbol.pdb
    local flags = {}
    for _, flag in ipairs(targetinfo.linkflags) do

        -- replace -libpath:dir or /libpath:dir
        flag = flag:gsub(string.ipattern("[%-/]libpath:(.*)"), function (dir)
                            dir = path.translate(dir:trim())
                            --if not path.is_absolute(dir) then
                                dir = path.relative(path.absolute(dir), vcxprojdir)
                            --end
                            return "/libpath:"..dir
                        end)

        -- replace -def:dir or /def:dir
        flag = flag:gsub(string.ipattern("[%-/]def:(.*)"), function (dir)
                        dir = path.translate(dir:trim())
                        --if not path.is_absolute(dir) then
                            dir = path.relative(path.absolute(dir), vcxprojdir)
                        --end
                        return "/def:" .. dir
                    end)

        -- save flag
        table.insert(flags, flag)
    end

    -- ok?
    return flags
end

function _make_ldflags(targetinfo, vcxprojdir, vcxprojfile)
    local has_dataexeprevention = false
    local has_linktimecodegeneration = false
    for _, flag in ipairs(targetinfo.ldflags) do
       
        -- make EntryPointSymbol
        if flag:find(string.ipattern("[%-/]ENTRY:\"(.*)\"")) then
            local entry_symbol = flag:gsub(string.ipattern("[%-/]ENTRY:\"(.*)\""), function(symbol)
                return symbol:trim()
            end)
            
            vcxprojfile:print("<EntryPointSymbol>%s</EntryPointSymbol>", entry_symbol)
        end

        -- make RandomizedBaseAddress
        if flag:find(string.ipattern("[%-/]DYNAMICBASE:(.*)")) then
            local dynamicbase = flag:gsub(string.ipattern("[%-/]DYNAMICBASE:(.*)"), function (value)
                return value:trim()
            end)

            vcxprojfile:print("<RandomizedBaseAddress>%s</RandomizedBaseAddress>", dynamicbase == "NO" and "false" or "true")
        end

        -- make RandomizedBaseAddress
        if flag:find(string.ipattern("[%-/]NXCOMPAT:(.*)")) then
            has_dataexeprevention = true
            local dataexeprevention = flag:gsub(string.ipattern("[%-/]NXCOMPAT:(.*)"), function (value)
                return value:trim()
            end)
            
            vcxprojfile:print("<DataExecutionPrevention>%s</DataExecutionPrevention>", dataexeprevention == "NO" and "false" or "true")
        end

        if flag:find(string.ipattern("[%-/]LTCG")) then
            has_linktimecodegeneration = true
            vcxprojfile:print("<LinkTimeCodeGeneration>%s</LinkTimeCodeGeneration>", "true")
        end
    end

    -- -- make RandomizedBaseAddress: inherit
    -- if not has_dataexeprevention then
    --     vcxprojfile:print("<DataExecutionPrevention></DataExecutionPrevention>")
    -- end

    -- if not has_linktimecodegeneration then
    --     vcxprojfile:print("<LinkTimeCodeGeneration>%s</LinkTimeCodeGeneration>", "false")
    -- end
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
    ,   vs2019 = '16'
    ,   vs2022 = '17'
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
    local function fix_arch(targetinfo)
        return targetinfo.arch == "x86" and "Win32" or targetinfo.arch
    end

    -- make ProjectConfigurations
    vcxprojfile:enter("<ItemGroup Label=\"ProjectConfigurations\">")
    for _, targetinfo in ipairs(target.info) do
        vcxprojfile:enter("<ProjectConfiguration Include=\"%s|%s\">", targetinfo.mode, fix_arch(targetinfo))
            vcxprojfile:print("<Configuration>%s</Configuration>", targetinfo.mode)
            vcxprojfile:print("<Platform>%s</Platform>", fix_arch(targetinfo))
        vcxprojfile:leave("</ProjectConfiguration>")
    end
    vcxprojfile:leave("</ItemGroup>")

    -- make Globals
    vcxprojfile:enter("<PropertyGroup Label=\"Globals\">")
        vcxprojfile:print("<ProjectGuid>{%s}</ProjectGuid>", hash.uuid(targetname))
        vcxprojfile:print("<RootNamespace>%s</RootNamespace>", targetname)
        if vsinfo.vstudio_version >= "2015" then
            vcxprojfile:print("<WindowsTargetPlatformVersion>%s</WindowsTargetPlatformVersion>", _get_platform_sdkver(target, vsinfo))
        end
    vcxprojfile:leave("</PropertyGroup>")

    -- import Microsoft.Cpp.Default.props
    vcxprojfile:print("<Import Project=\"%$(VCTargetsPath)\\Microsoft.Cpp.Default.props\" />")

    -- make Configuration
    for _, targetinfo in ipairs(target.info) do
        vcxprojfile:enter("<PropertyGroup Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\" Label=\"Configuration\">", targetinfo.mode, fix_arch(targetinfo))
            vcxprojfile:print("<ConfigurationType>%s</ConfigurationType>", assert(configuration_types[target.kind]))
            vcxprojfile:print("<PlatformToolset>%s</PlatformToolset>", _get_toolset_ver(targetinfo, vsinfo))
            vcxprojfile:print("<CharacterSet>%s</CharacterSet>", targetinfo.unicode and "Unicode" or "MultiByte")
            if targetinfo.usemfc then
                vcxprojfile:print("<UseOfMfc>%s</UseOfMfc>", targetinfo.usemfc)
            end
        vcxprojfile:leave("</PropertyGroup>")
    end

    -- import Microsoft.Cpp.props
    vcxprojfile:print("<Import Project=\"%$(VCTargetsPath)\\Microsoft.Cpp.props\" />")

    -- make ExtensionSettings
    vcxprojfile:enter("<ImportGroup Label=\"ExtensionSettings\">")
    vcxprojfile:leave("</ImportGroup>")

    -- make PropertySheets
    for _, targetinfo in ipairs(target.info) do
        vcxprojfile:enter("<ImportGroup Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\" Label=\"PropertySheets\">", targetinfo.mode, fix_arch(targetinfo))
            vcxprojfile:print("<Import Project=\"%$(UserRootDir)\\Microsoft.Cpp.%$(Platform).user.props\" Condition=\"exists(\'%$(UserRootDir)\\Microsoft.Cpp.%$(Platform).user.props\')\" Label=\"LocalAppDataPlatform\" />")
        vcxprojfile:leave("</ImportGroup>")
    end

    -- make UserMacros
    vcxprojfile:print("<PropertyGroup Label=\"UserMacros\" />")

    -- make OutputDirectory and IntermediateDirectory
    for _, targetinfo in ipairs(target.info) do
        vcxprojfile:enter("<PropertyGroup Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\">", targetinfo.mode, fix_arch(targetinfo))
            vcxprojfile:print("<OutDir>%s\\</OutDir>", path.relative(path.absolute(targetinfo.targetdir), vcxprojdir))
            vcxprojfile:print("<IntDir>%s\\</IntDir>", path.relative(path.absolute(targetinfo.objectdir), vcxprojdir))
            vcxprojfile:print("<TargetName>%s</TargetName>", path.basename(targetinfo.targetfile))
            vcxprojfile:print("<TargetExt>%s</TargetExt>", path.extension(targetinfo.targetfile))

            if target.kind == "binary" then
                vcxprojfile:print("<LinkIncremental>true</LinkIncremental>")
            end
        vcxprojfile:leave("</PropertyGroup>")
    end
end

-- make source options
function _make_source_options(vcxprojfile, flags, condition)

    -- exists condition?
    condition = condition or ""

    -- get flags string
    local flagstr = os.args(flags)

    -- make Optimization
    if flagstr:find("[%-/]Os") or flagstr:find("[%-/]O1") then
        vcxprojfile:print("<Optimization%s>MinSpace</Optimization>", condition) 
    elseif flagstr:find("[%-/]O2") or flagstr:find("[%-/]Ot") then
        vcxprojfile:print("<Optimization%s>MaxSpeed</Optimization>", condition) 
    elseif flagstr:find("[%-/]Ox") then
        vcxprojfile:print("<Optimization%s>Full</Optimization>", condition) 
    else
        vcxprojfile:print("<Optimization%s>Disabled</Optimization>", condition) 
    end

    -- make FloatingPointModel
    if flagstr:find("[%-/]fp:fast") then
        vcxprojfile:print("<FloatingPointModel%s>Fast</FloatingPointModel>", condition) 
    elseif flagstr:find("[%-/]fp:strict") then
        vcxprojfile:print("<FloatingPointModel%s>Strict</FloatingPointModel>", condition) 
    elseif flagstr:find("[%-/]fp:precise") then
        vcxprojfile:print("<FloatingPointModel%s>Precise</FloatingPointModel>", condition) 
    end

    -- make WarningLevel
    if flagstr:find("[%-/]W1") then
        vcxprojfile:print("<WarningLevel%s>Level1</WarningLevel>", condition) 
    elseif flagstr:find("[%-/]W2") then
        vcxprojfile:print("<WarningLevel%s>Level2</WarningLevel>", condition) 
    elseif flagstr:find("[%-/]W3") then
        vcxprojfile:print("<WarningLevel%s>Level3</WarningLevel>", condition) 
    elseif flagstr:find("[%-/]W4") then
        vcxprojfile:print("<WarningLevel%s>Level4</WarningLevel>", condition) 
    elseif flagstr:find("[%-/]Wall") then
        vcxprojfile:print("<WarningLevel%s>EnableAllWarnings</WarningLevel>", condition) 
    else
        vcxprojfile:print("<WarningLevel%s>TurnOffAllWarnings</WarningLevel>", condition) 
    end
    if flagstr:find("[%-/]WX") then
        vcxprojfile:print("<TreatWarningAsError%s>true</TreatWarningAsError>", condition) 
    end
    
    if flagstr:find("[%-/]MP") then
        vcxprojfile:print("<MultiProcessorCompilation%s>true</MultiProcessorCompilation>", condition) 
    end

    if flagstr:find("[%-/]WPO") then
        vcxprojfile:print("<WholeProgramOptimization%s>true</WholeProgramOptimization>", condition) 
    end
    if flagstr:find("[%-/]RTCs") then
        vcxprojfile:print("<BasicRuntimeChecks%s>StackFrameRuntimeCheck</BasicRuntimeChecks>", condition) 
    elseif flagstr:find("[%-/]RTCu") then
        vcxprojfile:print("<BasicRuntimeChecks%s>UninitializedLocalUsageCheck</BasicRuntimeChecks>", condition) 
    elseif flagstr:find("[%-/]RTC1") then
        vcxprojfile:print("<BasicRuntimeChecks%s>EnableFastChecks</BasicRuntimeChecks>", condition) 
    else
        vcxprojfile:print("<BasicRuntimeChecks%s>Default</BasicRuntimeChecks>", condition) 
    end

    if flagstr:find("[%-/]Zp1") then
        vcxprojfile:print("<StructMemberAlignment%s>1Bytes</StructMemberAlignment>", condition) 
    elseif flagstr:find("[%-/]Zp2") then
        vcxprojfile:print("<StructMemberAlignment%s>2Bytes</StructMemberAlignment>", condition) 
    elseif flagstr:find("[%-/]Zp4") then
        vcxprojfile:print("<StructMemberAlignment%s>4Bytes</StructMemberAlignment>", condition) 
    elseif flagstr:find("[%-/]Zp8") then
        vcxprojfile:print("<StructMemberAlignment%s>8Bytes</StructMemberAlignment>", condition) 
    elseif flagstr:find("[%-/]Zp16") then
        vcxprojfile:print("<StructMemberAlignment%s>16Bytes</StructMemberAlignment>", condition) 
    else
        vcxprojfile:print("<StructMemberAlignment%s>Default</StructMemberAlignment>", condition) 
    end

    if flagstr:find("[%-/]GF") then
        vcxprojfile:print("<StringPooling%s>true</StringPooling>", condition) 
    end

    if flagstr:find("[%-/]GM") then
        vcxprojfile:print("<MinimalRebuild%s>true</MinimalRebuild>", condition) 
    end

    if flagstr:find("[%-/]Gy") then
        vcxprojfile:print("<FunctionLevelLinking%s>true</FunctionLevelLinking>", condition) 
    end

    if flagstr:find("[%-/]Oy") then
        vcxprojfile:print("<OmitFramePointers%s>true</OmitFramePointers>", condition) 
    end
    
    -- make PreprocessorDefinitions
    local defstr = ""
    for _, flag in ipairs(flags) do
        flag:gsub("[%-/]D(.*)",
            function (def) 
                defstr = defstr .. def .. ";"
            end
        )
    end
    defstr = defstr .. "%%(PreprocessorDefinitions)"
    vcxprojfile:print("<PreprocessorDefinitions%s>%s</PreprocessorDefinitions>", condition, defstr) 

    -- make DebugInformationFormat
    if flagstr:find("[%-/]Zi") then
        vcxprojfile:print("<DebugInformationFormat%s>ProgramDatabase</DebugInformationFormat>", condition)
    elseif flagstr:find("[%-/]ZI") then
        vcxprojfile:print("<DebugInformationFormat%s>EditAndContinue</DebugInformationFormat>", condition)
    elseif flagstr:find("[%-/]Z7") then
        vcxprojfile:print("<DebugInformationFormat%s>OldStyle</DebugInformationFormat>", condition)
    else
        vcxprojfile:print("<DebugInformationFormat%s>None</DebugInformationFormat>", condition)
    end

    -- make RuntimeLibrary
    if flagstr:find("[%-/]MDd") then
        vcxprojfile:print("<RuntimeLibrary%s>MultiThreadedDebugDLL</RuntimeLibrary>", condition)
    elseif flagstr:find("[%-/]MD") then
        vcxprojfile:print("<RuntimeLibrary%s>MultiThreadedDLL</RuntimeLibrary>", condition)
    elseif flagstr:find("[%-/]MTd") then
        vcxprojfile:print("<RuntimeLibrary%s>MultiThreadedDebug</RuntimeLibrary>", condition)
    elseif flagstr:find("[%-/]MT") then
        vcxprojfile:print("<RuntimeLibrary%s>MultiThreaded</RuntimeLibrary>", condition)
    end

    -- make CallingConvention
    if flagstr:find("[%-/]Gz") then
        vcxprojfile:print("<CallingConvention%s>StdCall</CallingConvention>", condition)
    elseif flagstr:find("[%-/]Gv") then
        vcxprojfile:print("<CallingConvention%s>VectorCall</CallingConvention>", condition)
    elseif flagstr:find("[%-/]Gr") then
        vcxprojfile:print("<CallingConvention%s>FastCall</CallingConvention>", condition)
    elseif flagstr:find("[%-/]Gd") then
        vcxprojfile:print("<CallingConvention%s>Cdecl</CallingConvention>", condition)
    end

    -- make AdditionalIncludeDirectories
    if flagstr:find("[%-/]I") then
        local dirs = {}
        for _, flag in ipairs(flags) do
            flag:gsub("[%-/]I(.*)", function (dir) table.insert(dirs, dir) end)
        end
        if #dirs > 0 then
            vcxprojfile:print("<AdditionalIncludeDirectories%s>%s</AdditionalIncludeDirectories>", condition, table.concat(dirs, ";"))
        end
    end

    -- complie as c++ if exists flag: /TP
    if flagstr:find("[%-/]TP") then
        vcxprojfile:print("<CompileAs%s>CompileAsCpp</CompileAs>", condition)
    end

    -- make AdditionalOptions
    local includedirs = {}
    local predefinitions = {}
    local warningsdisables = {}
    local additional_flags = {}
    local excludes = {"Od", "Os", "O0", "O1", "O2", "Ot", "Ox", "Od", "W0", "W1", "W2", "W3", "W4", "WX", "Wall",
    "Zi", "ZI", "Z7", "MT", "MTd", "MD", "MDd", "TP", "Fd", "fp", "I", "D", "wd", "GF", "MP",
    "GM", "Gy", "Oy", "Gz", "Gr", "Gd", "Gv", "FD", "GWPO", "Zp", "LTCG", "RTCs", "RTCu", "RTC1" }
    for _, flag in ipairs(flags) do
        local excluded = false
        local is_include_dir = false
        local is_pre_define = false
        local is_warningd = false
        for _, exclude in ipairs(excludes) do
            if flag:find("[%-/]" .. exclude) then
                excluded = true
                is_include_dir = exclude == "I"
                is_pre_define = exclude == "D"
                is_warningd = exclude == "wd"
                break
            end
        end
        if not excluded then
            table.insert(additional_flags, flag)
        end

        -- include paths
        if is_include_dir then
            local search_dir = flag:gsub("[%-/]I(.*)", function(dir)
                dir = dir:trim()
                return dir
            end)
            table.insert(includedirs, search_dir)
        end
        -- pre defines
        if is_pre_define then
            local definition = flag:gsub("[%-/]D(.*)", function(define)
                define = define:trim()
                return define
            end)
            table.insert(predefinitions, definition)
        end
        -- warning disables
        if is_warningd then
            local warndisable = flag:gsub("[%-/]wd(.*)", function(warn)
                warn = warn:trim()
                return warn
            end)
            table.insert(warningsdisables, warndisable)
        end
    end

    -- make include path
    local str_includedirs = table.concat(includedirs,";"):trim()
    vcxprojfile:print("<AdditionalIncludeDirectories>%s%%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>", #str_includedirs>0 and str_includedirs..";" or "")
    
    -- make predefinitions
    table.insert(predefinitions, '_VS_PROJECT_')
    local str_predefinitions = table.concat(predefinitions,";"):trim()
    vcxprojfile:print("<PreprocessorDefinitions>%s%%(PreprocessorDefinitions)</PreprocessorDefinitions>", #str_predefinitions>0 and str_predefinitions..";" or "")
    
    -- make disableSpecificWarnings
    local str_warningsdisables = table.concat(warningsdisables,";"):trim()
    vcxprojfile:print("<DisableSpecificWarnings>%s%%(DisableSpecificWarnings)</DisableSpecificWarnings>", #str_warningsdisables>0 and str_warningsdisables..";" or "")


    if #additional_flags > 0 then
        vcxprojfile:print("<AdditionalOptions%s>%s %%(AdditionalOptions)</AdditionalOptions>", condition, os.args(additional_flags))
    end
end

-- make common item 
function _make_common_item(vcxprojfile, vsinfo, target, targetinfo, vcxprojdir)
    local function fix_arch(targetinfo)
        return targetinfo.arch == "x86" and "Win32" or targetinfo.arch
    end
    -- enter ItemDefinitionGroup 
    vcxprojfile:enter("<ItemDefinitionGroup Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\">", targetinfo.mode, fix_arch(targetinfo))
    
    -- init the linker kinds
    local linkerkinds = 
    {
        binary = "Link"
    ,   static = "Lib"
    ,   shared = "Link"
    }

    -- for linker?
    vcxprojfile:enter("<%s>", linkerkinds[targetinfo.targetkind])

        -- save subsystem
        local subsystem = "Console"

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
        local default_libs = {}
        for _,v in ipairs(excludes_libs) do
            default_libs[v:lower()] = true
        end

        -- make linker flags
        local flags = {}
        local lib_paths = {}
        local lib_files = {}
        for _, flag in ipairs(_make_linkflags(targetinfo, vcxprojdir)) do

            local flag_lower = flag:lower()

            -- remove "-subsystem:windows"
            if flag_lower:find("[%-/]subsystem:windows") then
                subsystem = "Windows"
            elseif flag_lower:find("[%-/]libpath:(.*)") then
                flag:gsub(string.ipattern("[%-/]libpath:(.*)"), function (dir) table.insert(lib_paths, dir) end)
            -- remove "-machine:[x86|x64]", "-pdb:*.pdb" and "-debug"
            elseif not flag_lower:find("[%-/]machine:%w+") and 
                not flag_lower:find("[%-/]pdb:.+%.pdb") and 
                not flag_lower:find("[%-/]debug") and
                not flag_lower:find("[%-/]entry:(.*)") and 
                not flag_lower:find("[%-/]dynamicbase:(.*)") and 
                not flag_lower:find("[%-/]nxcompat:(.*)") then 
                    if not default_libs[flag_lower] and flag_lower:find("(.*).lib") then
                        table.insert(lib_files, flag)
                    elseif not default_libs[flag_lower] then
                        table.insert(flags, flag)
                    end
            end
        end
        flags = os.args(flags)

        -- make lib search path
        local str_libdirs = table.concat(lib_paths,";"):trim()
        vcxprojfile:print("<AdditionalLibraryDirectories>%s%%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>", #str_libdirs >0 and str_libdirs..";" or "")
        
        -- make libs
        local str_libfiles = table.concat(lib_files,";"):trim()
        vcxprojfile:print("<AdditionalDependencies>%s%%(AdditionalDependencies)</AdditionalDependencies>", #str_libfiles >0 and str_libfiles..";" or "")       

        -- make AdditionalOptions
        vcxprojfile:print("<AdditionalOptions>%s %%(AdditionalOptions)</AdditionalOptions>", flags)

        -- generate debug infomation?
        if linkerkinds[targetinfo.targetkind] == "Link" then

            -- enable debug infomation?
            local debug = false
            for _, symbol in ipairs(targetinfo.symbols) do
                if symbol == "debug" then
                    debug = true
                    break
                end
            end
            vcxprojfile:print("<GenerateDebugInformation>%s</GenerateDebugInformation>", tostring(debug))

            -- make *.pdb file path
            local symbolfile = targetinfo.symbolfile
            if symbolfile then
               vcxprojfile:print("<ProgramDatabaseFile>%s</ProgramDatabaseFile>", path.relative(path.absolute(symbolfile), vcxprojdir))
            end
        end

        -- make SubSystem
        if targetinfo.targetkind == "binary" then
            vcxprojfile:print("<SubSystem>%s</SubSystem>", subsystem)
        end
    
        -- make TargetMachine
        vcxprojfile:print("<TargetMachine>%s</TargetMachine>", ifelse(targetinfo.arch == "x64", "MachineX64", "MachineX86"))

        -- make EntryPointSymbol
        _make_ldflags(targetinfo, vcxprojdir, vcxprojfile)

    vcxprojfile:leave("</%s>", linkerkinds[targetinfo.targetkind])

    -- for compiler?
    vcxprojfile:enter("<ClCompile>")

        -- make source options
        _make_source_options(vcxprojfile, targetinfo.commonflags)


        -- use c or c++ precompiled header
        local pcheader = target.pcxxheader or target.pcheader
        if pcheader then 

            -- make precompiled header and outputfile
            vcxprojfile:print("<PrecompiledHeader>Use</PrecompiledHeader>")
            vcxprojfile:print("<PrecompiledHeaderFile>%s</PrecompiledHeaderFile>", path.filename(pcheader))
            local pcoutputfile = targetinfo.pcxxoutputfile or targetinfo.pcoutputfile
            if pcoutputfile then
                vcxprojfile:print("<PrecompiledHeaderOutputFile>%s</PrecompiledHeaderOutputFile>", path.relative(path.absolute(pcoutputfile), vcxprojdir))
            end
        end

    vcxprojfile:leave("</ClCompile>")

    --PreBuildEvent
    local fpath = path.join(vcxprojdir, "pre-build.bat")
    local PreBuildEventFile = io.open(fpath, "w")
    PreBuildEventFile:print("@echo off")
    PreBuildEventFile:print("@echo *******************PreBuild %s*******************", target.name)
    PreBuildEventFile:print("@setlocal enabledelayedexpansion")
    PreBuildEventFile:print("@set configuration=%1")
    PreBuildEventFile:print("@set platform=%2")
    PreBuildEventFile:print("@set outfile=\"%3\"")
    PreBuildEventFile:print("@set outdir=\"%4\"")
    PreBuildEventFile:print("@set projectdir=\"%5\"")

    local eventStr = target.target:values("PreBuildEvent")
    if eventStr then
        PreBuildEventFile:print(eventStr)
    end

    PreBuildEventFile:print("@endlocal enabledelayedexpansion")
    PreBuildEventFile:print("@echo on")
    PreBuildEventFile:close()
    vcxprojfile:enter("<PreBuildEvent>")
    vcxprojfile:print("<Command>@call %s %$(Configuration) %$(Platform) %$(OutDir)%$(TargetName)%$(TargetExt) %$(OutDir) %$(ProjectDir)</Command>", "pre-build.bat")
    vcxprojfile:leave("</PreBuildEvent>")
    
    --PreLinkEvent
    local fpath = path.join(vcxprojdir, "pre-link.bat")
    local PreLinkEvent = io.open(fpath, "w")
    PreLinkEvent:print("@echo off")
    PreLinkEvent:print("@echo *******************PreLink %s*******************", target.name)
    PreLinkEvent:print("@setlocal enabledelayedexpansion")
    PreLinkEvent:print("@set configuration=%1")
    PreLinkEvent:print("@set platform=%2")
    PreLinkEvent:print("@set outfile=\"%3\"")
    PreLinkEvent:print("@set outdir=\"%4\"")
    PreLinkEvent:print("@set projectdir=\"%5\"")

    local eventStr = target.target:values("PreLinkEvent")
    if eventStr then
        PreLinkEvent:print(eventStr)
    end

    PreLinkEvent:print("@endlocal enabledelayedexpansion")
    PreLinkEvent:print("@echo on")
    PreLinkEvent:close()
    vcxprojfile:enter("<PreLinkEvent>")
    vcxprojfile:print("<Command>@call %s %$(Configuration) %$(Platform) %$(OutDir)%$(TargetName)%$(TargetExt) %$(OutDir) %$(ProjectDir)</Command>", "pre-link.bat")
    vcxprojfile:leave("</PreLinkEvent>")
    
    --PostBuildEvent
    local fpath = path.join(vcxprojdir, "post-build.bat")
    local PostBuildEvent = io.open(fpath, "w")
    PostBuildEvent:print("@echo off")
    PostBuildEvent:print("@echo *******************PostBuild %s*******************", target.name)
    PostBuildEvent:print("@setlocal enabledelayedexpansion")
    PostBuildEvent:print("@set configuration=%1")
    PostBuildEvent:print("@set platform=%2")
    PostBuildEvent:print("@set outfile=\"%3\"")
    PostBuildEvent:print("@set outdir=\"%4\"")
    PostBuildEvent:print("@set projectdir=\"%5\"")

    local eventStr = target.target:values("PostBuildEvent")
    if eventStr then
        PostBuildEvent:print(eventStr)
    end

    PostBuildEvent:print("@endlocal enabledelayedexpansion")
    PostBuildEvent:print("@echo on")
    PostBuildEvent:close()
    vcxprojfile:enter("<PostBuildEvent>")
    vcxprojfile:print("<Command>@call %s %$(Configuration) %$(Platform) %$(OutDir)%$(TargetName)%$(TargetExt) %$(OutDir) %$(ProjectDir)</Command>", "post-build.bat")
    vcxprojfile:leave("</PostBuildEvent>")

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
            if not sourcebatch.rulename and (sourcekind == "cc" or sourcekind == "cxx" or sourcekind == "as" or sourcekind == "mrc") then
                for _, sourcefile in ipairs(sourcebatch.sourcefiles) do

                    -- make compiler flags
                    local flags = _make_compflags(sourcefile, targetinfo, vcxprojdir)

                    -- no common flags for asm
                    if sourcekind ~= "as" and sourcekind ~= "mrc"  then
                        for _, flag in ipairs(flags) do
                            flags_stats[flag] = (flags_stats[flag] or 0) + 1
                        end

                        -- update files count
                        files_count = files_count + 1

                        -- save first flags
                        if first_flags == nil then
                            first_flags = flags
                        end
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
        _make_common_item(vcxprojfile, vsinfo, target, targetinfo, vcxprojdir)
    end
end

-- make header file
function _make_header_file(vcxprojfile, includefile, vcxprojdir)
    vcxprojfile:print("<ClInclude Include=\"%s\" />", path.relative(path.absolute(includefile), vcxprojdir))
end

-- make source file for all modes
function _make_source_file_forall(vcxprojfile, vsinfo, target, sourcefile, sourceinfo, vcxprojdir)

    -- get object file and source kind 
    local sourcekind = nil
    for _, info in ipairs(sourceinfo) do
        sourcekind = info.sourcekind
        break
    end

    -- enter it
    local nodename = ifelse(sourcekind == "as", "CustomBuild", ifelse(sourcekind == "mrc", "ResourceCompile", "ClCompile"))
    sourcefile = path.relative(path.absolute(sourcefile), vcxprojdir)
    vcxprojfile:enter("<%s Include=\"%s\">", nodename, sourcefile)

        -- for *.asm files
        if sourcekind == "as" then
            vcxprojfile:print("<ExcludedFromBuild>false</ExcludedFromBuild>")
            vcxprojfile:print("<FileType>Document</FileType>")
            for _, info in ipairs(sourceinfo) do
                local objectfile = path.relative(path.absolute(info.objectfile), vcxprojdir)
                local compcmd = _make_compcmd(info.compargv, sourcefile, objectfile, vcxprojdir)
                vcxprojfile:print("<Outputs Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s\'\">%s</Outputs>", info.mode .. '|' .. info.arch, objectfile)
                vcxprojfile:print("<Command Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s\'\">%s</Command>", info.mode .. '|' .. info.arch, compcmd)
            end
            vcxprojfile:print("<Message>%s</Message>", path.filename(sourcefile))

        -- for *.rc files
        elseif sourcekind == "mrc" then
            for _, info in ipairs(sourceinfo) do
                local objectfile = path.relative(path.absolute(info.objectfile), vcxprojdir)
                vcxprojfile:print("<ResourceOutputFileName Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\">%s</ResourceOutputFileName>", info.mode, info.arch, objectfile)
            end

        -- for *.c/cpp files
        else

            -- init items
            local items = 
            {
                AdditionalOptions = 
                {
                    key = function (info) return os.args(info.flags) end
                ,   value = function (key) return key .. " %%(AdditionalOptions)" end
                }
            ,   ObjectFileName =
                {
                    key = function (info) return path.relative(path.absolute(info.objectfile), vcxprojdir) end
                ,   value = function (key) return key end
                }
            }
        
            -- make items
            for itemname, iteminfo in pairs(items) do

                -- make merge keys
                local mergekeys  = {}
                for _, info in ipairs(sourceinfo) do
                    local key = iteminfo.key(info)
                    mergekeys[key] = mergekeys[key] or {}
                    mergekeys[key][info.mode .. '|' .. info.arch] = true
                end
                for key, mergeinfos in pairs(mergekeys) do

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

                    -- disable the precompiled header if sourcekind ~= headerkind
                    local pcheader = target.pcxxheader or target.pcheader
                    local pcheader_disable = false
                    if pcheader and language.sourcekind_of(sourcefile) ~= ifelse(target.pcxxheader, "cxx", "cc") then
                        pcheader_disable = true
                    end

                    -- all modes and archs exist?
                    if count == #vsinfo.modes then
                        if #key > 0 then
                            vcxprojfile:print("<%s>%s</%s>", itemname, iteminfo.value(key), itemname)
                            if pcheader_disable then
                                vcxprojfile:print("<PrecompiledHeader>NotUsing</PrecompiledHeader>")
                            end
                        end
                    else
                        for cond, _ in pairs(mergeinfos) do
                            if cond:find('|', 1, true) then
                                -- for mode | arch
                                if #key > 0 then
                                    vcxprojfile:print("<%s Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s\'\">%s</%s>", itemname, cond, iteminfo.value(key), itemname)
                                    if pcheader_disable then
                                        vcxprojfile:print("<PrecompiledHeader Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s\'\">NotUsing</PrecompiledHeader>", cond)
                                    end
                                end
                            else
                                -- only for mode
                                if #key > 0 then
                                    vcxprojfile:print("<%s Condition=\"\'%$(Configuration)\'==\'%s\'\">%s</%s>", itemname, cond, iteminfo.value(key), itemname)
                                    if pcheader_disable then
                                        vcxprojfile:print("<PrecompiledHeader Condition=\"\'%$(Configuration)\'==\'%s\'\">NotUsing</PrecompiledHeader>", cond)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

    -- leave it
    vcxprojfile:leave("</%s>", nodename)
end

-- make source file for specific modes
function _make_source_file_forspec(vcxprojfile, vsinfo, target, sourcefile, sourceinfo, vcxprojdir)

    -- add source file
    sourcefile = path.relative(path.absolute(sourcefile), vcxprojdir)
    for _, info in ipairs(sourceinfo) do

        -- enter it
        local nodename = ifelse(info.sourcekind == "as", "CustomBuild", ifelse(info.sourcekind == "mrc", "ResourceCompile", "ClCompile"))
        vcxprojfile:enter("<%s Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\" Include=\"%s\">", nodename, info.mode, info.arch, sourcefile)

        -- for *.asm files
        local objectfile = path.relative(path.absolute(info.objectfile), vcxprojdir)
        if info.sourcekind == "as" then 
            local compcmd = _make_compcmd(info.compargv, sourcefile, objectfile, vcxprojdir)
            vcxprojfile:print("<ExcludedFromBuild>false</ExcludedFromBuild>")
            vcxprojfile:print("<FileType>Document</FileType>")
            vcxprojfile:print("<Outputs>%s</Outputs>", objectfile)
            vcxprojfile:print("<Command>%s</Command>", compcmd)

        -- for *.rc files
        elseif sourcekind == "mrc" then
            vcxprojfile:print("<ResourceOutputFileName Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\">%s</ResourceOutputFileName>",info.mode,info.arch,objectfile)

        -- for *.c/cpp files
        else

            -- disable the precompiled header if sourcekind ~= headerkind
            local pcheader = target.pcxxheader or target.pcheader
            if pcheader and language.sourcekind_of(sourcefile) ~= ifelse(target.pcxxheader, "cxx", "cc") then
                vcxprojfile:print("<PrecompiledHeader>NotUsing</PrecompiledHeader>")
            end
            vcxprojfile:print("<ObjectFileName>%s</ObjectFileName>", objectfile)
            vcxprojfile:print("<AdditionalOptions>%s %%(AdditionalOptions)</AdditionalOptions>", os.args(info.flags))
        end

        -- leave it
        vcxprojfile:leave("</%s>", nodename)
    end
end

-- make source file for precompiled header 
function _make_source_file_forpch(vcxprojfile, vsinfo, target, vcxprojdir)

    -- add precompiled source file
    local pcheader = target.pcxxheader or target.pcheader
    if pcheader then
        local sourcefile = path.relative(path.absolute(pcheader), vcxprojdir)
        vcxprojfile:enter("<ClCompile Include=\"%s\">", sourcefile)
            vcxprojfile:print("<PrecompiledHeader>Create</PrecompiledHeader>")
            vcxprojfile:print("<PrecompiledHeaderFile></PrecompiledHeaderFile>")
            vcxprojfile:print("<AdditionalOptions> %%(AdditionalOptions)</AdditionalOptions>")
            for _, info in ipairs(target.info) do

                -- compile as c/c++
                local compileas = ifelse(target.pcxxheader, "CompileAsCpp", "CompileAsC")
                vcxprojfile:print("<CompileAs Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\">%s</CompileAs>", info.mode, info.arch, compileas)

                -- add object file
                local pcoutputfile = info.pcxxoutputfile or info.pcoutputfile
                if pcoutputfile then
                    local objectfile = path.relative(path.absolute(pcoutputfile .. ".obj"), vcxprojdir)
                    vcxprojfile:print("<ObjectFileName Condition=\"\'%$(Configuration)|%$(Platform)\'==\'%s|%s\'\">%s</ObjectFileName>", info.mode, info.arch, objectfile)
                end
            end
        vcxprojfile:leave("</ClCompile>")
    end
end

-- make source files
function _make_source_files(vcxprojfile, vsinfo, target, vcxprojdir)

    -- add source files
    vcxprojfile:enter("<ItemGroup>")

        -- make source file infos
        local sourceinfos = {}
        for _, targetinfo in ipairs(target.info) do
            for sourcekind, sourcebatch in pairs(targetinfo.sourcebatches) do
                if not sourcebatch.rulename and (sourcekind == "cc" or sourcekind == "cxx" or sourcekind == "as" or sourcekind == "mrc") then
                    local objectfiles = sourcebatch.objectfiles
                    for idx, sourcefile in ipairs(sourcebatch.sourcefiles) do
                        local objectfile    = objectfiles[idx]
                        local flags         = targetinfo.sourceflags[sourcefile]
                        sourceinfos[sourcefile] = sourceinfos[sourcefile] or {}
                        table.insert(sourceinfos[sourcefile], {mode = targetinfo.mode, arch = targetinfo.arch, sourcekind = sourcekind, objectfile = objectfile, flags = flags, compargv = targetinfo.compargvs[sourcefile]})
                    end
                end
            end
        end

        -- make source files
        for sourcefile, sourceinfo in pairs(sourceinfos) do
            if #sourceinfo == #target.info then
                _make_source_file_forall(vcxprojfile, vsinfo, target, sourcefile, sourceinfo, vcxprojdir) 
            else
                _make_source_file_forspec(vcxprojfile, vsinfo, target, sourcefile, sourceinfo, vcxprojdir) 
            end
        end

        -- make precompiled source file
        _make_source_file_forpch(vcxprojfile, vsinfo, target, vcxprojdir) 

    vcxprojfile:leave("</ItemGroup>")

    -- add headers
    vcxprojfile:enter("<ItemGroup>")
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
    local vcxprojpath = path.join(vcxprojdir, targetname .. ".vcxproj")
    local vcxprojfile = vsfile.open(vcxprojpath, "w")

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

    -- convert gb2312 to utf8
    io.writefile(vcxprojpath, io.readfile(vcxprojpath):convert("gb2312", "utf8"))
end
