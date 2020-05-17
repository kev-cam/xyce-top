TEST_DIR=../xyce-testbuild
XYCE_TAR=$(PWD)/Xyce-7.0.tar.gz
CONFIG=$(PWD)/dkc-wsl.config
MK_BLD_OPTIONS=-j$$[ $$(nproc) / 2 ]
SHELL=bash

help:
	@echo Targets:
	@echo " " clean "(rm -fr $(TEST_DIR)/*)"
	@echo " " unpack "$(XYCE_TAR) -> $(TEST_DIR)"
	@echo " " configure with $(CONFIG)
	@echo " " build
	@echo " " update
	@echo " " purge
	@echo " " patch

configure:
	cd $(TEST_DIR)/Xyce-7.0 ; sh $(CONFIG)


build_exe:
	cd $(TEST_DIR)/Xyce-7.0 ; make $(MK_BLD_OPTIONS)

build: build_exe
	@cd $(TEST_DIR)/Xyce-7.0/src ; echo Built $$PWD/Xyce

purge:
	find src -type f -name "??*.*" -exec rm {} \;

update:
	cvs update .

unpack:
	@echo Unpacking
	tar -C $(TEST_DIR) -xvzf $(XYCE_TAR)

tgz:
	@echo Packing
	tar -cvf patch.tgz --exclude=CVS src

patch: tgz 
	@echo Patching
	tar -C $(TEST_DIR)/Xyce-7.0 --touch -xvf $$PWD/patch.tgz

test_setup:
	if [ ! -d sandbox ] ; then mkdir sandbox ; fi
	ln -s ../src/DeviceModelPKG/Core/N_DEV_BridgeOp.inc\
		  ../src/DeviceModelPKG/Core/N_DEV_SourceDataExt.h\
		  ../src/DeviceModelPKG/Core/N_DEV_SourceDataExt.inc\
		sandbox/

run_tests:
	cd sandbox ; sh ./run_tests.sh $(TEST_DIR)/Xyce-7.0/src/Xyce

results:
	@cd sandbox ; for cir in *.cir ; do\
		echo $$cir; \
		grep plot $$cir | cut -c2- | gnuplot -p ; done

clean:
	rm -fr $(TEST_DIR)/*

