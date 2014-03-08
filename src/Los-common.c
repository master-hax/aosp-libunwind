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

static void
move_cached_elf_data(struct map_info *old_list, struct map_info *new_list)
{
  intrmask_t ei_saved_mask;
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
              /* Even doing this lock, there is a chance that other code
                 could mmap the same memory in the old list. If that happens,
                 there will be some waste, but it should be minimal and
                 when the to delete list is destroyed, it will be cleaned up. */
              lock_acquire (&old_list->ei_lock, ei_saved_mask);
              new_list->ei.size = old_list->ei.size;
              new_list->ei.image = old_list->ei.image;
              /* Do not zero out the elf image data. If other processes
                 are reading from the same cached data, let it stay but mark
                 it so it's only freed in the new_list. */
              old_list->ei_shared = 1;
              lock_release (&old_list->ei_lock, ei_saved_mask);
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
static struct map_info *
rebuild_if_necessary (unw_word_t addr, int expected_flags)
{
  struct map_info *map;
  struct map_info *new_list;

  intrmask_t saved_mask;
  lock_acquire (&local_map_lock, saved_mask);

  new_list = maps_create_list(getpid());
  map = map_find_from_addr(new_list, addr);
  if (map && (expected_flags == 0 || (map->flags & expected_flags)))
    {
      /* Move any cached items to the new list. */
      move_cached_elf_data(local_map_list, new_list);
      if (local_to_delete_list)
        {
          /* If there is already an old list of elements to delete, add the
             old to delete list at the end of the current to delete list.
             If a thread is still accessing this list, there is the possibility
             it will traverse over the elements in the current to delete list.
             No other running code makes any assumptions about the list
             having a specific order. */
          struct map_info *last = local_map_list;
          while (last->next != NULL)
            last = last->next;
          /* It is assumed that the operation below is atomic, and any other
             running thread will either see a NULL pointer at the end of the
             list, or the correct next pointer. */
          last->next = local_to_delete_list;
        }
      local_to_delete_list = local_map_list;
      local_map_list = new_list;
    }
  else
    maps_destroy_list(new_list);
  lock_release (&local_map_lock, saved_mask);

  return map;
}

PROTECTED int
maps_is_readable(struct map_info *map_list, unw_word_t addr)
{
  struct map_info *map = map_find_from_addr(map_list, addr);
  int ret = 0;
  if (map != NULL)
    ret = map->flags & PROT_READ;

  if (!ret)
    {
      map = rebuild_if_necessary(addr, PROT_READ);
      if (map)
        ret = map->flags & PROT_READ;
    }
  return ret;
}

PROTECTED int
maps_is_writable(struct map_info *map_list, unw_word_t addr)
{
  struct map_info *map = map_find_from_addr(map_list, addr);
  int ret = 0;
  if (map != NULL)
    ret = map->flags & PROT_WRITE;

  if (!ret)
    {
      map = rebuild_if_necessary(addr, PROT_WRITE);
      if (map)
        ret = map->flags & PROT_WRITE;
    }
  return ret;
}
