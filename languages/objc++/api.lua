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
        -- target.set_xxx
        "target.set_config_h_prefix"
        -- target.add_xxx
    ,   "target.add_links"
    ,   "target.add_mflags"
    ,   "target.add_mxflags"
    ,   "target.add_mxxflags"
    ,   "target.add_ldflags"
    ,   "target.add_arflags"
    ,   "target.add_shflags"
    ,   "target.add_defines"
    ,   "target.add_undefines"
    ,   "target.add_defines_h"
    ,   "target.add_undefines_h"
    ,   "target.add_frameworks"
        -- option.add_xxx
    ,   "option.add_cincludes"
    ,   "option.add_cxxincludes"
    ,   "option.add_cfuncs"
    ,   "option.add_cxxfuncs"
    ,   "option.add_ctypes"
    ,   "option.add_cxxtypes"
    ,   "option.add_links"
    ,   "option.add_mflags"
    ,   "option.add_mxflags"
    ,   "option.add_mxxflags"
    ,   "option.add_ldflags"
    ,   "option.add_arflags"
    ,   "option.add_shflags"
    ,   "option.add_defines"
    ,   "option.add_defines_if_ok"
    ,   "option.add_defines_h_if_ok"
    ,   "option.add_undefines"
    ,   "option.add_undefines_if_ok"
    ,   "option.add_undefines_h_if_ok"
    ,   "option.add_frameworks"
    }
    _g.pathes = 
    {
        -- target.set_xxx
        "target.set_headerdir"
    ,   "target.set_config_h"
        -- target.add_xxx
    ,   "target.add_headers"
    ,   "target.add_linkdirs"
    ,   "target.add_rpathdirs"
    ,   "target.add_includedirs"
        -- option.add_xxx
    ,   "option.add_linkdirs"
    ,   "option.add_rpathdirs"
    ,   "option.add_includedirs"
    }

    -- ok
    return _g
end


