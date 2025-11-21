# Verilated -*- Makefile -*-
# DESCRIPTION: Verilator output: Makefile for building Verilated archive or executable
#
# Execute this makefile from the object directory:
#    make -f Vsimple_inv.mk

default: libVsimple_inv

### Constants...
# Perl executable (from $PERL)
PERL = perl
# Path to Verilator kit (from $VERILATOR_ROOT)
VERILATOR_ROOT = /usr/share/verilator
# SystemC include directory with systemc.h (from $SYSTEMC_INCLUDE)
SYSTEMC_INCLUDE ?= 
# SystemC library directory with libsystemc.a (from $SYSTEMC_LIBDIR)
SYSTEMC_LIBDIR ?= 

### Switches...
# C++ code coverage  0/1 (from --prof-c)
VM_PROFC = 0
# SystemC output mode?  0/1 (from --sc)
VM_SC = 0
# Legacy or SystemC output mode?  0/1 (from --sc)
VM_SP_OR_SC = $(VM_SC)
# Deprecated
VM_PCLI = 1
# Deprecated: SystemC architecture to find link library path (from $SYSTEMC_ARCH)
VM_SC_TARGET_ARCH = linux

### Vars...
# Design prefix (from --prefix)
VM_PREFIX = Vsimple_inv
# Module prefix (from --prefix)
VM_MODPREFIX = Vsimple_inv
# User CFLAGS (from -CFLAGS on Verilator command line)
VM_USER_CFLAGS = \
	-fPIC \

# User LDLIBS (from -LDFLAGS on Verilator command line)
VM_USER_LDLIBS = \

# User .cpp files (from .cpp's on Verilator command line)
VM_USER_CLASSES = \

# User .cpp directories (from .cpp's on Verilator command line)
VM_USER_DIR = \


### Default rules...
# Include list of all generated classes
include Vsimple_inv_classes.mk
# Include global rules
include $(VERILATOR_ROOT)/include/verilated.mk

### Library rules (default lib mode)
libVsimple_inv.a: $(VK_OBJS) $(VK_USER_OBJS) $(VM_HIER_LIBS)
libverilated.a: $(VK_GLOBAL_OBJS)
libVsimple_inv: libVsimple_inv.a libverilated.a $(VM_PREFIX)__ALL.a

# Verilated -*- Makefile -*-
