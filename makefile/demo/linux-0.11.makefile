# Comment this to use me in host
# DOCKER ?= yes

ifeq ($(DOCKER),yes)
# Check running envrionment
LAB_ENV_ID=/home/ubuntu/Desktop/lab.desktop
ifneq ($(LAB_ENV_ID),$(wildcard $(LAB_ENV_ID)))
  ifneq (../../configs/linux-0.11-lab, $(wildcard ../../configs/linux-0.11-lab))
    $(error ERR: No 'Cloud Lab' found, please refer to 'Download the lab' part of README.md)
  else
    $(error ERR: Please not try Linux 0.11 Lab in local host, but use it with 'Cloud Lab', please refer to 'Install the environment' part of README.md)
  endif
endif
endif

LINUX_VERSION ?= 0.11
LINUX_SRC     := src
LINUX_IMAGE ?= $(LINUX_SRC)/Image
# src/boot/bootsect.sym, src/boot/setup.sym
DST ?= $(if $(LINUX_DST), $(LINUX_DST), $(LINUX_SRC)/kernel.sym)

TOOL_DIR := tools
ROOTFS_DIR := rootfs
CALLGRAPH_DIR := callgraph

# Xterminal: lxterminal, terminator ...
ifeq ($(shell env | egrep -q "^XDG|^LXQT"; echo $$?), 0)
  XTERM ?= $(shell echo `tools/xterm.sh lxterminal`)
else
  XTERM := null
endif
  GDB ?= gdb

# Qemu
QEMU_PATH =
QEMU ?= qemu-system-i386
MEM  ?= 16M

# Bochs
#BOCHS ?= tools/bochs/bochs-debugger
BOCHS_PATH =
BOCHS_PREBUILT ?= 1
BOCHS_PREBUILT_PATH = ${TOOL_DIR}/bochs

BOCHS ?= bochs

# VM configuration
VM_CFG = $(TOOL_DIR)/.vm.cfg

# Tool for specify root device
SETROOTDEV = RAMDISK_START=$(RAMDISK_START) $(TOOL_DIR)/setrootdev.sh

# Specify the Rootfs Image file
HDA_IMG = hdc-0.11.img
FLP_IMG = rootimage-0.11
RAM_IMG = rootram.img

# Ramdisk start offset and size, in Kb
RAMDISK_START ?= 256

# Tool for call graph generation
CG = $(TOOL_DIR)/callgraph

_QEMU_OPTS = -m $(MEM) -boot c 2>/dev/null
QEMU_OPTS  = -m $(MEM) -boot a -fda $(LINUX_IMAGE) 2>/dev/null


# To using this kvm feature in hardisk boot, please must enable cpu virtualization in bios
#
# Usage: CTRL+ALT+Delete --> Delete --> bios features --> Intel virtualization technology --> enabled
#

QEMU_PREBUILT_PATH= $(TOOL_DIR)/qemu
# Linux 0.11 floppy support is broken in new qemu version, so, please use prebuilt 0.10.6 qemu by default
# But the harddisk support is ok in both of old and new qemu, use qemu here to get possible kvm speedup
ifeq ($(filter $(MAKECMDGOALS),start-hd boot-hd hd-boot hd-start debug-hd),$(MAKECMDGOALS))
   QEMU_PREBUILT ?= 0
else
   QEMU_PREBUILT ?= 1
endif

# Only enable kvm for new qemu, the old one prebuilt in tools/qemu/ not work with kvm
ifeq ($(QEMU_PREBUILT),0)
   # KVM speedup for x86 architecture, assume our host is x86 currently
   QEMU := sudo $(QEMU)
   ifneq ($(findstring debug,$(MAKECMDGOALS)),debug)
     KVM_DEV ?= /dev/kvm
     ifeq ($(KVM_DEV),$(wildcard $(KVM_DEV)))
       QEMU_OPTS += -enable-kvm
       _QEMU_OPTS += -enable-kvm
     endif
   endif
endif

ifeq ($(OS), Linux)
  ifeq ($(QEMU_PREBUILT), 1)
    QEMU_PATH = $(QEMU_PREBUILT_PATH)
    QEMU_LPATH ?= LD_LIBRARY_PATH=$(LD_LIBRARY_PATH):$(CURDIR)/$(QEMU_PREBUILT_PATH)/libs
    QEMU_XOPTS += -no-kqemu -L $(QEMU_PATH)
  endif
  ifeq ($(BOCHS_PREBUILT), 1)
    BOCHS_PATH = $(BOCHS_PREBUILT_PATH)
  endif
endif

ifeq ($(OS), Darwin)
  GDB := tools/mac/gdb
endif
include Makefile.head

all: Image

$(LINUX_SRC): $(LINUX_VERSION)
	$(Q)rm -rf $@
	$(Q)ln -sf $< $@

Image: $(LINUX_SRC)
	$(Q)(cd $(LINUX_SRC); make $@)

clean: $(LINUX_SRC)
	$(Q)(cd $(ROOTFS_DIR); make $@)
	$(Q)(cd $(CALLGRAPH_DIR); make $@)
	$(Q)(cd $(LINUX_SRC); make $@)
	$(Q)rm -rf bochsout.txt

distclean: clean
	$(Q)(cd $(LINUX_SRC); make $@)

# Test on emulators with different prebuilt rootfs
# Rootfs preparation
hda:
	$(Q)(cd $(ROOTFS_DIR); make $@)

flp:
	$(Q)(cd $(ROOTFS_DIR); make $@)

ramfs:
	$(Q)(cd $(ROOTFS_DIR); make $@)

hda-install:
	$(Q)(cd $(ROOTFS_DIR); make $@)

hd-install: hda-install
install-hd: hd-install

flp-install:
	$(Q)(cd $(ROOTFS_DIR); make $@)

fd-install: flp-install
install-fd: fd-install

ramfs-install:
	$(Q)(cd $(ROOTFS_DIR); make $@)

install-ramfs: ramfs-install

hda-mount:
	$(Q)(cd $(ROOTFS_DIR); make $@)

hda-umount:
	$(Q)(cd $(ROOTFS_DIR); make $@)

hd-mount: hda-mount
mount-hd: hd-mount
hd-umount: hda-umount
umount-hd: hd-umount

flp-mount:
	$(Q)(cd $(ROOTFS_DIR); make $@)

flp-umount:
	$(Q)(cd $(ROOTFS_DIR); make $@)

fd-mount: flp-mount
mount-fd: fd-mount
fd-umount: flp-umount
umount-fd: fd-umount

ramfs-mount:
	$(Q)(cd $(ROOTFS_DIR); make $@)

ramfs-umount:
	$(Q)(cd $(ROOTFS_DIR); make $@)


mount-ramfs: ramfs-mount
umount-ramfs: ramfs-umount

# VM (Qemu/Bochs) Setting for different rootfs

ROOT_RAM = 0000
ROOT_FDB = 021d
ROOT_HDA = 0301

SETROOTDEV_CMD = $(SETROOTDEV) $(LINUX_IMAGE)
SETROOTDEV_CMD_RAM = $(SETROOTDEV_CMD) $(ROOT_RAM) $(ROOTFS_DIR)/$(RAM_IMG)
SETROOTDEV_CMD_FDB = $(SETROOTDEV_CMD) $(ROOT_FDB)
SETROOTDEV_CMD_HDA = $(SETROOTDEV_CMD) $(ROOT_HDA)

QEMU_CMD = $(QEMU)
_QEMU_CMD = $(QEMU)

ifeq ($(QEMU_PREBUILT),1)
  QEMU_STATUS = $(shell $(QEMU_LPATH) $(QEMU_PATH)/$(QEMU) --help >/dev/null 2>&1; echo $$?)
  ifeq ($(QEMU_STATUS), 0)
    QEMU_CMD :=  $(QEMU_LPATH) $(QEMU_PATH)/$(QEMU) $(QEMU_XOPTS)
    _QEMU_CMD := $(QEMU_LPATH) $(QEMU_PATH)/$(QEMU) $(QEMU_XOPTS)
  endif
endif

_BOCHS_CMD = $(BOCHS)
ifeq ($(BOCHS_PREBUILT),1)
  BOCHS_STATUS = $(shell $(BOCHS_PATH)/$(BOCHS) --help >/dev/null 2>&1; echo $$?)
  ifeq ($(BOCHS_STATUS), 0)
    _BOCHS_CMD := $(BOCHS_PATH)/$(BOCHS)
  endif
endif

_QEMU_CMD += $(_QEMU_OPTS)
QEMU_CMD += $(QEMU_OPTS)

QEMU_CMD_FDB = $(QEMU_CMD) -fdb $(ROOTFS_DIR)/$(FLP_IMG)
QEMU_CMD_HDA = $(QEMU_CMD) -hda $(ROOTFS_DIR)/$(HDA_IMG)
_QEMU_CMD_HDA = $(_QEMU_CMD) -hda $(ROOTFS_DIR)/$(HDA_IMG)
nullstring :=
QEMU_DBG = $(nullstring) -s -S #-nographic #-serial '/dev/ttyS0'"

BOCHS_CFG = $(TOOL_DIR)/bochs/bochsrc
BOCHS_CMD = $(_BOCHS_CMD) -q -f $(BOCHS_CFG)/bochsrc-fda.bxrc
BOCHS_CMD_FDB = $(_BOCHS_CMD) -q -f $(BOCHS_CFG)/bochsrc-fdb.bxrc
BOCHS_CMD_HDA = $(_BOCHS_CMD) -q -f $(BOCHS_CFG)/bochsrc-hd.bxrc
BOCHS_DBG = .dbg

ifneq ($(VM),)
  NEW_VM = $(VM)
else
  VM ?= $(shell cat $(VM_CFG) 2>/dev/null)

  ifeq ($(VM), bochs)
    NEW_VM=qemu
  else
    NEW_VM=bochs
  endif
endif

switch:
	$(Q)echo "Switch to use emulator: $(NEW_VM)"
	$(Q)echo $(NEW_VM) > $(VM_CFG)

VM=$(shell cat $(VM_CFG) 2>/dev/null)

ifeq ($(VM), bochs)
  VM_CMD = $(BOCHS_CMD)
  VM_CMD_FDB = $(BOCHS_CMD_FDB)
  VM_CMD_HDA = $(BOCHS_CMD_HDA)
  VM_DBG = $(BOCHS_DBG)
else
  VM_CMD = $(QEMU_CMD)
  VM_CMD_FDB = $(QEMU_CMD_FDB)
  VM_CMD_HDA = $(QEMU_CMD_HDA)
  _VM_CMD_HDA = $(_QEMU_CMD_HDA)
  VM_DBG = $(QEMU_DBG)
endif

# Allow to use curses based console via ssh
# Exit with 'ESC + 2' + quit
ifneq ($(SSH_TTY),)
  override G := 0
endif
ifeq ($(XTERM),null)
  override G := 0
endif

VM_DISPLAY =
ifeq ($(G),0)
  ifeq ($(VM), bochs)
    VM_DISPLAY = .term
  else
    VM_DISPLAY = $(nullstring) -curses
  endif
endif

# Running on emulators with differrent rootfs
ramdisk-boot: ramfs $(LINUX_SRC)
	@# Force init/main.o build with ramdisk support
	$(Q)(cd $(LINUX_SRC); make -B init/main.o \
	RAMDISK_SIZE=$(shell wc -c $(ROOTFS_DIR)/$(RAM_IMG) | tr -C -d '[0-9]' | xargs -i echo {}/1024 + 1 | bc))
	$(Q)(cd $(LINUX_SRC); make -B kernel/blk_drv/blk_drv.a RAMDISK_START=$(RAMDISK_START))

# Boot with Image and Rootfs from harddisk
hd-boot: hd-start

# Boot with rootfs from ramfs, floppy and hardisk
boot-hd: start-hd
boot-fd: start-fd
boot: start
_boot: _start

start: ramdisk-boot Image
	$(SETROOTDEV_CMD_RAM)
	$(VM_CMD)$(VM_DISPLAY)

start-fd: Image flp
	$(SETROOTDEV_CMD_FDB)
	$(VM_CMD_FDB)$(VM_DISPLAY)

HDA_INSTALL = hda-install
ifeq ($(OS), Linux)
  MINIX_FS = $(shell lsmod | grep -q minix >/dev/null 2>&1; echo $$?)
  ifeq ($(MINIX_FS), 0)
    HDA_INSTALL = hda-install
  else
    MINIX_FS = $(shell sudo modprobe minix >/dev/null 2>&1; echo $$?)
    ifeq ($(MINIX_FS), 0)
      HDA_INSTALL = hda-install
    endif
  endif
endif

start-hd: Image hda $(HDA_INSTALL)
	$(SETROOTDEV_CMD_HDA)
	$(VM_CMD_HDA)$(VM_DISPLAY)

hd-start: Image hda $(HDA_INSTALL)
	$(_VM_CMD_HDA)$(VM_DISPLAY)

# For any other images
_start:
	$(VM_CMD)$(VM_DISPLAY)

# see examples/linux-0.11/README.md
LINUX_000 ?= $(ROOTFS_DIR)/_hda/usr/root/examples/linux-0.00/Image
linux-0.00:
	$(Q)(cd $(ROOTFS_DIR); make hda-mount)
	$(Q)sudo make _start LINUX_IMAGE=$(LINUX_000)
	$(Q)(cd $(ROOTFS_DIR); make hda-umount)

# Debugging the above targets

GDB_CMD ?= $(GDB) --quiet $(DST)

ifneq ($(XTERM), null)
  XTERM_CMD ?= $(Q)$(XTERM) --working-directory=$(CURDIR) -T "$(GDB_CMD)" -e "$(GDB_CMD)"

  XTERM_STATUS = $(shell $(XTERM) --help >/dev/null 2>&1; echo $$?)
else
  XTERM_STATUS := 1
  XTERM_CMD    := null
endif
ifeq ($(XTERM_STATUS), 0)
  DEBUG_CMD = $(XTERM_CMD)
else
  DEBUG_CMD = $(Q)echo "\nLOG: Please run this in another terminal:\n\n    " $(GDB_CMD) "\n"
endif

gdbinit:
	$(Q)echo "add-auto-load-safe-path .gdbinit" > $(HOME)/.gdbinit
ifeq ($(findstring kernel,$(DST)),kernel)
	$(Q)cp .kernel_gdbinit .gdbinit
else
	$(Q)cp .boot_gdbinit .gdbinit
endif
ifeq ($(OS), Darwin)
	$(Q)cd tools/mac && [ -f gdb.xz ] && tar Jxf gdb.xz
endif

debug: ramdisk-boot Image gdbinit
	$(SETROOTDEV_CMD_RAM)
	$(DEBUG_CMD) &
	$(VM_CMD)$(VM_DBG)$(VM_DISPLAY)

debug-fd: Image flp gdbinit
	$(SETROOTDEV_CMD_FDB)
	$(DEBUG_CMD) &
	$(VM_CMD_FDB)$(VM_DBG)$(VM_DISPLAY)

debug-hd: Image hda gdbinit
	$(SETROOTDEV_CMD_HDA)
	$(DEBUG_CMD) &
	$(VM_CMD_HDA)$(VM_DBG)$(VM_DISPLAY)
include Makefile.emu

# Tags for source code reading
include Makefile.tags

# For Call graph generation
include Makefile.cg

# For help
include Makefile.help
