LOCAL_PATH := $(call my-dir)

build_host := false
ifeq ($(HOST_OS),linux)
ifeq ($(HOST_ARCH),$(filter $(HOST_ARCH),x86 x86_64))
build_host := true
endif
endif

# Function to build a target
# $(1): module
# $(2): module tag
# $(3): build type (host or target)
# $(4): build target (SHARED_LIBRARY, NATIVE_TEST, etc)
define build
  module := $(1)
  module_tag := $(2)
  build_type := $(3)
  build_target := $(4)

  include $(CLEAR_VARS)

  LOCAL_MODULE := $$(module)
  LOCAL_MODULE_TAGS := $$(module_tag)

  LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/Android.mk

  LOCAL_CFLAGS := \
    $$(common_cflags) \
    $$($$(module)_cflags) \
    $$($$(module)_cflags_$$(build_type)) \

  LOCAL_ASFLAGS := \
    $$(common_asflags) \
    $$($$(module)_asflags) \
    $$($$(module)_asflags_$$(build_type)) \

  LOCAL_CONLYFLAGS += \
    $$(common_conlyflags) \
    $$($$(module)_conlyflags) \
    $$($$(module)_conlyflags_$$(build_type)) \

  LOCAL_CPPFLAGS += \
    $$(common_cppflags) \
    $$($$(module)_cppflags) \
    $$($$(module)_cppflags_$$(build_type)) \

  LOCAL_C_INCLUDES := \
    $$(common_c_includes) \
    $$($$(module)_c_includes) \
    $$($$(module)_c_includes_$$(build_type)) \

  ifneq ($$(build_type),host)
    $$(foreach arch,$$(libunwind_arches), \
      $$(eval LOCAL_C_INCLUDES_$$(arch) := $$(common_c_includes_$$(arch))))
  else
    $$(eval LOCAL_C_INCLUDES += $$(common_c_includes_$$(HOST_ARCH)))
  endif

  LOCAL_SRC_FILES := \
    $$($$(module)_src_files) \
    $$($$(module)_src_files_$$(build_type)) \

  ifneq ($$(build_type),host)
    $$(foreach arch,$$(libunwind_arches), \
      $$(eval LOCAL_SRC_FILES_$$(arch) :=  $$($$(module)_src_files_$$(arch))))
  else
    $$(eval LOCAL_SRC_FILES +=  $$($$(module)_src_files_$$(HOST_ARCH)))
  endif

  LOCAL_STATIC_LIBRARIES := \
    $$($$(module)_static_libraries) \
    $$($$(module)_static_libraries_$$(build_type)) \

  LOCAL_SHARED_LIBRARIES := \
    $$($$(module)_shared_libraries) \
    $$($$(module)_shared_libraries_$$(build_type)) \

  LOCAL_LDLIBS := \
    $$($$(module)_ldlibs) \
    $$($$(module)_ldlibs_$$(build_type)) \

  ifeq ($$(build_type),target)
    include $$(BUILD_$$(build_target))
  endif

  ifeq ($$(build_type),host)
    # Only build if host builds are supported.
    ifeq ($$(build_host),true)
      include $$(BUILD_HOST_$$(build_target))
    endif
  endif
endef

common_cflags := \
	-DHAVE_CONFIG_H \
	-DNDEBUG \
	-D_GNU_SOURCE \
	-Wno-unused-parameter \

# For debug build it is required:
#  1. Enable flags below
#  2. On runtime export UNW_DEBUG_LEVEL=x where x controls verbosity (from 1 to 20)
#common_cflags := \
#	-DHAVE_CONFIG_H \
#	-DDEBUG \
#	-D_GNU_SOURCE \
#	-U_FORTIFY_SOURCE

common_c_includes := \
	$(LOCAL_PATH)/src \
	$(LOCAL_PATH)/include \

define libunwind-arch
$(if $(filter arm64,$(1)),aarch64,$(1))
endef

libunwind_arches := arm arm64 mips x86 x86_64

$(foreach arch,$(libunwind_arches), \
  $(eval common_c_includes_$(arch) := $(LOCAL_PATH)/include/tdep-$(call libunwind-arch,$(arch))))

#-----------------------------------------------------------------------
# libunwind shared library
#-----------------------------------------------------------------------
libunwind_src_files := \
	src/mi/init.c \
	src/mi/flush_cache.c \
	src/mi/mempool.c \
	src/mi/strerror.c \
	src/mi/backtrace.c \
	src/mi/dyn-cancel.c \
	src/mi/dyn-info-list.c \
	src/mi/dyn-register.c \
	src/mi/maps.c \
	src/mi/Ldyn-extract.c \
	src/mi/Lfind_dynamic_proc_info.c \
	src/mi/Lget_proc_info_by_ip.c \
	src/mi/Lget_proc_name.c \
	src/mi/Lput_dynamic_unwind_info.c \
	src/mi/Ldestroy_addr_space.c \
	src/mi/Lget_reg.c \
	src/mi/Lset_reg.c \
	src/mi/Lget_fpreg.c \
	src/mi/Lset_fpreg.c \
	src/mi/Lset_caching_policy.c \
	src/mi/Gdyn-extract.c \
	src/mi/Gdyn-remote.c \
	src/mi/Gfind_dynamic_proc_info.c \
	src/mi/Gget_accessors.c \
	src/mi/Gget_proc_info_by_ip.c \
	src/mi/Gget_proc_name.c \
	src/mi/Gput_dynamic_unwind_info.c \
	src/mi/Gdestroy_addr_space.c \
	src/mi/Gget_reg.c \
	src/mi/Gset_reg.c \
	src/mi/Gget_fpreg.c \
	src/mi/Gset_fpreg.c \
	src/mi/Gset_caching_policy.c \
	src/dwarf/Lexpr.c \
	src/dwarf/Lfde.c \
	src/dwarf/Lparser.c \
	src/dwarf/Lpe.c \
	src/dwarf/Lstep.c \
	src/dwarf/Lfind_proc_info-lsb.c \
	src/dwarf/Lfind_unwind_table.c \
	src/dwarf/Gexpr.c \
	src/dwarf/Gfde.c \
	src/dwarf/Gfind_proc_info-lsb.c \
	src/dwarf/Gfind_unwind_table.c \
	src/dwarf/Gparser.c \
	src/dwarf/Gpe.c \
	src/dwarf/Gstep.c \
	src/dwarf/global.c \
	src/os-linux.c \

# Arch specific source files.
$(foreach arch,$(libunwind_arches), \
  $(eval libunwind_src_files_$(arch) += \
	src/$(call libunwind-arch,$(arch))/is_fpreg.c \
	src/$(call libunwind-arch,$(arch))/regname.c \
	src/$(call libunwind-arch,$(arch))/Gcreate_addr_space.c \
	src/$(call libunwind-arch,$(arch))/Gget_proc_info.c \
	src/$(call libunwind-arch,$(arch))/Gget_save_loc.c \
	src/$(call libunwind-arch,$(arch))/Gglobal.c \
	src/$(call libunwind-arch,$(arch))/Ginit.c \
	src/$(call libunwind-arch,$(arch))/Ginit_local.c \
	src/$(call libunwind-arch,$(arch))/Ginit_remote.c \
	src/$(call libunwind-arch,$(arch))/Gregs.c \
	src/$(call libunwind-arch,$(arch))/Gresume.c \
	src/$(call libunwind-arch,$(arch))/Gstep.c \
	src/$(call libunwind-arch,$(arch))/Lcreate_addr_space.c \
	src/$(call libunwind-arch,$(arch))/Lget_proc_info.c \
	src/$(call libunwind-arch,$(arch))/Lget_save_loc.c \
	src/$(call libunwind-arch,$(arch))/Lglobal.c \
	src/$(call libunwind-arch,$(arch))/Linit.c \
	src/$(call libunwind-arch,$(arch))/Linit_local.c \
	src/$(call libunwind-arch,$(arch))/Linit_remote.c \
	src/$(call libunwind-arch,$(arch))/Lregs.c \
	src/$(call libunwind-arch,$(arch))/Lresume.c \
	src/$(call libunwind-arch,$(arch))/Lstep.c \
	))

# 64-bit architectures
libunwind_src_files_arm64 += src/elf64.c
libunwind_src_files_x86_64 += src/elf64.c

# 32-bit architectures
libunwind_src_files_arm   += src/elf32.c
libunwind_src_files_mips  += src/elf32.c
libunwind_src_files_x86   += src/elf32.c

libunwind_src_files_arm += \
	src/arm/getcontext.S \
	src/arm/Gis_signal_frame.c \
	src/arm/Gex_tables.c \
	src/arm/Lis_signal_frame.c \
	src/arm/Lex_tables.c \

libunwind_src_files_arm64 += \
	src/aarch64/Gis_signal_frame.c \
	src/aarch64/Lis_signal_frame.c \

libunwind_src_files_mips += \
	src/mips/getcontext-android.S \
	src/mips/Gis_signal_frame.c \
	src/mips/Lis_signal_frame.c \

libunwind_src_files_x86 += \
	src/x86/getcontext-linux.S \
	src/x86/Gos-linux.c \
	src/x86/Los-linux.c \

libunwind_src_files_x86_64 += \
	src/x86_64/getcontext.S \
	src/x86_64/Gstash_frame.c \
	src/x86_64/Gtrace.c \
	src/x86_64/Gos-linux.c \
	src/x86_64/Lstash_frame.c \
	src/x86_64/Ltrace.c \
	src/x86_64/Los-linux.c \
	src/x86_64/setcontext.S \

libunwind_shared_libraries_target := \
	libdl \

$(eval $(call build,libunwind,optional,target,SHARED_LIBRARY))
$(eval $(call build,libunwind,optional,host,SHARED_LIBRARY))

#-----------------------------------------------------------------------
# libunwind-ptrace shared library
#-----------------------------------------------------------------------
libunwind-ptrace_src_files := \
	src/ptrace/_UPT_elf.c \
	src/ptrace/_UPT_accessors.c \
	src/ptrace/_UPT_access_fpreg.c \
	src/ptrace/_UPT_access_mem.c \
	src/ptrace/_UPT_access_reg.c \
	src/ptrace/_UPT_create.c \
	src/ptrace/_UPT_destroy.c \
	src/ptrace/_UPT_find_proc_info.c \
	src/ptrace/_UPT_get_dyn_info_list_addr.c \
	src/ptrace/_UPT_put_unwind_info.c \
	src/ptrace/_UPT_get_proc_name.c \
	src/ptrace/_UPT_reg_offset.c \
	src/ptrace/_UPT_resume.c \

libunwind-ptrace_shared_libraries := \
	libunwind \

$(eval $(call build,libunwind-ptrace,optional,target,SHARED_LIBRARY))
$(eval $(call build,libunwind-ptrace,optional,host,SHARED_LIBRARY))
