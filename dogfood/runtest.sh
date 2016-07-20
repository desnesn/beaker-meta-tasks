#!/bin/bash

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

. /usr/bin/rhts-environment.sh

function run() {
    phase="$1"
    shift
    echo -n "Running $phase ... "
    OUTPUTFILE="./${phase}.log"
    "$@" 2>&1 | tee "$OUTPUTFILE"
    if [ "${PIPESTATUS[0]}" -eq 0 ] ; then
        result=PASS
    else
        result=FAIL
    fi
    echo "$result"
    report_result "$TEST/$phase" "$result"
}

run beakerd_stop /sbin/service beakerd stop
if [[ "$SOURCE" == "git" ]] ; then
    run yum_install_git yum install -y /mnt/testarea/beaker/rpmbuild-output/noarch/beaker-integration-tests-*.rpm
else
    run yum_install yum install -y beaker-integration-tests$VERSION
fi
run create_migration_test_db mysql -u root -e "CREATE DATABASE beaker_migration_test; GRANT ALL ON beaker_migration_test.* TO beaker@localhost;"
run update_config ./update-config.sh

if echo $SERVERS | grep -q $(hostname -f) ; then
    echo "Running with remote lab controller: ${CLIENTS}"
    export BEAKER_LABCONTROLLER_HOSTNAME="${CLIENTS}"
else
    echo "Running in single-host mode"
    export BEAKER_LABCONTROLLER_HOSTNAME="$(hostname -f)"
fi

# Beaker 22 switched to py.test instead of nose. The bkr.inttest.conftest
# module is a pytest local plugin, so we can use its presence as an indication
# that we should be running py.test. If it's absent we fall back to nose to
# support older Beaker branches.
if python -c 'import bkr.inttest.conftest' 2>/dev/null ; then
    echo "Running tests with py.test"
    run tests /usr/bin/time py.test -v --pyargs $PACKAGES_TO_TEST
else
    echo "Running tests with nose"
    if [ -n "$COLLECT_COVERAGE" ] ; then
        run tests /usr/bin/time \
            python -c '__requires__ = ["CherryPy < 3.0"]; import pkg_resources; from nose.core import main; main()' \
            -v --logging-format='%(asctime)s %(name)s %(levelname)s %(message)s' \
            --with-coverage --cover-package=bkr --cover-erase --cover-html --cover-html-dir=covhtml --cover-xml \
            $PACKAGES_TO_TEST
    else
        run tests /usr/bin/time \
            python -c '__requires__ = ["CherryPy < 3.0"]; import pkg_resources; from nose.core import main; main()' \
            -v --logging-format='%(asctime)s %(name)s %(levelname)s %(message)s' \
            $PACKAGES_TO_TEST
    fi
fi

echo "Checking for leaked browser processes"
if ps -ww -lf -Cfirefox >firefox-ps.out ; then
    rhts-report-result $TEST/browser_leak FAIL firefox-ps.out
fi

if [ -n "$COLLECT_COVERAGE" ] ; then
    for f in ./covhtml/*; do
        rhts-submit-log -l $f
    done
    rhts-submit-log -l ./coverage.xml
fi
rhts-submit-log -l /var/log/beaker/server-errors.log
rhts-submit-log -l /var/log/beaker/server-debug.log
rhts-submit-log -l /var/log/httpd/access_log
rhts-submit-log -l /var/log/httpd/error_log
