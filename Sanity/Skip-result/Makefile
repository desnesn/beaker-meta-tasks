export TEST=/distribution/beaker/Sanity/Skip-result
export TESTVERSION=1.0

FILES=$(METADATA) runtest.sh Makefile PURPOSE

.PHONY: run
run: $(FILES)
	./runtest.sh

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Beaker Developers <beaker-devel@lists.fedorahosted.org>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     Produces a single Skip result" >> $(METADATA)
	@echo "Type:            Sanity" >> $(METADATA)
	@echo "TestTime:        10m" >> $(METADATA)
	@echo "RunFor:          beaker" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	rhts-lint $(METADATA)
