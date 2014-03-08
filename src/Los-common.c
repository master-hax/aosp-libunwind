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

/* Global to hold the map for all local unwinds. */
extern struct map_info *local_map_list;
extern lock_var (local_map_lock);
extern struct map_info *local_to_delete_list;
extern pthread_rwlock_t local_rdwr_lock;

HIDDEN void
maps_local_init (void)
{
  pthread_rwlock_init (&local_rdwr_lock, NULL);
}

static void
move_cached_elf_data(struct map_info *old_list, struct map_info *new_list)
{
  while (old_list)
    {
      if (old_list->ei.image == NULL)
        {
          old_list = old_list->next;
          continue;
        }
      /* Both lists are in order, so it's not necessary to scan through
         from the beginning of new_list each time looking for a match to
         the current map. As we progress, simply start from the last element
         in new list we checked. */
      while (new_list && old_list->start <= new_list->start)
        {
          if (old_list->start == new_list->start
              && old_list->end == new_list->end)
            {
              /* No need to do any lock, the entire local_map_list is locked
                 at this point. */
              new_list->ei.size = old_list->ei.size;
              new_list->ei.image = old_list->ei.image;
              old_list->ei.size = 0;
              old_list->ei.image = NULL;
              /* Don't bother breaking out of the loop, the next while check
                 is guaranteed to fail, causing us to break out of the loop
                 after advancing to the next map element. */
            }
          new_list = new_list->next;
        }
      old_list = old_list->next;
    }
}

/* In order to cache as much as possible while unwinding the local process,
   we gather a map of the process before starting. If the cache is missing
   a map, or a map exists but doesn't have the "expected_flags" set, then
   check if the cache needs to be regenerated.
   When the cache is regenerated, we keep a to delete list which is not deleted
   until the entire map is no longer needed. We do it this way so that any
   threads that are still using the old cache will continue to function
   correctly, and not access freed memory. This scheme relies on the fact that
   all calling threads have to call unw_map_local_destroy when done with the
   unwind. Otherwise, the memory used by the to delete will persist until the
   process terminates. */
static int
rebuild_if_necessary (unw_word_t addr, int expected_flags)
{
  struct map_info *map;
  struct map_info *new_list;
  int ret_value = -1;

  new_list = maps_create_list (getpid());
  map = map_find_from_addr (new_list, addr);
  if (map && (expected_flags == 0 || (map->flags & expected_flags)))
    {
      /* Get a write lock on local_map_list since it's going to be modified. */
      pthread_rwlock_wrlock (&local_rdwr_lock);

      /* To avoid doing an update at the same time, do one more check to see
         if the local map has been update. */
      map = map_find_from_addr (local_map_list, addr);
      if (!map || (expected_flags != 0 && !(map->flags & expected_flags)))
        {
          /* Move any cached items to the new list. */
          move_cached_elf_data (local_map_list, new_list);
          map = local_map_list;
          local_map_list = new_list;
          new_list = map;
          ret_value = 0;
        }

      pthread_rwlock_unlock (&local_rdwr_lock);
    }

  maps_destroy_list (new_list);

  return ret_value;
}

static int
is_flag_set(unw_word_t addr, int flag)
{
  struct map_info *map;
  int ret = 0;

  pthread_rwlock_rdlock (&local_rdwr_lock);
  map = map_find_from_addr (local_map_list, addr);
  if (map != NULL)
    ret = map->flags & flag;
  pthread_rwlock_unlock (&local_rdwr_lock);

  if (!ret && rebuild_if_necessary (addr, flag) == 0)
    {
      pthread_rwlock_rdlock (&local_rdwr_lock);
      map = map_find_from_addr (local_map_list, addr);
      if (map)
        ret = map->flags & flag;
      pthread_rwlock_unlock (&local_rdwr_lock);
    }
  return ret;
}

PROTECTED int
maps_local_is_readable(unw_word_t addr)
{
  return is_flag_set (addr, PROT_READ);
}

PROTECTED int
maps_local_is_writable(unw_word_t addr)
{
  return is_flag_set (addr, PROT_WRITE);
}

PROTECTED int
local_get_elf_image (struct elf_image *ei, unw_word_t ip,
                     unsigned long *segbase, unsigned long *mapoff, char **path)
{
  struct map_info *map;

  pthread_rwlock_rdlock (&local_rdwr_lock);
  map = map_find_from_addr (local_map_list, ip);
  if (!map)
    {
      pthread_rwlock_unlock (&local_rdwr_lock);
      if (rebuild_if_necessary (ip, 0) < 0)
        return -UNW_ENOINFO;

      pthread_rwlock_rdlock (&local_rdwr_lock);
      map = map_find_from_addr (local_map_list, ip);
    }

  if (map && elf_map_cached_image (map, ip) < 0)
    map = NULL;
  else
    {
      *ei = map->ei;
      *segbase = map->start;
      *mapoff = map->offset;
      if (path != NULL)
        {
          if (map->path)
            *path = strdup(map->path);
          else
            *path = NULL;
        }
    }
  pthread_rwlock_unlock (&local_rdwr_lock);

  return 0;
}
