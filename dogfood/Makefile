# Copyright (c) 2010 Red Hat, Inc. All rights reserved. This copyrighted material 
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Dan Callaghan <dcallagh@redhat.com>

TOPLEVEL_NAMESPACE=distribution
PACKAGE_NAME=beaker
RELATIVE_PATH=dogfood
export TESTVERSION=1.3
export TEST=/$(TOPLEVEL_NAMESPACE)/$(PACKAGE_NAME)/$(RELATIVE_PATH)

.PHONY: all install clean

# executables to be built should be added here, they will be generated on the system under test.
BUILT_FILES= 

# data files, .c files, scripts anything needed to either compile the test and/or run it.
FILES=$(METADATA) runtest.sh update-config.sh Makefile PURPOSE

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh

clean:
	rm -f *~ *.rpm $(BUILT_FILES)

# Include Common Makefile
include /usr/share/rhts/lib/rhts-make.include

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
	@echo "Owner:        Dan Callaghan <dcallagh@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)"	>> $(METADATA)
	@echo "License:      GPL-2" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"	>> $(METADATA)
	@echo "Description:  Runs Beaker's internal test suite" >> $(METADATA)
	@echo "TestTime:     6h" >> $(METADATA)
	@echo "Requires:     $(PACKAGE_NAME)-integration-tests" >> $(METADATA)
	@echo "Requires:     python-nose" >> $(METADATA)  
#	@echo "Environment:  BEAKER_SKIP_INIT_DB=1" >> $(METADATA)
	@echo "Environment:  BEAKER_CONFIG_FILE=/etc/beaker/server.cfg" >> $(METADATA)
	@echo "Environment:  BEAKER_LABCONTROLLER_CONFIG_FILE=/etc/beaker/labcontroller.conf" >> $(METADATA)
	@echo "Environment:  BEAKER_CLIENT_COMMAND=bkr" >> $(METADATA)
	@echo "Environment:  BEAKER_WIZARD_COMMAND=beaker-wizard" >> $(METADATA)
	@echo "Environment:  PACKAGES_TO_TEST=bkr.inttest" >> $(METADATA)

	rhts-lint $(METADATA)
