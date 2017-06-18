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
-- @file        api.lua
--

-- get apis
function apis()

    -- init apis
    _g.values = 
    {
        -- target.add_xxx
        "target.add_links"
    ,   "target.add_gcflags"
    ,   "target.add_ldflags"
    ,   "target.add_arflags"
        -- option.add_xxx
    ,   "option.add_links"
    ,   "option.add_gcflags"
    ,   "option.add_ldflags"
    ,   "option.add_arflags"
    }
    _g.pathes = 
    {
        -- target.add_xxx
        "target.add_linkdirs"
    ,   "target.add_includedirs"
        -- option.add_xxx
    ,   "option.add_linkdirs"
    ,   "option.add_includedirs"
    }

    -- ok
    return _g
end


