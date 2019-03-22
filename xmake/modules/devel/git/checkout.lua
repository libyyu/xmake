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
-- @file        checkout.lua
--

-- imports
import("core.base.option")
import("lib.detect.find_tool")

-- checkout to given branch, tag or commit
--
-- @param commit    the commit, tag or branch
-- @param opt       the argument options
--
-- @code
--
-- import("devel.git")
-- 
-- git.checkout("master", {repodir = "/tmp/xmake"})
-- git.checkout("v1.0.1", {repodir = "/tmp/xmake"})
--
-- @endcode
--
function main(commit, opt)

    -- find git
    local git = find_tool("git")
    if not git then
        return 
    end

    -- init argv
    local argv = {"checkout", commit}

    -- enter repository directory
    local oldir = nil
    if opt.repodir then
        oldir = os.cd(opt.repodir)
    end

    -- checkout it
    os.vrunv(git.program, argv)

    -- leave repository directory
    if oldir then
        os.cd(oldir)
    end
end
