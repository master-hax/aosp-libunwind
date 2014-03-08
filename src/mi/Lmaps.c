/* libunwind - a platform-independent unwind library
   Copyright (C) 2014 The Android Open Source Project

This file is part of libunwind.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.  */

#define UNW_LOCAL_ONLY
#include <libunwind.h>
#include "libunwind_i.h"

/* Globals to hold the map data for local unwinds. */
HIDDEN struct map_info *local_map_list = NULL;
HIDDEN int local_map_list_refs = 0;
HIDDEN struct map_info *local_to_delete_list = NULL;

HIDDEN pthread_rwlock_t local_rdwr_lock;

PROTECTED void
unw_map_local_cursor_get(unw_map_cursor_t *map_cursor)
{
  map_cursor->map_list = local_map_list;
  map_cursor->cur_map = NULL;
}

PROTECTED int
unw_map_local_cursor_valid(unw_map_cursor_t *map_cursor)
{
  if (map_cursor->map_list == local_map_list)
    return 0;
  return -1;
}

PROTECTED int
unw_map_local_create (void)
{
  int ret_value = 0;

  pthread_rwlock_wrlock(&local_rdwr_lock);
  if (local_map_list_refs == 0)
    {
      local_map_list = maps_create_list(getpid());
      if (local_map_list != NULL)
        local_map_list_refs = 1;
      else
        ret_value = -1;
    }
  else
    local_map_list_refs++;
  pthread_rwlock_unlock(&local_rdwr_lock);
  return ret_value;
}

PROTECTED void
unw_map_local_destroy (void)
{
  pthread_rwlock_wrlock(&local_rdwr_lock);
  if (local_map_list != NULL && --local_map_list_refs == 0)
    {
      maps_destroy_list(local_to_delete_list);
      local_to_delete_list = NULL;
      maps_destroy_list(local_map_list);
      local_map_list = NULL;
    }
  pthread_rwlock_unlock(&local_rdwr_lock);
}
