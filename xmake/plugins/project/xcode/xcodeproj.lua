
-- imports
import("core.base.option")
import("core.tool.compiler")
import("core.tool.linker")
import("core.project.config")
import("core.project.project")
import("core.language.language")
import("core.platform.platform")

function __guid(n)
	n = n or 24
	local seed = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'}
	local tb = {}
	for i=1, n do
		tb[#tb+1] = seed[math.random(1,#seed)]
	end
	local guid = table.concat(tb)
	return guid
end
local guid_set = {}
local randomseed
function _guid(n)
	if not randomseed then
		math.randomseed(os.time())
		randomseed = true
	end
	guid = __guid(n)
	while guid_set[guid] ~= nil do
		guid = __guid(n)
	end
	return guid
end

--
function _objectsTostring(objects, indent)
	local function _is_dict(t)
		local empty = true
		for k, v in pairs( t ) do
			empty = false
			break
		end
		if empty then return false end
		return #t == 0
	end
	local function _strIndent(n)
		local s = ""
		for i=1,n do
			s = s .. "\t"
		end
		return s
	end
	local text = "\n"
	local function _tostring(tab, indent)
		for k, v in pairs( tab ) do
			if type( v ) ~= "table" then
				text = text .. _strIndent(indent)
				if _is_dict(tab) then
					text = text .. k .. " = "
				end
				text = text .. tostring(v)
				text = text .. (_is_dict(tab) and ";\n" or ",\n")
			else
				local isdict = _is_dict(v)
				text = text .. _strIndent(indent)
				text = text .. k .. " = "
				text = text .. ( isdict and "{\n" or "(\n")
				indent = indent + 1
				_tostring(v, indent)
				indent = indent - 1
				text = text .. _strIndent(indent)
				text = text .. (isdict and "};\n" or ");\n")
			end
		end
	end
	
	_tostring(objects,  indent)
	return text
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
    print(target:name(), targetinfo.targetkind)
    -- deps
    targetinfo.deps = table.copy(target:get("deps"))
    if targetinfo.targetkind == "static" then
    	for k, v in pairs(targetinfo.deps) do
    		if not link_map[v] then
    			table.insert(targetinfo.links, v)
    			local dep_target = project.target(v)
    			local ppath = path.directory(dep_target:targetfile())
    			if not linkdir_map[ppath] then
    				table.insert(targetinfo.linkdirs, ppath)
    			end
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

    -- frameworkdirs
    targetinfo.frameworkdirs = table.copy(target:get("frameworkdirs"))

    -- frameworks
    targetinfo.frameworks = table.copy(target:get("frameworks"))

    -- target dir
    targetinfo.targetdir = target:get("targetdir")

    -- mkfiledir
    targetinfo.outputdir = target.outputdir

    -- languages
    targetinfo.languages = table.copy(target:get("languages"))

    -- ok
    return targetinfo
end

function _convert_string(s)
	if s:find(" ") or s:find("+") then
		return "\"" .. s .. "\""
	end
	return s
end

function _get_targetinfo(target, mode, arch)
	for _, targetinfo in ipairs( target.info ) do
        if targetinfo.mode == mode and targetinfo.arch == arch then
        	return targetinfo
        end
    end
	return target.info[1]
end

function _getKind(target)
	local kind = target.kind
	local name = target.name
	if config.get(name.."Bundle") == true then
		kind = "bundle"
	end
	return kind
end

function _getValidArchs()
	local archs = option.get("archs")
    if archs then
    	archs = archs:split(',')
    else
        archs = platform.archs(config.plat())
    end
    local ret = ""
    for i, v in ipairs( archs ) do
    	if i > 1 then
    		ret = ret .. " " .. v
    	else
    		ret = ret .. v
    	end
    end
    return "\""..ret.."\""
end

function _get_MACH_O_TYPE(target)
	local kind = _getKind(target)
	if kind == "static" then
		return  "staticlib"
	elseif kind == "shared" then
		return "mh_dylib"
	elseif kind == "binary" then
		return "\"\"" --mh_execute
	elseif kind == "bundle" then
		return "mh_bundle"
	else
		return "\"\""
	end
end

function _get_EXECUTABLE_PREFIX(target)
	local kind = _getKind(target)
	if kind == "static" then
		return  "lib"
	elseif kind == "shared" then
		return "lib"
	elseif kind == "binary" then
		return "\"\""
	elseif kind == "bundle" then
		return "\"\""
	else
		return "\"\""
	end
end

function _getEXECUTABLE_EXTENSION(target)
	local kind = _getKind(target)
	if kind == "static" then
		return  "a"
	elseif kind == "shared" then
		return "dylib"
	elseif kind == "binary" then
		return "\"\""
	elseif kind == "bundle" then
		return "bundle"
	else
		return "\"\""
	end
end

function _get_productType(target)
	local kind = _getKind(target)
	if kind == "static" then
		return  "\"com.apple.product-type.library.static\""
	elseif kind == "shared" then
		return "\"com.apple.product-type.library.dynamic\""
	elseif kind == "binary" then
		return "\"com.apple.product-type.tool\""--"\"com.apple.product-type.execute\""
	elseif kind == "bundle" then
		return "\"com.apple.product-type.bundle\""
	else
		return "\"\""
	end
end
function _get_explicitFileType(target)
	local kind = _getKind(target)
	if kind == "static" then
		return "archive.ar"
	elseif kind == "shared" then
		return "\"compiled.mach-o.dylib\""
	elseif kind == "binary" then
		return "\"compiled.mach-o.executable\""
	elseif kind == "bundle" then
		return "wrapper.cfbundle"
	else
		return "\"\""
	end
end 

function _get_archs(plat, arch)
	if plat == "macosx" then
		if arch == "i386" then
			return "\"%$(ARCHS_STANDARD_32_BIT)\""
		elseif arch == "x86_64" then
			return "\"%$(ARCHS_STANDARD_64_BIT)\""
		else
			return "\"%$(ARCHS_STANDARD_32_64_BIT)\""
		end
	elseif plat == "iphoneos" then
		return "\"%$(ARCHS_STANDARD)\""
	else
		return ""
	end
end

function _getSDKROOT(plat)
	if plat == "macosx" then
		return "macosx"
	elseif plat == "iphoneos" then
		return "iphoneos"
	else
		return ""
	end
end

local SourceTree = {
	GROUP = "\"<group>\"",
    ROOT = "SOURCE_ROOT",
    SDK_ROOT = "SDKROOT",
    BUILD_PRODUCT = "BUILT_PRODUCTS_DIR",
    ABSOLUTE = "\"<absolute>\"",
}

function _make_xcworkspace(folderpath, target)
	os.mkdir(folderpath)
	local f = io.open(path.join(folderpath, "contents.xcworkspacedata"), "w")
    f:print(([[<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:%s.xcodeproj">
   </FileRef>
</Workspace>]]):format(target.name))
    f:close()
end

function _make_sourcefolder(folderpath, target)
	os.mkdir(folderpath)
	--bundle写入Info.plist
	if _getKind(target) ~= "bundle" then return end
	local fplist = io.open(path.join(folderpath, target.name .. "-Info.plist"), "w")
	fplist:print([[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2017年 ZuLong. All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string></string>
</dict>
</plist>]])
	fplist:close()
end
function _getMainGroupGUID(pbxinfo)
	local rootObjId = pbxinfo.rootObjectGUID
	return pbxinfo.objects[rootObjId]["mainGroup"]
end
function _getNativeTargetGUID(pbxinfo)
	local rootObjId = pbxinfo.rootObjectGUID
	return pbxinfo.objects[rootObjId].targets[1]
end
function _getNativeConfigurationListID(pbxinfo)
	local nativeId = _getNativeTargetGUID(pbxinfo)
	return pbxinfo.objects[nativeId].buildConfigurationList
end
function _getGroup(pbxinfo, groupId)
	if not groupId then
		--根分区
		local rootObjId = pbxinfo.rootObjectGUID
		groupId = pbxinfo.objects[rootObjId]["mainGroup"]
	end
	local groupInfo = pbxinfo.objects[groupId]
    if groupInfo["isa"] == "PBXGroup" or groupInfo["isa"] == "PBXVariantGroup" then
        return groupInfo
    end
    error("no group found")
end

function _releativePath(target, _path, make_proj)
	local project_dir = path.join(target.outputdir, target.name)--, target.name..".xcodeproj")--, "project.pbxproj")
	project_dir = project_dir:gsub("\\", "/")
	_path = path.absolute(_path)
	local _path_relative = path.relative(_path, project_dir):trim():gsub("\\", "/")
	if not make_proj then return _path_relative end
	if _path_relative:sub(1,2) == ".." then
		while true do
			local i = _path_relative:find_last("..", true)
			if not i then
				break
			else
				_path_relative = _path_relative:sub(i+3, -1)
			end
		end
		return _path_relative
	else
		return _path_relative
	end
end
function __find(pbxinfo, paths, target)
	local mainGroup = _getGroup(pbxinfo, nil)

	local parentGroup = mainGroup
	local findID = nil
	local stop = false
	while true do
		if stop then
			break
		end
		if #paths == 0 then
			break
		end
		local name = table.remove(paths, 1)
		for _,child in ipairs(parentGroup.children) do
			if pbxinfo.objects[child].name == name or pbxinfo.objects[child].path == name then
				parentGroup = pbxinfo.objects[child]
				if #paths == 0 then
					findID = child
				end
				break
			else
				stop = true
				break
			end
		end
	end

	return findID
end
function _find(pbxinfo, _path, target)
	local _tpath = _releativePath(target, _path, true)
	local paths = _tpath:split("/")
	return __find(pbxinfo, paths, target)
end

function _findInGroup(pbxinfo, parentGUID, name, target)
	local parentGroup = _getGroup(pbxinfo, parentGUID)
	for _,child in ipairs(parentGroup.children) do
		if pbxinfo.objects[child].name == name or pbxinfo.objects[child].path == name then
			return child
		end
	end
	return nil
end
--GCC_INPUT_FILETYPE
function __addGroup(pbxinfo, parentGUID, _name, _path, sourceTree, isVarGroup)
	sourceTree = sourceTree or SourceTree.GROUP
	if not _name then return nil end
	local groupInfo = {}
    groupInfo["isa"] = isVarGroup and "PBXVariantGroup" or "PBXGroup"
    groupInfo["name"] = _name
    groupInfo["sourceTree"] = sourceTree
    groupInfo["children"] = {}
    --if _path then groupInfo["path"] = _path end
    local newguid = _guid()
    pbxinfo.objects[newguid] = groupInfo
    local parentGroup = _getGroup(pbxinfo, parentGUID)
    table.insert(parentGroup.children, newguid)
    return newguid
end

function _addGroup(pbxinfo, target, parentGUID, _path, sourceTree, isVarGroup)
	local _tpath = _releativePath(target, _path, true)
	local paths = _tpath:split("/")
	local preGUID = parentGUID
	for _, v in ipairs(paths) do
		local groupGUID = _findInGroup(pbxinfo, preGUID, v, target)
		if not groupGUID then
			groupGUID = __addGroup(pbxinfo, preGUID, v, v, sourceTree, isVarGroup)
		end
		preGUID = groupGUID
	end
	return preGUID
end

function _addBuildFilesourcesBuildPhase(pbxinfo, fileGUID)
	local nativeTargetId = _getNativeTargetGUID(pbxinfo)
	local sourcePahseId = pbxinfo.objects[nativeTargetId].buildPhases[1]
	--PBXBuildFile
    local buildFile = {}
    buildFile["isa"] = "PBXBuildFile"
    buildFile["fileRef"] = fileGUID
    local buildGUID = _guid()
    pbxinfo.objects[buildGUID] = buildFile
    pbxinfo.objects[sourcePahseId].files = pbxinfo.objects[sourcePahseId].files or {}
    table.insert(pbxinfo.objects[sourcePahseId].files, buildGUID)
end
function _addBuildframeworkBuildPhase(pbxinfo, fileGUID)
	local nativeTargetId = _getNativeTargetGUID(pbxinfo)
	local sourcePahseId = pbxinfo.objects[nativeTargetId].buildPhases[2]
	--PBXBuildFile
    local buildFile = {}
    buildFile["isa"] = "PBXBuildFile"
    buildFile["fileRef"] = fileGUID
    local buildGUID = _guid()
    pbxinfo.objects[buildGUID] = buildFile
    pbxinfo.objects[sourcePahseId].files = pbxinfo.objects[sourcePahseId].files or {}
    table.insert(pbxinfo.objects[sourcePahseId].files, buildGUID)
end
function _addBuildheaderBuildPhase(pbxinfo, fileGUID)
end
function _addBuildresourceBuildPhase(pbxinfo, fileGUID)
end

function _addShellscriptBuildPhase(pbxinfo, scripts, shell)
	shell = shell or "/bin/sh"
	local info = {}
	info["isa"] = "PBXShellScriptBuildPhase"
	info["buildActionMask"] = "2147483647"
	info["files"] = {}
	info["inputPaths"] = {}
	info["outputPaths"] = {}
	info["runOnlyForDeploymentPostprocessing"] = 0
	info["shellPath"] = shell
	info["shellScript"] = scripts
	local newGUID = _guid()
	pbxinfo.objects[newGUID] = info
	local targetid = _getNativeTargetGUID(pbxinfo)
	table.insert(pbxinfo.objects[targetid].buildPhases, newGUID)
end

function _addShellscriptBuildPhase(pbxinfo, dstSubfolderSpec, dstPath, files)

	local info = {}
	info["isa"] = "PBXCopyFilesBuildPhase"
	info["buildActionMask"] = "2147483647"
	info["dstPath"] = dstPath
	info["name"] = "\"Copy Files\""
	info["files"] = {}
	info["dstSubfolderSpec"] = dstSubfolderSpec
	info["runOnlyForDeploymentPostprocessing"] = 0
	local newGUID = _guid()
	pbxinfo.objects[newGUID] = info
	local targetid = _getNativeTargetGUID(pbxinfo)
	table.insert(pbxinfo.objects[targetid].buildPhases, newGUID)

	--PBXBuildFile
	for _,v in ipairs(files) do
		local buildFile = {}
	    buildFile["isa"] = "PBXBuildFile"
	    buildFile["fileRef"] = v
	    local buildGUID = _guid()
	    pbxinfo.objects[buildGUID] = buildFile
	    pbxinfo.objects[newGUID].files = pbxinfo.objects[newGUID].files or {}
	    table.insert(pbxinfo.objects[newGUID].files, buildGUID)
	end
end

function __addFile(pbxinfo, parentGUID, _path, no_relative, target, sourceTree, settings)
	local name = path.basename(_path)
    local ext = path.extension(_path):lower()
    local fileTypeMapping = {
        [".c"] 				= "sourcecode.c.c",
        [".cc"] 			= "sourcecode.cpp.cpp",
        [".cpp"] 			= "sourcecode.cpp.cpp",
        [".hpp"] 			= "sourcecode.cpp.h",
        [".h"] 				= "sourcecode.c.h",
        [".swift"] 			= "sourcecode.swift",
        [".mm"] 			= "sourcecode.cpp.objcpp",
        [".m"] 				= "sourcecode.c.objc",
        [".tbd"] 			= "\"sourcecode.text-based-dylib-definition\"",
        [".bundle"] 		= "wrapper.plug-in",
        [".a"] 				= "archive.ar",
        [".framework"] 		= "wrapper.framework",
        [".strings"] 		= "text.plist.strings",
        [".applescript"] 	= "sourcecode.applescript",
        [".html"] 			= "text.html",
        [".jpg"] 			= "image.jpeg",
        [".jpeg"] 			= "image.jpeg",
        [".png"] 			= "image.png",
        [".tif"] 			="image.tiff",
        [".tiff"] 			= "image.tiff",
    }
    local filePhaseMapping = {
    	[".h"]				= _addBuildheaderBuildPhase,
    	[".hpp"]			= _addBuildheaderBuildPhase,
        [".c"] 				= _addBuildFilesourcesBuildPhase,
        [".cc"] 			= _addBuildFilesourcesBuildPhase,
        [".cpp"] 			= _addBuildFilesourcesBuildPhase,
        [".swift"] 			= _addBuildFilesourcesBuildPhase,
        [".mm"] 			= _addBuildFilesourcesBuildPhase,
        [".m"] 				= _addBuildFilesourcesBuildPhase,
        [".tbd"] 			= _addBuildframeworkBuildPhase,
        [".bundle"] 		= _addBuildresourceBuildPhase,
        [".a"] 				= _addBuildframeworkBuildPhase,
        [".framework"] 		= _addBuildframeworkBuildPhase,
        [".strings"] 		= _addBuildresourceBuildPhase,
        [".applescript"] 	= _addBuildFilesourcesBuildPhase,
        [".html"] 			= _addBuildresourceBuildPhase,
        [".jpg"] 			= _addBuildresourceBuildPhase,
        [".jpeg"] 			= _addBuildresourceBuildPhase,
        [".png"] 			= _addBuildresourceBuildPhase,
        [".tif"] 			= _addBuildresourceBuildPhase,
        [".tiff"] 			= _addBuildresourceBuildPhase,
    }
    local fileType = fileTypeMapping[ext] or "text"
  	local buildPhase = filePhaseMapping[ext]

  	--PBXFileReference
	local fileInfo = {}
    fileInfo["isa"] = "PBXFileReference"
    fileInfo["name"] = _convert_string(path.filename(_path))
    fileInfo["sourceTree"] = sourceTree
    fileInfo["children"] = {}
    fileInfo["lastKnownFileType"] = fileType
    fileInfo["path"] = no_relative and _convert_string(_path) or _convert_string(_releativePath(target, _path, false))
    local fileGUID = _guid()
    pbxinfo.objects[parentGUID].children = pbxinfo.objects[parentGUID].children or {}
    table.insert(pbxinfo.objects[parentGUID].children, fileGUID)
    pbxinfo.objects[fileGUID] = fileInfo

    if buildPhase then buildPhase(pbxinfo, fileGUID) end
end

function _addFile(pbxinfo, _path, target, sourceTree, settings)
	local mainGroup = _getGroup(pbxinfo)
	local parentGroupGUID = mainGroup.children[2]

    local _dir = path.directory(_path)
    local parentGUID = _addGroup(pbxinfo, target, parentGroupGUID, _dir)

    __addFile(pbxinfo, parentGUID, _path, false, target, sourceTree, settings)
end

function _addFile2(pbxinfo, _dir, _path, target, sourceTree, settings)
	--local mainGroup = _getGroup(pbxinfo)
	--local parentGroupGUID = mainGroup.children[2]
	local parentGUID = _addGroup(pbxinfo, target, nil, _dir)

	__addFile(pbxinfo, parentGUID, _path, false, target, sourceTree, settings)
end

function _addFramework(pbxinfo, _path, parentGUID, target, sourceTree, settings)
	parentGUID = parentGUID or _addGroup(pbxinfo, target, nil, "Frameworks")
	__addFile(pbxinfo, parentGUID, _path, true, target, sourceTree, settings)
end


function _make_pbxproj_file(pbxinfo, target)
	--source files
	for _, file in ipairs( target.sourcefiles ) do     
        _addFile(pbxinfo, path.absolute(file), target, SourceTree.ROOT)
    end

    local targetinfo = _get_targetinfo(target, "release", option.get("archs"))
    local objects = pbxinfo.objects
    --include path
    do
	    local buildConfigID = _getNativeConfigurationListID(pbxinfo)
	    local searchPaths = {}
	    for _, dir_ in ipairs( targetinfo.includedirs ) do
	        dir_ = _releativePath(target, dir_, false)
	        table.insert(searchPaths, dir_) 
	    end
	    for _, buildID in ipairs(objects[buildConfigID].buildConfigurations) do
	    	objects[buildID].buildSettings = objects[buildID].buildSettings or {}
	    	objects[buildID].buildSettings["HEADER_SEARCH_PATHS"] = table.unique(searchPaths)
	    end
   	end
   	--hearder files
   	do
   		for _, file in ipairs( target.headerfiles ) do
   			_addFile(pbxinfo, path.absolute(file), target, SourceTree.ROOT)
   		end
   	end
    --macros
    do
	    local buildConfigID = _getNativeConfigurationListID(pbxinfo)
	    local defines = {}
	    for _, def in ipairs( targetinfo.defines ) do
	    	table.insert(defines, "\"" .. def .. "\"")
	    end
	    for _, buildID in ipairs(objects[buildConfigID].buildConfigurations) do
	    	objects[buildID].buildSettings = objects[buildID].buildSettings or {}
	    	local defs = objects[buildID].buildSettings["GCC_PREPROCESSOR_DEFINITIONS"] or {}
	    	defines = table.join("\"%$(inherited)\"", defines, defs)
	    	objects[buildID].buildSettings["GCC_PREPROCESSOR_DEFINITIONS"] = table.unique(defines)
	    end
	end

    --link dirs
    local linkReadDirs = {}
    do
    	local linkdirs = {}
    	local buildConfigID = _getNativeConfigurationListID(pbxinfo)
    	for _, linkdir in ipairs(targetinfo.linkdirs) do
    		table.insert(linkReadDirs, linkdir)
    		linkdir = _releativePath(target, linkdir, false)
	        table.insert(linkdirs, linkdir) 
    	end
    	for _, buildID in ipairs(objects[buildConfigID].buildConfigurations) do
	    	objects[buildID].buildSettings = objects[buildID].buildSettings or {}
	    	objects[buildID].buildSettings["LIBRARY_SEARCH_PATHS"] = table.unique(linkdirs)
	    end
	    linkReadDirs = table.unique(linkReadDirs)
    end

    --libs
    do
	    local function _is_dep(link, deps)
	        for i, dep in ipairs( deps ) do
	            local dep_target = project.target(dep)
	            if dep_target and dep_target:get("kind") == "static" then
	                local basename = dep_target:basename()             
	                local name = dep_target:name()
	                basename = basename == nil and name or basename
	                if basename == link then
	                    return true, dep_target
	                end
	            end
	        end
	        return false
	    end

	    local function _find_lib(name)
	    	if not name:find("/") then
	    		local libname = name
	    		if not name:find_last(".tdb") and not name:find_last(".dylib") then
			    	libname = "lib" .. name .. ".a"
			    end
			    for _,v in ipairs(linkReadDirs) do	
		    		v = path.absolute(v)  	
		    		if os.exists(path.join(v, libname)) then
		    			return 1, path.join(v, libname)
		    		end
		    	end
		    	if os.exists(path.join("/usr/lib", libname)) then
		    		return 2, path.join("/usr/lib", libname)
		    	else
		    		local xcode_dir     = config.get("xcode_dir")
				    local xcode_sdkver  = ""--config.get("xcode_sdkver")
				    local xcode_sdkdir  = xcode_dir .. "/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX" .. xcode_sdkver .. ".sdk"

				    if os.exists(xcode_sdkdir.."/usr/lib/"..libname) then
				    	return 2, xcode_sdkdir.."/usr/lib/"..libname
				    end
		    	end
		    else
		    	if name:sub(1,8) == "/usr/lib" then
		    		return 2, name
		    	elseif name:sub(1,7) == "usr/lib" then
		    		local xcode_dir     = config.get("xcode_dir")
				    local xcode_sdkver  = ""--config.get("xcode_sdkver")
				    local xcode_sdkdir  = xcode_dir .. "/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX" .. xcode_sdkver .. ".sdk"
		    		return 2, xcode_sdkdir .. "/" .. name
		    	else
	    			return 3, name
	    		end
	    	end
	    	return 0, name
	    end

    	local buildConfigID = _getNativeConfigurationListID(pbxinfo)
	    local links = {}
	    local frameworkGroupGUID = _addGroup(pbxinfo, target, nil, "Frameworks")
	    for _, linkname in ipairs(targetinfo.links) do
	    	local ret, dep_target = _is_dep(linkname, targetinfo.deps)
	    	if ret then 
	    		_addFile2(pbxinfo, "libs", dep_target:targetfile(), target, SourceTree.ROOT)
	    	else
	    		local flag, p = _find_lib(linkname)
	    		if flag ~= 0 then
	    			if flag ~= 2 then
	    				_addFile(pbxinfo, p, target, SourceTree.ROOT)
	    			else
	    				__addFile(pbxinfo, frameworkGroupGUID, p, true, target, SourceTree.SDK_ROOT)
	    			end
	    		end
	    	end
	    end
	end
	--framework dirs
	local frameworkReadDirs = {}
	do
		local buildConfigID = _getNativeConfigurationListID(pbxinfo)
    	local frameworkdirs = {}
    	for _, dir_ in ipairs(targetinfo.frameworkdirs) do
    		table.insert(frameworkReadDirs, path.absolute(dir_))
    		dir_ = _releativePath(target, dir_, false)
	        table.insert(frameworkdirs, dir_) 
	    end
	    for _, buildID in ipairs(objects[buildConfigID].buildConfigurations) do
	    	objects[buildID].buildSettings = objects[buildID].buildSettings or {}
	    	objects[buildID].buildSettings["FRAMEWORK_SEARCH_PATHS"] = table.unique(frameworkdirs)
	    end
	    frameworkReadDirs = table.unique(frameworkReadDirs)
	end
	--frameworks
	do
		local function _get_framework_path(f)
			for _,v in ipairs(frameworkReadDirs) do
				if os.exists(path.join(v, f)) then
					return path.join(v, f), 1
				end
			end
			return 'System/Library/Frameworks/' .. f, 2
		end
		local buildConfigID = _getNativeConfigurationListID(pbxinfo)
		local frameworkGroupGUID = nil--_addGroup(pbxinfo, target, nil, "Frameworks")
    	for _, name in ipairs(targetinfo.frameworks) do
    		if name:sub(-10, -1) ~= ".framework" then
    			name = name .. ".framework"
    		end
    		if not name:find("/") then
    			local f = _get_framework_path(name)
	        	_addFramework(pbxinfo, f, frameworkGroupGUID, target, SourceTree.SDK_ROOT)
	        else
	        	name = path.absolute(name)
	        	_addFramework(pbxinfo, name, frameworkGroupGUID, target, SourceTree.SDK_ROOT)
	        end
	    end
	end
	--cflag
	do
		local flags = {}
		for _,v in ipairs(targetinfo.cxflags) do
			if v:find("\"") then
				flags[#flags+1] = v
			else
				flags[#flags+1] = "\"" .. v .. "\""
			end
		end
		local buildConfigID = _getNativeConfigurationListID(pbxinfo)
		for _, buildID in ipairs(objects[buildConfigID].buildConfigurations) do
	    	objects[buildID].buildSettings = objects[buildID].buildSettings or {}
	    	objects[buildID].buildSettings["OTHER_CFLAGS"] = table.unique(flags)
	    	--objects[buildID].buildSettings["OTHER_CPPFLAGS"] = table.unique(targetinfo.cxflags)
	    end
	end
	--ldflags
	do
		local flags = {}
		for _,v in ipairs(targetinfo.ldflags) do
			if v:find("\"") then
				flags[#flags+1] = v
			else
				flags[#flags+1] = "\"" .. v .. "\""
			end
		end
		local buildConfigID = _getNativeConfigurationListID(pbxinfo)
		for _, buildID in ipairs(objects[buildConfigID].buildConfigurations) do
	    	objects[buildID].buildSettings = objects[buildID].buildSettings or {}
	    	objects[buildID].buildSettings["OTHER_LDFLAGS"] = table.unique(flags)
	    end
	end
	--output product
	do
		local nativeTargetId = _getNativeTargetGUID(pbxinfo)
		local productGUID = pbxinfo.objects[nativeTargetId].productReference
		local outproductdir = _releativePath(target, path.directory(target.product), false)
		if outproductdir:sub(1,2) == ".." then
			_addShellscriptBuildPhase(pbxinfo, 0, "\"%$(PROJECT_DIR)/" .. outproductdir.."\"", {productGUID})
		else
			_addShellscriptBuildPhase(pbxinfo, 0, outproductdir, {productGUID})
		end
	end
end

function _make_objects(pbxinfo, target)
	local rootGUID = pbxinfo.rootObjectGUID
	local objects = pbxinfo.objects
	local targetid = _guid()
	objects[rootGUID] = {}
	do--PBXProject
		local PBXProject = objects[rootGUID]
		PBXProject["isa"] = "PBXProject"
		PBXProject["attributes"] = {
			LastUpgradeCheck = 0800,
			TargetAttributes = {
				[targetid] = {
					CreatedOnToolsVersion = 8.0,
				}
			}
		}
		PBXProject["compatibilityVersion"] = "\"Xcode 3.2\""
		PBXProject["developmentRegion"] = "English"
		PBXProject["hasScannedForEncodings"] = 0
		PBXProject["knownRegions"] = {"en"}
		PBXProject["projectDirPath"] = "\"\""
		PBXProject["projectRoot"] = "\"\""
		PBXProject["targets"] = {
			targetid
		}
	end
	do--Build configuration list for PBXProject
		local PBXProjectbuildConfigurationListid = _guid()
		objects[PBXProjectbuildConfigurationListid] = {}
		local XCConfigurationList = objects[PBXProjectbuildConfigurationListid]
		XCConfigurationList["isa"] = "XCConfigurationList"
		XCConfigurationList["buildConfigurations"] = { }
		XCConfigurationList["defaultConfigurationIsVisible"] = 0
		XCConfigurationList["defaultConfigurationName"] = "Release"
		objects[rootGUID].buildConfigurationList = PBXProjectbuildConfigurationListid
	end
	do
		local PBXProjectbuildConfigurationListid = objects[rootGUID].buildConfigurationList
		local debugGUID = _guid()
		local XCBuildConfiguration = {}
		XCBuildConfiguration["isa"] = "XCBuildConfiguration"
		XCBuildConfiguration["buildSettings"] = {
			ALWAYS_SEARCH_USER_PATHS = "NO",
			CLANG_ANALYZER_NONNULL = "YES",
			CLANG_CXX_LANGUAGE_STANDARD = "\"gnu++0x\"",
			CLANG_CXX_LIBRARY = "\"libc++\"",
			CLANG_ENABLE_MODULES = "YES",
			CLANG_ENABLE_OBJC_ARC = "YES",
			CLANG_WARN_BOOL_CONVERSION = "YES",
			CLANG_WARN_CONSTANT_CONVERSION = "YES",
			CLANG_WARN_DIRECT_OBJC_ISA_USAGE = "YES_ERROR",
			CLANG_WARN_DOCUMENTATION_COMMENTS = "YES",
			CLANG_WARN_EMPTY_BODY = "YES",
			CLANG_WARN_ENUM_CONVERSION = "YES",
			CLANG_WARN_INFINITE_RECURSION = "YES",
			CLANG_WARN_INT_CONVERSION = "YES",
			CLANG_WARN_OBJC_ROOT_CLASS = "YES_ERROR",
			CLANG_WARN_SUSPICIOUS_MOVES = "YES",
			CLANG_WARN_UNREACHABLE_CODE = "YES",
			CLANG_WARN__DUPLICATE_METHOD_MATCH = "YES",
			CODE_SIGN_IDENTITY = "\"-\"",
			COPY_PHASE_STRIP = "NO",
			DEBUG_INFORMATION_FORMAT = "dwarf",
			ENABLE_STRICT_OBJC_MSGSEND = "YES",
			ENABLE_TESTABILITY = "YES",
			GCC_C_LANGUAGE_STANDARD = "\"compiler-default\"",
			GCC_DYNAMIC_NO_PIC = "NO",
			GCC_NO_COMMON_BLOCKS = "YES",
			GCC_OPTIMIZATION_LEVEL = 0,
			GCC_PREPROCESSOR_DEFINITIONS = {
				"\"DEBUG=1\"",
				"\"%$(inherited)\"",
			},
			GCC_WARN_64_TO_32_BIT_CONVERSION = "YES",
			GCC_WARN_ABOUT_RETURN_TYPE = "YES_ERROR",
			GCC_WARN_UNDECLARED_SELECTOR = "YES",
			GCC_WARN_UNINITIALIZED_AUTOS = "YES_AGGRESSIVE",
			GCC_WARN_UNUSED_FUNCTION = "YES",
			GCC_WARN_UNUSED_VARIABLE = "YES",
			MTL_ENABLE_DEBUG_INFO = "YES",
			ONLY_ACTIVE_ARCH = "YES",
			SDKROOT = _getSDKROOT(target.plat),
			VALID_ARCHS = _getValidArchs(),
			ENABLE_BITCODE = "NO",
		}
		if target.plat == "macosx" then
			XCBuildConfiguration["buildSettings"].MACOSX_DEPLOYMENT_TARGET = 10.11
		else
			XCBuildConfiguration["buildSettings"].IPHONEOS_DEPLOYMENT_TARGET = 7.0
			XCBuildConfiguration["buildSettings"].SYMROOT = "build"
		end
		XCBuildConfiguration["name"] = "Debug"
		objects[debugGUID] = XCBuildConfiguration
		table.insert(objects[PBXProjectbuildConfigurationListid].buildConfigurations, debugGUID)
	end
	do
		local PBXProjectbuildConfigurationListid = objects[rootGUID].buildConfigurationList
		local releaseGUID = _guid()
		local XCBuildConfiguration = {}
		XCBuildConfiguration["isa"] = "XCBuildConfiguration"
		XCBuildConfiguration["buildSettings"] = {
			ALWAYS_SEARCH_USER_PATHS = "NO",
			CLANG_ANALYZER_NONNULL = "YES",
			CLANG_CXX_LANGUAGE_STANDARD = "\"gnu++0x\"",
			CLANG_CXX_LIBRARY = "\"libc++\"",
			CLANG_ENABLE_MODULES = "YES",
			CLANG_ENABLE_OBJC_ARC = "YES",
			CLANG_WARN_BOOL_CONVERSION = "YES",
			CLANG_WARN_CONSTANT_CONVERSION = "YES",
			CLANG_WARN_DIRECT_OBJC_ISA_USAGE = "YES_ERROR",
			CLANG_WARN_DOCUMENTATION_COMMENTS = "YES",
			CLANG_WARN_EMPTY_BODY = "YES",
			CLANG_WARN_ENUM_CONVERSION = "YES",
			CLANG_WARN_INFINITE_RECURSION = "YES",
			CLANG_WARN_INT_CONVERSION = "YES",
			CLANG_WARN_OBJC_ROOT_CLASS = "YES_ERROR",
			CLANG_WARN_SUSPICIOUS_MOVES = "YES",
			CLANG_WARN_UNREACHABLE_CODE = "YES",
			CLANG_WARN__DUPLICATE_METHOD_MATCH = "YES",
			CODE_SIGN_IDENTITY = "\"-\"",
			COPY_PHASE_STRIP = "NO",
			DEBUG_INFORMATION_FORMAT = "\"dwarf-with-dsym\"",
			ENABLE_NS_ASSERTIONS = "NO",
			ENABLE_STRICT_OBJC_MSGSEND = "YES",
			GCC_C_LANGUAGE_STANDARD = "\"compiler-default\"",
			GCC_NO_COMMON_BLOCKS = "YES",
			GCC_WARN_64_TO_32_BIT_CONVERSION = "YES",
			GCC_WARN_ABOUT_RETURN_TYPE = "YES_ERROR",
			GCC_WARN_UNDECLARED_SELECTOR = "YES",
			GCC_WARN_UNINITIALIZED_AUTOS = "YES_AGGRESSIVE",
			GCC_WARN_UNUSED_FUNCTION = "YES",
			GCC_WARN_UNUSED_VARIABLE = "YES",
			MTL_ENABLE_DEBUG_INFO = "NO",
			SDKROOT = _getSDKROOT(target.plat),
			VALID_ARCHS = _getValidArchs(),
			ENABLE_BITCODE = "NO",
		}
		if target.plat == "macosx" then
			XCBuildConfiguration["buildSettings"].MACOSX_DEPLOYMENT_TARGET = 10.11
		else
			XCBuildConfiguration["buildSettings"].IPHONEOS_DEPLOYMENT_TARGET = 7.0
			XCBuildConfiguration["buildSettings"].SYMROOT = "build"
		end
		XCBuildConfiguration["name"] = "Release"
		objects[releaseGUID] = XCBuildConfiguration
		table.insert(objects[PBXProjectbuildConfigurationListid].buildConfigurations, releaseGUID)
	end
	do--mainGroup
		local PBXProjectmainGroupid = _guid()
		local PBXGroup = {}
		PBXGroup["isa"] = "PBXGroup"
		PBXGroup["children"] = { }
		PBXGroup["sourceTree"] = "\"<group>\""
		objects[PBXProjectmainGroupid] = PBXGroup
		objects[rootGUID].mainGroup = PBXProjectmainGroupid
	end
	do --Group/Products
		local PBXProjectmainGroupid = objects[rootGUID].mainGroup
		local productGroupGUID = _guid()
		local productGroup = {}
		productGroup["isa"] = "PBXGroup"
		productGroup["children"] = { }
		productGroup["name"] = "Products"
		productGroup["sourceTree"] = "\"<group>\""
		objects[productGroupGUID] = productGroup
		table.insert(objects[PBXProjectmainGroupid].children, productGroupGUID)
	end
	do--Group/targetname
		local PBXProjectmainGroupid = objects[rootGUID].mainGroup
		local selfGroupGUID = _guid()
		local selfGroup = {}
		selfGroup["isa"] = "PBXGroup"
		selfGroup["children"] = { }
		selfGroup["path"] = target.name
		selfGroup["name"] = target.name
		selfGroup["sourceTree"] = "\"<group>\""
		objects[selfGroupGUID] = selfGroup
		table.insert(objects[PBXProjectmainGroupid].children, selfGroupGUID)
	end
	do--PBXNativeTarget
		local PBXNativeTarget = {}
		PBXNativeTarget["isa"] = "PBXNativeTarget"
		PBXNativeTarget["buildPhases"] = {}
		PBXNativeTarget["buildRules"] = {}
		PBXNativeTarget["dependencies"] = {}
		PBXNativeTarget["name"] = target.name
		PBXNativeTarget["productName"] = target.name
		PBXNativeTarget["productType"] = _get_productType(target)
		objects[targetid] = PBXNativeTarget
	end
	do--Build configuration list for PBXNativeTarget
		local buildConfigurationListGUID = _guid()
		local XCConfigurationList = {}
		XCConfigurationList["isa"] = "XCConfigurationList"
		XCConfigurationList["buildConfigurations"] = {}
		XCConfigurationList["defaultConfigurationIsVisible"] = 0
		objects[buildConfigurationListGUID] = XCConfigurationList

		objects[targetid].buildConfigurationList = buildConfigurationListGUID
	end
	do --productReference
		local productReferenceGUID = _guid()
		local productReference = {}
		productReference["isa"] = "PBXFileReference"
		productReference["explicitFileType"] = _get_explicitFileType(target) --"archive.ar"
		productReference["includeInIndex"] = 0

		local kind = _getKind(target)
		if kind == "bundle" then
			local d = path.basename(target.product)
			d = d:gsub("lib", "")
			productReference["path"] = d .. ".bundle"
		else
			productReference["path"] = path.filename(target.product)
		end 
		
		productReference["sourceTree"] = "BUILT_PRODUCTS_DIR"
		objects[productReferenceGUID] = productReference

		objects[targetid].productReference = productReferenceGUID
		--Product Group
		local PBXProjectmainGroupid = objects[rootGUID].mainGroup
		local productGroupGUID = objects[PBXProjectmainGroupid].children[1]
		table.insert(objects[productGroupGUID].children, productReferenceGUID)
	end
	do--PBXSourcesBuildPhase
		local guid = _guid()
		local PBXSourcesBuildPhase = {}
		PBXSourcesBuildPhase["isa"] = "PBXSourcesBuildPhase"
		PBXSourcesBuildPhase["buildActionMask"] = "2147483647"
		PBXSourcesBuildPhase["files"] = {}
		PBXSourcesBuildPhase["runOnlyForDeploymentPostprocessing"] = 0
		objects[guid] = PBXSourcesBuildPhase
		table.insert(objects[targetid].buildPhases, guid)
	end
	do--PBXFrameworksBuildPhase
		local guid = _guid()
		local PBXFrameworksBuildPhase = {}
		PBXFrameworksBuildPhase["isa"] = "PBXFrameworksBuildPhase"
		PBXFrameworksBuildPhase["buildActionMask"] = "2147483647"
		PBXFrameworksBuildPhase["files"] = {}
		PBXFrameworksBuildPhase["runOnlyForDeploymentPostprocessing"] = 0
		objects[guid] = PBXFrameworksBuildPhase
		table.insert(objects[targetid].buildPhases, guid)
	end
	do--PBXHeadersBuildPhase
		local guid = _guid()
		local PBXHeadersBuildPhase = {}
		PBXHeadersBuildPhase["isa"] = "PBXHeadersBuildPhase"
		PBXHeadersBuildPhase["buildActionMask"] = "2147483647"
		PBXHeadersBuildPhase["files"] = {}
		PBXHeadersBuildPhase["runOnlyForDeploymentPostprocessing"] = 0
		objects[guid] = PBXHeadersBuildPhase
		table.insert(objects[targetid].buildPhases, guid)
	end
	do--PBXResourcesBuildPhase
		local guid = _guid()
		local PBXResourcesBuildPhase = {}
		PBXResourcesBuildPhase["isa"] = "PBXResourcesBuildPhase"
		PBXResourcesBuildPhase["buildActionMask"] = "2147483647"
		PBXResourcesBuildPhase["files"] = {}
		PBXResourcesBuildPhase["runOnlyForDeploymentPostprocessing"] = 0
		objects[guid] = PBXResourcesBuildPhase
		table.insert(objects[targetid].buildPhases, guid)
	end
	do
		local debugGUID = _guid()
		local XCBuildConfiguration = {}
		XCBuildConfiguration["isa"] = "XCBuildConfiguration"
		XCBuildConfiguration["buildSettings"] = {
			--DEVELOPMENT_TEAM = "EXHFBWBL96",
			EXECUTABLE_EXTENSION = _getEXECUTABLE_EXTENSION(target),
			EXECUTABLE_PREFIX = _get_EXECUTABLE_PREFIX(target),
			GCC_ENABLE_CPP_EXCEPTIONS = "YES",
			GCC_ENABLE_CPP_RTTI = "YES",
			PRODUCT_NAME = "\"%$(TARGET_NAME)\"",
			ARCHS = _get_archs(target.plat, ""),
			MACH_O_TYPE = _get_MACH_O_TYPE(target),
			VALID_ARCHS = _getValidArchs(),
		}
		local kind = _getKind(target)
		if kind == "shared" then
			XCBuildConfiguration["buildSettings"].GCC_SYMBOLS_PRIVATE_EXTERN = "YES"
			XCBuildConfiguration["buildSettings"].DYLIB_COMPATIBILITY_VERSION = 1
			XCBuildConfiguration["buildSettings"].DYLIB_CURRENT_VERSION = 1
		elseif kind == "bundle" then
			XCBuildConfiguration["buildSettings"].COMBINE_HIDPI_IMAGES = "YES"
			XCBuildConfiguration["buildSettings"].INFOPLIST_FILE = target.name .. "/" .. target.name .. "-Info.plist"
			XCBuildConfiguration["buildSettings"].INSTALL_PATH = "\"%$(LOCAL_LIBRARY_DIR)/Bundles\""
			XCBuildConfiguration["buildSettings"].SKIP_INSTALL = "YES"
			XCBuildConfiguration["buildSettings"].WRAPPER_EXTENSION = "bundle"
		elseif kind == "static" then
			XCBuildConfiguration["buildSettings"].SKIP_INSTALL = "YES"
		end
		XCBuildConfiguration["name"] = "Debug"
		objects[debugGUID] = XCBuildConfiguration

		local buildConfigurationListGUID = objects[targetid].buildConfigurationList
		table.insert(objects[buildConfigurationListGUID].buildConfigurations, debugGUID)
	end
	do
		local releaseGUID = _guid()
		local XCBuildConfiguration = {}
		XCBuildConfiguration["isa"] = "XCBuildConfiguration"
		XCBuildConfiguration["buildSettings"] = {
			--DEVELOPMENT_TEAM = "EXHFBWBL96",
			EXECUTABLE_EXTENSION = _getEXECUTABLE_EXTENSION(target),
			EXECUTABLE_PREFIX = _get_EXECUTABLE_PREFIX(target),
			GCC_ENABLE_CPP_EXCEPTIONS = "YES",
			GCC_ENABLE_CPP_RTTI = "YES",
			PRODUCT_NAME = "\"%$(TARGET_NAME)\"",
			ARCHS = _get_archs(target.plat, ""), --ARCHS_STANDARD_32_64_BIT; ARCHS_STANDARD_32_BIT
			MACH_O_TYPE = _get_MACH_O_TYPE(target),
			VALID_ARCHS = _getValidArchs(),
		}
		local kind = _getKind(target)
		if kind == "shared" then
			XCBuildConfiguration["buildSettings"].GCC_SYMBOLS_PRIVATE_EXTERN = "YES"
			XCBuildConfiguration["buildSettings"].DYLIB_COMPATIBILITY_VERSION = 1
			XCBuildConfiguration["buildSettings"].DYLIB_CURRENT_VERSION = 1
		elseif kind == "bundle" then
			XCBuildConfiguration["buildSettings"].COMBINE_HIDPI_IMAGES = "YES"
			XCBuildConfiguration["buildSettings"].INFOPLIST_FILE = target.name .. "/" .. target.name .. "-Info.plist"
			XCBuildConfiguration["buildSettings"].INSTALL_PATH = "\"%$(LOCAL_LIBRARY_DIR)/Bundles\""
			XCBuildConfiguration["buildSettings"].SKIP_INSTALL = "YES"
			XCBuildConfiguration["buildSettings"].WRAPPER_EXTENSION = "bundle"
		elseif kind == "static" then
			XCBuildConfiguration["buildSettings"].SKIP_INSTALL = "YES"
		end
		XCBuildConfiguration["name"] = "Release"
		objects[releaseGUID] = XCBuildConfiguration

		local buildConfigurationListGUID = objects[targetid].buildConfigurationList
		table.insert(objects[buildConfigurationListGUID].buildConfigurations, releaseGUID)
	end

	_make_pbxproj_file(pbxinfo, target)

	--table.dump(objects)
	return _objectsTostring(objects, 2)
end

function _make_pbxproj(pbxfile, target)
	local pbxinfo = {
		rootObjectGUID = _guid(),
        archiveVersion = 1,
        objectVersion = 46,
        classes = {},
        objects = {},
	}
	pbxfile:print("// !$*UTF8*$!")
	pbxfile:print("{")
	pbxfile:print("	archiveVersion = %d;", pbxinfo.archiveVersion)
	pbxfile:print("	classes = {")
	pbxfile:print("	};")
	pbxfile:print("	objectVersion = %d;", pbxinfo.objectVersion)
	pbxfile:print("	objects = {")
	pbxfile:print(_make_objects(pbxinfo, target))
	pbxfile:print("	};")
	pbxfile:print("	rootObject = %s /* Project object */;", pbxinfo.rootObjectGUID)
	pbxfile:print("}")
end

function _make_xcodeprojfolder(folderpath, target)
	os.mkdir(folderpath) 
	_make_xcworkspace(path.join(folderpath, "project.xcworkspace"), target)
	local pbxfile = io.open(path.join(folderpath, "project.pbxproj"), "w")

	_make_pbxproj(pbxfile, target)

	pbxfile:close()
end

function _make_all(pbxinfo)
	-- make all
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
    local sorttargets = {}
    for _, target in pairs(pbxinfo.targets) do
        sorttargets[#sorttargets+1] = target
    end    
    table.sort(sorttargets, function(ta, tb)
        if _is_dep(ta, tb) then
            return false
        elseif _is_dep(tb, ta) then
            return true
        else
            return false
        end
    end)

    for _, target in ipairs( sorttargets ) do
        print("gen ["..target.name.."] for " .. target.plat)
        local target_dir = path.join(target.outputdir, target.name)
        _make_sourcefolder(path.join(target_dir, target.name), target)
        _make_xcodeprojfolder(path.join(target_dir, target.name..".xcodeproj"), target)
    end
end


-- make
function make(outputdir)
	-- enter project directory
    local olddir = os.cd(project.directory())
    print( "general xcodeproj at " .. outputdir )

    outputdir = outputdir --path.join(outputdir, "jni")

    --mk info
    local pbxinfo = {
        outputdir = outputdir,
    }

    -- init modes
    local modes = option.get("modes")
    if modes then
        pbxinfo.modes = {}
        for _, mode in ipairs(modes:split(',')) do
            table.insert(pbxinfo.modes, mode:trim())
        end
    else
        pbxinfo.modes = project.modes()
    end
    if not pbxinfo.modes or #pbxinfo.modes == 0 then
        pbxinfo.modes = { config.mode() }
    end

    -- init archs
    local archs = option.get("archs")
    if archs then
        pbxinfo.archs = {}
        for _, arch in ipairs(archs:split(',')) do
            table.insert(pbxinfo.archs, arch:trim())
        end
    else
        pbxinfo.archs = platform.archs(config.plat())
    end

    -- load targets

    local targets = {}
    for _, mode in ipairs(pbxinfo.modes) do
        for _, arch in ipairs(pbxinfo.archs) do

            -- reload config, project and platform
            if mode ~= config.mode() or arch ~= config.arch() then
                -- modify config
                config.set("mode", mode)
                config.set("arch", arch)

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
            	print("checking for the %s.%s.%s ...", targetname, mode, arch)
                -- make target with the given mode and arch
                targets[targetname] = targets[targetname] or {}
                local _target = targets[targetname]
                -- init target info
                _target.name = targetname
                _target.kind = target:get("kind")
                _target.plat = config.plat()
                _target.scriptdir = target:scriptdir()
                _target.info = _target.info or {}
                _target.target = target
                _target.outputdir = outputdir
                _target.product = target:targetfile()
                _target.projectdir = target:get("projectdir")

                table.insert(_target.info, _make_targetinfo(mode, arch, target))

                -- save all sourcefiles and headerfiles
                _target.sourcefiles = table.unique(table.join(_target.sourcefiles or {}, (target:sourcefiles())))
                _target.headerfiles = table.unique(table.join(_target.headerfiles or {}, (target:headerfiles())))
            end
        end
    end

    pbxinfo.targets = targets

    _make_all(pbxinfo)
    
    -- leave project directory
    os.cd(olddir)
end