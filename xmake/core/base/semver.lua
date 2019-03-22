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
-- Copyright (C) 2015 - 2018, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        semver.lua
--

-- define module: semver
local semver = semver or {}
local _instance = _instance or {}

-- load modules
local os        = require("base/os")
local string    = require("base/string")

-- get the version info
function _instance:get(name)

    -- get it from info first
    local value = self._INFO[name]
    if value ~= nil then
        return value 
    end
end

-- get the major version
function _instance:major()
    return self:get("major")
end

-- get the minor version
function _instance:minor()
    return self:get("minor")
end

-- get the patch version
function _instance:patch()
    return self:get("patch")
end

-- get the raw version string
function _instance:rawstr()
    return self:get("raw")
end

-- satisfies the given semantic version(.e.g '> 1.0 < 2.0', '~1.5')?
function _instance:satisfies(version)
    return semver.satisfies(self:rawstr(), version) 
end

-- is in the given version range, [version1, version2]?
function _instance:at(version1, version2)
    return self:ge(version1) and self:le(version2)
end

-- v1 == v2 (str/ver)?
function _instance:eq(version)
    if type(version) == "string" then
        return semver.compare(self:rawstr(), version) == 0
    elseif type(version) == "table" then
        return semver.compare(self:rawstr(), version:rawstr()) == 0
    end
end

-- v1 < v2 (str/ver)?
function _instance:lt(version)
    if type(version) == "string" then
        return semver.compare(self:rawstr(), version) < 0
    elseif type(version) == "table" then
        return semver.compare(self:rawstr(), version:rawstr()) < 0
    end
end

-- v1 <= v2 (str/ver)?
function _instance:le(version)
    if type(version) == "string" then
        return semver.compare(self:rawstr(), version) <= 0
    elseif type(version) == "table" then
        return semver.compare(self:rawstr(), version:rawstr()) <= 0
    end
end

-- v1 > v2 (str/ver)?
function _instance:gt(version)
    return not self:le(version)
end

-- v1 >= v2 (str/ver)?
function _instance:ge(version)
    return not self:lt(version)
end

-- v1 == v2?
function _instance:__eq(version)
    return self:eq(version)
end

-- v1 < v2?
function _instance:__lt(version)
    return self:lt(version)
end

-- v1 <= v2?
function _instance:__le(version)
    return self:le(version)
end

-- get the raw version string
function _instance:__tostring()
    return self:rawstr()
end

-- new an instance
function semver.new(version)

    -- parse version first
    local info, errors = semver.parse(version)
    if not info then
        return nil, errors
    end

    -- new an instance
    local instance = table.inherit(_instance)

    -- init instance
    instance._INFO = info

    -- ok
    return instance
end

-- return module: semver
return semver
