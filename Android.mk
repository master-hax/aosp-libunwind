LOCAL_PATH := $(call my-dir)

libunwind_cflags := \
	-DHAVE_CONFIG_H \
	-DNDEBUG \
	-D_GNU_SOURCE \
	-Wno-unused-parameter \

libunwind_includes := \
	$(LOCAL_PATH)/src \
	$(LOCAL_PATH)/include \

ifeq ($(TARGET_ARCH),$(filter $(TARGET_ARCH),aarch64 arm mips x86))
libunwind_includes += $(LOCAL_PATH)/include/tdep-$(TARGET_ARCH)
endif

include $(CLEAR_VARS)

LOCAL_MODULE := libunwind

LOCAL_CFLAGS += $(libunwind_cflags)
LOCAL_C_INCLUDES := $(libunwind_includes)

LOCAL_SRC_FILES := \
	src/mi/init.c \
	src/mi/flush_cache.c \
	src/mi/mempool.c \
	src/mi/strerror.c \
	src/mi/backtrace.c \
	src/mi/dyn-cancel.c \
	src/mi/dyn-info-list.c \
	src/mi/dyn-register.c \
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
	src/elfxx.c \
	src/os-linux.c \

ifeq ($(TARGET_ARCH),$(filter $(TARGET_ARCH),aarch64 arm mips x86))
LOCAL_SRC_FILES += \
	src/$(TARGET_ARCH)/is_fpreg.c \
	src/$(TARGET_ARCH)/regname.c \
	src/$(TARGET_ARCH)/Gcreate_addr_space.c \
	src/$(TARGET_ARCH)/Gget_proc_info.c \
	src/$(TARGET_ARCH)/Gget_save_loc.c \
	src/$(TARGET_ARCH)/Gglobal.c \
	src/$(TARGET_ARCH)/Ginit.c \
	src/$(TARGET_ARCH)/Ginit_local.c \
	src/$(TARGET_ARCH)/Ginit_remote.c \
	src/$(TARGET_ARCH)/Gregs.c \
	src/$(TARGET_ARCH)/Gresume.c \
	src/$(TARGET_ARCH)/Gstep.c \
	src/$(TARGET_ARCH)/Lcreate_addr_space.c \
	src/$(TARGET_ARCH)/Lget_proc_info.c \
	src/$(TARGET_ARCH)/Lget_save_loc.c \
	src/$(TARGET_ARCH)/Lglobal.c \
	src/$(TARGET_ARCH)/Linit.c \
	src/$(TARGET_ARCH)/Linit_local.c \
	src/$(TARGET_ARCH)/Linit_remote.c \
	src/$(TARGET_ARCH)/Lregs.c \
	src/$(TARGET_ARCH)/Lresume.c \
	src/$(TARGET_ARCH)/Lstep.c \

endif

ifeq ($(TARGET_ARCH),$(filter $(TARGET_ARCH),aarch64 arm mips))
LOCAL_SRC_FILES += \
	src/$(TARGET_ARCH)/Gis_signal_frame.c \
	src/$(TARGET_ARCH)/Lis_signal_frame.c \

endif

ifeq ($(TARGET_ARCH),arm)
LOCAL_SRC_FILES += \
	src/arm/getcontext.S \
	src/arm/Gex_tables.c \
	src/arm/Lex_tables.c \

endif  # arm

ifeq ($(TARGET_ARCH),mips)
LOCAL_SRC_FILES += \
	src/mips/getcontext-android.S \

endif

ifeq ($(TARGET_ARCH),x86)
LOCAL_SRC_FILES += \
	src/x86/getcontext-linux.S \
	src/x86/Gos-linux.c \
	src/x86/Los-linux.c \

endif  # x86

LOCAL_SHARED_LIBRARIES := \
	libdl \
	liblog \

LOCAL_ADDITIONAL_DEPENDENCIES := \
	$(LOCAL_PATH)/Android.mk \

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := libunwind-ptrace

LOCAL_CFLAGS += $(libunwind_cflags)
LOCAL_C_INCLUDES := $(libunwind_includes)

# Files needed to trace running processes.
LOCAL_SRC_FILES += \
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

LOCAL_SHARED_LIBRARIES := \
	libunwind \
	liblog \

LOCAL_ADDITIONAL_DEPENDENCIES := \
	$(LOCAL_PATH)/Android.mk \

include $(BUILD_SHARED_LIBRARY)
