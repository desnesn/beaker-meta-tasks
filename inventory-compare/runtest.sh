#!/bin/bash

set -e

. /usr/bin/rhts-environment.sh
. /usr/share/beakerlib/beakerlib.sh


rlJournalStart

rlPhaseStartSetup

# For RHEL 5
rlRun -c "yum -y install python-simplejson || true"

# git clone beaker's lshw fork
rlRun -c "git clone git://git.beaker-project.org/lshw"
pushd lshw
rlRun -c "yum -y install docbook-utils gcc-c++ make"
rlRun -c "make install"
popd

# For debugging later
rlRun -c "lshw -xml -numeric > lshw-xml.out"

# install smolt, python-linux-procfs
rlRun -c "yum -y install smolt python-linux-procfs"

# beaker-system-scan
rlRun -c "git clone git://git.beaker-project.org/beaker-system-scan"
pushd beaker-system-scan
rlRun -c "make" # for hvm_detect
# master is using smolt
PYTHONPATH=. python systemscan/main.py -d > smolt.out
smolt=`PYTHONPATH=. python systemscan/main.py -d -j 2> /dev/null`
# lshw branch
git checkout lshw
PYTHONPATH=. python systemscan/main.py -d > lshw.out
lshw=`PYTHONPATH=. python systemscan/main.py -d -j 2> /dev/null`
popd

rlPhaseEnd

# For debugging later
cat /proc/cpuinfo > proc_cpuinfo

rlPhaseStartTest
rlRun -c './compare.py "$smolt" "$lshw"'
rlFileSubmit beaker-system-scan/smolt.out
rlFileSubmit lshw-xml.out
rlFileSubmit beaker-system-scan/lshw.out
rlFileSubmit comparison.html
rlFileSubmit proc_cpuinfo
rlPhaseEnd

rlJournalPrintText

rlJournalEnd
