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
-- @file        ipairs.lua
--

-- load modules
local table = require("base/table")

-- ipairs
--
-- .e.g
--
-- @code
-- 
-- for idx, val in ipairs({"a", "b", "c", "d", "e", "f"}) do
--      print("%d %s", idx, val)
-- end
--
-- for idx, val in ipairs({"a", "b", "c", "d", "e", "f"}, function (v) return v:upper() end) do
--      print("%d %s", idx, val)
-- end
--
-- for idx, val in ipairs({"a", "b", "c", "d", "e", "f"}, function (v, a, b) return v:upper() .. a .. b end, "a", "b") do
--      print("%d %s", idx, val)
-- end
--
-- @endcode
function sandbox_ipairs(t, filter, ...)

    -- has filter?
    local has_filter = type(filter) == "function"

    -- init iterator
    local args = {...}
    local iter = function (t, i)
        i = i + 1
        local v = t[i]
        if v then
            if has_filter then
                v = filter(v, unpack(args))
            end
            return i, v
        end
    end

    -- return iterator and initialized state
    return iter, table.wrap(t), 0
end

-- load module
return sandbox_ipairs

