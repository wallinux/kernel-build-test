# Build test Makefile

default: help

# Default settings
HOSTNAME 	?= $(shell hostname)
USER		?= $(shell whoami)
DOMAIN		?= $(shell dnsdomainname)

# Optional configuration
-include hostconfig-$(HOSTNAME).mk
-include userconfig-$(USER).mk
-include domainconfig-$(DOMAIN).mk
-include userconfig-$(HOSTNAME)-$(USER).mk

TOP	:= $(shell pwd)

KERNEL_VER 	?= linux-4.1.6.tar.xz
KERNEL_DL	?= https://www.kernel.org/pub/linux/kernel/v4.x
KERNEL		= git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
KERNEL_STABLE	= git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_TAG	?= v4.1.6
#KERNEL_CONFIG	?= allyesconfig
KERNEL_CONFIG	?= x86_64_defconfig
KERNEL_TARGET	?= bzImage

PBUILDS		?= 2
PJOBS		?= $(shell nproc)

DL_DIR		?= $(TOP)/download

SRC_BASE	?= $(TOP)/src
SRC_DIR		?= $(SRC_BASE)/1
SRC_DIRS 	= $(foreach dir, $(shell seq 1 $(PBUILDS)), $(SRC_BASE)/$(dir))

OUT_BASE	?= $(TOP)/out
OUT_DIR		?= $(OUT_BASE)/1
OUT_DIRS 	= $(foreach dir, $(shell seq 1 $(PBUILDS)), $(OUT_BASE)/$(dir))

# Tools used
# Define V=1 to echo everything
ifeq ($(V),1)
Q=
else
Q=@
endif

ECHO	:= $(Q)echo
MKDIR	:= $(Q)mkdir -p
RM	:= $(Q)rm -f
MAKE	:= $(Q)make -s
TIME	?= $(Q)/usr/bin/time -v

help:
	$(ECHO) "all - Build and measure"
	$(ECHO) ""
	$(ECHO) "Host:         $(HOSTNAME)"
	$(ECHO) "User:         $(USER)"
	$(ECHO) "Date:         $(shell date)"
	$(ECHO) "SRC location: $(SRC_BASE)"
	$(ECHO) "OUT location: $(OUT_BASE)"
	$(ECHO) "No of builds: $(PBUILDS)"
	$(ECHO) "No of jobs:   $(PJOBS)"

.PHONY: help
.FORCE:

$(DL_DIR):
	$(MKDIR) $@

repo: repo.update

repo.checkout: $(DL_DIR)/linux
	$(Q)cd $<; git checkout -b branch_$(KERNEL_TAG) $(KERNEL_TAG)

repo.update: $(DL_DIR)/linux
	$(Q)cd $<; git fetch --all
	$(MAKE) repo.checkout

repo.stable: $(DL_DIR)/linux
	$(Q)cd $<; git remote add stable $(KERNEL_STABLE)
	$(MAKE) repo.update

repo.clone: $(DL_DIR)/linux
$(DL_DIR)/linux:
	$(Q)git clone $(KERNEL) $@
	$(MAKE) repo.stable

dl: $(DL_DIR)/$(KERNEL_VER) 
$(DL_DIR)/$(KERNEL_VER): $(DL_DIR)
	$(Q)cd $(DL_DIR); wget -c $(KERNEL_DL)/$(KERNEL_VER)
	$(Q)touch $(DL_DIR)/$(KERNEL_VER)

prepare: $(SRC_DIRS)
$(SRC_DIRS): $(DL_DIR)/$(KERNEL_VER)
	$(MKDIR) $@
	$(Q)tar -C $@ --strip-components=1 -xf $<

build: $(OUT_DIRS)
$(OUT_DIRS): $(SRC_DIRS)
	$(MKDIR) $@
	$(eval index=$(shell basename $@))
	$(MAKE) -C $(SRC_BASE)/$(index) O=$@ $(KERNEL_CONFIG) > /dev/null
	$(MAKE) -j $(PJOBS) -C $(SRC_BASE)/$(index) O=$@ $(KERNEL_TARGET) > $@/build.out

all: $(SRC_DIRS)
	$(ECHO) "Host:         $(HOSTNAME)"
	$(ECHO) "User:         $(USER)"
	$(ECHO) "Date:         $(shell date)"
	$(ECHO) "SRC location: $(SRC_BASE)"
	$(ECHO) "OUT location: $(OUT_BASE)"
	$(ECHO) "No of builds: $(PBUILDS)"
	$(ECHO) "No of jobs:   $(PJOBS)"
	$(ECHO) Start build $@
	$(TIME) make -s -j build
	$(ECHO) End build $@

prepare.clean:
	$(ECHO) $@
	$(RM) -r $(SRC_BASE)

build.clean:
	$(ECHO) $@
	$(RM) -r $(OUT_BASE)

clean: prepare.clean build.clean 

distclean: clean
	$(ECHO) $@
	$(RM) -r $(DL_DIR)
