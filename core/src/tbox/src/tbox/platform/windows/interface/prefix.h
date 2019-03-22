/*!The Treasure Box Library
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
 * Copyright (C) 2009 - 2017, TBOOX Open Source Group.
 *
 * @author      ruki
 * @file        prefix.h
 *
 */
#ifndef TB_PLATFORM_WINDOWS_INTERFACE_PREFIX_H
#define TB_PLATFORM_WINDOWS_INTERFACE_PREFIX_H

/* //////////////////////////////////////////////////////////////////////////////////////
 * includes
 */
#include "../prefix.h"
#include "../../atomic.h"
#include "../../dynamic.h"

/* //////////////////////////////////////////////////////////////////////////////////////
 * macros
 */
#define TB_INTERFACE_LOAD(module_name, interface_name) \
    do \
    { \
        module_name->interface_name = (tb_##module_name##_##interface_name##_t)GetProcAddress((HMODULE)module, #interface_name); \
        \
    } while (0)

#endif
