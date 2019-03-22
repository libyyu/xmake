/*!The Make-like Build Utility based on Lua
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 * Copyright (C) 2015 - 2018, TBOOX Open Source Group.
 *
 * @author      ruki
 * @file        uuid.c
 *
 */

/* //////////////////////////////////////////////////////////////////////////////////////
 * trace
 */
#define TB_TRACE_MODULE_NAME                "uuid"
#define TB_TRACE_MODULE_DEBUG               (0)

/* //////////////////////////////////////////////////////////////////////////////////////
 * includes
 */
#include "prefix.h"

/* //////////////////////////////////////////////////////////////////////////////////////
 * implementation
 */
tb_int_t xm_hash_uuid(lua_State* lua)
{
    // check
    tb_assert_and_check_return_val(lua, 0);

    // get the name  
    tb_char_t const* name = luaL_optstring(lua, 1, tb_null);

    // make uuid
    tb_char_t uuid[37];
	lua_pushstring(lua, tb_uuid_make_cstr(uuid, name));

    // ok
    return 1;
}
