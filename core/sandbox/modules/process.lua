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
-- @file        process.lua
--

-- load modules
local sandbox   = require("sandbox/sandbox")
local raise     = require("sandbox/modules/raise")
local vformat   = require("sandbox/modules/vformat")

-- define module
local sandbox_process = sandbox_process or {}

-- open process
function sandbox_process.open(command, outfile, errfile) 

    -- check
    assert(command)

    -- format command first
    command = vformat(command)

    -- format output file if exists
    if outfile then
        outfile = vformat(outfile)
    end

    -- format error file if exists
    if errfile then
        errfile = vformat(errfile)
    end

    -- open process
    local proc = process.open(command, outfile, errfile)
    if not proc then
        raise("open process(%s) failed!", command)
    end

    -- ok
    return proc
end

-- open process with arguments
function sandbox_process.openv(argv, outfile, errfile) 

    -- check
    assert(argv)

    -- format output file if exists
    if outfile then
        outfile = vformat(outfile)
    end

    -- format error file if exists
    if errfile then
        errfile = vformat(errfile)
    end

    -- open process
    local proc = process.openv(argv, outfile, errfile)
    if not proc then
        raise("openv process(%s) failed!", table.concat(argv, " "))
    end

    -- ok
    return proc
end

-- close process
function sandbox_process.close(proc)

    -- check
    assert(proc)

    -- close it
    process.close(proc)
end

-- wait process
function sandbox_process.wait(proc, timeout)

    -- check
    assert(proc)

    -- wait it
    local ok, status = process.wait(proc, timeout)
    if ok < 0 then
        raise("wait process failed(%d)", ok)
    end

    -- timeout or finished
    return ok, status
end

-- wait processes
function sandbox_process.waitlist(processes, timeout)

    -- check
    assert(processes)

    -- wait them
    local count, infos = process.waitlist(processes, timeout)
    if count < 0 then
        raise("wait processes(%d) failed(%d)", #processes, count)
    end

    -- timeout or finished
    return infos
end

-- return module
return sandbox_process

