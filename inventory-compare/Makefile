TOPLEVEL_NAMESPACE=distribution
RELATIVE_PATH=inventory-compare
export RHTS_RPM_NAME=beaker-distribution-inventory-comparison
export TESTVERSION=1.5
# The combined namespace of the test.
export TEST=/$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)


# A phony target is one that is not really the name of a file.
# It is just a name for some commands to be executed when you
# make an explicit request. There are two reasons to use a
# phony target: to avoid a conflict with a file of the same
# name, and to improve performance.
.PHONY: all install download clean

# data files, .c files, scripts anything needed to either compile the test and/or run it.
FILES=$(METADATA) runtest.sh Makefile compare.py

run: $(FILES) build
	./runtest.sh

build:
	chmod a+x ./runtest.sh

clean: 
	rm -rf beaker-system-scan lshw comparison.html
	rm -f *~ *.rpm

# Include Common Makefile
include /usr/share/rhts/lib/rhts-make.include

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
# Change to the test owner's name
	@echo "Owner:        Beaker Developers <beaker-devel@lists.fedorahosted.org>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)"	>> $(METADATA)
	@echo "License:      GPLv2+" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"	>> $(METADATA)
	@echo "Description:  This runs beaker-system-scan using smolt and lshw and produces a comparison">> $(METADATA)
	@echo "TestTime:     60m" >> $(METADATA)
	@echo "Requires:     make" >> $(METADATA)
	@echo "Requires:     git" >> $(METADATA)
	@echo "Requires:     beakerlib" >> $(METADATA)

